# Project history (public, sanitized)

This is the history of the **Fredy Test native SwiftUI client experiment**, not a claim that a full property app has been delivered. Entries summarize retained Oracle reports and observed tests. Original reports, raw responses, credentials and deployment configuration stay outside this repository and outside its graph corpus. Evidence fingerprints are listed in `docs/provenance.json`; they establish document identity, not independent reproduction of every historical claim.

## Two distinct workstreams

- **This repository:** independently authored SwiftUI experiment, now eighteen Swift files and one app target. Authorized scope is Arabic/RTL login followed by rental list/image and read-only search-job reads over the same temporary cookie session, with native section tabs. No listing-detail/edit or job mutation implementation. Native execution remains unverified.
- **Separate earlier work:** analysis of Fredy and an independently authored Go backend. That backend's commits and experiments are historical context only; no backend source, data, runtime configuration or fixtures have been imported here. Its architecture proposals do not silently become requirements or implemented features of this app.

## Completed research and backend stages

| Stage | Retained result and limit |
|---|---|
| Functional analysis, Stage 1 | Fredy 31.0.0 feature inventory completed; 109 inventory entries. Source/document review, not a successful test of all providers. |
| Source analysis, Stage 2 | Pinned reference `c230d2e931723dc933f851963dbc7f48ac02b8ed`. Historical Graphify corpus: 330 backend JS files, 2,465 built nodes, 6,942 built directed relationships versus 7,125 serialized link records. Frontend/tests were outside that corpus. Keep this graph separate and unchanged. |
| Independent architecture, Stage 3 | Design recommendation: SwiftUI client, modular Go API/worker, relational/geographic storage and APNs-only external notifications. A design document, not a deployed system or cleared data licence. |
| Backend Stage 4 baseline / 4.2 | Separate backend baseline preserved; explicit startup/check/serve/monitor/migration modes implemented. Stage 4.2 records 5 main tests / 18 cases, build and vet passing. Backend commits `2fa206c`, `3c1b544`. |
| Backend Stage 4.3 | Isolated PostgreSQL integration and recovery tests; recorded 28 main tests / 48 cases and 75.5% statement coverage. Two persistence/lease defects fixed. Commit `b6959ab`. No proof of APNs delivery or production readiness. |
| Backend Stage 4.4.1 | ImmoScout integration analysis only. Commit `7a2dcf1`. |
| Backend Stage 4.4.2 | Strict offline search/query foundation; recorded 35 main tests / 99 cases and bounded fuzz testing. Commit `2778b95`. Not full filter parity or live access. |
| Backend Stage 4.4.3 | Independent offline response parser; recorded 41 main tests / 134 cases for the whole backend. Commit `776cefa`. |
| Backend Stage 4.4.4–4.4.5 | Live adapter and request correction did **not** establish successful live retrieval. Preserve the negative result. Commits `3e792ac`, `3fbfd85`. |
| Later isolated evidence labelled 4.4.6 | Retained result JSON reports one HTTP call, HTTP 200, 50 parsed items, zero issues, `complete=false`. This establishes one partial result window only, not completion of the backend integration or production approval. No matching completed stage report/commit was established during this archival task. Raw items remain private. |

Backend test counts above are historical report outcomes, not tests rerun in this repository.

## Existing Fredy deployment/API investigation

These are historical snapshots, not current uptime guarantees. No deployment identifiers, addresses, credentials or real property/contact data are archived here.

