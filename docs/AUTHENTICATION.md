# Native authentication boundary

## Verified REST contract

Origin: `https://fredy.salatiq.online`. App User-Agent: `fredy-ios/1.0`.

1. `POST /api/login`, `Content-Type: application/json`, JSON string fields `username` and `password`. HTTP 200 has no required response body. Session cookies are supplied by the server, not a Bearer token.
2. Require the isolated session's cookie store to contain a Secure `fredy-admin-session` cookie. Let URLSession manage both session/signature cookies; never construct a Cookie header.
3. `GET /api/login/user` through **that same session**. Require HTTP 200, JSON content type and `{userId: String, username: String, isAdmin: Bool}`, with nonempty ID/name. Importantly, HTTP 200 with `{}` means **not authenticated**; it must not show success.
4. Show only the verified username and a simple confirmation screen. No further API requests.

The currently installed route and public user mapping were read without changing them. Login's account/IP rate limiting returns 429; wrong credentials return 401. The user probe returns an empty object when unauthenticated. This task's unauthenticated HTTPS probe reproduced HTTP 200 + `{}`. No login POST, guessed credentials, credential-store reads or server setting changes were performed.

## Client decisions

- Native URLSession, default system TLS/ATS and one fixed HTTPS origin. No HTTP exceptions, custom trust acceptance, browser impersonation, redirects or retries. A delegate rejects all redirects, including same-origin redirects, so a credential-bearing POST is never replayed by this client.
- A private `URLSessionConfiguration.ephemeral` owns memory-only cookies; no shared cookie jar, URL credential store, disk URL cache, UserDefaults, Keychain, credentials in URLs, response/request logging or raw server error text. The public endpoint URL is not a secret.
- The observable main-actor model owns input/state; the view owns focus/cancellable submission. The password input is cleared before the network await and when the form backgrounds/disappears. Credentials necessarily exist transiently in memory for JSON/HTTP; no claim of guaranteed memory zeroization is made.
- Disable repeated submissions, send entered values without lowercasing/trimming them, cancel in-flight form submission on background/disappearance, check cancellation before success and discard local cookies on failure. Server sessions may remain until their normal expiry if authentication partly succeeded; no automatic logout is sent.
- Map 401, 403, 429, session-verification failures, other server statuses and transport failures to bounded Arabic messages. Never echo a response body, cookie or underlying error. The logged-in view is a post-login snapshot, not continuous session-health monitoring.
- No restoration after process termination, periodic renewal, logout feature, data UI or persistent password/session storage in this step.

## Required runtime acceptance checks (NOT executed on Oracle)

On an authorized Mac/simulator or iPhone, using credentials entered only in the app:

- Build/type-check with the iOS 17+ SDK; inspect Arabic RTL, keyboard/autofill, large text, dark mode and VoiceOver.
- Correct credentials: show loading, receive POST 200 + Secure cookies, probe a full user and show the verified username. Do not print cookie/body values while inspecting.
- Wrong credentials: bounded Arabic error, password field empty, retry possible, no authenticated screen. Do not deliberately exhaust the real server's account/IP limits.
- Offline/timeout/TLS failure, 403/429/server failure, missing cookie, probe 200 `{}`, malformed/partial user and redirects: no success screen. Prefer isolated mocked transport tests for failure/status cases.
- Double submission/background cancellation: no duplicate authentication or late successful transition after cancellation. Relaunch after process termination: require fresh login.

Only Python source/syntax/project checks ran here. There is no Swift compiler or Xcode/SDK on the Oracle host, so no Swift runtime or native URLSession result is claimed. Historical REST tests are not a substitute for these checks.
