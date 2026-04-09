# iPhone-First Scan Implementation Plan

This file is the working implementation checklist for barcode scan and nutrition label scan support.

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

- `FoodDraft` is already the review/edit contract and should remain the single contract for scanned data before logging.
- `LogFoodScreen` is already the confirmation/edit/logging flow and should be reused instead of building a parallel editor.
- `FoodItemRepository` is already the reusable food persistence path and should be extended instead of bypassed.
- `LogEntryRepository` already persists nutrition snapshots for consumed entries.
- `AddFoodScreen` currently supports only `Search` and `Manual` flows.
- There is currently no scan, OCR, photo import, camera capture, or network client code in the repo.
- The Xcode target is still configured as multi-platform and uses generated Info.plist values from `project.pbxproj`.
- Current quality/build automation still assumes a macOS build destination, so iOS-first project changes must account for that.

## Implementation Checklist

### Project and iOS configuration
- [x] Lower the iPhone deployment target in `cal-macro-tracker.xcodeproj/project.pbxproj` to an iOS version that supports the planned APIs.
- [x] Add `INFOPLIST_KEY_NSCameraUsageDescription` to generated Info.plist settings.
- [x] Add `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` to generated Info.plist settings.
- [x] Decide whether `TARGETED_DEVICE_FAMILY` should stay `1,2` or become strict iPhone-only `1`.
- [x] Decide whether non-iOS platforms stay temporarily for validation or are removed now.
- [x] If platform support changes, update the validation/build command path so verification still works.

### Existing code reuse and extension points
- [x] Keep `FoodDraft` as the single editable contract for manual, barcode, and label-derived data.
- [x] Keep `LogFoodScreen` as the review-and-log destination for scan flows.
- [x] Extend `FoodItemRepository` rather than adding a second persistence path.
- [x] Keep `LogEntryRepository` snapshot behavior intact unless a scan-specific persistence gap is proven.
- [x] Reuse existing shared UI pieces such as `ErrorBanner`, `BottomPinnedActionBar`, navigation helpers, and numeric input handling where they still fit iOS-first behavior.

### Domain model updates
- [x] Extend `FoodSource` with scan-related cases needed by the product flow.
- [x] Add optional scan metadata to `FoodItem` only where the current and planned flows require it.
- [x] Add matching optional metadata to `FoodDraft` only if needed to preserve scan provenance before persistence.
- [x] Keep schema changes additive and focused to reduce migration risk.
- [x] Update searchable/indexed text only if doing so improves local reuse without adding a second indexing system.

### Barcode scan flow
- [x] Add a barcode scan entry point from `AddFoodScreen` without replacing the existing search/manual behaviors unnecessarily.
- [x] Prefer an iPhone-friendly add-food layout that keeps the current UI understandable.
- [x] Implement a live barcode scan surface using `VisionKit.DataScannerViewController` on supported devices.
- [x] Gate live scanning with `DataScannerViewController.isSupported` and availability checks.
- [x] Add a fallback path for unsupported/unavailable cases instead of hard failing.
- [x] Use `VNDetectBarcodesRequest` for still-image barcode detection fallback.
- [x] Add a local-first barcode resolution path: check cached local foods before network lookup.
- [x] Add a thin Open Food Facts client using `URLSession` and async/await.
- [x] Send a proper `User-Agent` with Open Food Facts requests.
- [x] Map Open Food Facts data conservatively into `FoodDraft`.
- [x] Route successful barcode results into `LogFoodScreen` for user confirmation and edits.
- [x] Cache successful barcode products locally as reusable `FoodItem` records for offline reuse.

### Nutrition label scan flow
- [x] Add a nutrition label scan entry point from `AddFoodScreen`.
- [x] Add an iPhone-native image input path for label scanning.
- [x] Add photo library import support for label images.
- [x] Add camera capture support for label images if the chosen implementation path requires it now.
- [x] Use `VNRecognizeTextRequest` for OCR.
- [x] Keep OCR recognition separate from nutrition parsing.
- [x] Build a deterministic parser for serving description, grams per serving when explicitly present, calories, protein, fat, and carbs.
- [x] Keep parser behavior conservative: do not invent missing gram conversions or hidden nutrient values.
- [x] Produce editable draft data even when OCR is partial, as long as the result is still useful.
- [x] Route label-derived drafts into `LogFoodScreen` for user confirmation and edits.

### Persistence and local reuse
- [x] Add repository support for looking up previously cached barcode products locally.
- [x] Add repository support for upserting cached scan-derived foods without duplicating custom-food persistence logic.
- [x] Decide whether cached scan-derived foods should appear in local search results.
- [x] If cached scan-derived foods are searchable, update `AddFoodScreen` filtering logic accordingly.
- [x] Decide whether scan-derived reusable foods need a Settings editing surface now or can remain editable only during review/log flows for the first pass.

