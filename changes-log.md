# Changes Log

`changes-log.md` is the canonical project history file for implemented work, bugs found, decisions made, and validation results.

## History and Calendar

### Delivered

- Reworked History to feel closer to Apple's Fitness-style flow.
- Replaced the old navigation-title setup with a custom top bar.
- Replaced the old date navigator with a compact week strip.
- Kept calendar expansion inline inside the same card.
- Reused the shared macro ring renderer for compact weekday rings.
- Extended summary plumbing so the week strip uses shared per-day nutrition snapshots.

### Main implementation steps

- `HistoryScreen.swift` now owns the custom header, selected date, and calendar expansion state.
- `HistoryWeekCard`, `HistoryWeekStrip`, and `HistoryWeekdayCell` keep the week selector and inline calendar inside one glass container.
- `LogEntryDaySummary.swift` and `ModelSupport.swift` were extended instead of adding screen-local date logic.
- `LogEntryListSection.swift` was updated so History can hide duplicate header context.

### Bug fixed

- Calendar selection could crash when leaving History after interacting with the iOS inline calendar.
- Cause: the custom `UICalendarView` bridge introduced a UIKit/SwiftUI teardown problem after selection.
- Fix: removed the bridge from `HistoryCalendarView.swift` and used SwiftUI's graphical `DatePicker` on iOS with normalized start-of-day binding.

## Scan Flows

### Delivered

- Added barcode scan entry from `AddFoodScreen`.
- Added nutrition label scan entry from `AddFoodScreen`.
- Added live barcode scanning with `VisionKit.DataScannerViewController` where supported.
- Added still-image barcode fallback with `VNDetectBarcodesRequest`.
- Added OCR-based label scanning with `VNRecognizeTextRequest`.
- Kept `FoodDraft` as the only editable contract and `LogFoodScreen` as the only review/logging surface.
- Reused `FoodItemRepository` for local cache lookup and reusable-food persistence.
- Added Settings editing support for scan-derived reusable foods.

### Main implementation steps

- Lowered device targeting to strict iPhone and aligned the project with iOS-first validation.
- Added camera and photo-library usage descriptions.
- Extended `FoodSource`, `FoodItem`, and `FoodDraft` only where scan provenance required it.
- Built local-first barcode resolution: local cache first, then Open Food Facts, then editable review.
- Built conservative nutrition label parsing without inventing hidden gram conversions or nutrients.
- Kept scan capture, recognition, parsing, mapping, and persistence as separate responsibilities.

### Bugs and implementation findings

- iOS 16 deployment target was not viable because the existing app already relied on SwiftData, Observation, and `ContentUnavailableView`; deployment target was corrected to iOS 17.
- A shared `PhotosPickerItem` abstraction added compile friction and unnecessary indirection; picker handling was moved back into the screens.
- Duplicate camera/photo glue between barcode and label flows was reduced by extracting `ScanCameraCaptureSheet.swift`.
- Barcode symbology support initially used unsupported assumptions around `.upca`; the implementation was corrected to `.ean13`, `.ean8`, and `.upce`, and `Vision` imports were fixed.
- Barcode save flow could crash because a temporary SwiftData identifier escaped an isolated context; the repository now returns stable app IDs and reloads in the main context.
- Barcode nutrient mapping originally mixed per-serving and per-100g bases; mapping was changed to use one consistent nutrition basis.
- Label scan originally paused on an unnecessary intermediate review step; the flow now goes straight into `LogFoodScreen`.
- Today-list quick actions were moved onto native list rows so swipe behavior is actually native.

### Validation recorded during scan work

- iOS simulator builds passed.
- Duplicate blocks, tech debt, dependency inventory, and n+1 smoke checks passed.
- At that stage, formatter and dead-code commands were present in the repo but the required local tools were not yet installed, so those scripts skipped cleanly.

## Food Search

### Delivered

- Improved on-device food search quality.
- Added packaged-food text search.
- Kept `AddFoodScreen` as the single search surface.
- Kept `FoodDraft` as the single review contract.
- Kept `LogFoodScreen` as the single review/log destination.
- Kept `FoodItemRepository` as the single reusable-food persistence path.
- Added `FoodSource.searchLookup` for remote text-search provenance.
- Kept remote search rows transient until the user selects and saves/logs a result.
- Kept one saved externally-derived foods area in Settings rather than splitting scan vs search.

### Main implementation steps

- Improved deterministic on-device ranking: exact match, then prefix, then token containment.
- Preserved durable normalized search terms so edits do not silently weaken local search.
- Extended Open Food Facts text search with explicit submit-driven queries and bounded pagination.
- Reused shared remote-to-`FoodDraft` mapping rather than creating a second edit flow.
- Split supporting Add Food views into `AddFoodComponents.swift` and `AddFoodSearchResults.swift` when `AddFoodScreen.swift` exceeded the repo's file-size guardrail.

### Bugs and implementation findings

- `FoodItemRepository` originally deduped by local ID or barcode but not by `(source, externalProductID)`; that gap was closed so selected remote foods reuse the same saved record.
- `FoodItem.searchableText` had a durability risk around aliases during normalization updates; persistence now retains durable normalized search terms.
- Open Food Facts search constraints required submit-driven UX rather than search-as-you-type.
- Restaurant search was intentionally removed from scope to keep the implementation focused and maintainable.

### Validation recorded during food-search work

