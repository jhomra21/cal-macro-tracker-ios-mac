# USDA Proxy Implementation Plan

This file is the working implementation checklist for moving packaged-food remote search behind a Hono-based Cloudflare Worker, with Open Food Facts first and USDA FoodData Central fallback behind one app-facing contract.

Rules for this plan:
- Keep changes aligned with `AGENTS.md`, `SOFTWARE_PATTERNS.md`, and `code-simplifier.md`.
- Reuse existing code paths before adding new ones.
- Do not introduce duplicate models, duplicate editors, duplicate persistence flows, or a broad multi-provider framework.
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

- `Features/AddFood/AddFoodScreen.swift` is already the single search entry point and currently owns local ranking plus the Open Food Facts remote-search trigger.
- `Features/AddFood/RemoteSearchResult.swift` now exists and is the current minimal shared remote-result wrapper for packaged-food search rows and selection flow.
- `Features/AddFood/AddFoodSearchResults.swift` renders grouped on-device and remote packaged-food results and consumes `RemoteSearchResult` without provider-specific list duplication.
- `Features/Scan/Barcode/OpenFoodFactsClient.swift` is still the client-side barcode lookup provider, but remote packaged-food text search no longer needs to stay in Swift.
- `Features/Scan/Barcode/BarcodeLookupMapper.swift` already maps Open Food Facts products into `FoodDraft` and should remain the pattern to mirror lightly, not replace with a large abstraction.
- `Data/Models/FoodDraft.swift` is already the single editable contract for remote results before review and logging.
- `Features/AddFood/LogFoodScreen.swift` is already the single review/edit/log destination and should be reused for USDA-backed results.
- `Data/Services/FoodItemRepository.swift` already persists reusable foods and now dedupes selected remote foods by `(source, externalProductID)`.
- `Data/Models/ModelSupport.swift` already has `FoodSource.searchLookup`, so USDA fallback can share the same intake path while using provider-qualified external IDs.
- `Features/Settings/CustomFoodEditorScreen.swift` and `LogFoodScreen.swift` already surface `sourceName` / `sourceURL` when present, so externally-derived foods already have a visible provenance surface.
- The repo now has a Bun-managed Worker project under `worker/usda-proxy/` with committed `package.json`, `tsconfig.json`, and `wrangler.jsonc`.
- The Worker already exposes `GET /v1/usda/search`; unified packaged-food search should extend that Worker rather than introducing a second backend project.
- Root `.gitignore` now explicitly ignores Worker-local `.dev.vars*`, `node_modules/`, and `.wrangler/` state.
- The current Open Food Facts outage showed that the app needs a remote fallback path that does not expose an app-owned USDA API key in the shipped client.
- The repo uses a filesystem-synchronized Xcode root group, so adding app Swift files does not require manual `project.pbxproj` file references, but a Worker project will remain fully outside the Xcode target.

## Scope Locked Before Coding

- [x] USDA is a fallback provider for packaged-food text search, not a replacement for the current Open Food Facts path.
- [x] The USDA API key is app-owned and shared across users, so it must not be embedded in the iOS client.
- [x] The shared USDA key will be stored in Cloudflare Worker secrets, not in app code, not in repo files, and not as user BYOK.
- [x] The Cloudflare Worker will live in this same repo as a separate top-level deployable, not mixed into `cal-macro-tracker/` source files.
- [x] The app will keep `FoodDraft`, `LogFoodScreen`, and `FoodItemRepository` as the single edit/review/persist path.
- [x] The implementation will avoid a broad provider-agnostic framework and instead add only the smallest shared remote-result layer needed for OFF plus USDA.
- [x] USDA fallback will target `Branded` search only so it stays aligned with the packaged-food use case.
- [x] USDA search results will stay transient until the user selects one and logs or saves it locally.
- [x] Remote packaged-food text search will move behind the Worker, while Open Food Facts barcode lookup remains client-side.

## Non-Goals For This Plan