### UI and error handling
- [x] Keep hard failures routed through existing error presentation unless a stronger need emerges.
- [x] Keep partial-success flows editable instead of blocking the user.
- [x] Make unsupported-device and unavailable-camera states understandable on iPhone.
- [x] Avoid adding a second review editor or a heavy scan-specific state architecture.

### Validation
- [x] Verify the app still boots through `AppLaunchState` and `AppBootstrap` after model changes.
- [x] Build the app with an iPhone simulator destination once iOS-focused changes land.
- [x] Run any available repo quality checks that are actually present and usable in this environment.
- [x] Fix any diagnostics caused by the changes before considering the work complete.
- [x] Review touched code for duplicate logic, unnecessary layers, and dead paths before finishing.

## Simplifier Checkpoints

Use these checkpoints continuously while implementing:
- Prefer extending an existing path over adding a new wrapper around it.
- Prefer small pure helpers over broad manager objects.
- Keep scan capture, recognition, parsing, mapping, and persistence as separate responsibilities.
- Avoid introducing a second editable data shape when `FoodDraft` already exists.
- Avoid dense abstractions that hide control flow.
- Choose explicit code over clever compact code.
- Remove duplicated assignment/mapping logic when the second instance appears.
- If a helper needs too many parameters, stop and simplify the design.

## Simplifier Review Against `code-simplifier.md`

This plan was checked against the simplifier guidance and is intentionally shaped to reduce trace depth and state overhead.

- It keeps one editable data contract: `FoodDraft`.
- It keeps one review/logging destination: `LogFoodScreen`.
- It extends one persistence path: `FoodItemRepository`.
- It separates capture, recognition, parsing, mapping, and persistence so each step can stay small and explicit.
- It avoids introducing a broad scan manager or a second form/editor flow.
- It leaves room to refactor duplicated mapping only when duplication actually appears during implementation.
- It keeps open questions explicit instead of hiding them inside premature abstractions.

## Resolved Scope Decisions

- Device family: strict iPhone-only now (`TARGETED_DEVICE_FAMILY = 1`).
- Non-iOS platforms: kept temporarily in `SUPPORTED_PLATFORMS`, but validation was moved to an iOS Simulator build path.
- Label scan scope: include both photo import and camera capture.
- Scan-derived reusable foods: add a Settings editing surface now.
- Deployment target correction during implementation: the original iOS 16 idea was not viable for this repo because the existing codebase already depends on SwiftData, Observation, and `ContentUnavailableView`, so the implemented target is iOS 17.

## Notes, Bugs, and Weird Behavior

- 2026-04-03 — Scope decisions locked before coding.
  - Decision: strict iPhone-only device family, keep non-iOS platforms temporarily, include both photo import and camera capture for label scanning, and add Settings editing for scan-derived foods.
  - Files touched later because of these decisions: `cal-macro-tracker.xcodeproj/project.pbxproj`, `Makefile`, `Features/Settings/*`, `Features/Scan/*`.

- 2026-04-03 — iOS 16 deployment target failed against the existing codebase.
  - What happened: build verification failed after lowering the target to iOS 16.
  - Where: existing app types including `AppLaunchState`, `FoodItem`, and `AppLaunchErrorView`.
  - Cause: the repo already uses SwiftData `@Model`, Observation `@Observable`, and `ContentUnavailableView`, which require iOS 17 in this codebase.
  - Resolution: updated `IPHONEOS_DEPLOYMENT_TARGET` to 17.0 in `cal-macro-tracker.xcodeproj/project.pbxproj`.

- 2026-04-03 — Shared `PhotosPickerItem` helper added unnecessary complexity.
  - What happened: shared scan helper files using `PhotosPickerItem` caused compile issues and added indirection without much value.
  - Where: `Features/Scan/Shared/ScanImageLoading.swift`, temporary `Features/Scan/Shared/ScanPhotoImportHandler.swift`.
  - Cause: the abstraction pulled the picker-specific type out of the screens even though only the screens needed it.
  - Resolution: removed `ScanPhotoImportHandler.swift`, kept `PhotosPickerItem` handling local to the scan screens, and reduced shared code to image conversion plus the camera sheet presenter.

- 2026-04-03 — Duplicate scan-state/view glue appeared during implementation.
  - What happened: the duplicate-block quality check flagged repeated photo-import and camera-sheet logic between barcode and label scan screens.
  - Where: `Features/Scan/Barcode/BarcodeScanScreen.swift`, `Features/Scan/Label/LabelScanScreen.swift`.
  - Cause: both screens initially owned the same capture/picker glue.
  - Resolution: extracted shared camera presentation into `Features/Scan/Shared/ScanCameraCaptureSheet.swift` and kept only the minimum repeated picker handling that still reads clearly.