1. **Read-only API inspection:** installed Fredy version 31.0.0 was checked. REST uses a signed, server-side web session; MCP Bearer authentication is a separate protocol. Initial data inspection found 51 stored listings, one search job and 50 stored primary images. At that initial inspection no valid session was available, so local read-only storage queries were used; that stage did not prove authenticated REST.
2. **HTTPS connector:** a dedicated persistent connector was configured without changing Fredy functionality. HTTPS certificate verification and four healthy connector connections were observed. An edge 403/1010 depended on the client signature: default Python identification was rejected while an honest descriptive app User-Agent worked. This is not a reason to impersonate a browser or relax security globally.
3. **Authenticated REST test:** login and user probe returned 200; session attributes Secure, HttpOnly and SameSite=Lax were confirmed without exposing values. Listing table, a listing detail, a stored WebP image and existing job collection returned 200. Unauthenticated protected reads returned 401. Two pages returned distinct entries and the same total of 51. The test session was ended.
4. **Missing fields investigation:** five authenticated listing/detail samples returned `description: null` and `images: []`. Matching live upstream detail responses returned nonempty text and 12/4/12/9/9 pictures. Pure installed parsers successfully read them in memory. Owner-scoped `provider_details` was absent, so optional enrichment was skipped; the ordinary search card supplied only the primary picture. Storage and REST supported the missing fields; they were not stripping them. No fix/backfill was performed.

## API contract findings retained for future work

- `POST /api/login`, `GET /api/login/user` and `POST /api/login/logout` manage a web session; password/cookie values must never enter source, logs, fixtures or graphs.
- `GET /api/listings/table`: `{totalNumber, page, result, availableProviders}`. Page numbers start at 1, default page size 50, maximum 1000; there is no REST `hasMore`. Filters and sorting need explicit compatibility tests. `jobNameFilter` accepts a job identifier despite its name.
- `GET /api/listings/:listingId`: stored detail object, with additional `images` gallery and affordability field. `GET /api/listings/:listingId/image` serves the primary picture independently. `images: []` does not mean no primary picture.
- `GET /api/jobs/`: accessible job array, including disabled jobs. `GET /api/jobs/data`: paginated `{totalNumber, page, result}`. The inspected REST router did not define a separate `GET /api/jobs/:jobId`.
- Field names mix snake_case and camelCase; values can be null; some flags are numeric 0/1; timestamps are Unix milliseconds. Do not force nonoptional Swift DTO fields later without evidence.
- GET is not universally side-effect-free: authentication middleware can refresh stored session state, and an uncached primary-image request can queue capture. Authentication itself updates session/last-login state. The prior approved tests had those normal authentication effects, not direct database edits.
- Enabling detail enrichment for the **job owner** affects newly discovered listings. Existing known listings are skipped before the enrichment stage. The existing `POST /api/listings/:listingId/details` can fetch/store details, but is a write operation and was not called in the read-only investigation.
- Upstream public HTML was blocked during comparison; live provider mobile detail responses, not rendered browser galleries, supported the comparison. Availability is not a licence to redistribute provider content.

## SwiftUI shell stage — completed

Created a native Xcode project with Home/About screens, standard navigation, system colors/typography, Arabic/English localization and isolated App/Features/Shared folders. Installed SwiftUI and Apple HIG guidance was applied. Offline source syntax/project/resource/localization checks passed. No Xcode build, simulator launch, rendered preview, VoiceOver audit, archive or IPA was verified. No signing identity or development team was embedded.

## Public repository archival stage

The existing shell is prepared for publication on `main` with this sanitized history, `HANDOFF.md`, `AGENTS.md`, a strict public-file allowlist and a separate external Graphify index. Source functionality remains unchanged: all five Swift files were compared byte-for-byte with the original scaffold archive. The graph uses installed local AST extraction plus deterministic Markdown section/reference indexing; it is not an LLM semantic analysis. Existing historical graphs and private evidence are retained outside this repository.

Archival verification on 2026-11-14: native scaffold validation passed; public-scope gate accepted clean files and rejected a synthetic secret, a staged-only secret and an out-of-allowlist graph input. Incremental extraction was exercised; a repeated no-change refresh preserved graph bytes and history count. The legacy Fredy graph SHA-256 remained unchanged. No tools were installed, no additional agents were launched, and no app, Fredy or Cloudflare behavior changed. Publication is complete only when the remote main SHA is verified against the delivery commit.

## Native login stage — 2026-11-14