- User-supplied USDA keys or BYOK flows.
- Moving Open Food Facts barcode lookup behind the proxy in this change set.
- A generic remote-provider framework with many adapters and protocol layers.
- Restaurant search or restaurant dataset integration.
- Background sync, bulk catalog mirroring, or server-side persistence of selected foods.
- A second review editor, second logging flow, or second local persistence path.
- Cloudflare KV, D1, Durable Objects, or other persistence products unless a concrete need appears during implementation.

## Validated External Constraints

### USDA FoodData Central
- USDA FoodData Central is the official U.S. government source among the evaluated providers.
- USDA access is free with an API key.
- USDA documentation exposes a food search endpoint and supports application use with a key.
- USDA branded search is the best match for packaged-food fallback in this app.
- USDA rate limiting is materially lower than an app-wide anonymous public endpoint should assume, so the proxy must bound, validate, and cache requests.

### Cloudflare Workers / Wrangler
- Current Cloudflare guidance uses Wrangler for local development and deployment.
- Current Cloudflare guidance recommends `wrangler.jsonc` for Worker configuration.
- Current Cloudflare guidance stores runtime secrets as Worker secrets, not plain-text config vars.
- Local development secrets belong in `.dev.vars` or `.env` files next to the Worker config and must not be committed.
- Current Cloudflare guidance supports declaring required runtime secrets in `wrangler.jsonc` with `secrets.required`; local dev and deploy validate missing secrets against that list.
- Current Wrangler flow supports `npx wrangler dev`, `npx wrangler deploy`, `npx wrangler secret put`, `npx wrangler login`, and `npx wrangler whoami`.
- Cloudflare provides a quick `workers.dev` deployment path without DNS setup; custom domains are a follow-up option when a production domain is available.
- Cloudflare Cache API is useful as a best-effort edge cache, but `cache.put` is not a globally replicated correctness layer.
- Current Wrangler versions can auto-configure a Worker project on deploy if no config exists, but for this repo we should still keep an explicit Worker project and committed `wrangler.jsonc` so the Worker remains reviewable and deterministic.
- Current Workers Builds docs support monorepo root-directory configuration, so a Worker under `worker/usda-proxy/` can be deployed from the same repo without splitting to a separate repository.

### Hono on Cloudflare Workers
- Current Hono docs provide a Cloudflare Workers getting-started path and support deploying Hono apps on Workers with Wrangler.
- Current Hono docs support creating a Cloudflare Workers starter with `create-hono`, but the starter docs still show `wrangler.toml` examples in places, so this repo should normalize the generated config to explicit `wrangler.jsonc` to stay aligned with current Cloudflare guidance.
- Hono works directly on Workers with a normal `export default app` pattern, and `c.env` is the correct boundary for Worker bindings and secrets.
- Hono docs explicitly show GitHub Actions deployment using `cloudflare/wrangler-action`, which matches Cloudflare’s external CI/CD guidance.
- For this proxy, Hono is a routing layer convenience, not a reason to add extra server architecture; the Worker should stay tiny and route-focused.

## Architecture Decisions

### Repo placement
- Add a new top-level Worker project at `worker/usda-proxy/`.
- Keep all iOS app code under `cal-macro-tracker/` unchanged in structure except for the minimum search-integration files.
- Do not mix Worker code into the Xcode target or app folders.

### Network boundary
- The iOS app will call the Worker for remote packaged-food text search.
- The Worker will be the only place where the USDA API key is used.
- The Worker will expose a narrow app-shaped search endpoint rather than a generic provider tunnel.
- The Worker will translate simple app query params into bounded Open Food Facts and USDA upstream requests.

### Fallback behavior
- Keep Open Food Facts as the first remote packaged-food search provider.
- Retry Open Food Facts only for bounded transport, timeout, 429, or 5xx-style failures.
- Fall back to USDA when Open Food Facts is unavailable.
- Allow an explicit `fallbackOnEmpty` policy at the Worker boundary so the app can keep one logical search request while the backend decides whether OFF zero-results should also widen to USDA.

