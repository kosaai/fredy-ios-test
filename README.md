# Fredy Test

A minimal, independently authored native SwiftUI iPhone client experiment. Implemented scope: **Arabic/RTL sign-in, real rental listings/images and read-only search jobs from existing Fredy**. No listing-detail or job mutation feature; no Fredy source/assets, real account data or credentials are included.

## Open the project

Xcode 15+, iOS 17+. Open `FredyTest.xcodeproj`, select the shared `FredyTest` scheme, and choose a simulator. No third-party app dependencies or project generator. Device signing requires your own team; none is embedded. The app has not been compiled on this Oracle Linux host.

## Structure

```text
Sources/
  App/                       # Login owner and native Listings/Jobs tabs with shared expiry
  Features/Authentication/   # Existing Arabic login form and client owner
  Features/Listings/         # Native list, paging state, row and authenticated image loader
  Features/Jobs/             # Read-only job list, refresh/error/snapshot state
  Features/Home/             # Original shell retained, not the current root
  Features/About/            # Original shell retained unchanged
  Shared/Authentication/    # Isolated ephemeral URLSession and Fredy user contract
  Shared/Listings/          # Actual nullable DTO/envelope and bounded errors
  Shared/Jobs/              # Actual optional job fields and GET-only protocol
  Shared/Components/        # Original reusable InfoBlock
Resources/Localizable.xcstrings # English/Arabic; authentication deliberately uses Arabic RTL
FredyTest.xcodeproj/          # One native app target and shared scheme
Tests/                       # Offline syntax/project/source-contract checks
```

Eighteen app Swift files. System Form/List/navigation, text styles and semantic colors; no redesign or UI framework. Installed SwiftUI and Apple HIG guidance was consulted, including accounts, text fields, buttons, progress, accessibility and RTL. This is not a HIG/accessibility certification.

## Authentication

Fixed authorized HTTPS origin: `https://fredy.salatiq.online`. `User-Agent: fredy-ios/1.0` on login, user probe, pages, images and job reads. A JSON login POST is followed by a GET user probe **using the same URLSession and its session cookies**. Success requires a Secure session cookie and a complete authenticated user, not merely HTTP 200. See `docs/AUTHENTICATION.md` for the contract, privacy choices and runtime acceptance matrix.

No credential/cookie logging or disk persistence; the password field clears on submission, backgrounding and disappearance. Cookies live only in this session's ephemeral storage. After process termination, sign in again. There is no persistent session restoration, logout UI, token auth, automatic retry or biometric login.

## Rental listings

The same authenticated URLSession loads `/api/listings/table` and each `/api/listings/{id}/image`. A native List shows title, EUR price, city/address as provided, area in m², rooms and main image. Explicit Load More, pull-to-refresh, loading/empty/error/retry and session-expired states are included. No synthetic data. See `docs/LISTINGS.md` for exact mapping and limitations: no separate city field; client-side rental filtering; no currency conversion; uncached-image redirects are rejected.

## Read-only jobs

A second native tab loads the plain array from `GET /api/jobs/` with the same authenticated client. It shows `name`, `enabled`, `running` and optional `numberOfFoundListings` (active, non-hidden listings), with loading/empty/error/retry/pull-to-refresh. Optional flags stay unknown rather than false, missing counts are not zero, and the UI labels statuses as snapshots. Detected 401 in either tab replaces both sections with shared session-expired/re-login UI. No create/edit/delete/run controls or requests. See `docs/JOBS.md` for exact mapping and unexecuted iOS checks.

## Deliberately excluded

No listing detail/edit/backfill, job creation/edit/deletion/runs, search triggering, backend changes, Cloudflare changes, analytics, persistent credentials, release pipeline, archive or IPA. Existing Home/About code is not redesigned or presented in the new authentication flow.

## Verification

Using the already available Python validation environment:

```sh
python3 Tests/validate_project.py
python3 Tests/test_login_contract.py
python3 Tests/test_listings_contract.py
python3 Tests/test_jobs_contract.py
python3 tools/check_public_scope.py
```

The first command needs the parsers listed in `Tests/requirements.txt`. Oracle already has those development tools externally; no installation was performed in the login task. Nine checks cover eighteen Swift syntax trees, native source/resource membership, scheme XML, translations, scope and authentication/listing/pagination/image/jobs/tab source invariants. **Source-contract checks do not run Swift or HTTP authentication.**

Live read-only probe in the login task: unauthenticated `GET /api/login/user` returned HTTP 200 with `{}`. No credentials were used and no login POST was sent. The listing-stage unauthenticated table GET returned 401; a read-only local type/count audit verified actual nullable field names, with no raw listing fixtures imported. The jobs-stage unauthenticated GET returned 401; read-only route/storage inspection confirmed actual job fields without importing response/configuration fixtures. Prior authenticated API evidence is historical, not proof of this native implementation.

Swift, Xcode and Apple SDKs are unavailable here: type-checking, compilation, actual URLSession cookie handling, successful/failed native sign-in, real authenticated listing/image fetches, jobs decoding/refresh, tab navigation and shared expiry/cancellation, pagination, previews, device/simulator layout and VoiceOver remain untested. No IPA or archive.

## Project memory and safety

- `PROJECT_HISTORY.md`: sanitized stages, decisions and evidence limits.
- `HANDOFF.md`: exact current scope, gaps and next authorized checks.
- `AGENTS.md`: update history/handoff, safe incremental Graphify, then validated commit/push to main.
- `docs/GRAPHIFY.md`: external offline index and maintenance commands.
- `tools/public-scope.json`: exact public/index allowlists. Raw reports, private configuration, credentials and generated graphs remain excluded.
