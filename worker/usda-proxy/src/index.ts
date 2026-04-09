import { Hono } from 'hono'
import type { Context } from 'hono'
import { OpenFoodFactsClientError } from './openFoodFacts'
import { searchPackagedFoods } from './packagedFoods'
import type { SearchProvider, USDAProxyErrorResponse } from './types'
import { USDAClientError, searchUSDAFoods } from './usda'

const app = new Hono<{ Bindings: Env }>()
const CACHE_TTL_SECONDS = 300
const MAX_PAGE = 10
const MAX_PAGE_SIZE = 25
const MIN_QUERY_LENGTH = 2
const SEARCH_QUERY_KEYS = new Set(['q', 'page', 'pageSize'])
const PACKAGED_SEARCH_QUERY_KEYS = new Set([...SEARCH_QUERY_KEYS, 'fallbackOnEmpty', 'provider'])

app.get('/v1/packaged-foods/search', async (c) => {
  const params = parseSearchParams(c, PACKAGED_SEARCH_QUERY_KEYS, true)
  if (params instanceof Response) {
    return params
  }

  const cache = await caches.open('usda-proxy')
  const cacheKey = buildCacheKey(new URL(c.req.url), '/v1/packaged-foods/search', [
    ['q', params.query.toLowerCase()],
    ['page', String(params.page)],
    ['pageSize', String(params.pageSize)],
    ['fallbackOnEmpty', params.fallbackOnEmpty ? '1' : '0'],
    ['provider', params.provider ?? ''],
  ])
  const cachedResponse = await cache.match(cacheKey)
  if (cachedResponse != null) {
    return cachedResponse
  }

  try {
    const response = await searchPackagedFoods(params, c.env.USDA_API_KEY)
    const jsonResponse = c.json(response)
    jsonResponse.headers.set('Cache-Control', `public, s-maxage=${CACHE_TTL_SECONDS}`)
    c.executionCtx.waitUntil(cache.put(cacheKey, jsonResponse.clone()))
    return jsonResponse
  } catch (error) {
    return handleSearchError(error, 'Packaged food search is unavailable right now.')
  }
})

app.get('/v1/usda/search', async (c) => {
  const params = parseSearchParams(c, SEARCH_QUERY_KEYS, false)
  if (params instanceof Response) {
    return params
  }

  const cache = await caches.open('usda-proxy')
  const cacheKey = buildCacheKey(new URL(c.req.url), '/v1/usda/search', [
    ['q', params.query.toLowerCase()],
    ['page', String(params.page)],
    ['pageSize', String(params.pageSize)],
  ])
  const cachedResponse = await cache.match(cacheKey)
  if (cachedResponse != null) {
    return cachedResponse
  }

  try {
    const response = await searchUSDAFoods(params, c.env.USDA_API_KEY)
    const jsonResponse = c.json(response)
    jsonResponse.headers.set('Cache-Control', `public, s-maxage=${CACHE_TTL_SECONDS}`)
    c.executionCtx.waitUntil(cache.put(cacheKey, jsonResponse.clone()))
    return jsonResponse
  } catch (error) {
    return handleSearchError(error, 'USDA search is unavailable right now.')
  }
})

app.notFound((c) => jsonError(c, 'Not found.', 404))

app.onError((error) => handleSearchError(error, 'Packaged food search is unavailable right now.'))

function parseSearchParams(c: Context, allowedKeys: Set<string>, allowFallbackOnEmpty: boolean) {
  const url = new URL(c.req.url)
  const invalidKeys = [...new Set(url.searchParams.keys())].filter((key) => allowedKeys.has(key) === false)
  if (invalidKeys.length > 0) {
    return jsonError(c, 'Unsupported query parameters.', 400)
  }

  const query = (c.req.query('q') ?? '').trim()
  if (query.length < MIN_QUERY_LENGTH) {
    return jsonError(c, 'Enter at least 2 characters to search packaged foods.', 400)
  }

  const page = parseBoundedPositiveInt(c.req.query('page') ?? '1', MAX_PAGE)
  if (page == null) {
    return jsonError(c, `Page must be between 1 and ${MAX_PAGE}.`, 400)
  }

  const pageSize = parseBoundedPositiveInt(c.req.query('pageSize') ?? '12', MAX_PAGE_SIZE)
  if (pageSize == null) {
    return jsonError(c, `Page size must be between 1 and ${MAX_PAGE_SIZE}.`, 400)
  }

  const fallbackOnEmpty = allowFallbackOnEmpty ? parseBooleanFlag(c.req.query('fallbackOnEmpty') ?? '1') : false
  if (allowFallbackOnEmpty && fallbackOnEmpty == null) {
    return jsonError(c, 'fallbackOnEmpty must be 0, 1, true, or false.', 400)
  }

  const provider = allowFallbackOnEmpty ? parseSearchProvider(c.req.query('provider')) : undefined
  if (allowFallbackOnEmpty && c.req.query('provider') != null && provider == null) {
    return jsonError(c, 'provider must be openFoodFacts or usda.', 400)
  }

  if (allowFallbackOnEmpty && page > 1 && provider == null) {
    return jsonError(c, 'provider is required for packaged food search pages after page 1.', 400)
  }

  return {
    query,
    page,
    pageSize,
    fallbackOnEmpty: fallbackOnEmpty ?? false,
    provider,
  }
}

function parseBoundedPositiveInt(value: string, max: number): number | null {
  if (/^\d+$/.test(value) === false) {
    return null
  }

  const parsed = Number.parseInt(value, 10)
  return Number.isInteger(parsed) && parsed > 0 && parsed <= max ? parsed : null
}

function parseBooleanFlag(value: string): boolean | null {
  if (value === '1' || value.toLowerCase() === 'true') {
    return true
  }

  if (value === '0' || value.toLowerCase() === 'false') {
    return false
  }

  return null
}

function parseSearchProvider(value: string | undefined): SearchProvider | undefined {
  if (value == null) {
    return undefined
  }

  if (value === 'openFoodFacts' || value === 'usda') {
    return value
  }

  return undefined
}

function buildCacheKey(url: URL, path: string, queryItems: Array<[string, string]>): Request {
  const cacheURL = new URL(url.origin)
  cacheURL.pathname = path
  for (const [key, value] of queryItems) {
    cacheURL.searchParams.set(key, value)
  }
  return new Request(cacheURL.toString(), { method: 'GET' })
}

function handleSearchError(error: unknown, fallbackMessage: string) {
  if (error instanceof USDAClientError || error instanceof OpenFoodFactsClientError) {
    return jsonError(undefined, error.message, error.status)
  }

  console.error('Unhandled Worker search error')
  return jsonError(undefined, fallbackMessage, 503)
}

function jsonError(_c: Context | undefined, message: string, status: number) {
  const body: USDAProxyErrorResponse = { error: message }
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
  })
}

export default app