### Result identity and dedupe
- Keep `FoodSource.searchLookup` for both OFF text search and USDA text search.
- Qualify external product IDs by provider to avoid collisions under the shared `.searchLookup` source.
- Use namespaced IDs such as `openfoodfacts:<code>` and `usda:<fdcId>` when persisting selected foods.
- Keep repository dedupe based on `(source, externalProductID)` so a selected USDA food reuses its saved record cleanly.

### Response normalization
- The Worker should return a small app-shaped JSON response instead of the full raw USDA payload.
- Normalize only fields the app actually needs for search rows and `FoodDraft` mapping.
- Keep the normalized USDA response explicit and flat enough that the Swift client can map it without a second large adapter layer.

## Proposed Worker Project Shape

```text
worker/
  usda-proxy/
    package.json
    tsconfig.json
    wrangler.jsonc
    .dev.vars.example
    src/
      index.ts
      openFoodFacts.ts
      packagedFoods.ts
      usda.ts
      types.ts
```

- `package.json`
  - Hono + Wrangler dependencies
  - local dev / deploy / types scripts
- `tsconfig.json`
  - explicit TS settings for the Worker project only
- `wrangler.jsonc`
  - Worker name
  - entrypoint
  - compatibility date
  - optional observability config if enabled
  - `secrets.required`
  - local dev settings if needed
- `.dev.vars.example`
  - documents required local secret names without committing real values
- `src/index.ts`
  - Hono app creation
  - route registration
  - request validation
  - response shaping
  - not-found / error handlers
- `src/openFoodFacts.ts`
  - upstream Open Food Facts search request building
  - polite request headers
  - bounded error mapping
- `src/packagedFoods.ts`
  - narrow orchestration for OFF-first remote search
  - bounded retries/timeouts
  - USDA fallback when OFF is unavailable or when widening on empty is explicitly enabled
- `src/usda.ts`
  - upstream USDA request building
  - upstream response decoding
  - normalization into the app-facing result shape
- `src/types.ts`
  - Worker `Bindings` / env types and small normalized response types

Keep the Worker small. Hono is the routing layer here, not a reason to add service classes, ORM-like layers, or broad middleware stacks.

## Worker Endpoint Contract

### Public endpoint
- `GET /v1/packaged-foods/search?q=<query>&page=<page>&pageSize=<pageSize>&fallbackOnEmpty=<0|1>`
- Keep `GET /v1/usda/search` as a narrow USDA-only route for direct debugging and validation.

### Request rules
- Require a non-empty trimmed query.
- Enforce a minimum query length after trimming.
- Bound `page` to `>= 1` and to a small maximum.
- Bound `pageSize` to a small max such as `25`.
- Accept only explicit `fallbackOnEmpty` boolean-like values for the unified packaged-food route.
- Reject unsupported parameters instead of creating a generic provider tunnel.

### Upstream request shape
- Worker calls Open Food Facts search first with polite headers and a bounded timeout/retry policy.
- Worker calls USDA FoodData Central search with the shared secret API key only when fallback is needed.
- Restrict USDA upstream search to `Branded` data.
- Pass only the minimal paging/search parameters the app needs.
- Keep upstream requests deterministic and auditable.

### Worker response shape

```json
{
  "query": "fairlife chocolate",
  "page": 1,
  "pageSize": 12,
  "resolvedProvider": "usda",
  "results": [
    {
      "provider": "usda",
      "item": {
        "id": "usda:1234567",
        "fdcId": 1234567,
        "name": "Nutrition Plan Chocolate",
        "brand": "Fairlife",
        "servingDescription": "1 bottle",
        "gramsPerServing": 414,
        "caloriesPerServing": 150,
        "proteinPerServing": 30,
        "fatPerServing": 2,
        "carbsPerServing": 4,
        "sourceName": "USDA FoodData Central",
        "sourceURL": "https://fdc.nal.usda.gov/food-details/1234567"
      }
    }
  ],
  "hasMore": true
}
```

### Error contract
- Return 400 for invalid query parameters.
- Return 429 when the Worker adds explicit local throttling later, if needed.
- Map upstream provider unavailability to clean 503 responses.
- Return stable user-safe JSON errors; do not leak secrets, raw upstream URLs with API keys, or oversized upstream error bodies.

