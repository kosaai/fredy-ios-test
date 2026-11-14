# Handoff

## Native iPhone interface refresh — 2026-11-14

The user requested a **SwiftUI-only visual refresh**, direct on main, with a manual GitHub Actions IPA build. The active authenticated app shell now uses four native bottom tabs: Home, Listings, Jobs, Map. Budget and Settings are top-bar sheets. The bundle display name is **رصد العقارات**, with the same FredyTest executable/bundle ID and unsigned IPA packaging.

Existing login, ephemeral session, authenticated rental data/images, jobs API, select-job filters, and the prior explicit Add Search workflow remain in place. Home reads real loaded rental rows and jobs; counts are clearly labelled loaded jobs/rows, not a fabricated server-wide total. Listings and Jobs are styled native cards. Small client-side listing filters apply only to already loaded pages. Budget calculates solely from user-entered values; no hardcoded money values or backend call. Settings supports local appearance selection. MapKit shows a live base map but **no fake property pins**: the current RentalListing DTO has no coordinates. No external notifications, Telegram, new backend endpoints, job toggles or scheduled runs were added.

New sources: Sources/Features/Map/RentalMapView.swift, Budget/RentalBudgetView.swift, Settings/RentalSettingsView.swift. Project target and public/index allowlists were updated to include all **25 Swift files**; source project-count test updated. Build remains a separate manual-only GitHub Actions workflow at .github/workflows/unsigned-ipa.yml (macos-26, iphoneos arm64, unsigned). The user explicitly owns dispatch. Do not claim that these Swift changes were compiled or device-tested until the workflow succeeds.

Important: the external Oracle Graphify incremental refresh was **not run** from the GitHub connector. The three new paths were added to its allowlist for the next authorized Oracle refresh. Existing Graphify history remains untouched. The inherited YAML-as-JSON test failure in Tests/test_build_tools.py was not addressed in this UI-only work.

## Fredy web Jobs card alignment — 2026-11-14

The Jobs screen now uses the dark Fredy-web-inspired card from the user's reference screenshot: identity/status dot at left, actual stored provider ID, locale-relative lastRunAt from server milliseconds, actual active listing count at right, and bottom controls visually arranged as enabled-state switch, Run, Edit, Duplicate, and overflow with Delete Listings / Delete Job. Only tapping the listings count navigates to the existing filtered rental feed. All new mutation/action controls show an informational alert and **never call an endpoint**, as the user currently authorized UI-only work. Status/amounts/counts come from JobsModel's authenticated GET and are not synthetic. The change replaces only Sources/Features/Jobs/JobsView.swift, preserves all original job creation behavior, and requires user-triggered Xcode build via the existing manual macos-26 workflow to verify compilation and rendering. External Oracle Graphify remains untouched; no new public file paths were introduced.

## Current deliverable

Repository: https://github.com/kosaai/fredy-ios-test — `main`; iOS 17+/Xcode 15+, one native app target, **25 Swift sources**, no third-party app dependencies.

The explicitly authorized extension implements Arabic RTL **Add Search by URL** with (+), name + pasted German ImmoScout24 rental URL, and **Save & Search**. Existing login/session, rental rows/images/pagination and native Listings/Jobs tabs remain. Jobs are selectable; Home is the existing all-accessible-jobs rental feed with job/URL-region filter chips and actual per-job active counts. The previous integration task did not include UI redesign; the later native UI refresh is described above. No fabricated listings, direct provider requests, detail backfill or backend changes. The approved visual prototype asset was not available for comparison; visual parity is unverified.

Read `docs/ADD_SEARCH.md` for the exact inspected API, safety decisions, data scopes and iPhone acceptance matrix. `docs/JOBS.md` and `docs/LISTINGS.md` preserve earlier stage evidence; their older no-mutation restriction is superseded only by this explicit new action.

## Mutation, errors and observation

