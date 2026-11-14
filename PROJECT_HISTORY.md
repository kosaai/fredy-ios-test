# Project history (public, sanitized)

This is the history of the **Fredy Test SwiftUI shell**, not a claim that a full property app has been delivered. Entries summarize retained Oracle reports and observed tests. Original reports, raw responses, credentials and deployment configuration stay outside this repository and outside its graph corpus. Evidence fingerprints are listed in `docs/provenance.json`; they establish document identity, not independent reproduction of every historical claim.

## Two distinct workstreams

- **This repository:** independently authored, local-only SwiftUI UI shell, five Swift files, one app target, English/Arabic text. No login, networking, property or job implementation.
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

## Decisions preserved

- Do not copy Fredy implementation, SQL, assets or branding into the original app. Use facts/contracts only; legal/provider-rights review remains open.
- Keep the existing-Fredy client experiment distinct from the independent-backend programme. Choose integration scope explicitly before adding runtime services.
- Remain local-only until a new feature is authorized. No speculative login/network/listing/job scaffolds, IPA, signing automation or production assertions.
- Update this history and handoff, safely refresh the graph incrementally, verify and secret-scan, then commit/push completed authorized changes to `main` as specified in `AGENTS.md`.