## Worker Implementation Checklist

### Project setup
- [x] Create `worker/usda-proxy/` as a dedicated Worker project in this repo.
- [x] Scaffold a minimal Hono-compatible Cloudflare Workers project and normalize it to the committed file shape in this plan.
- [x] Use committed `wrangler.jsonc` instead of legacy TOML config.
- [x] Add only the minimum package scripts needed for local dev, type generation, and deploy.
- [x] Add `hono`, `wrangler`, and only the minimum Worker-local TypeScript dependencies.
- [x] Add Worker-local ignore rules for `.dev.vars*` before creating local secret files.
- [x] Add `.dev.vars.example` documenting required local secret names without real values.
- [ ] Store the USDA key as a Worker secret named `USDA_API_KEY`.
- [x] Declare `USDA_API_KEY` in `wrangler.jsonc` using `secrets.required` so local dev and deploy validate it.
- [x] Run `wrangler types` after config setup if generated Worker env typings are needed.

### Request handling and security
- [x] Expose a narrow `GET /v1/packaged-foods/search` endpoint for app traffic.
- [x] Keep `GET /v1/usda/search` available for direct USDA validation.
- [x] Validate and trim `q`, `page`, and `pageSize` before calling upstream providers.
- [x] Reject empty or overly broad queries.
- [x] Bound page size and page count to protect the shared key and avoid wasteful upstream traffic.
- [x] Avoid logging the USDA secret or upstream URLs that include it.
- [x] Return compact JSON errors suitable for direct app display.

### Provider integration
- [x] Implement a thin Open Food Facts search client in `src/openFoodFacts.ts`.
- [x] Reuse the existing thin USDA search client in `src/usda.ts`.
- [x] Restrict USDA searches to branded results.
- [x] Normalize the USDA payload into the small app-facing result contract.
- [x] Keep Open Food Facts payload shaping minimal so existing Swift decoding can be reused.
- [x] Extract calories, protein, fat, and carbs conservatively from USDA nutrient data.
- [x] Prefer explicit serving-based data when USDA provides it; do not invent gram conversions when the source does not support them.
- [x] Build a stable `sourceURL` using the USDA food-details page for the returned `fdcId`.

### Caching and resilience
- [x] Add best-effort Cloudflare edge caching for identical normalized search requests.
- [x] Use a short TTL so the cache reduces burst load without pretending to be durable storage.
- [x] Keep cache keys based on normalized `query/page/pageSize` and `fallbackOnEmpty`.
- [x] Treat cache as an optimization only; the Worker must still behave correctly on a cold edge.
- [x] Add bounded Open Food Facts retries and timeout handling inside the Worker instead of the app.
- [x] Return clear 503 responses for upstream unavailability.

### Local Worker validation
- [x] Run local dev with `bun run dev`.
- [x] Verify the Worker rejects invalid query requests.
- [x] Verify the orchestrator returns normalized OFF-shaped results with mocked Open Food Facts success.
- [x] Verify the orchestrator falls back to USDA with mocked Open Food Facts empty results when widening is enabled.
- [x] Verify the Worker succeeds for known packaged-food branded queries against real upstream services.
- [ ] Verify the Worker returns app-safe errors when USDA is unavailable or misconfigured.
- [ ] Verify the Worker does not expose the USDA key in responses or logs.

## iOS App Integration Checklist

### Client and mapping
- [x] Add a thin Worker-backed packaged-food search client in the existing remote-search area of the app.
- [x] Keep `OpenFoodFactsClient` only for barcode lookup and remove dead Swift text-search code.
- [x] Reuse the existing OFF and USDA result models rather than adding duplicate app-side provider stacks.
- [x] Keep the USDA-to-`FoodDraft` mapper mirroring the existing OFF mapping style.
- [x] Keep provider-specific mapping small and explicit instead of introducing a generic protocol hierarchy.