- Same login-owned client and original ephemeral URLSession/cookie jar/User-Agent. No new session, Cookie header, credentials/configuration logging or persistence.
- Verified installed v31: `GET /api/jobs/provider/`, `GET /api/jobs/`, `POST /api/jobs/` (upsert; empty HTTP 200 acknowledgement), `POST /api/jobs/{id}/run` (202; conflict 409). Never assume a create response contains an id.
- A fresh client UUID is collision-checked before creation, then exact id/name/provider/disabled/rent read-back is required before running. This is not an existing-id update or a fake identity fallback.
- Payload chooses one `immoscout` URL, `dealType: rent`, **enabled false**, empty notification/blacklist/exclusion/share arrays. Disabled is intentional: save a search and request ONE manual run without automatic scheduler repeats or new notifications. Existing jobs are never altered. Default-null optional filters are not configured.
- Only the explicit button starts the save flow. Flags are set before awaiting each POST. At most one creation/run application call per draft; no run-all, automatic replay, rollback/delete or existing-job mutation. Unknown delivery/cancellation locks that draft. Recovery only GETs the exact pending id; it cannot replay a run even if an acknowledgement was lost.
- Duplicate URLs are checked against all visible jobs, preserving every query value and only normalizing comparison syntax. No server-wide uniqueness or distributed exactly-once guarantee is claimed; concurrent other clients remain a limitation.
- The shell owns the save task across sheet dismissal. Read-only polling during that flow observes `running`/`lastRunAt` about every two seconds for a five-minute window, subject to per-request timeout. Unknown/initial false status is not success; fast runs can be observed via changed `lastRunAt`. Expiry dismisses the sheet and replaces both tabs. Generation/cancellation guards protect shared snapshots and page/filter changes.
- **Important backend limit:** provider failures are logged inside Fredy but not exposed as an API outcome, even in job-status SSE. The UI says stopped/uncertain, never claims success from false/zero, and warns that no stored results cannot prove a successful search. Exact provider-error/completeness reporting is impossible without a separately authorized backend change. HTTP/network/validation/expiry errors are surfaced safely.

## Home/job/region semantics

- No selected job means the existing table feed across all accessible jobs; keep rental-only presentation, original nullable field handling, images and raw-total pagination. Selecting a job sends `jobNameFilter=<exact id>`, resets pages and rejects a response with unrelated `job_id`s.
- Job chips show the actual optional `numberOfFoundListings`: active, non-hidden rows across that job's deal types, not loaded rental count. Captions explicitly distinguish these scopes and inactive saved rentals. Missing count is unavailable, never zero.
- Region chips use raw search-area path labels from saved URLs, not invented/geocoded cities. Only a consistently classified region across ALL providers qualifies; radius/shape/geocode overrides and ambiguous/missing providers have no region label. Region membership filters loaded rows by actual job id; partial pages keep Load More and do not assert final emptiness.
- Shared JobsModel serves both tabs. Its generation guard prevents an older ordinary refresh from overwriting a newer verified/polled snapshot. Ordinary jobs status remains last-read/manual-refresh outside the explicit save flow.

## Evidence and limits

