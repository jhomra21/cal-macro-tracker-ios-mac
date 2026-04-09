import type { USDAProxyFoodResult, USDAProxySearchResponse } from './types'

const USDA_SEARCH_URL = 'https://api.nal.usda.gov/fdc/v1/foods/search'
const USDA_PROVIDER_NAME = 'USDA FoodData Central' as const
const BRANDED_DATA_TYPE = 'Branded'
const MAX_PAGE = 10
const CACHE_TTL_SECONDS = 300

const NUTRIENT_IDS = {
  calories: 1008,
  protein: 1003,
  fat: 1004,
  carbs: 1005,
} as const

interface USDAFoodSearchResponse {
  foods?: USDAFood[]
  totalHits?: number
}

interface USDAFood {
  fdcId?: number
  description?: string
  brandName?: string
  brandOwner?: string
  gtinUpc?: string
  servingSize?: number
  servingSizeUnit?: string
  householdServingFullText?: string
  foodNutrients?: USDAFoodNutrient[]
}

interface USDAFoodNutrient {
  nutrientId?: number
  value?: number
}

export class USDAClientError extends Error {
  readonly status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'USDAClientError'
    this.status = status
  }
}

export interface USDAQuery {
  query: string
  page: number
  pageSize: number
}

export async function searchUSDAFoods(
  input: USDAQuery,
  apiKey: string,
  fetcher: typeof fetch = fetch,
): Promise<USDAProxySearchResponse> {
  const response = await fetcher(buildSearchURL(apiKey), {
    method: 'POST',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      query: input.query,
      dataType: [BRANDED_DATA_TYPE],
      pageNumber: input.page,
      pageSize: input.pageSize,
    }),
    cf: {
      cacheTtl: CACHE_TTL_SECONDS,
      cacheEverything: true,
    },
  })

  if (response.status === 401 || response.status === 403) {
    throw new USDAClientError('USDA search is unavailable right now.', 503)
  }

  if (response.status === 429) {
    throw new USDAClientError('USDA search is temporarily busy. Please try again shortly.', 503)
  }

  if (response.ok === false) {
    throw new USDAClientError('USDA search is unavailable right now.', 503)
  }

  const decoded = (await response.json()) as USDAFoodSearchResponse
  const foods = decoded.foods ?? []
  const results = foods
    .map(makeProxyFoodResult)
    .filter((value): value is USDAProxyFoodResult => value != null)
  const totalHits = decoded.totalHits ?? 0
  const hasMore = input.page < MAX_PAGE && input.page * input.pageSize < totalHits

  return {
    query: input.query,
    page: input.page,
    pageSize: input.pageSize,
    provider: USDA_PROVIDER_NAME,
    results,
    hasMore,
  }
}

function buildSearchURL(apiKey: string): string {
  const url = new URL(USDA_SEARCH_URL)
  url.searchParams.set('api_key', apiKey)
  return url.toString()
}

function makeProxyFoodResult(food: USDAFood): USDAProxyFoodResult | null {
  const fdcId = food.fdcId
  const name = food.description?.trim()
  const servingDescription = makeServingDescription(food)
  const calories = nutrientValue(food, NUTRIENT_IDS.calories)
  const protein = nutrientValue(food, NUTRIENT_IDS.protein)
  const fat = nutrientValue(food, NUTRIENT_IDS.fat)
  const carbs = nutrientValue(food, NUTRIENT_IDS.carbs)

  if (fdcId == null || Number.isFinite(fdcId) === false) {
    return null
  }

  if (name == null || name.length === 0) {
    return null
  }

  if ([calories, protein, fat, carbs].some((value) => value == null)) {
    return null
  }

  const safeCalories = calories!
  const safeProtein = protein!
  const safeFat = fat!
  const safeCarbs = carbs!

  return {
    id: `usda:${fdcId}`,
    fdcId,
    name,
    brand: firstNonEmpty(food.brandOwner, food.brandName),
    servingDescription,
    gramsPerServing: gramsPerServing(food),
    caloriesPerServing: safeCalories,
    proteinPerServing: safeProtein,
    fatPerServing: safeFat,
    carbsPerServing: safeCarbs,
    sourceName: USDA_PROVIDER_NAME,
    sourceURL: `https://fdc.nal.usda.gov/food-details/${fdcId}`,
    barcode: normalizedText(food.gtinUpc),
  }
}

function nutrientValue(food: USDAFood, nutrientId: number): number | null {
  const nutrient = food.foodNutrients?.find((candidate) => candidate.nutrientId === nutrientId)
  const value = nutrient?.value
  return typeof value === 'number' && Number.isFinite(value) ? value : null
}

function makeServingDescription(food: USDAFood): string {
  const householdServing = normalizedText(food.householdServingFullText)
  if (householdServing != null) {
    return householdServing
  }

  const servingSize = food.servingSize
  const servingSizeUnit = normalizedText(food.servingSizeUnit)
  if (typeof servingSize === 'number' && Number.isFinite(servingSize) && servingSize > 0 && servingSizeUnit != null) {
    return `${roundForDisplay(servingSize)} ${servingSizeUnit}`
  }

  return '1 serving'
}

function gramsPerServing(food: USDAFood): number | undefined {
  const servingSize = food.servingSize
  const servingSizeUnit = normalizedText(food.servingSizeUnit)?.toLowerCase()
  if (typeof servingSize !== 'number' || Number.isFinite(servingSize) === false || servingSize <= 0) {
    return undefined
  }

  if (servingSizeUnit === 'g' || servingSizeUnit === 'gram' || servingSizeUnit === 'grams') {
    return servingSize
  }

  return undefined
}

function normalizedText(value: string | undefined): string | undefined {
  const trimmed = value?.trim()
  return trimmed == null || trimmed.length === 0 ? undefined : trimmed
}

function firstNonEmpty(...values: Array<string | undefined>): string | undefined {
  return values.map(normalizedText).find((value) => value != null)
}

function roundForDisplay(value: number): string {
  return Math.abs(Math.round(value) - value) < 0.01 ? String(Math.round(value)) : value.toFixed(1)
}
