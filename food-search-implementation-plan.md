# Food Search Implementation Plan

This file is the working implementation checklist for on-device food search and online packaged-food text search.

Rules for this plan:
- Keep changes aligned with `AGENTS.md`, `SOFTWARE_PATTERNS.md`, and `code-simplifier.md`.
- Reuse existing code paths before adding new ones.
- Do not introduce duplicate models, duplicate editors, or parallel persistence flows.
- Mark completed work with `[x]`.
- Keep incomplete work as `[ ]`.
- When a checklist item is completed, update this file immediately.
- Record bugs, dead ends, decisions, and weird behavior in the notes section so the same mistakes are not repeated.
- If a decision closes an open question, document the decision here and remove or rewrite the outdated alternative.

## Tracking Conventions

- Use `[x]` only for work that is actually implemented and verified.
- If something is partially done or blocked, keep it as `[ ]` and add a note explaining the blocker.
- For significant implementation decisions, add a dated note with the files touched.
- For bugs or unexpected behavior, add a dated note with:
  - what happened
  - where it happened
  - what caused it if known
  - how it was resolved, or what remains open

## Ground Truth From Current Codebase

- `Features/AddFood/AddFoodScreen.swift` currently supports only local in-memory search over the `foods` array passed into the screen.
- `Features/Dashboard/DashboardScreen.swift` provides that food array from `@Query(sort: \FoodItem.name)`, so food search is not repository-backed yet.
- `FoodItem.searchableText` already exists and is the current local search surface.
- `FoodDraft` is already the review/edit contract and should remain the single editable contract for search-derived data before logging.
- `LogFoodScreen` is already the confirmation/edit/logging flow and should be reused instead of building a parallel search-result editor.
- `FoodItemRepository` is already the reusable food persistence path and should be extended instead of bypassed.
- `LogEntryRepository` already persists nutrition snapshots for consumed entries and should remain snapshot-based.
- Barcode lookup already follows the shape we want to reuse for remote packaged-food search: local cache check -> Open Food Facts fetch -> map to `FoodDraft` -> save locally -> review in `LogFoodScreen`.
- `FoodItem` already stores provenance fields that should be reused for search flows: `source`, `barcode`, `externalProductID`, `sourceName`, and `sourceURL`.
- There is currently no remote text-search pipeline for food names, brands, or product catalogs.
- Settings currently expose saved custom foods and saved scan foods, but not common foods.

## Scope Locked Before Coding

- [x] Current implementation scope is on-device search improvements plus online packaged-food text search.
- [x] Restaurant search is not part of this implementation plan.
- [x] USDA, FatSecret, Nutritionix, and other credentialed providers are not part of this implementation plan.
- [x] Keep one editable contract (`FoodDraft`), one review/logging destination (`LogFoodScreen`), and one reusable-food persistence path (`FoodItemRepository`).
- [x] Keep remote search results transient until the user confirms or logs a food; do not persist search result pages.
- [x] Simplify Add Food result groups for this plan to `On Device` and `Online Packaged Foods`.
- [x] Keep one saved externally-derived foods section in Settings instead of adding parallel scan-vs-search sections.
- [x] Resolve provenance now by adding `FoodSource.searchLookup` for remote text search instead of overloading `.barcodeLookup`.
- [x] Keep the current plan free of background sync, large bootstrap-seeded catalogs, and blended multi-provider catalogs.

## Non-Goals For This Plan

- Restaurant search UI or restaurant dataset integration.
- Backend or credentialed provider integration.
- Search-as-you-type against Open Food Facts.
- A second editable model or second review screen.
- Bootstrap seeding of large remote or dataset-backed catalogs.
- Background sync or silent bulk caching of remote result pages.

## Current External Source Constraints

### Open Food Facts
- Open Food Facts requires a custom `User-Agent` on API requests.
- Open Food Facts rate-limits product reads and search separately.
- Open Food Facts search is documented as unsuitable for search-as-you-type because search endpoints are rate-limited.
- Open Food Facts data is under ODbL with attribution and share-alike constraints, so provider mixing must be considered carefully.
- Open Food Facts is a strong fit for packaged and branded grocery products.

### Other providers kept out of this plan
- USDA FoodData Central exposes `/foods/search`, but it requires an API key and does not fit the current no-secret client architecture.
- FatSecret food search requires OAuth 2.0 client credentials and token handling, which does not fit the current local-first client architecture.
- Nutritionix offers strong branded and restaurant coverage, but access is commercial and is not a fit for this current implementation plan.
- MenuStat is useful for chain restaurant support, but restaurant datasets are outside the scope of this implementation plan.

## Implementation Checklist

### Data model, provenance, and persistence
- [x] Add `searchLookup` to `FoodSource`.
- [x] Update exhaustive `switch` statements and source-specific UI copy to handle `searchLookup` explicitly.
- [x] Keep `FoodDraft` as the single editable contract for manual, barcode, label-scan, and text-search-derived foods.
- [x] Reuse existing provenance fields (`source`, `barcode`, `externalProductID`, `sourceName`, `sourceURL`) before adding new metadata.
- [x] Add repository support for fetching a reusable food by `(source, externalProductID)`.
- [x] Update reusable-food upsert logic to dedupe selected text-search results by `externalProductID` before inserting a new `FoodItem`.
- [x] Keep `LogEntryRepository` snapshot behavior unchanged.