### Remote search state reuse
- [x] Reuse `AddFoodScreen` as the single search surface.
- [x] Introduce only the minimum shared remote-result enum or wrapper needed to render OFF and USDA results in one UI.
- [x] Avoid duplicating remote result lists, remote selection screens, or review flows.
- [x] Keep manual entry and on-device search usable regardless of remote provider state.
- [x] Collapse remote packaged-food search to one app-side request path.

### Persistence and provenance
- [x] Persist selected USDA results through `FoodItemRepository` only after the user logs or saves them.
- [x] Use provider-qualified external IDs such as `usda:<fdcId>` and `openfoodfacts:<code>` when saving search-backed foods.
- [x] Keep `FoodSource.searchLookup` as the search provenance without adding another source enum case unless the UX later proves it necessary.
- [x] Keep `sourceName` and `sourceURL` visible in review and saved-food editing surfaces.

### Search UX
- [x] Keep remote packaged-food search submit-driven; do not add search-as-you-type to the Worker.
- [x] Keep provider labels visible in rows and review.
- [x] Remove app-owned OFF-vs-USDA branching so one user action maps to one app-level remote request.
- [x] Keep local on-device search unchanged and available before any remote call.

## Local Development Workflow

### Worker bring-up in this repo
- Run all Worker commands from `worker/usda-proxy/`, not from the repo root.
- Keep the Worker self-contained so app and Worker changes can evolve in the same repo without sharing package tooling.
- Add Worker-local ignore rules for `.dev.vars*` before creating local secret files.

### Recommended local dev loop
1. Keep the Worker project under `worker/usda-proxy/` as the single remote packaged-food backend.
2. Add `.dev.vars` locally with `USDA_API_KEY=<value>` and do not commit it.
3. Run `bun run dev` from `worker/usda-proxy/`.
4. Verify the local Worker directly before exercising the iOS app.
5. Point the app config at the Worker base URL and validate unified remote search from the simulator.

### Local Worker testing expectations
- Use direct HTTP requests against the local `wrangler dev` server for endpoint validation.
- Use Hono’s app-level request testing only where it actually helps; do not add a complex test harness just to prove one route works.
- Keep local validation focused on:
  - invalid query handling
  - valid OFF-first packaged-food search
  - USDA fallback behavior when OFF fails or returns empty and widening is enabled
  - normalized response shape
  - user-safe error responses
  - secret non-exposure

## Deployment Strategy

### Recommended rollout order
1. Manual Wrangler deployment first.
2. App integration against the deployed `workers.dev` URL.
3. CI/CD automation only after the endpoint contract is stable.

### Why manual deploy first
- It removes CI variables while the Worker contract is still changing.
- It makes it easier to validate secret configuration, local-vs-remote behavior, and USDA response shaping.
- It avoids introducing GitHub/Cloudflare build configuration before the Worker itself is proven.

### Manual deployment path
- Authenticate locally with `npx wrangler login`.
- Confirm account/auth state with `npx wrangler whoami`.
- Set the production secret with `npx wrangler secret put USDA_API_KEY`.
- Deploy with `npx wrangler deploy`.
- Record the resulting `workers.dev` URL and keep it in one app config location.

### CI/CD options after first deploy
- **GitHub Actions**
  - Best when you want deployment controlled in-repo and reviewed like normal code.
  - Use `cloudflare/wrangler-action` and store `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` in GitHub secrets.
- **Workers Builds**
  - Best when you want Cloudflare-managed Git-based deployment.
  - Current docs support monorepo root-directory configuration, so `worker/usda-proxy/` can be the build root.
  - Current docs default the deploy command to `npx wrangler deploy`, and non-production builds can use `npx wrangler versions upload`.

### Deployment recommendation for this repo
- Start with manual `wrangler deploy`.
- Move to GitHub Actions once the Worker URL, secret setup, and endpoint contract are stable.
- Consider Workers Builds later only if you want Cloudflare-native preview/build workflows for this monorepo.

## Deployment And Ops Checklist

