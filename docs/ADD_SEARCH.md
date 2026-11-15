# Add Search by URL — inspected v31 contract and native workflow

## 2026-11-15 — Direct provider website link in Add Search

Added an explicit native SwiftUI external `Link` directly below the selected rental provider in the existing German-source picker. The destination is the reviewed provider's canonical `https://` website from the closed `GermanRentalProvider` enum, not server-supplied redirect data, a listing URL or a fabricated search-results route. The link appears only after successful server catalog confirmation of that selected provider. Tapping it opens the website through iOS URL handling so users can configure a rental search, copy the search results URL and return to FindHaus to paste it. Selecting or opening a provider does **not** create, save or run any job, auto-fill the search URL, change Fredy settings or affect the existing one-create/one-run safety flow. A source-contract regression checks the conditional link, destination, and separation from job writes.

Scope: AddSearchView, the provider enum, a focused source test, and sanitized documentation. Existing Arabic RTL, provider filtering, URL validation, OAuth/MCP, sessions, other screens and the deliberately deferred three inherited test failures are unchanged. No Xcode/Swift runtime, on-device URL-handler test, live provider search, workflow dispatch, IPA build or Oracle Graphify refresh was performed from the GitHub-connected environment. The Graphify index can be refreshed incrementally later via the existing Oracle tool; no rebuild is needed.


## 2026-11-15 — German rental provider picker and Add Search redesign

The existing Add Search sheet is now a compact native Arabic RTL Form with three focused sections: selectable German rental source, search name/URL (with an explicit clipboard paste button and LTR URL entry), and the existing Save & Search/reconciliation controls. The dropdown uses only the intersection of the app's reviewed 15 German rental provider IDs with Fredy's authenticated, live `GET /api/jobs/provider/` metadata, and offers a manual catalog reload/error state rather than fabricated providers. The selected provider ID is submitted alongside the original HTTPS results URL. Switching providers clears the old URL to avoid cross-provider mistakes. `jobs.search_url` localization is generic instead of hardcoded ImmoScout24. InBerlinWohnen, purchase-only providers and other countries are excluded.

The client keeps strict exact host checks, original ImmoScout rental path/radius/shape rules, dedicated checks for Immowelt (classified-search, locations and Rent), Kleinanzeigen, WG-Gesucht, Deutsche Wohnen and Betterhomes, and conservative rental indicators for other providers where the URL dialect varies. No generic arbitrary hosts, translated URLs, fake provider results, purchase-only links or invented API capabilities are accepted. Some valid unusual search URL dialects can be rejected until individually verified; client-side URL screening cannot prove provider execution success or page completeness. Provider metadata `baseUrl`, when present, must agree with the selected reviewed host. No server/network scraping beyond the original authenticated Fredy metadata call.

All original single-job safety gates remain: `dealType="rent"`, `enabled=false`, no notification adapters, collision/duplicate checks within visible jobs, one create POST, exact GET readback of ID/name/provider/disabled/deal type, one manual run POST, GET-only uncertainty recovery and a bounded actual job-state observation. The server still does not expose a reliable provider success/error result. Read-only metadata loading is the only new network activity from simply opening Add Search. The project-specific Graphify index on Oracle cannot be refreshed through this GitHub-only task; run its existing incremental offline refresh on Oracle when authorized, without rebuilding unrelated graphs.

Implementation checked source contracts, unchanged shell/Jobs routing, and localized source strings. No live authenticated provider call, job write, true multi-provider fetch verification, Apple typecheck, iPhone visual test, IPA, Actions dispatch or backend/Oracle/Cloudflare modification is claimed. User's previously deferred three inherited test defects are not included in this scope.


## Scope and evidence

The authorized extension adds a native Arabic RTL (+) form, an explicit **Save & Search** action, selectable saved jobs and job/region chips on the existing rental list. It reuses the original authenticated client and its single ephemeral URLSession. No provider scraping in the app, fabricated listings, new backend, server changes, detail backfill or IPA.

The installed Fredy 31.0.0 source was inspected read-only, specifically:

| Source | Contract evidence |
|---|---|
| `lib/api/api.js` | Registers job routes at `/api/jobs` and provider metadata at `/api/jobs/provider`. Existing session auth applies. |
| `lib/api/routes/providerRouter.js:15–24`, `lib/provider/immoscout.js:18–28` | Provider metadata array; Germany provider id is `immoscout`, base URL is the German ImmoScout24 host. |
| `lib/api/routes/jobRouter.js:211–309` | POST root is an upsert. Payload keys include `jobId`, `name`, `enabled`, `provider` (array of `{id,url}`), `notificationAdapter`, `blacklist`, `excludedLocations`, `shareWithUsers`, `dealType`. Success is HTTP 200 with an empty body, NOT a returned created-job object. |
| `lib/services/storage/jobStorage.js:79–151` | A supplied new `jobId` is stored as that id; an existing id would update that job. Creation does not itself call run. |
| `lib/api/routes/jobRouter.js:187–209` | `POST /api/jobs/{jobId}/run` accepts one job, checks permission/running state, emits a single run request and returns 202. 409 is a real conflict, not success. |
| `lib/services/jobs/jobExecutionService.js` | Manual single-job runs are allowed for disabled jobs. Scheduled run-all selects enabled jobs. The service catches/logs provider failures and emits start/finish without a provider success result. |
| `lib/services/storage/jobStorage.js:309–346` | GET root includes provider configuration, deal type, epoch-millisecond `lastRunAt`, active/non-hidden count. Route adds Boolean `running`. |
| `lib/api/listingFilterQuery.js:65–74`, `lib/services/storage/listingsStorage.js:1376–1383,1740–1743` | `jobNameFilter` takes an exact job ID, not a name; unknown id stays a filter matching nothing. Table rows include `job_id`, `job_name`, `dealType`. |
| `lib/services/immoscout/immoscout-web-translator.js:138–166` | The server translates web `/Suche/.../<rental-type>` URLs. The app must not invent a mobile URL or rewrite filters. |

No Fredy implementation/SQL/assets or raw property/configuration fixtures were imported. Only independent client code and the verified contracts are included.

## Explicit action and mutation safety

1. Opening (+), entering text, navigating, refreshing, loading an image, or selecting a chip never creates or runs anything.
2. Save & Search validates a name and a complete HTTPS German ImmoScout24 rental-search URL. Exact allowed host, no credentials/nonstandard port/fragment, actual `/Suche/de/.../*-mieten` structure, valid percent escapes and required radius/shape geometry. Homepage, exposé, buy links, alternate domains, missing scheme and malformed values are rejected rather than repaired. Unknown query filters are preserved verbatim in the submitted URL. Surrounding form whitespace is trimmed; no other URL translation is sent.
3. GET provider metadata verifies `immoscout`; GET all visible jobs checks duplicate URLs and rejects missing/malformed provider arrays that prevent checking. Comparison normalizes only host/www, scheme/default port, fragment and query ordering, preserving query names/values. This is client-side duplicate prevention, **not** server-wide uniqueness across concurrent devices or semantic equivalence of every possible search URL.
4. A fresh client-generated UUID is supplied as `jobId` and checked against existing ids before the upsert. This is a deliberate **new job identity**, never a fallback for a malformed server id. Payload explicitly chooses `enabled: false`, `dealType: rent`, one `immoscout` URL and empty notification/blacklist/excluded-location/share arrays. Default-null optional filters are not configured. The disabled state prevents unintended scheduler searches: this workflow requests one manual run, not ongoing scheduled search.
5. The app attempts one creation POST. It then GETs the collection and verifies that exact new id, name, provider URL, disabled status and rental type before attempting one `/run` POST. It neither infers identity from a name nor decodes the empty create acknowledgement as JSON.
6. Flags are set **before** each POST awaits. The shell owns the in-flight task across sheet dismissal. Duplicate taps/reopening do not replay it. A transport/cancellation/verification ambiguity locks that draft; the recovery button is GET-only. A job can have been saved even if the acknowledgement or run request failed. No automatic POST retry, rollback/delete, run-all or existing-job edit is performed.
7. This is at-most-one application-level POST attempt per draft/run, not a claim of distributed exactly-once delivery: Fredy has no run idempotency key/outcome resource. If saving cannot be confirmed, no run is sent. If a run response is lost, it is not sent again. An explicit fresh draft still performs the URL duplicate check.

## Progress, errors and actual results

The UI shows validation, saving, exact read-back verification, requesting a run, accepted/waiting, server-reported running, stopped, uncertainty and bounded error/expired-session states. HTTP 400/403/409/429 and transport/server/invalid-response failures have safe localized messages without exposing raw bodies, URLs, credentials or cookies.

After 202, GET jobs polls approximately every two seconds for a bounded five-minute observation window (HTTP requests retain their own timeout). `running == true` alone displays running. A false flag is classified stopped only after an observed start or changed nonmissing `lastRunAt`, so a very fast run can be observed through its persisted trigger timestamp. An initially false snapshot is NOT a successful empty search. Timeout/disconnection is uncertainty; stopping observation does not cancel a server search. Ordinary job refresh outside this flow remains manual. No invented percentage, SSE subscription or run-completion resource.