The user explicitly authorized only native sign-in to the existing Fredy HTTPS REST service. Added a small main-actor observable login model, Arabic RTL Form with SecureField/loading/errors, an ephemeral URLSession service and a verified-user confirmation view. The existing App/Features/Shared layout, one app target and original Home/About/component source remain intact. This stage chooses the existing-Fredy REST experiment; it does not integrate the separate Go backend.

The client sends the required descriptive User-Agent on JSON POST login and GET user verification, requires a Secure session cookie plus a complete typed user and rejects redirects. HTTP 200 with an empty object is not success. Credentials are not embedded, logged or persisted; cookie storage is private/in-memory, failed attempts discard local cookies, password input is cleared before awaiting, and cancellation is checked before showing success. No persistent login, logout UI, listings, jobs, redesign, IPA or deployment changes were added. Details and future runtime checks: `docs/AUTHENTICATION.md`.

Validation: executable Python source-contract checks were observed failing before implementation and then passing. All three Python checks passed, including Swift syntax trees, OpenStep project and source/resource membership, scheme and English/Arabic keys. A live unauthenticated GET user probe returned HTTP 200 with `{}`. Installed server route/user-mapping source was read only; no credential store or real login POST was used. No tools or additional agents were installed/launched. Source review is local, not an independent review or a runtime proof.

Maintenance: public-scope checks passed for 28 reviewed files; the 20-file Graphify corpus was incrementally refreshed, a repeated no-change refresh preserved graph/history, and the legacy graph checksum was unchanged. One extractor call-resolution self-loop is retained and documented in `docs/GRAPHIFY.md`; it is not source recursion. No missing/dangling endpoints or exact duplicate edges were reported.

Limits: Oracle has neither Swift nor Xcode/Apple SDK; native type-check/build, URLSession's actual cookie round trip, correct/incorrect app sign-in, cancellation and visual/accessibility checks are **not executed**. Historical authenticated REST success is not evidence that this Swift client runs. Follow the runtime matrix before declaring native authentication verified.

## Native rental listings stage — 2026-11-14

The user authorized only the real rental list after login. The existing ephemeral Fredy client is shared through its original login owner; there is still one URLSession, with the same cookie jar, User-Agent and redirect/TLS policy. The authenticated root now presents a standard SwiftUI List, without redesigning login or the legacy shell. Added nullable actual-field DTO/envelope, page model, row and authenticated image loader; fourteen Swift files in one native target. No mock data, hardcoded listings, provider fixtures, jobs, searches, detail/write endpoints or IPA.

Contract grounding: read installed table/image/filter/query source and performed a bounded read-only local SQLite type/count audit. This snapshot contained 51 non-hidden rental/EUR rows. The API has `address`, not a separate city field, and `size`, not an invented area field; nullable/malformed optional values are safe. Only explicitly EUR prices are formatted as EUR. Client-side `dealType == rent` filtering is necessary because the current route normalizer exposes no general deal-type filter. Pagination tracks the raw server total/page, not the filtered count, with deduplication and same-page retry. No listing values, IDs, raw responses or image fixtures were imported. A live unauthenticated table GET returned 401; no authenticated REST/native result is claimed.

Loading/empty/error/retry/refresh/expiry are implemented. Page or image 401 clears local cookies, rows and the bounded thumbnail cache; a generation/cancellation guard rejects stale responses and the screen offers re-login. Images use Fredy's authenticated endpoint only; provider redirects remain rejected. Uncached Fredy image GETs can queue preview capture in the server's existing behavior; development tools did not request those images or trigger capture/backfill. This is not a Fredy or Cloudflare modification.

Validation: the three new source checks were observed red then green; all six Python source/project tests passed (14 syntax trees, Xcode source/resource membership, scheme and translations included). Public-scope scan passed. Swift/Xcode/Apple SDK are absent; no Swift execution/type-check, UI build, real native pagination/cookies/images/expiry/cancellation, screenshot/accessibility check or IPA is claimed. Runtime acceptance and protocol limits are in `docs/LISTINGS.md`. No tools or agents were installed/launched; local review only.