### On-device search quality
- [x] Keep local search in `AddFoodScreen` unless the ranking logic becomes large enough to justify one small pure helper.
- [x] Improve local ranking deterministically: exact name or brand matches first, then prefix matches, then token containment.
- [x] Preserve durable search terms so local search quality does not regress after food edits.
- [x] Keep search fully offline for on-device foods.
- [x] Do not add a second indexing system or a broad search-manager layer unless the current approach proves insufficient.

### Online packaged-food text search
- [x] Extend `OpenFoodFactsClient` with packaged-food text search using the current network style: `URLSession`, async/await, explicit HTTP response handling, and custom `User-Agent`.
- [x] Respect Open Food Facts search limits with explicit submit-driven queries or another tightly bounded interaction; do not implement remote search-as-you-type.
- [x] Add bounded result loading or pagination for remote packaged-food queries.
- [x] Reuse or extract shared Open Food Facts mapping so barcode lookup and text search do not fork into duplicate remote-to-`FoodDraft` logic.
- [x] Keep remote search rows transient until the user selects one.
- [x] On selection, map the result into `FoodDraft`, route to `LogFoodScreen`, and persist locally only if the user logs or saves it.
- [x] Cache only user-selected packaged foods locally for offline reuse.
- [x] Keep provider and source labeling visible on remote results and in the review flow.

### Add Food and Settings UI
- [x] Keep `AddFoodScreen` as the single search entry point.
- [x] Group search results simply as `On Device` and `Online Packaged Foods`.
- [x] Keep manual entry as the immediate fallback when search misses or remote lookup fails.
- [x] Ensure network failures never block on-device results or manual logging.
- [x] Reuse the existing reusable-food editor for saved text-search foods.
- [x] Keep barcode, label-scan, and text-search foods in one saved externally-derived foods area in Settings instead of splitting them into parallel sections.
- [x] Avoid introducing extra tabs, parallel search surfaces, or a dedicated search-result editor.

### Validation
- [x] Confirm there is currently no Xcode test target; validation for this repo currently relies on build and repo quality checks.
- [ ] Verify the app still boots through `AppLaunchState` and `AppBootstrap` after search-related model changes.
- [x] Run `xcodebuild -project "/Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'generic/platform=iOS Simulator' build`.
- [x] Run `make quality-build`.
- [ ] Run `make quality-format-check`.
- [ ] Run `make quality-dead`.
- [x] Run `make quality-dup`.
- [x] Run `make quality-debt`.
- [x] Run `make quality-deps`.
- [x] Run `make quality-n1`.
- [x] Fix diagnostics caused by the change set before considering the work complete.
- [x] Review touched code for duplicate logic, unnecessary layers, and dead paths before finishing.

## Simplifier Checkpoints

Use these checkpoints continuously while implementing:
- Prefer extending the existing barcode/local-food path over adding a new manager or second remote pipeline.
- Prefer small pure helpers over broad service layers.
- Keep provider fetch, provider mapping, local ranking, and persistence as separate responsibilities.
- Avoid introducing a second editable data shape when `FoodDraft` already exists.
- Avoid dense abstractions that hide control flow.
- Choose explicit code over clever compact code.
- Do not add a repository-backed search layer unless local ranking logic clearly outgrows the screen.
- Merge similar UI groupings instead of proliferating near-duplicate sections.
- Stop and simplify if any helper starts taking too many parameters.

## Simplifier Review Against `code-simplifier.md`

This plan was checked against the simplifier guidance and is intentionally shaped to reduce trace depth and state overhead.

- It keeps one editable data contract: `FoodDraft`.
- It keeps one review/logging destination: `LogFoodScreen`.
- It extends one persistence path: `FoodItemRepository`.
- It keeps local ranking close to the search screen unless a very small pure helper is justified.
- It reuses the existing barcode lookup architecture for remote packaged-food search instead of creating a parallel remote-food subsystem.
- It keeps remote results transient until selection instead of introducing a second persisted search-result model.
- It removes restaurant work from the current implementation plan so the change set stays focused.

## Resolved Scope Decisions

- Current implementation scope: on-device search improvements plus online packaged-food text search.
- Restaurant search is excluded from this implementation plan.
- Open Food Facts is the only planned remote provider for this implementation plan.
- USDA, FatSecret, Nutritionix, and other credentialed providers are excluded from this implementation plan.
- Remote text-search provenance will use `FoodSource.searchLookup`.
- Remote search results stay transient until the user confirms or logs a food.
- Add Food result groups will be simplified to `On Device` and `Online Packaged Foods`.
- Settings will keep one saved externally-derived foods area instead of separate scan-vs-search sections.
- Validation will use the iOS simulator build path plus the actual Makefile quality commands available in this repo.
- No Xcode test target exists yet.

## Notes, Bugs, and Weird Behavior