- [ ] Authenticate Wrangler with `npx wrangler login`.
- [ ] Confirm local auth/account state with `npx wrangler whoami`.
- [ ] Set the production USDA secret with `npx wrangler secret put USDA_API_KEY`.
- [ ] Deploy with `npx wrangler deploy`.
- [ ] Record the initial `workers.dev` URL used by the app.
- [ ] Keep the Worker base URL in one app config location so a later custom-domain cutover stays small.
- [ ] Decide whether to automate deploys with GitHub Actions after the first manual deploy succeeds.
- [ ] If Workers Builds is adopted later, set the Worker root directory to `worker/usda-proxy/` and keep the deploy command explicit.
- [ ] If a production domain exists later, decide whether to move from `workers.dev` to a custom domain after the first working release.

## Validation Checklist

### Worker
- [x] Verify local Worker development with a real USDA key in `.dev.vars`.
- [ ] Verify direct local requests against `bun run dev` for valid query, invalid query, OFF-upstream error, and USDA-upstream error cases.
- [x] Verify the Hono route returns stable user-safe error JSON for invalid requests.
- [x] Verify the orchestrator returns the normalized app-facing JSON shape for successful mocked OFF responses.
- [x] Verify the orchestrator falls back to normalized USDA results for mocked OFF-empty responses when widening is enabled.
- [ ] Verify deployed Worker responses from the public URL.
- [ ] Verify repeated identical searches benefit from cache hits where expected.
- [ ] Verify the Worker still behaves correctly when the edge cache is cold.

### App
- [x] Run `xcodebuild -project "/Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'generic/platform=iOS Simulator' build`.
- [x] Run `make quality-build`.
- [x] Run `make quality-format-check`.
- [x] Run `make quality-dead`.
- [x] Run `make quality-dup`.
- [x] Run `make quality-debt`.
- [x] Run `make quality-deps`.
- [x] Run `make quality-n1`.
- [ ] Verify the app still boots through `AppLaunchState` and `AppBootstrap` after unified remote-search changes.
- [x] Review touched Worker and iOS code for duplicate logic, unnecessary layers, and dead paths before finishing.

## Simplifier Checkpoints

Use these checkpoints continuously while implementing:
- Prefer one narrow Worker endpoint over a generic USDA pass-through proxy.
- Prefer one small USDA client and one small USDA mapper over a provider framework.
- Prefer one small shared remote-result type over duplicate OFF-vs-USDA result UIs.
- Keep `FoodDraft`, `LogFoodScreen`, and `FoodItemRepository` as the only edit/review/persist path.
- Keep Worker logic in a tiny number of files.
- Avoid adding Cloudflare storage products unless a real requirement appears.
- Choose explicit code over clever abstractions.
- Stop and simplify if any helper starts taking too many parameters or if provider branching starts scattering across many files.

## Simplifier Review Against `code-simplifier.md`

This plan was checked against the simplifier guidance and is intentionally shaped to reduce trace depth and state overhead.

- It keeps one shared review/edit contract: `FoodDraft`.
- It keeps one review/logging destination: `LogFoodScreen`.
- It keeps one persistence path: `FoodItemRepository`.
- It adds one narrow backend boundary for the shared USDA secret instead of spreading secret handling into the app.
- It keeps the Worker small and explicit rather than introducing a layered backend stack.
- It generalizes the remote-search UI only enough to support two providers without duplicate screens.
- It keeps OFF primary and USDA fallback, which avoids turning this change into a large provider-aggregation project.

## Resolved Scope Decisions

- USDA will be proxied through Cloudflare Workers rather than embedded in the app.
- The Worker will live in the same repo under `worker/usda-proxy/`.
- The Worker will use Hono as a minimal routing layer on Cloudflare Workers.
- Remote packaged-food text search now lives behind the Worker, while barcode lookup remains client-side.
- USDA fallback uses branded search only.
- Provider identity will be preserved through namespaced `externalProductID` values.
- The first deployment target will be a `workers.dev` URL unless a production domain is already available.
- The Worker, not the app, owns OFF retry/fallback behavior for unified remote search.

## Notes, Bugs, and Weird Behavior