**Backend limitation:** installed Fredy catches provider failures in logs and exposes no REST provider-success/error/completeness result. Even its `jobStatus` SSE only reports `{jobId,running}`. Therefore stopped is **not** called successful; empty saved listings are not proof of a successful search. This limitation appears in the form and results UI. Precise provider-error diagnostics cannot be delivered under the no-backend-change constraint; no imaginary endpoint or inferred success is used.

Jobs can be selected to show their actual stored listings through `jobNameFilter=<id>`. A missing/deleted job does not widen the filter. New results appear after completion/uncertainty refresh or explicit pull-to-refresh. Images keep the original authenticated route/redirect/cache behavior.

## Home aggregation, counts and regions

- With no job filter, the existing table endpoint returns listings across all accessible jobs. Rental filtering, pagination, unique server-id rows and explicit load-more remain intact. No hardcoded city, count or job id.
- A job chip or Jobs-tab selection resets pagination with the exact server job-id filter. Both the session generation and an independent page/filter generation reject late responses, including cancellation/error branches. A response that widens a selected job to unrelated `job_id`s is rejected.
- Job chips use **Fredy's active, non-manually-deleted count** per job; missing count is unavailable, not zero. They never use the loaded page size as the job total. The caption explicitly says the server count covers all deal types whereas the feed is rentals, including inactive saved rentals. The loaded count is separately labelled.
- Region chips represent the **search area path in saved provider URLs**, not a geocoded city. No label is claimed for radius/shape/geocode overrides, unknown/missing providers or a multi-provider job whose regions cannot all be classified identically. Region filtering matches actual `job_id` membership locally over the pages loaded; load-more remains available until raw server pagination is exhausted. A partial region page uses the partial/empty-page message, not a false final-empty claim.
- The shared jobs snapshot feeds both tabs. Cancellation/generation guards prevent an older Jobs-tab refresh from overwriting a later verified/polled snapshot. Shared session expiry replaces both tabs and dismisses the add sheet; no second session/cookie jar is created.

## Verification and remaining acceptance

Executed locally: red/green Python source-contract regressions, all available Python checks, 22 Swift syntax trees, Xcode membership/scheme/localization checks, explicit public-scope/staged scans and incremental external Graphify. These are **not Swift execution or an Xcode build**. No development-tool POST created a job or launched a search. Fresh unauthenticated GET provider/jobs/table probes each returned 401.

A readonly/query_only audit at the start found **52 stored, visible, active listings and one existing job**, not the historical 51. No hardcoded 51 is used. Before/after whole-row fingerprints are compared privately; no raw data or private runtime configuration enters Git or the graph. The historic count remains a historic observation, not a current assertion.

Still required on a real iPhone/authorized Apple toolchain:

- Type-check/build; real login → paste URL → explicit save → exact job read-back → a single run request → actual statuses/results. Verify disabled/manual-only new job and untouched existing jobs/listings. No credentials in logs/screenshots.
- Double tap, close/reopen while saving, very fast/slow run, server refusal/403/409/429, lost create or run acknowledgement, expiry during every stage, offline/re-login and cancellation. Verify GET-only ambiguity recovery and no replay; no intentional live rate-limit exhaustion.
- Valid rentals, homepage/exposé/buy/other-host/credential/port/malformed-percent inputs, duplicate query order/host variants, missing/malformed provider/count/time fields and concurrent-client duplicate limitations, using isolated nonproduction tests.
- All-jobs list, job selection, region membership over multiple pages, genuine zero/unavailable counts, inactive/non-rental rows, later-page failure, rapid filter switches and old response races; confirm raw pagination and correct active-count captions.
- Arabic RTL with an LTR URL field, large text, keyboard/focus, light/dark appearance, VoiceOver and comparison to the approved visual prototype. That prototype's visual asset was not available in the repository/recovered evidence, so pixel/layout parity has **not** been verified. The implementation uses existing native components, not an invented redesign.

No IPA, CI dispatch, signing, Fredy/database/Cloudflare/provider_details changes, tool installations or additional agents in this task. Concurrent upstream CI commits were retained through an ordinary merge; prior local CI edits are preserved byte-for-byte in a local stash rather than overwriting upstream. After reconciliation all 14 native source/project checks pass; the full 25-test suite has the same one inherited JSON-versus-YAML workflow-test error reproduced in the 20-test upstream baseline. Details: `HANDOFF.md`.
