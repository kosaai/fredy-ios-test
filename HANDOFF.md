# Handoff

## Current deliverable

Public repository: https://github.com/kosaai/fredy-ios-test — `main`. iOS 17+/Xcode 15+, one native app target, 14 Swift sources; no third-party app dependencies.

Current authorized scope: existing Arabic RTL login, followed by **real rental listings and authenticated main images** from existing Fredy. No mocks, hardcoded listings, detail/edit screens, jobs, searches, redesign or IPA. Original Home/About/InfoBlock and the earlier confirmation view remain retained, not the active authenticated route. Read `PROJECT_HISTORY.md`; the historical Go backend is separate and not integrated.

## Current data/session contract

- One existing ephemeral URLSession for login, user probe, `/api/listings/table?page=…&pageSize=20` and `/api/listings/{id}/image`. `User-Agent: fredy-ios/1.0`; no AsyncImage/new/shared session, credential logging, disk cache, redirects or TLS exceptions.
- Table envelope `{totalNumber, page, result, availableProviders}`; native DTO requires identity/envelope and treats display fields safely as optional. Map `title`, `price`/`currency`, `address`, `size`, `rooms`, `dealType` exactly.
- No separate city field: display `address` under city/address as provided. No city guessing or geocoding. Only explicit EUR money is displayed as EUR; no conversion. Filter only `dealType == rent` locally, because the route has no general deal-type filter.
- Explicit Load More and pull-to-refresh; raw total/page drive progress even for pages with no rentals, IDs deduplicate, later-page errors retain rows and retry the same page. Offset paging is not a server snapshot.
- Page/image HTTP 401 invalidates local cookies and generation; clear rows/image cache and show expiry plus re-login. Reject stale requests after reauthentication. No proactive expiry polling, renewal, permanent restore or server logout feature.
- Authenticated image bytes only; validate path/MIME/accepted size, downsample with ImageIO and retain a bounded per-screen memory cache. Uncached server images can return 302 and queue Fredy's normal preview capture; the app rejects the redirect and offers retry. Development tools did not trigger image capture/backfill.
- Exact mapping, security/pagination limits and unexecuted acceptance matrix: `docs/LISTINGS.md`. Existing sign-in boundary: `docs/AUTHENTICATION.md`.

## Verified evidence and gaps

- Six executable Python source/project checks passed: 3 new listing contracts, 2 login contracts, one syntax/project/resource/localization test across 14 Swift files. New source contracts were red before implementation and green afterwards. These do not execute Swift, decode real payloads in Swift, or exercise URLSession.
- Read installed route/filter/query source only; bounded read-only/query_only SQLite audit found 51 current non-hidden rows, all rent/EUR, with actual field types and no city column. No raw values, IDs or real-data fixtures published/indexed.
- Live unauthenticated table GET returned HTTP 401. No credentials, session-store inspection or authenticated live API/image request in this task. Historical authenticated tests do not prove this native implementation.
- Public-scope scan passed for 35 reviewed files; 27-file Graphify index was incrementally refreshed. No-change refresh preserved graph/history, and the legacy graph checksum stayed unchanged. No missing/dangling endpoints or exact duplicate edges; one known login name-resolution self-loop remains an extractor limitation. Recheck staged content before publishing, index only allowlisted inputs and preserve snapshots.
- **Not verified:** Swift type-check/build; native login/listing/image cookie round trips; nullable decoding at runtime; pagination/retry/expiry/races; ImageIO WebP/scroll performance; simulator/device/RTL/Dynamic Type/VoiceOver. Oracle has no Swift, Xcode or Apple SDK. No IPA/archive.
- No tool installs, subagents, direct Fredy/database/source/configuration or Cloudflare changes.

## Next checks (not permission to add features)

1. On an authorized Mac, build/type-check without IPA and execute `docs/LISTINGS.md` acceptance matrix with credentials entered only in the app. Verify real login → page 1 → subsequent pages and authenticated stored-image decoding; don't log credentials/cookies/real response bodies.
2. In isolated tests, cover missing optional fields/invalid IDs, non-rental-only pages, empty results, duplicates, offline/later-page retry, 403/429, missing/redirected/malformed image, page/image 401, cancellation and re-login while older requests complete. Do not deliberately rate-limit a live account.
3. Inspect RTL, large text, dark mode, keyboard and VoiceOver on iPhone/simulator. Record actual results; source parsing is not compilation.
4. Persistent sessions/logout, listing details/editing, jobs, background refresh, provider redirects/backfill and deployment changes require separate explicit authorization. Provider/source rights review remains open.

## Completion/privacy rules

Follow `AGENTS.md`: preserve work; validate honestly; update history/handoff; review public/index allowlists; scan; incrementally refresh external Graphify; review/stage only reviewed files; commit/push main without force; read back the exact remote SHA. Keep private reports, listing/contact values, credentials, cookies, runtime configuration, raw responses, databases and graph artifacts out of Git/index inputs. Do not alter shared tooling or other project graphs.
