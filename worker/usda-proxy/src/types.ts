export type SearchProvider = 'openFoodFacts' | 'usda'

export interface OpenFoodFactsProxyProduct {
  externalProductID?: string
  code?: string
  product_name?: string
  brands?: string
  serving_size?: string
  serving_quantity?: number
  serving_quantity_unit?: string
  quantity?: string
  nutriments?: OpenFoodFactsProxyNutriments
  url?: string
}

export interface OpenFoodFactsProxyNutriments {
  'energy-kcal_serving'?: number
  'proteins_serving'?: number
  'fat_serving'?: number
  'carbohydrates_serving'?: number
  'energy-kcal_100g'?: number
  'proteins_100g'?: number
  'fat_100g'?: number
  'carbohydrates_100g'?: number
}

export interface USDAProxyFoodResult {
  id: string
  fdcId: number
  name: string
  brand?: string
  servingDescription: string
  gramsPerServing?: number
  caloriesPerServing: number
  proteinPerServing: number
  fatPerServing: number
  carbsPerServing: number
  sourceName: string
  sourceURL: string
  barcode?: string
}

export type PackagedFoodSearchResult =
  | {
      provider: 'openFoodFacts'
      item: OpenFoodFactsProxyProduct
    }
  | {
      provider: 'usda'
      item: USDAProxyFoodResult
    }

export interface PackagedFoodSearchResponse {
  query: string
  page: number
  pageSize: number
  resolvedProvider?: SearchProvider
  results: PackagedFoodSearchResult[]
  hasMore: boolean
}

export interface PackagedFoodSearchQuery {
  query: string
  page: number
  pageSize: number
  fallbackOnEmpty: boolean
  provider?: SearchProvider
}

export interface USDAProxySearchResponse {
  query: string
  page: number
  pageSize: number
  provider: 'USDA FoodData Central'
  results: USDAProxyFoodResult[]
  hasMore: boolean
}

export interface USDAProxyErrorResponse {
  error: string
}

export interface ProviderPage<T> {
  query: string
  page: number
  pageSize: number
  results: T[]
  hasMore: boolean
}