- 2026-04-03 — Barcode symbology support required API-specific correction.
  - What happened: build verification failed on `.upca` and then on missing Vision imports for live scanner symbologies.
  - Where: `Features/Scan/Barcode/BarcodeImageScanner.swift`, `Features/Scan/Barcode/BarcodeLiveScannerView.swift`.
  - Cause: the initial enum set assumed a UPC-A case that is not exposed here, and `BarcodeLiveScannerView` also needed `import Vision` for the symbology constants.
  - Resolution: narrowed the implemented symbology set to `.ean13`, `.ean8`, and `.upce`, and added `import Vision` to the live scanner view.

- 2026-04-03 — Barcode scan crash after saving a fetched product.
  - What happened: scanning a barcode could crash with a SwiftData temporary identifier / invalidated backing data error.
  - Where: `Data/Services/FoodItemRepository.swift`, triggered by the barcode flow in `Features/Scan/Barcode/BarcodeScanScreen.swift`.
  - Cause: `saveReusableFood` returned SwiftData `persistentModelID` from an isolated context before the save finalized, so newly inserted foods could hand back a temporary identifier that became invalid when resolved in the main context.
  - Resolution: changed `saveReusableFood` to return the app's stable `FoodItem.id` UUID from the isolated context and then reload the saved record through `fetchReusableFood(id:)` in the main context.

- 2026-04-03 — Barcode nutrition mismatch from mixed bases.
  - What happened: some scanned products showed the correct item and calories, but protein/fat/carbs were wrong.
  - Where: `Features/Scan/Barcode/BarcodeLookupMapper.swift`.
  - Cause: the initial mapper chose each nutrient independently, preferring per-serving values when present and otherwise falling back to per-100g values. That allowed calories to come from a serving basis while macros came from a 100g basis for the same product.
  - Resolution: changed the mapper to use one consistent nutrition basis only: full serving data first, scaled 100g-to-serving data second when a gram serving is available, and pure 100g data last.

- 2026-04-03 — Today list quick actions added.
  - What happened: deleting or logging the same item again from the Today list required opening the edit screen first.
  - Where: `App/LogEntryListSection.swift`, `Features/Dashboard/DashboardScreen.swift`, `Data/Services/LogEntryRepository.swift`, `Data/Models/FoodDraft.swift`.
  - Resolution: added swipe actions for Today entries: trailing swipe deletes, leading swipe logs the same stored food/quantity again through a new repository `logAgain` path.

- 2026-04-03 — Label scan flow simplified.
  - What happened: after OCR parsing, the flow paused on an extra intermediate screen with a single review button before reaching the editable log form.
  - Where: `Features/Scan/Label/LabelScanScreen.swift`, `Features/AddFood/LogFoodScreen.swift`.
  - Resolution: removed the intermediate screen, routed parsed label data directly into `LogFoodScreen`, and added an optional preview button plus full-screen image preview for the captured/imported label.

- 2026-04-03 — Post-implementation cleanup review.
  - What happened: after the scan flows shipped, a cleanup pass reviewed the touched code against `AGENTS.md`, `SOFTWARE_PATTERNS.md`, and `code-simplifier.md`.
  - Where: `Data/Services/FoodItemRepository.swift`, `Features/Scan/Barcode/OpenFoodFactsClient.swift`, `Features/AddFood/AddFoodScreen.swift`, `Features/AddFood/LogFoodScreen.swift`, `Features/Scan/Barcode/BarcodeScanScreen.swift`.
  - Resolution: removed unused custom-food compatibility wrappers from `FoodItemRepository`, added explicit HTTP response/status handling to the Open Food Facts client, simplified Add Food scan actions into a single two-column row, surfaced scan-source metadata in `LogFoodScreen`, and removed confirmed-unused imports/state.

- 2026-04-03 — Today-list swipe gestures moved onto native list rows.
  - What happened: swipe actions were wired onto Today entries inside a `ScrollView` + `LazyVStack`, which did not provide the native Apple Music-style behind-the-row swipe behavior the feature expected.
  - Where: `App/LogEntryListSection.swift`, `Features/Dashboard/DashboardScreen.swift`.
  - Resolution: added a `LogEntryListSection.Layout` mode so Today can render inside a real `List` while History keeps the existing stacked-card layout. Today rows now support trailing full-swipe delete and leading swipe actions for Edit and Log Again without duplicating the row UI.

- 2026-04-03 — Verification status.
  - iOS simulator build: passed with `xcodebuild -project "/Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'generic/platform=iOS Simulator' build`.
  - Quality checks: passed for duplicate blocks, tech debt, dependency inventory, and n+1 smoke.
  - Tool availability note: the lint CLI and formatter CLI configured in the repo at that time were not installed in that environment, so those checks were skipped by the repo scripts rather than executed.