- iOS simulator `xcodebuild` passed.
- `make quality-build`, `quality-dup`, `quality-debt`, `quality-deps`, and `quality-n1` passed.
- At that stage, `quality-format-check` and `quality-dead` still depended on tooling that was not yet installed locally.

## USDA Proxy and Unified Remote Search

### Delivered

- Added a Bun-managed Cloudflare Worker under `worker/usda-proxy/`.
- Used Hono as a thin routing layer.
- Added a unified `GET /v1/packaged-foods/search` endpoint.
- Kept `GET /v1/usda/search` for direct validation.
- Moved packaged-food text search behind the Worker while leaving barcode lookup client-side.
- Kept Open Food Facts as the primary provider and USDA as bounded fallback.
- Added worker-side timeout, retry, fallback, and short-lived edge caching.
- Added a thin app-side `PackagedFoodSearchClient.swift`.
- Reused a small shared `RemoteSearchResult` wrapper for OFF and USDA results.
- Persisted selected USDA/OFF results using provider-qualified external IDs.

### Main implementation steps

- Added committed Worker config and source files: `package.json`, `tsconfig.json`, `wrangler.jsonc`, `.dev.vars.example`, `src/index.ts`, `src/openFoodFacts.ts`, `src/packagedFoods.ts`, `src/usda.ts`, and `src/types.ts`.
- Declared `USDA_API_KEY` as a required Worker secret and kept it out of app code and repo files.
- Normalized Worker responses to a small app-facing contract instead of shipping raw provider payloads.
- Kept one app-level request path for remote packaged-food search so the app no longer owns OFF-vs-USDA branching.
- Stored the Worker base URL in one generated Info.plist key, `USDA_PROXY_BASE_URL`.

### Bugs and implementation findings

- Bun was standardized for the Worker to avoid mixed package managers.
- With `nodejs_compat`, Wrangler needed `@types/node`; installing it early avoided a failed first check.
- Cache typing did not behave as the first draft expected with `caches.default`, so the Worker now uses `caches.open("usda-proxy")`.
- `secrets.required` works for this setup but still emits an experimental warning during `wrangler types`.
- Page-2 empty Open Food Facts results originally widened to USDA, which would have created mixed-provider pagination; that regression was fixed so only the right request shapes widen.

### Validation recorded during USDA proxy work

- Worker type checks passed with Bun.
- Invalid query requests returned stable `400` JSON errors.
- Mocked Open Food Facts success returned normalized `openFoodFacts` results.
- Mocked Open Food Facts empty responses widened correctly to normalized USDA results when enabled.
- Local `bun run dev` worked with a real USDA key and real packaged-food queries.
- iOS simulator builds and repo quality commands passed.

### Still open operational follow-ups

- Set the production `USDA_API_KEY` Worker secret.
- Deploy the Worker.
- Record the public `workers.dev` URL used by the app.
- Validate deployed responses, cold-cache behavior, and public cache-hit behavior.

## Settings and General UX Follow-ups

### Delivered

- Fixed Settings macro inputs so a single row tap focuses more reliably.
- Added an iOS trailing-caret numeric input bridge so the insertion point appears at the end instead of the beginning.
- Made the Settings save row fully tappable instead of only the `Save` text.
- Ran a Settings-focused SwiftUI review pass; the result was LGTM.

### Main implementation steps

- Updated `NutrientInputField.swift` to make the whole row tappable and adapt focus handling cleanly.
- Added `TrailingCaretNumericTextField.swift` as a small `UIViewRepresentable` escape hatch for iOS numeric entry.
- Updated `DailyGoalsSection.swift` so the full save row acts as the button target.

## Branding and App Configuration

### Delivered

- Updated the user-facing app name to `MACROS`.
- Added `CFBundleDisplayName` and updated `CFBundleName` in both `Info-iOS.plist` and `Info-macOS.plist`.

## Quality, Cleanup, and Review

### Delivered

- Ran multiple focused review passes over the working tree and Settings-specific changes.
- Installed Periphery, then upgraded the local CLI to 3.7.2 when Homebrew lagged behind.
- Updated `.periphery.yml` for Periphery 3 compatibility.
- Updated `make quality-dead` and `tools/quality/run_periphery.sh` so Periphery scans the iOS simulator destination.
- Removed genuinely unused code surfaced by Periphery.
- Marked preview-only helpers with `// periphery:ignore` where the code is intentionally retained.

### Bugs and implementation findings

- Periphery initially produced false positives because it scanned the multiplatform scheme without an explicit iOS destination.
- The root fix was to pass `-destination "generic/platform=iOS Simulator"` through the wrapper instead of suppressing warnings.
- After the destination fix, the remaining findings were validated symbol-by-symbol and either removed or intentionally ignored for preview-only usage.

### Final validation state

- `make quality-format-check` passes.
- iOS simulator build passes.
- macOS build passes.
- Worker TypeScript/Bun checks pass.
- `make quality-dead` reports `No unused code detected.`
- Focused review pass on the Periphery cleanup returned LGTM.

## Deferred Work

- Forward edge-swipe navigation from Home into History/calendar was analyzed but intentionally deferred to a later commit because iOS does not provide a native forward interactive edge push equivalent to the back swipe.

## Consolidated Source Docs

The following planning documents have been fully consolidated into this file and can be removed safely:

- `scan-implementation-plan.md`
- `food-search-implementation-plan.md`
- `usda-proxy-implementation-plan.md`