- 2026-04-05 — Scope tightened after plan review.
  - Decision: current implementation plan is limited to on-device search improvements and online packaged-food text search.
  - Why: keeps the diff focused, reduces open decisions, and matches the simplifier guidance to reduce layers and state.

- 2026-04-05 — Restaurant search removed from current implementation plan.
  - Decision: restaurant search is out of scope for this plan and should only be revisited after packaged-food search lands cleanly.
  - Why: restaurant data is a separate problem with different provider and dataset tradeoffs.

- 2026-04-05 — Remote text-search provenance resolved before coding.
  - Decision: add `FoodSource.searchLookup` instead of reusing `.barcodeLookup`.
  - Why: overloading `.barcodeLookup` for name-based search would be inaccurate and would hide the actual intake path.

- 2026-04-05 — Remote result persistence clarified.
  - Decision: remote search rows are transient until the user confirms or logs a selected food.
  - Why: avoids duplicate local data, avoids caching entire result pages, and keeps the persistence path aligned with existing barcode behavior.

- 2026-04-05 — Add Food grouping simplified during planning.
  - Decision: the current plan uses `On Device` and `Online Packaged Foods` rather than finer-grained groups such as Local vs Saved.
  - Why: this keeps mental overhead lower and avoids parallel groupings that do not materially help the user.

- 2026-04-05 — Planning audit found that food search is currently only local and view-level.
  - What was found: `AddFoodScreen` filters the already-loaded `foods` array using `FoodItem.searchableText.contains(query)`.
  - Where: `Features/AddFood/AddFoodScreen.swift`, with source data coming from `Features/Dashboard/DashboardScreen.swift`.
  - Why it matters: there is no repository-backed or remote text-search path yet, so the search plan must extend existing flows instead of assuming one already exists.

- 2026-04-05 — Planning audit found that current reusable-food dedupe is not sufficient for remote text search.
  - What was found: `FoodItemRepository` currently reuses foods by `foodItemID` or barcode, but not by `(source, externalProductID)`.
  - Where: `Data/Services/FoodItemRepository.swift`.
  - Why it matters: remote name-search selections could duplicate locally if they do not arrive through barcode lookup.
  - Current status: resolved in `Data/Services/FoodItemRepository.swift` by adding external-product lookups and reusing selected remote foods before insert.

- 2026-04-05 — Planning audit found a local-search durability risk around aliases.
  - What was found: `FoodItem` builds `searchableText` with aliases at initialization time, but later normalization updates rebuild the field without aliases.
  - Where: `Data/Models/FoodItem.swift`, `Data/Services/CommonFoodSeedLoader.swift`.
  - Why it matters: search quality can quietly regress after editing foods if alias coverage is lost.
  - Current status: resolved in `Data/Models/FoodItem.swift` by retaining durable normalized search terms during persistence updates.

- 2026-04-05 — Open Food Facts search constraints affect UX design.
  - What was found: Open Food Facts requires a custom `User-Agent`, rate-limits search separately, and documents that search should not be used for search-as-you-type.
  - Why it matters: the packaged-food search UX should use explicit submit-driven or otherwise tightly bounded remote queries.
  - Current status: implemented in `Features/AddFood/AddFoodScreen.swift` and `Features/Scan/Barcode/OpenFoodFactsClient.swift` with submit-driven search and bounded pagination.

- 2026-04-05 — Add Food search helpers were split to satisfy repo debt checks.
  - What happened: the initial Add Food implementation made `AddFoodScreen.swift` exceed the repo tech-debt line-count limit.
  - Where: `Features/AddFood/AddFoodScreen.swift`.
  - Cause: local ranking, remote search state, result lists, quick actions, and manual-entry UI were all living in one file.
  - Resolution: split supporting views into `Features/AddFood/AddFoodComponents.swift` and `Features/AddFood/AddFoodSearchResults.swift`, then reran build and debt checks successfully.

- 2026-04-05 — Some Makefile validation commands were skipped by missing local tooling.
  - What happened: `make quality-format-check` and `make quality-dead` exited without performing analysis because required tools were not installed locally.
  - Where: the formatter wrapper script for `make quality-format-check` and `tools/quality/run_periphery.sh`.
  - Cause: the formatter CLI available on that machine and `periphery` were not installed in that environment.
  - Current status: still open for a fully provisioned machine; the commands were executed and reported the missing-tool condition explicitly.

- 2026-04-05 — Large restaurant datasets should not be seeded in app bootstrap by default.
  - What was found: the current bootstrap path is appropriate for the small common-food seed but would be a poor fit for a large chain restaurant catalog.
  - Where: `Data/Services/AppBootstrap.swift`, `Data/Services/CommonFoodSeedLoader.swift`.
  - Why it matters: first-launch cost and local database bloat would increase unnecessarily.
  - Current status: not part of this implementation plan; if restaurant work is revisited later, prefer lazy read-only search plus local persistence only for selected foods.

- 2026-04-05 — Validation commands locked to actual repo commands.
  - Decision: use the iOS simulator `xcodebuild` command plus the `make quality-*` targets defined in `Makefile`.
  - Why: the repo already has a concrete validation surface, so the plan should track those exact checks rather than generic placeholders.