Maintenance verification: public-scope scan passed for 35 reviewed files; Graphify incrementally indexed 27 files using local AST/structural Markdown only. A no-change refresh preserved graph bytes/history and the legacy graph checksum remained unchanged. Diagnostics had no missing/dangling endpoints or exact duplicate edges; the existing single login call-resolution self-loop remains documented, with no source recursion.

## Native read-only search jobs stage — 2026-11-14

Authorized only GET-based search jobs and simple native navigation. Added nullable actual-field SearchJob DTO, a main-actor refresh model, read-only list rows and a two-tab authenticated shell with one NavigationStack per section. Listings remains the initial section; Arabic RTL/system styling and existing login/listing behavior are retained. Both tabs receive the same login-owned client and existing URLSession/cookies/User-Agent. The only new service operation is `fetchJobs()` using the existing authenticated GET helper for `/api/jobs/`, decoding a plain array. No mutations, run triggers, SSE, mocks, real-data fixtures, redesign or IPA.

Grounding: installed GET route adds Boolean `running`; storage converts `enabled` to Bool and returns `numberOfFoundListings` for active, non-manually-deleted rows. Name/status/count may be unknown, never fabricated as false or zero; identity/envelope remain required. A readonly/query_only SQLite audit found one stored job and numeric/nonnegative count storage shapes without exposing job values or IDs. The unauthenticated HTTPS jobs GET returned 401; no credential store/session inspection, real login or authenticated response was used in this task. Runtime status values are not verified.

Loading, actual empty array, bounded errors, manual refresh/retry and cancellation are implemented; a failed refresh keeps the prior snapshot. Job status is last-load data, not live monitoring. Either feature's detected 401 notifies the shared shell, which replaces BOTH tabs with expired-session/re-login UI to avoid leaving the other tab's cached data visible. No job edit/start/delete controls exist. Exact contract and remaining acceptance matrix: `docs/JOBS.md`.

Validation: three new source checks were observed red then green; all nine Python source/project checks passed over 18 Swift syntax trees, project references, scheme and Arabic/English keys. These are not Swift runtime tests. Swift/Xcode/Apple SDK remain absent: native type-check/build, authenticated job decoding/refresh/cookies, tab state and cross-tab expiry/races/visual/accessibility behavior remain untested. No Fredy/Cloudflare changes, tool installs or additional agents; source review is local, not independent.

Jobs-stage maintenance: publication allowlist/secret scan passed for 41 reviewed files; Graphify incrementally indexed 33 files with local AST/structural Markdown and zero LLM tokens. A no-change refresh preserved graph bytes/history; the legacy graph checksum was unchanged. No missing/dangling endpoints or exact duplicate edges; the existing single login call-resolution self-loop remains documented.

## First unsigned iPhone IPA preparation — 2026-11-14

The user explicitly authorized the first real iPhone unsigned build on macos-26 only, with external Oracle queue monitoring and cancellation after 300 seconds without observed execution. Added a manual-only, least-permission, pinned-action workflow for Release iphoneos arm64/no signing/full Payload packaging and verified artifact upload; a reusable one-dispatch queue/build monitor; an independent ZIP/plist/arm64/iOS/unsigned verifier; and offline timing/structural policy tests. No app source/functionality, Fredy, Cloudflare or signing credentials changed. This entry is preparation, NOT a successful build/IPA claim. Live outcome and exact run/artifact must follow separately; no automatic retry or runner fallback is authorized.

## Decisions preserved

- Do not copy Fredy implementation, SQL, assets or branding into the original app. Use facts/contracts only; legal/provider-rights review remains open.
- Keep the existing-Fredy client experiment distinct from the independent-backend programme. Choose integration scope explicitly before adding runtime services.
- Remain local-only until a new feature is authorized. No speculative login/network/listing/job scaffolds, IPA, signing automation or production assertions.
- Update this history and handoff, safely refresh the graph incrementally, verify and secret-scan, then commit/push completed authorized changes to `main` as specified in `AGENTS.md`.
