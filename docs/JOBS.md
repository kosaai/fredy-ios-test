# Search jobs: current controls and historical read-only evidence

## 2026-11-16 — Job overflow deletion actions now wired to verified Fredy v31 REST

The Jobs card overflow "…" previously presented the same nonfunctional `واجهة التحكم` alert for both destructive choices. Fixed in native SwiftUI: "إخفاء جميع إعلانات المهمة" presents a dedicated destructive confirmation and invokes **one** `DELETE /api/listings/job` with `{"jobId": id, "hardDelete": false}`; the job remains in place. "حذف المهمة نهائيًا" presents a separate destructive alert that requires typing the exact job name before **one** `DELETE /api/jobs/` with `{"jobId": id}`. The latter can cascade to the job's listings in Fredy; this is clearly stated in the confirmation. Neither option runs automatically on opening the menu or entering the screen. Job deletion remains irreversible from FindHaus; bulk hiding may allow new listings after a later run.

All writes require an authenticated, owned, rental-only job with confirmed disabled scheduling and no currently running job, known name, and no pending concurrent action. A fresh preflight GET validates exact ID, permission, name/provider and active count against the last display snapshot; failed/stale/unknown statuses block DELETE. A separate GET after the single acknowledged DELETE verifies the absence of the removed job, or a confirmed zero active listing count while retaining the job. Missing/ambiguous acknowledgements and readbacks are **not** repeated: writes remain locked pending manual read-only reconciliation. The in-flight task is owned by the shared JobsModel, not a recycled card, and changes invalidate the existing data-synchronization pipeline. Session expiry retains existing global handling. Notification channels and all provider configuration are untouched.

The v31 HTTP request contracts were inspected read-only in upstream `lib/api/routes/jobRouter.js` and `lib/api/routes/listingsRouter.js` (empty HTTP 200 acknowledgments). Source contract checks were added and the specific old assertion expecting the two placeholder buttons was updated to require real guarded actions. The three long-standing unrelated test defects remain deliberately deferred, per user instruction. No live delete, server config mutation, IPA compilation, Mac/iPhone run, or GitHub Actions dispatch was performed. Incremental Oracle Graphify refresh is pending and must not rebuild unrelated graphs.


## Current Stage 2

The existing pencil/copy actions are now wired: real name/existing-URL Edit and inactive full-configuration Duplicate through the verified v31 upsert, using full documents and preserving source identity, owner, shares, provider options and filters. Pending operations use GET-only recovery. No run/delete is added by these actions; Stage 1 Run/Enable controls are retained. See docs/STAGE2.md for exact contracts, guard conditions, unsupported/deferred features and available-vs-native verification.

## Stage 1 functional stage (historical)

Run and Enable/Disable on the existing job card are now user-authorized and connected. Contract, complete UI audit, staged checklist, channel restrictions, source-test results and pending iPhone acceptance: **docs/FUNCTIONAL_STAGES.md**. POST `/api/jobs/{id}/run` expects 202 accepted; PUT `/api/jobs/{id}/status` sends `{status: Bool}` and expects an empty 200, then exact GET read-back. Shared/unknown permissions and unknown flags fail closed. Run/Enable additionally require a verified empty notification array; Disable does not remove channels. The same authenticated client is reused; no live development-tool mutation or native runtime proof is claimed.

Only these two controls changed. Edit/Copy/overflow remain previews; destructive job deletion is excluded because upstream cascades to listings. The original read-only stage below is retained as historical evidence, not a description of today's UI/protocol.

## Historical GET-only stage

Historical GET-only stage evidence follows. The current user-authorized extension adds selectable rows and explicit Save & Search through `docs/ADD_SEARCH.md`; provider/dealType/lastRunAt decoding and shared-snapshot guards are now included. Earlier no-create/run statements below describe that original stage, not a prohibition on the new explicit action. No general edit/delete controls were added.

## Actual inspected contract

`GET /api/jobs/` returns a **plain job array**, not the paginated `/data` envelope. The installed route includes disabled jobs visible to the authenticated user, checks access, maps the stored job and adds `running` from Fredy's in-process run-state service. No create/update/delete/run/event endpoint is used by this feature.

Decoded fields only:

| Field | Current API type | UI/fallback |
|---|---|---|
| `id` | nonempty string | Required stable identity; malformed identity fails the response, never generate a fake ID. |
| `name` | string or missing/null | Name; blank/malformed is a generic unnamed-job label. |
| `enabled` | Boolean | Enabled/disabled text; missing/null/wrong type is unknown, not false. The storage mapper explicitly converts SQLite's integer to Bool. |
| `running` | Boolean | Running/not-running text; missing/null/wrong type is unknown. This is a response-time snapshot, not live monitoring. |
| `numberOfFoundListings` | nonnegative integer | Localized count, including a genuine zero; missing/null/negative/fractional/overflow/wrong type is unavailable. |

The count is specifically **active, non-manually-deleted listings for that job**, as defined by the inspected storage subquery; it is not every historical listing, the loaded rental count, or a separately fetched estimate. No invented `listingCount`, `isEnabled` or `isRunning` alias. Unused provider/channel/share configuration is not bound into the UI or persisted. Missing/wrong envelope is an error; an actual empty array is empty success. Duplicate valid IDs are displayed once in server order.

Evidence in this task: read the installed GET route, `toClientJob` and `getJobs` source without changing them. A bounded SQLite `readonly`/`fileMustExist`/`query_only` audit found one stored job, numeric storage flags and nonnegative integer listing counts; no names, IDs, URLs, credentials, raw job responses or real-data fixtures were published/indexed. An unauthenticated HTTPS GET `/api/jobs/` returned HTTP 401. No real login, session-store inspection, authenticated REST fetch or run-state manipulation was performed by development tools. Current authenticated response values remain unverified; source/local shape inspection is not a live authenticated test.

## Shared session and native navigation

The existing client gains only `fetchJobs()` through a read-only protocol. It uses the same `authenticatedRead` helper, login-owned URLSession, ephemeral cookies, `User-Agent: fredy-ios/1.0`, HTTPS/redirect policy, status mapping and generation guards as listings/images. No second session, manually constructed Cookie header, tokens, persistent configuration or logging. Existing transport failures reuse the bounded common messages; no raw error is shown.

After verified login, two native iOS 17-compatible TabView sections show Listings and Jobs, each with its own NavigationStack. Arabic RTL is inherited unchanged from AppRootView. Tabs remain present for empty/error screens, with no redesigned styling or custom routing framework. List rows are Text/LabeledContent only: no toggle, swipe-delete, edit, start/run or other mutation control. Jobs load using view lifecycle `.task`; pull-to-refresh and explicit error retry fetch the full array, not pages or SSE. Statuses are explicitly labelled last-load snapshots.

The jobs model has loading/loaded/empty/error/expiry paths, prevents overlapping reloads and checks cancellation before publishing. Refresh failures retain the last jobs snapshot; cancellation restores the previous state and is not shown as an API error. View-owned retry tasks cancel on disappearance. A page, image **or job** 401 invalidates the existing client; either feature signals the authenticated shell, which replaces both tabs with a shared expired-session screen. This removes their view-owned rows/caches/tasks and prevents displaying the other cached tab after detected expiry. The person can return to login explicitly; the fresh authenticated subtree starts without the prior user's tab state. Memory zeroization and proactive expiry detection are not claimed.

## Verification and remaining iOS acceptance

Nine Python checks passed: three jobs source contracts, the prior five login/listing source contracts, and one project/syntax/resource/localization test across 18 Swift files. The new contracts were observed red before their implementation and green afterward. These inspect source; they do not execute Swift/URLSession, decode jobs at runtime, or prove UI behavior.

Swift, Xcode and Apple SDKs are absent on Oracle. Required later on an authorized Mac/simulator/iPhone, without IPA:

- Type-check/build and enter credentials only in the app. Confirm login → Listings and Jobs use the same authenticated session and jobs show actual names/flags/active counts, including disabled jobs.
- Check empty array; missing/null/malformed optional fields, false flags and zero count; invalid/duplicate identity and non-array/HTML responses in isolated tests, not committed real-data fixtures.
- Verify loading, manual refresh, failed refresh retaining the snapshot, retry and cancellation when changing tabs. Do not intentionally exhaust live rate limits.
- Verify 401 from either tab (including listing images) removes BOTH cached sections and shows shared re-login; reauthenticate with no old rows or late request publication. 403 must stay an access error, not a false logout.
- Inspect native tab order/selection, independent navigation/scroll state, Arabic RTL, Dynamic Type, dark mode and VoiceOver.

No job writes, searches, runs, SSE subscriptions, backend/Cloudflare changes, tool installs, extra agents, mock data, distribution or IPA were included.