- Before concurrent-main reconciliation, all worktree checks passed: **26 Python tests**, including 5 new source-contract gates observed red then green, prior login/listing/jobs gates, native project/resource/localization validation and existing build-tool tests. Twenty-two Swift syntax trees and target membership passed. These are source/tool checks, NOT Swift execution/type checking or URLSession runtime proof.
- Read installed v31 routes/storage/provider translator/execution code without copying its implementation. Fresh unauthenticated GET provider/jobs/table probes each returned 401. No credential store, session-store inspection, authenticated development-tool POST, job creation/run or uncached-image capture was performed.
- Start-of-task readonly/query_only audit already found **52 stored/visible/active listings**, one job, rather than the historical 51. Later count remained 52 and no current row had a creation time after the baseline. Whole-job fingerprint stayed identical; whole-listing fingerprint differed during the interval, so byte-for-byte row preservation is NOT claimed and the differing fields/cause were not established. No backend write was sent by this task. Private hashes/evidence stay outside Git/Graphify.
- **After upstream reconciliation:** all 14 native source/project checks pass (including the 5 new gates). The full exact HEAD suite runs 25 tests with one pre-existing error in `WorkflowPolicyTests`: it parses the upstream YAML workflow as JSON. The exact concurrent `origin/main` baseline runs 20 tests with that identical error; comparison found no newly failed case. Initial worktree/staged totals of 26/25 passed before merging the concurrent CI changes, not after. Neither result is a native Swift build.
- Public/index allowlists are reviewed: **52 public files / 44 graph inputs**. External Graphify refresh is incremental, retains prior snapshots, uses zero LLM tokens and preserves the historical graph. Source-resolution self-loops are documented in `docs/GRAPHIFY.md`; they are not app recursion.
- Oracle has no Swift, swiftc, Xcode or Apple SDK. No native build, authenticated Swift request, rendered UI, real iPhone/simulator test, IPA or CI dispatch. Self-review only; no additional agents/tools were installed or launched.

## Prior CI work remains separate

First IPA run 43596808016 at a6dbdebd637f40f17bb8ea53438d1e3dcbaf1b8d started macos-26 and passed Xcode 26.6/SDK 26.5 preflight, then failed before compilation on redundant `-arch` with generic destination. No IPA. A nullable-runner watchdog regression and local fixes already existed before this feature.

Before reconciliation, four local CI paths had pre-existing edits: `.github/workflows/unsigned-ipa.yml`, `tools/actions_queue.py`, `Tests/test_build_tools.py`, `docs/UNSIGNED_IPA.md`. A final fetch found four concurrent upstream CI commits through `0708f7f97d4b5a929b5f1814b2053d934760060a` (readable YAML, explicit target/output paths, failure-step reporting and notes). They were retained with an ordinary non-force merge; no build was dispatched.

The four original local files are preserved **byte-for-byte in durable local stash `74b1a8de6273656179f4569468e3ae326ee86cfd`**; blob hashes were checked against their pre-merge hashes. They were not reapplied blindly over the changed upstream CI or folded into the feature. Inspect the stash before any future application; do not drop it or overwrite upstream files. Private preservation metadata stays outside Git. Main's imported workflow-policy test already fails because it still expects JSON while the workflow is now YAML; that unrelated baseline error is left untouched under this no-IPA feature scope. No automatic build rerun is authorized.

## Required iPhone checks / remaining work

1. Type-check/build on an authorized Apple toolchain; compare the rendered RTL layout with the actual approved prototype, large text, dark mode, keyboard/focus and VoiceOver. Enter credentials only in the app.
2. Confirm save → exact read-back → one manual run; disabled new job, saved results and untouched existing searches. Exercise duplicate URLs, true zero/unknown fields, very fast/slow/error/no-start runs, rejected run, lost acknowledgements, double taps and closing/reopening. Ambiguity recovery must remain GET-only.
3. Check all-jobs/job/region filtering through multiple pages, active-vs-loaded count scopes, partial empty pages, unknown/mixed providers, rapid selection races, cancellation and failed refresh. Do not fake listings or exhaust live rate limits.
4. Check expiry during every save/read/run/image stage removes BOTH tabs and the sheet, re-login starts cleanly and late results do not leak. A saved job may remain on Fredy after a failed/unknown run; never delete it as an automatic rollback.

## Completion/privacy

Follow `AGENTS.md`: preserve unrelated work; record exact limits; update history/handoff; review public/index allowlists; secret-scan; incrementally refresh Graphify with snapshots and unrelated graph preservation; stage only intended feature paths; commit/push main without force; read back the exact remote SHA. Keep private reports, raw data, credentials/cookies, databases, configuration, graphs/builds/signing outside public/index inputs.
