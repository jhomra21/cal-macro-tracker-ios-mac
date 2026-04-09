import { OpenFoodFactsClientError, searchOpenFoodFactsFoods } from './openFoodFacts'
import type { PackagedFoodSearchQuery, PackagedFoodSearchResponse, ProviderPage, SearchProvider } from './types'
import { searchUSDAFoods } from './usda'

const OPEN_FOOD_FACTS_PROVIDER = 'openFoodFacts' as const
const USDA_PROVIDER = 'usda' as const
const REQUEST_TIMEOUT_MS = 4_000
const MAX_RETRY_ATTEMPTS = 2

export async function searchPackagedFoods(
  input: PackagedFoodSearchQuery,
  apiKey: string,
  fetcher: typeof fetch = fetch,
): Promise<PackagedFoodSearchResponse> {
  if (input.provider === OPEN_FOOD_FACTS_PROVIDER) {
    return searchOpenFoodFactsPackagedFoods(input, fetcher)
  }

  if (input.provider === USDA_PROVIDER) {
    return searchUSDAPackagedFoods(input, apiKey, fetcher)
  }

  try {
    const openFoodFactsResult = await searchOpenFoodFactsBeforeUSDA(input, fetcher)
    if (openFoodFactsResult != null) {
      return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, openFoodFactsResult)
    }
  } catch {
  }

  return searchUSDAPackagedFoods(input, apiKey, fetcher)
}

async function searchOpenFoodFactsBeforeUSDA(
  input: PackagedFoodSearchQuery,
  fetcher: typeof fetch,
): Promise<ProviderPage<PackagedFoodSearchResponse['results'][number]> | null> {
  const result = await searchOpenFoodFactsWithRetry(input, fetcher)
  if (shouldUseOpenFoodFactsResult(input, result)) {
    return result
  }

  return null
}

async function searchOpenFoodFactsWithRetry(
  input: PackagedFoodSearchQuery,
  fetcher: typeof fetch,
): Promise<ProviderPage<PackagedFoodSearchResponse['results'][number]>> {
  let lastError: OpenFoodFactsClientError | Error | null = null

  for (let attempt = 0; attempt < MAX_RETRY_ATTEMPTS; attempt += 1) {
    try {
      const result = await searchOpenFoodFactsFoods(input, withTimeout(fetcher, REQUEST_TIMEOUT_MS))
      return {
        ...result,
        results: result.results.map((item) => ({ provider: OPEN_FOOD_FACTS_PROVIDER, item })),
      }
    } catch (error) {
      lastError = error instanceof Error ? error : new Error('Unknown Open Food Facts error')
      if (shouldRetryOpenFoodFacts(error) === false || attempt + 1 >= MAX_RETRY_ATTEMPTS) {
        break
      }
    }
  }

  if (lastError instanceof OpenFoodFactsClientError) {
    throw lastError
  }

  throw new OpenFoodFactsClientError('Open Food Facts is unavailable right now.', 503, true)
}

async function searchOpenFoodFactsPackagedFoods(
  input: PackagedFoodSearchQuery,
  fetcher: typeof fetch,
): Promise<PackagedFoodSearchResponse> {
  const result = await searchOpenFoodFactsWithRetry(input, fetcher)
  return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, result)
}

async function searchUSDAPackagedFoods(
  input: PackagedFoodSearchQuery,
  apiKey: string,
  fetcher: typeof fetch,
): Promise<PackagedFoodSearchResponse> {
  const result = await searchUSDAFoods(input, apiKey, withTimeout(fetcher, REQUEST_TIMEOUT_MS))
  return makeResponse(input, USDA_PROVIDER, {
    ...result,
    results: result.results.map((item) => ({ provider: USDA_PROVIDER, item })),
  })
}

function shouldFallbackOnEmpty(input: PackagedFoodSearchQuery): boolean {
  return input.fallbackOnEmpty && input.page === 1
}

function shouldUseOpenFoodFactsResult(
  input: PackagedFoodSearchQuery,
  page: ProviderPage<PackagedFoodSearchResponse['results'][number]>,
): boolean {
  return page.results.length > 0 || page.hasMore || shouldFallbackOnEmpty(input) === false
}

function makeResponse(
  input: PackagedFoodSearchQuery,
  provider: SearchProvider,
  page: ProviderPage<PackagedFoodSearchResponse['results'][number]>,
): PackagedFoodSearchResponse {
  return {
    query: input.query,
    page: page.page,
    pageSize: page.pageSize,
    resolvedProvider: provider,
    results: page.results,
    hasMore: page.hasMore,
  }
}

function shouldRetryOpenFoodFacts(error: unknown): boolean {
  if (error instanceof OpenFoodFactsClientError) {
    return error.retryable
  }

  return error instanceof DOMException || error instanceof TypeError
}

function withTimeout(fetcher: typeof fetch, timeoutMs: number): typeof fetch {
  return (input, init) => {
    const timeoutSignal = AbortSignal.timeout(timeoutMs)
    const signal = init?.signal == null ? timeoutSignal : AbortSignal.any([init.signal, timeoutSignal])
    return fetcher(input, { ...init, signal })
  }
}
