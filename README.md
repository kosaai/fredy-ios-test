# Fredy Test

A minimal, independently authored native SwiftUI iPhone client experiment. The only live feature is **Arabic/RTL sign-in to the existing Fredy REST API**. This is not a listings/jobs client and does not include Fredy source, assets, real account data or credentials.

## Open the project

Xcode 15+, iOS 17+. Open `FredyTest.xcodeproj`, select the shared `FredyTest` scheme, and choose a simulator. No third-party app dependencies or project generator. Device signing requires your own team; none is embedded. The app has not been compiled on this Oracle Linux host.

## Structure

```text
Sources/
  App/                       # Root owns one observable login model
  Features/Authentication/   # Arabic native form, state and verified-user screen
  Features/Home/             # Original shell retained, not the current root
  Features/About/            # Original shell retained unchanged
  Shared/Authentication/    # Isolated ephemeral URLSession and Fredy user contract
  Shared/Components/        # Original reusable InfoBlock
Resources/Localizable.xcstrings # English/Arabic; authentication deliberately uses Arabic RTL
FredyTest.xcodeproj/          # One native app target and shared scheme
Tests/                       # Offline syntax/project/source-contract checks
```

Nine app Swift files. System Form/List/navigation, text styles and semantic colors; no redesign or UI framework. Installed SwiftUI and Apple HIG guidance was consulted, including accounts, text fields, buttons, progress, accessibility and RTL. This is not a HIG/accessibility certification.

## Authentication

Fixed authorized HTTPS origin: `https://fredy.salatiq.online`. `User-Agent: fredy-ios/1.0` on both requests. A JSON login POST is followed by a GET user probe **using the same URLSession and its session cookies**. Success requires a Secure session cookie and a complete authenticated user, not merely HTTP 200. See `docs/AUTHENTICATION.md` for the contract, privacy choices and runtime acceptance matrix.

No credential/cookie logging or disk persistence; the password field clears on submission, backgrounding and disappearance. Cookies live only in this session's ephemeral storage. After process termination, sign in again. There is no persistent session restoration, logout UI, token auth, automatic retry or biometric login.

## Deliberately excluded

No listings, images, jobs, searches, backend changes, Cloudflare changes, analytics, persistent credentials, release pipeline, archive or IPA. Existing Home/About code is not redesigned or presented in the new authentication flow.

## Verification

Using the already available Python validation environment:

```sh
python3 Tests/validate_project.py
python3 Tests/test_login_contract.py
python3 tools/check_public_scope.py
```

The first command needs the parsers listed in `Tests/requirements.txt`. Oracle already has those development tools externally; no installation was performed in the login task. Checks cover nine Swift syntax trees, native source/resource membership, scheme XML, translations, scope and authentication source invariants. **Source-contract checks do not run Swift or HTTP authentication.**

Live read-only probe in the login task: unauthenticated `GET /api/login/user` returned HTTP 200 with `{}`. No credentials were used and no login POST was sent. Prior authenticated API evidence is historical, not proof of this native implementation.

Swift, Xcode and Apple SDKs are unavailable here: type-checking, compilation, actual URLSession cookie handling, successful/failed native sign-in, cancellation, previews, device/simulator layout and VoiceOver remain untested. No IPA or archive.

## Project memory and safety

- `PROJECT_HISTORY.md`: sanitized stages, decisions and evidence limits.
- `HANDOFF.md`: exact current scope, gaps and next authorized checks.
- `AGENTS.md`: update history/handoff, safe incremental Graphify, then validated commit/push to main.
- `docs/GRAPHIFY.md`: external offline index and maintenance commands.
- `tools/public-scope.json`: exact public/index allowlists. Raw reports, private configuration, credentials and generated graphs remain excluded.
