# Handoff

## Current deliverable

Public repository: https://github.com/kosaai/fredy-ios-test — `main`; iOS 17+/Xcode 15+, one native target, 18 Swift sources, no third-party app dependencies.

After existing Arabic RTL login: **Listings and read-only Jobs native tabs**, with a NavigationStack per section and shared expiry UI. Rental list/image behavior is retained. No job create/edit/delete/run controls or requests, search triggering, live status stream, listing details/editing, redesign, mocks or IPA. Original shell/confirmation source remains retained but inactive. Read `PROJECT_HISTORY.md`; the historical Go backend is not integrated.

## First unsigned IPA build — authorized, pending attempt

A new explicit task authorizes a GitHub Actions device IPA, superseding only the earlier no-IPA restriction. Existing app features are unchanged. Manual workflow `.github/workflows/unsigned-ipa.yml` uses macos-26 only, Xcode Release iphoneos arm64, no signing, full Payload packaging, structural verifier and artifact upload. `tools/actions_queue.py` runs on Oracle: one tagged dispatch, a strict 300-second queue deadline with external cancellation/read-back, no alternate runner or automatic retry, then build monitoring if execution begins. Details: `docs/UNSIGNED_IPA.md`.

At this preparation commit no Mac execution or IPA is claimed. After the live attempt update this section with run/SHA, actual runner evidence, cancellation or compiler outcome and verified artifact if any. An unsigned IPA needs external signing and does not prove runtime features. No credentials/signing material or logs/IPA enter Git/index inputs.

## Jobs contract and states

- `GET /api/jobs/` is a plain array including disabled jobs visible to the user. Only decode `id`, optional `name`, Boolean `enabled`/`running` and nonnegative integer `numberOfFoundListings`. No invented aliases, missing flags defaulting false, missing counts defaulting zero, or generated identity.
- Count means active, non-manually-deleted listings as defined by Fredy's storage subquery. Running/enabled statuses are snapshots at the last GET, not live monitoring. The footer explains manual refresh.
- Same login-owned client, original ephemeral URLSession, signed cookies, descriptive User-Agent and common authenticated GET/status/generation guard. No extra session, jobs/data/events endpoint, provider/configuration binding, logging or persistence.
- View-lifecycle load, native pull-to-refresh, explicit error retry, loading/empty/failure/expiry; preserve previous rows on refresh failure. Prevent duplicate requests, deduplicate IDs and check cancellation before publishing; cancel view-owned retry on disappearance.
- Detected job/listing/image 401 invalidates the existing session; either feature signals `AuthenticatedTabs`, which replaces BOTH tabs with a shared expiry/re-login screen. Old section-owned view state/data is removed rather than keeping another cached tab visible. No proactive expiry polling or memory-zeroization guarantee.
- Contract evidence, scope and still-required runtime matrix: `docs/JOBS.md`. Prior boundaries: `docs/AUTHENTICATION.md`, `docs/LISTINGS.md` (rental fields, raw-total pagination, authenticated images, rejected uncached provider redirects).

## Verified evidence and limits

- Nine executable Python source/project tests passed: 3 jobs, 3 listing, 2 login contracts and one project/syntax/resource/localization check across 18 Swift files. New job checks were red before implementation and green afterward. No Swift execution/type-check or native URLSession proof.
- Inspected installed job GET/toClientJob/getJobs source without changes; bounded readonly/query_only database audit found one job and numeric storage/count types without reading out names/IDs/configuration. Runtime running flags were not queried from a separate process or invented.
- Live unauthenticated GET `/api/jobs/`: HTTP 401. No real login, credential-store/session reads, authenticated job requests or job execution in this task. Historical REST success is not current native-client evidence.
- Public-scope scan passed for 41 reviewed files; Graphify incrementally indexed 33 files, with a no-change byte/history check and legacy graph checksum preservation. No missing/dangling endpoints or exact duplicate edges; one known login symbol-resolution self-loop remains an extractor limitation. Recheck staged inputs before push.
- Unverified: Swift/iOS compilation, login/job/listing cookie round trips, optional decoding at runtime, refresh/retry/cancellation, tab navigation/scroll preservation, cross-tab expiry/reauthentication races, RTL/Dynamic Type/dark mode/VoiceOver. No Swift/Xcode/Apple SDK on Oracle; no IPA/archive.
- No tool installation, agents, direct database/source/configuration edits, Fredy or Cloudflare modifications. New jobs access is GET-only; existing authentication POST is unchanged.

## Next checks, not permission for new features

1. On an authorized Mac/simulator/iPhone, build/type-check without IPA. Enter credentials only in the app. Verify same-session login → Listings/Jobs, actual flags/active counts, disabled jobs and refresh.
2. Use isolated tests for empty/null/invalid payloads, false/zero, broken/duplicate IDs, stale refresh/error/cancellation and 403/429; do not exhaust a live account's limits. Verify 401 from either tab/image removes both cached sections, then re-login starts cleanly with no late publication.
3. Inspect native Arabic RTL tabs, independent navigation/scroll state, large text, dark appearance and VoiceOver. Execute `docs/JOBS.md` and remaining listing/image acceptance checks; record actual evidence.
4. Job mutation/run/search triggering, live SSE, details/backfill, persistent session/logout, background work and deployment changes need separate explicit authorization. Provider/source-rights review remains open.

## Completion/privacy

Follow `AGENTS.md`: preserve unrelated work; validate honestly; update history/handoff; review explicit public/index allowlists; secret-scan; incrementally refresh Graphify with snapshots/legacy preservation; review/stage only allowed paths; commit and push main without force; read back the exact remote SHA. Keep private reports, raw data, configuration, credentials/cookies, databases, generated graphs/builds and real-data fixtures out of Git/index inputs. Do not alter shared tools or other graphs.
