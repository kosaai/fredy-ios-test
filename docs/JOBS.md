# Read-only search jobs

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
