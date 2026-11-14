# Handoff

## Current deliverable

Public repository: https://github.com/kosaai/fredy-ios-test — branch `main`.

Native SwiftUI iPhone experiment, iOS 17+/Xcode 15+, one app target, nine Swift source files. **Only live feature: Arabic RTL login to the existing Fredy REST API**, followed by a simple verified-user screen. Existing Home/About/InfoBlock source is retained unchanged but is not the active root. No listings, jobs or IPA.

Read `PROJECT_HISTORY.md` first. The independent earlier Go backend is separate; its functionality is not in this app. Current authorization selects existing Fredy sign-in only, not backend integration or data UI.

## Authentication boundary

- Fixed authorized HTTPS origin and `User-Agent: fredy-ios/1.0`; JSON POST `/api/login`, then GET `/api/login/user` through the same ephemeral URLSession.
- Require a Secure session cookie and typed nonempty user ID/name plus Boolean admin flag. A 200 `{}` probe must fail closed.
- No stored credentials/cookies, shared cookie storage, raw error logging, redirect following, TLS/ATS exceptions or automatic retry. Password input clears before await and on background/disappearance; cancellation is checked before success. Relaunch after process termination requires login again.
- A logged-in screen is the verified result at sign-in time; no automatic session expiry/renewal, logout UI or later data access in scope. Failed/cancelled attempts discard local cookies, not necessarily an already-created server session.
- See `docs/AUTHENTICATION.md` for exact contract/security choices and runtime checks.

## Verified versus unverified

- **Passed on Oracle:** three Python checks: two authentication source-contract tests and the project validation test, which parses all nine Swift syntax trees, OpenStep source/resource membership, scheme XML and English/Arabic keys. Source checks were observed red before implementation and green after. They do not execute Swift or network authentication.
- Live read-only unauthenticated GET `/api/login/user`: HTTP 200, JSON `{}`. No credentials, login POST, real cookie values or credential-store reads in this task. Read installed route/user-mapping source without modifying it.
- **Not verified:** Swift type-checking/build, Apple URLSession cookie behavior, successful/failed native sign-in, task cancellation, simulator/device/preview appearance, VoiceOver and signing. No Swift compiler, Xcode or Apple SDK exists on this host; no IPA/archive.
- Prior public-file/staged-secret checks and incremental/no-change Graphify checks are historical validated maintenance mechanisms, not native login tests. Run them again for each change.
- Graphify uses installed local AST and deterministic Markdown structure/reference indexing in the offline project-specific sandbox. The refreshed corpus has 20 allowlisted files; a no-change refresh preserves graph/history bytes and the legacy graph checksum is unchanged. One documented AST self-loop misresolves `service.signIn` as model recursion; inspect source instead of trusting that call edge. No missing/dangling endpoints or exact duplicate edges. Preserve external history; no semantic calls or agents.
- No tools installed, additional agents launched, or Fredy/Cloudflare/source/database configuration changes in this feature task.

## Next authorized checks

1. On an authorized Mac, type-check/build and run the login flow without producing an IPA. Enter credentials only in the app, never in reports, shell arguments or committed test fixtures.
2. Execute the acceptance matrix in `docs/AUTHENTICATION.md`: valid login/user verification, incorrect input, empty user probe, offline/errors/redirect rejection, duplicate submission, cancellation and process relaunch. Use isolated mocks for rate-limit/error cases; do not lock out a real account.
3. Inspect Arabic RTL, password autofill, Dynamic Type, dark mode and VoiceOver on a simulator/device. Record actual results before asserting the client works end-to-end.
4. Persistent session lifecycle, logout, environment selection, listings/details/images and existing jobs need separate explicit authorization. Do not add them to finish this login-only task.
5. Detail enrichment/backfill remains a separately authorized Fredy write; no settings, jobs, searches or database changes are authorized here. Source/provider rights review also remains open.

## Finishing future Codex tasks

Follow `AGENTS.md`: preserve unrelated work; validate honestly; update history/handoff; review `tools/public-scope.json`; secret-scan; incrementally refresh Graphify; review/stage only allowed paths; commit and push to main without force; read back the remote SHA. Never label an untested native behavior as verified.

## Evidence privacy

Private Oracle reports, raw responses, property/contact details, private addresses, runtime secrets and graph outputs remain outside Git and graph inputs. Only reviewed public facts and source belong in the allowlists. Do not install tools or change shared services/graphs as maintenance.
