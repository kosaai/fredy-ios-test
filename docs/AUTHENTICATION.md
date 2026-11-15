# Native authentication boundary

## Verified REST contract

Origin: `https://fredy.salatiq.online`. App User-Agent: `fredy-ios/1.0`.

1. `POST /api/login`, `Content-Type: application/json`, JSON string fields `username` and `password`. HTTP 200 has no required response body. Session cookies are supplied by the server, not a Bearer token.
2. Require the isolated session's cookie store to contain a Secure `fredy-admin-session` cookie. Let URLSession manage both session/signature cookies; never construct a Cookie header.
3. `GET /api/login/user` through **that same session**. Require HTTP 200, JSON content type and `{userId: String, username: String, isAdmin: Bool}`, with nonempty ID/name. Importantly, HTTP 200 with `{}` means **not authenticated**; it must not show success.
4. Enter native Listings/Jobs tabs only after this verification. Listing/image/job GETs reuse this exact client/session; see `docs/LISTINGS.md` and `docs/JOBS.md`.

The currently installed route and public user mapping were read without changing them. Login's account/IP rate limiting returns 429; wrong credentials return 401. The user probe returns an empty object when unauthenticated. The login-stage unauthenticated HTTPS probe reproduced HTTP 200 + `{}`. No login POST, guessed credentials, credential-store reads or server setting changes were performed.

## Client decisions

- Native URLSession, default system TLS/ATS and one fixed HTTPS origin. No HTTP exceptions, custom trust acceptance, browser impersonation, redirects or retries. A delegate rejects all redirects, including same-origin redirects, so a credential-bearing POST is never replayed by this client.
- A private `URLSessionConfiguration.ephemeral` still manages live cookies; only Fredy's Secure host-scoped session and signature cookies are stored using iOS Security generic-password storage (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). No passwords, shared cookie jar, URL credential store, disk URL cache, UserDefaults, iCloud synchronization, request/response logging or raw server error text. This on-device token is credential-equivalent and must be protected.
- The observable main-actor model owns input/state; the view owns focus/cancellable submission. The password input is cleared before the network await and when the form backgrounds/disappears. Credentials necessarily exist transiently in memory for JSON/HTTP; no claim of guaranteed memory zeroization is made.
- Disable repeated submissions, send entered values without lowercasing/trimming them, cancel in-flight form submission on background/disappearance, check cancellation before success and discard local cookies on failure. Server sessions may remain until their normal expiry if authentication partly succeeded; no automatic logout is sent.
- Map 401, 403, 429, session-verification failures, other server statuses and transport failures to bounded Arabic messages. Never echo a response body, cookie or underlying error. Listing/image/job 401 responses invalidate the local session; a shared expired-session screen removes both tabs and offers return to login; there is no continuous health polling. A generation guard rejects stale in-flight results.
- On launch, including after a reboot and first unlock, reload the on-device Secure cookie records into the isolated session and revalidate them with a fresh authenticated GET /api/login/user. Only a fully validated user opens the app. Missing/expired/invalid cookies or 200+{} require manual sign-in; temporary offline/server failure preserves the saved record for a future attempt. There is no password persistence, periodic session renewal or newly invented logout endpoint. Read-only jobs and listings remain server-authorized; images and listings are not persisted.

## Required runtime acceptance checks (NOT executed on Oracle)

On an authorized Mac/simulator or iPhone, using credentials entered only in the app:

- Build/type-check with the iOS 17+ SDK; inspect Arabic RTL, keyboard/autofill, large text, dark mode and VoiceOver.
- Correct credentials: show loading, receive POST 200 + Secure cookies, probe a full user and then enter the native Listings/Jobs sections. Do not print cookie/body values while inspecting.
- Wrong credentials: bounded Arabic error, password field empty, retry possible, no authenticated screen. Do not deliberately exhaust the real server's account/IP limits.
- Offline/timeout/TLS failure, 403/429/server failure, missing cookie, probe 200 `{}`, malformed/partial user and redirects: no success screen. Prefer isolated mocked transport tests for failure/status cases.
- Double submission/background cancellation: no duplicate authentication or late successful transition after cancellation. Relaunch after process termination/reboot: verify restored cookies with GET /api/login/user before showing tabs. Expired or rejected sessions require login; an offline probe preserves the stored record.

Only Python source/syntax/project checks ran here. There is no Swift compiler or Xcode/SDK on the Oracle host, so no Swift runtime or native URLSession result is claimed. Historical REST tests are not a substitute for these checks.
