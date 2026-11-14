# رصد العقارات — native iPhone UI

An independently authored native SwiftUI iPhone client experiment: Arabic RTL sign-in, real rental listings/authenticated images, selectable saved jobs, and **Add Search by URL → Save & Search** using existing Fredy REST. No Fredy implementation/assets, account data, credentials or fabricated listings are included.

## Open and structure

Xcode 15+, iOS 17+. Open `FredyTest.xcodeproj` and shared scheme `FredyTest`. One app target, **25 Swift files**, no third-party app dependencies/project generator/signing team. App/Features/Shared folders retain the original organization; Home is active with real loaded listings and jobs; the legacy About screen remains inactive. Native SwiftUI four-tab Home/Listings/Jobs/Map navigation with top Budget/Settings sheets, MapKit and Arabic RTL. Appearance follows the system until changed locally in Settings.

- `Features/Authentication`: existing login form and client owner.
- `Features/Listings`: rental feed, raw pagination, rows, authenticated images and filter chips.
- `Features/Jobs`: saved jobs, add form and explicit action coordinator.
- `Shared/Authentication`: the original ephemeral URLSession and cookie authentication.
- `Shared/Jobs`, `Shared/Listings`: verified-contract DTOs, input/payload validation and bounded failures.


## Native design (2026-11-14)

The active tab bar presents Home, Listings, Jobs and Map. Budget and Settings open as top-bar sheets. The display name is «رصد العقارات» while the app target and IPA binary remain FredyTest. No sample ads, figures or property coordinates are embedded. Existing authorized Fredy login, listings, images and jobs reads remain intact; no new backend features or external notifications were connected. The map is a native real basemap without property pins because the current API DTO does not include latitude/longitude. New screens are independent Swift files registered in the Xcode target. See HANDOFF.md.

Build via the existing [manual GitHub Actions workflow](https://github.com/kosaai/fredy-ios-test/actions/workflows/unsigned-ipa.yml); the user triggers it. Swift compilation and appearance require the actual macOS build and iPhone check.

## Authentication and privacy

Authorized origin `https://fredy.salatiq.online`, `User-Agent: fredy-ios/1.0`. JSON login POST is followed by a same-session GET user probe; success requires a Secure session cookie and complete user, not HTTP 200 alone. Existing login/password clearing and generation guards remain. No logging/persistence of credentials, cookies, response bodies or search URLs; no shared cookie jar, persistent session restoration, biometric login or logout UI. Default TLS and rejected redirects remain. See `docs/AUTHENTICATION.md`.

## Add Search by URL

(+) opens an Arabic RTL form with a name and LTR URL field for a complete HTTPS ImmoScout24 Germany **rental search** URL. Opening, typing, refresh, navigation and chips never mutate a job. Only **Save & Search**:

1. Validates the literal URL, checks real provider metadata and all visible saved searches for duplicates.
2. Sends one `POST /api/jobs/` with a fresh collision-checked job id and the pasted URL. This v31 API is an upsert with an empty HTTP 200 body.
3. Re-reads and verifies that exact new job, then attempts one `POST /api/jobs/{id}/run`, requiring 202.
4. Observes actual `running`/`lastRunAt` snapshots through bounded read-only polling; displays safe errors/uncertainty and actual stored results, without invented progress percentages.

New searches are explicitly **disabled/manual-only**, with no notification channels, to avoid automatic scheduler repeats beyond the requested run. Existing searches are never edited/deleted. Duplicate taps/lost acknowledgements do not trigger automatic POST retries; ambiguity recovery is GET-only. Client checks are not server-wide URL uniqueness or distributed exactly-once delivery.

**Fredy limitation:** provider errors are logged internally, not exposed as an API outcome. Stopped/empty is therefore never labelled successful; the UI explains that provider success/failure remains unknown. Full contract, reasoning and iPhone matrix: `docs/ADD_SEARCH.md`.

## Listings, jobs and filters

The same authenticated client reads the real `/api/listings/table` and `/api/listings/{id}/image` endpoints. The rental list retains nullable title/EUR price/address as provided/area/rooms/main image, explicit load-more, refresh/retry and shared expiry. No independent city field or currency conversion is invented; uncached-image provider redirects remain rejected. See `docs/LISTINGS.md`.

Jobs show all accessible saved searches, real optional enabled/running states and active/non-hidden server counts. Selecting a row or job chip loads that exact id through `jobNameFilter`; no selection combines all accessible jobs. Region chips conservatively label search areas from provider URLs, not geocoded listing cities. Region filtering works over actual `job_id` membership on loaded pages; further pages remain loadable. Captions distinguish server active counts across deal types from loaded rental counts/inactive rentals. Unknown counts/flags are not zero/false. See `docs/JOBS.md` for retained GET-stage evidence and `docs/ADD_SEARCH.md` for the extension.

The shell shares one jobs snapshot, owns in-flight save work across sheet dismissal, and removes both tabs plus the sheet when expiry is detected. Independent page/filter generations reject late results during rapid selection changes.

## Verification

With the already available Python validation dependencies listed in `Tests/requirements.txt`:

```sh
python3 -m unittest discover -s Tests -p '*.py' -v
python3 tools/check_public_scope.py
python3 tools/refresh_graph.py
```

Source checks cover Swift syntax, complete native source/resource membership, scheme/localization, login/listing/jobs/filter/mutation invariants and existing build-helper policy. **They do not execute Swift or prove URLSession/UI behavior.** Fresh unauthenticated provider/jobs/table GET probes returned 401; no development-tool job creation/run was used. Initial current read-only data audit found 52 visible/active listings and one job, not the historical 51; no counts or real-data fixtures are embedded.

Oracle has no Swift/Xcode/Apple SDK. Native type checking/build, real authenticated save/run/cookie/image round trips, failure/cancellation/races, iPhone RTL/keyboard/large text/dark mode/VoiceOver and visual comparison with the approved prototype remain unverified. The prototype visual asset was unavailable; no pixel-parity claim. No IPA or CI dispatch in this task. Exact evidence and preservation limits: `VERIFICATION-AR.md`.

## Deliberately excluded / CI status

No listing detail/edit/backfill, general job edit/delete or repeat-run controls, backend/database/Cloudflare/provider_details changes, analytics, credential persistence, signing or release publication.

The manual-only unsigned-IPA workflow is available for building the current native UI (without code signing). First run 43596808016 failed before Swift compilation after macos-26 preflight; there is no verified IPA. Concurrent upstream CI changes were retained by a normal merge; earlier local CI edits are preserved separately in a verified local stash, not applied over upstream or dispatched by this feature. The full suite has one inherited workflow-policy error (JSON parser vs the upstream YAML file), reproduced on the upstream baseline; all 14 native source/project checks pass. Any later authorized build attempt must retain macos-26 and the independent 300-second queue watchdog, without fallback/automatic retry. See `docs/UNSIGNED_IPA.md` and `HANDOFF.md`.

## Project memory

`PROJECT_HISTORY.md` and `HANDOFF.md` record current scope and qualified historical evidence. `AGENTS.md` requires honest validation, sanitized documentation, reviewed public/index allowlists, incremental external Graphify and exact remote-SHA verification. `docs/GRAPHIFY.md` documents structural indexing and known AST resolution artifacts. Private evidence, runtime configuration, account data, generated graphs/builds and signing material stay outside public/index inputs.