- 2026-04-05 — Planning validated against current repo structure.
  - What was checked: `AddFoodScreen`, `AddFoodSearchResults`, `OpenFoodFactsClient`, `FoodDraft`, `FoodItemRepository`, and `FoodSource`.
  - Why it matters: USDA fallback should extend the existing packaged-food search path instead of creating a second stack.

- 2026-04-05 — Shared USDA key architecture resolved.
  - Decision: use a Cloudflare Worker proxy with a Worker secret instead of shipping the key in the client.
  - Why: a shared app-owned key embedded in the app would be effectively public and would violate the intended secret boundary.

- 2026-04-05 — Current Cloudflare guidance validated during planning.
  - What was validated: current Wrangler/Workers docs point to `wrangler.jsonc`, Worker secrets, `.dev.vars`, `npx wrangler dev`, `npx wrangler deploy`, and the newer `secrets.required` validation path.
  - Why it matters: the plan should follow current Cloudflare setup instead of older TOML or legacy setup assumptions.

- 2026-04-05 — Hono Worker choice validated against current docs.
  - What was validated: current Hono docs support Cloudflare Workers, local development with Wrangler, deployment with Wrangler, and GitHub Actions deployment using `cloudflare/wrangler-action`.
  - Why it matters: Hono is a valid routing choice here, but the plan still keeps Wrangler config and deployment grounded in current Cloudflare guidance.

- 2026-04-05 — Cache scope constrained during planning.
  - Decision: use Cloudflare edge cache only as a short-lived optimization.
  - Why: Cloudflare cache locality means it should not be treated as globally durable shared state.

- 2026-04-06 — Worker scaffold created under `worker/usda-proxy/`.
  - Files added: `package.json`, `bun.lock`, `tsconfig.json`, `wrangler.jsonc`, `.dev.vars.example`, `worker-configuration.d.ts`, `src/index.ts`, `src/usda.ts`, `src/types.ts`.
  - Repo hygiene updates: root `.gitignore` now ignores `.dev.vars*`, `node_modules/`, and Worker-local `.wrangler/` state.
  - Validation: `bun run --cwd "/Users/juan/Documents/xcode/cal-macro-tracker/worker/usda-proxy" check` passes.

- 2026-04-06 — Useful Worker implementation findings.
  - Bun request: switched the Worker project to Bun and removed the initial npm lockfile so the Worker does not mix package managers.
  - Wrangler typing: with `nodejs_compat` enabled, Wrangler currently asks for `@types/node`; install it early to avoid a failed first check run.
  - Cache typing: the generated local type environment did not expose `caches.default` the way the first draft assumed, so the Worker now uses `caches.open("usda-proxy")` instead.
  - `secrets.required`: current Wrangler supports it and type generation works, but it is still marked experimental and emits a warning during `wrangler types`.
  - Cache caveat: Cloudflare docs note Cache API behavior has important caveats for `workers.dev`, so treat caching as an optimization only and do not assume early cache-hit validation on the first deployment target.

- 2026-04-06 — App-side USDA fallback wiring landed.
  - Files added: `Features/AddFood/USDAProxyFood.swift`, `Features/AddFood/USDAFoodDraftMapper.swift`, `Features/AddFood/RemoteFoodSearchConfiguration.swift`.
  - Files updated: `Features/AddFood/AddFoodScreen.swift`, `Features/AddFood/AddFoodSearchResults.swift`, `Features/AddFood/RemoteSearchResult.swift`, `cal-macro-tracker.xcodeproj/project.pbxproj`.
  - What changed: search still starts with Open Food Facts, auto-falls back to USDA on OFF outage-style failures, shows a deliberate `Try USDA Fallback` action on OFF zero results, and persists USDA selections using provider-qualified IDs.
  - Config decision: the Worker base URL now lives in one generated Info.plist key, `USDA_PROXY_BASE_URL`, which avoids inventing a larger app config layer just for this proxy.

- 2026-04-06 — Unified remote-search boundary was re-validated against the codebase.
  - What was checked: `AddFoodScreen`, `AddFoodSearchResults`, `RemoteSearchResult`, `OpenFoodFactsClient`, Worker `index.ts`, and Worker `usda.ts`.
  - Decision: move remote packaged-food text search behind the existing Worker instead of keeping OFF orchestration in Swift.
  - Why: one app-level request is the smallest way to hide bounded OFF retries/fallbacks without duplicating result, draft, or persistence code.

- 2026-04-06 — Worker now owns OFF-first packaged-food search orchestration.
  - Files added: `worker/usda-proxy/src/openFoodFacts.ts`, `worker/usda-proxy/src/packagedFoods.ts`.
  - Files updated: `worker/usda-proxy/src/index.ts`, `worker/usda-proxy/src/types.ts`.
  - What changed: added `GET /v1/packaged-foods/search`, bounded OFF timeout/retry handling, optional widen-on-empty fallback to USDA, and one normalized result contract carrying provider identity.

- 2026-04-06 — App-side remote packaged-food search collapsed to one Worker client.
  - Files added: `Features/AddFood/PackagedFoodSearchClient.swift`.
  - Files updated: `Features/AddFood/AddFoodScreen.swift`, `Features/AddFood/AddFoodSearchResults.swift`, `Features/AddFood/RemoteFoodSearchConfiguration.swift`, `Features/AddFood/RemoteSearchResult.swift`, `Features/Scan/Barcode/OpenFoodFactsClient.swift`.
  - What changed: removed app-owned OFF-vs-USDA branching for remote text search, kept local search and review flows intact, and removed dead Swift OFF text-search code.

- 2026-04-06 — Repo quality guardrail caught an oversized feature file.
  - What happened: `make quality-debt` failed after USDA integration because `Features/AddFood/AddFoodScreen.swift` exceeded the repo's 300-line file budget.
  - Resolution: simplified and compacted the file instead of bypassing the rule so the quality pass could succeed cleanly.

- 2026-04-06 — Validation executed after unified-search integration.
  - Worker: `bun run --cwd "/Users/juan/Documents/xcode/cal-macro-tracker/worker/usda-proxy" check` passes.
  - Worker request check: `bun --cwd "/Users/juan/Documents/xcode/cal-macro-tracker/worker/usda-proxy" --eval "import app from './src/index.ts'; const response = await app.request('http://localhost/v1/packaged-foods/search?q=a'); console.log(response.status); console.log(await response.text());"` returned `400` with stable JSON error output.
  - Worker mocked OFF success check: `searchPackagedFoods(...)` returned normalized `openFoodFacts` results.
  - Worker mocked OFF-empty fallback check: `searchPackagedFoods(...)` returned normalized `usda` results after two mocked upstream calls.
  - Worker pagination regression check: page-2 empty OFF results no longer widen to USDA, which avoids mixed-provider pagination.
  - Local dev check: `bun run dev` loaded `.dev.vars`, bound the hidden USDA key, and a direct request for `fairlife` returned real Open Food Facts results through the unified endpoint.
  - App: simulator `xcodebuild` succeeded.
  - Repo quality scripts: `make quality-build quality-format-check quality-dead quality-dup quality-debt quality-deps quality-n1` completed; format/dead-code tools were skipped because the formatter CLI configured in the repo at that time and `periphery` were not installed in this environment.

- 2026-04-05 — Non-USDA groundwork landed before proxy integration.
  - What changed: `AddFoodScreen` and `AddFoodSearchResults` now use a small shared `RemoteSearchResult` wrapper instead of binding the search UI directly to `OpenFoodFactsProduct`, and saved-food editing now shows `sourceName` / `sourceURL` when present.
  - Files touched: `Features/AddFood/AddFoodScreen.swift`, `Features/AddFood/AddFoodSearchResults.swift`, `Features/AddFood/RemoteSearchResult.swift`, `Features/Settings/CustomFoodEditorScreen.swift`, `usda-proxy-implementation-plan.md`.
  - Why it matters: USDA can be added later without duplicating result rows, selection screens, or source metadata UI.
  - Current limitation: provider-qualified `externalProductID` namespacing is intentionally deferred until USDA is actually wired in, to avoid unnecessary churn in the existing Open Food Facts-only path.
