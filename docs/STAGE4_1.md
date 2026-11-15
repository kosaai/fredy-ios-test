# Stage 4.1 — Real per-account MCP settings

Initial source baseline `88040a6`; final ff-only reconciliation baseline `fe94f2261899916f42927d457bb8c6586ec6e225` on main preserves the concurrent login animation/no-overlap fix and test. Scope is the existing MCP settings page only, not OAuth authorization, token/grant management, MCP tool invocation, APNs or global service configuration. Source/structure checks are not an Apple build or proof of a live persisted account change.

## Installed Fredy v31 contract inspected before completion

Inspected installed `mcpServerSettingsRoute.js`, API registration/authHook, `mcpUserSettings.js`, `mcpAdapter.js`, `mcpAuthentication.js`, `mcpHttpRoute.js` and user-scoped settings storage. Version: **31.0.0**.

| Operation | Exact contract |
|---|---|
| Read | **GET `/api/user/mcp-server`** → `{enabled: Bool, disabledTools: [String], tools: [{name, title, description, readOnly}]}`. |
| Save | **POST `/api/user/mcp-server`** with **both** `enabled: Bool` and `disabledTools: [String]`; returns HTTP **200** and the current settings object. It is **not PUT**, PATCH, per-tool POST, global process start/stop, or an MCP JSON-RPC call. |
| Identity | Both routes are behind existing web-session `authHook`; target is `request.session.currentUser`, not a caller-supplied userId. Ordinary authenticated users can manage their own settings; no invented admin-only gate. |
| Permissions/errors | Missing/expired session → 401; demo-mode non-admin POST → 403; wrong enabled type, non-array disabledTools or unknown tool names → 400; storage failure → 500. Existing client handles network/redirect/TLS, 429 and expiry. GET does not expose a canWrite/demo flag, so the app cannot promise write permission merely from read access. |

The response catalog is derived from actual registered Fredy tools and their annotation title, description and `readOnlyHint`; the app does not ship a second tool list or guess tool identities/classification. GET omits disabled names for tools no longer registered; POST validates known names and deduplicates. The app compares disabled names as a set and rejects missing/wrong types, duplicate/blank catalog identities, duplicate disabled names or unknown disabled names rather than defaulting permission states.

The account setting is `mcp_server`, stored with that user's ID, not global configuration. Server-side defaults are enabled and no disabled tools when no setting exists, and tools added in a future release are enabled by default. These are **server policy**, not fallback values invented by the app; before a valid GET the UI shows unavailable/unloaded and disables mutation controls.

## What this setting means

The actual MCP transports authenticate separately using a Bearer token or OAuth access token. Account enabled/disabled-tool policy is checked on each request/tool call, and the listed tool set is updated by the server. OAuth write scope, demo restrictions and ordinary resource permissions remain additional gates; allowing a tool here does not grant a read-only OAuth connection write permission. Disabling account MCP neither deletes tokens/grants nor revokes them; re-enabling can restore their existing authorized access. There is no tool execution or validation-by-invocation in this feature.

Global Fredy configuration, deployment, Oracle services and Cloudflare are unchanged. Only explicit confirmed actions **inside the app** are wired to the supported per-account POST. Development tools did not save/toggle a real account or inspect tokens/credentials/sessions.

## Existing native page wiring

The vertical Settings root/back/navigation and existing MCP cards/read-write groups/disclosure rows remain. The MCP page now reads live account status and the live tool catalog; the old static list is removed. It supports the actual account enabled switch, individual tool allowance, and the existing group enable/disable controls by building the supported full disabledTools array. A server-enable change preserves disabled tools; an individual/group change preserves other choices and account enabled state. Tool names stay exact/LTR; Arabic layout, explanatory text and existing system colors remain.

All changes first create an in-memory proposal and show a security confirmation describing affected server-provided tool titles and target account status. Toggle bindings display the last confirmed snapshot, not unsaved optimistic success. Cancel, outside dismissal or leaving the page clears only the unsubmitted proposal. The UI labels effective account availability as last-read and distinguishes it from token/OAuth permissions; a disabled account has no effective tools even when individual allowances remain stored.

MCP loading/recovery is independent of unrelated general-settings load failure, dirty drafts or uncertainty; the account-settings banner does not masquerade as MCP load/save status. The existing Connections navigation remains an explicitly unconnected informational page. No OAuth/API calls or APNs changes were added.

## Verified-save and failure design

- A main-actor model owned by the authenticated shell keeps pending work across navigating away/closing Settings; a new sheet does not create a new pending target or replay a write.
- After explicit confirmation, state/task guards synchronously block duplicates. A fresh GET must equal the original configuration **and catalog metadata** before one POST is sent. Detected stale settings/catalog fail closed and require a new read and confirmation.
- The POST response body or a successful HTTP status alone is not success. A separate GET must match the desired enabled/disabled set and the confirmed catalog before showing verified persistence.
- An acknowledged POST followed by 403/429/network/invalid data from read-back remains **uncertain**, not a rejected original write. Lost POST replies may have committed. The target/baseline remain locked across navigation and recovery is **GET only**, never repeat POST, rollback or delete.
- A known rejected POST/preflight error disables further edits until an explicit fresh reload. There is no automatic retry, polling or lifecycle mutation. If the uncertain target cannot be confirmed, controls remain locked until confirmation or session end; there is no unsafe discard-and-replay shortcut.
- Session expiry clears catalog/snapshot/proposal/pending notices, increments a generation, cancels the owned task and triggers the shared expiry UI. Global expiry also clears MCP state. Generation checks and terminal handling prevent late completions from restoring it.

## Limits

There is no server CAS/ETag/idempotency token. Another client can change permissions/catalog between preflight and POST or immediately after verification. Read-back proves one observed stored snapshot, not distributed atomicity or indefinite enforcement. Equality includes the catalog, so a catalog upgrade/reorder can require fresh confirmation and can leave an old uncertain target locked. Upstream deliberately filters removed tool names and defaults new tools to allowed; the app cannot preserve unknown disabled entries the API omits or enforce a future-tool deny-by-default policy without a separately authorized backend change.

No global server health/process status, actual client-token scope/grant list or successful MCP invocation is inferred from account enabled state. Changing allowance is not rollback/cancellation of a tool operation that already passed its permission check. No live credentials, responses, tool/account fixtures or private settings enter Git/Graphify. Pending state is memory-only and not a distributed or app-restart exactly-once guarantee.

## Source checks and pending native acceptance

Seven MCP source/structure gates pass. The recovered incomplete draft already had transport/model checks; page wiring, confirmation-dismissal and target/corpus registration failures were observed before completion and then passed. Final full source/tool suite: **73 cases / 70 passing / same 2 failures + 1 error as exact reconciled baseline 66/63**. The inherited cases are the old global startAll prohibition, stale original-logo digest in the Jobs structural gate after the user's new logo, and YAML-as-JSON workflow policy parser. They are not weakened or fixed outside scope; source-count expectations only move from 38 to 39. Independent `validate_project.py` passes all three checks for **39 Swift sources**, PBX membership, localization and the current genuine logo assets.

No local swift/swiftc/Xcode, so no Apple type-check, real native cookie round trip, displayed UI or live saved-state proof. Unauthenticated HTTPS GET MCP settings returned **401**. No authenticated development-tool POST, MCP request/tool invocation, OAuth operation, notification, backend/configuration change, branch, workflow dispatch, IPA, install or extra agent.

Required authorized device checks: compile and render the existing MCP page in RTL/light-dark/Dynamic Type/VoiceOver; real account GET and tool metadata; enable/disable account and individual/read-write groups with explicit cancel/confirm/outside-dismiss; reload/relaunch to check real persistence; preserve unrelated tool flags and account settings; one write despite repeated taps or closing/reopening; changed catalog/settings before save; 400/403/429/500, offline/lost POST/failed verification and GET-only recovery; expire during each await and verify the whole shell clears, then re-login with a clean model. Verify existing login animation, new user-supplied logo, Safari-return map preservation, Home notification guard and Stage 1–3 behavior. Do not add tokens, authorize clients or invoke tools merely to test this page.

## Main/history preservation

A pre-existing incomplete Stage 4.1 draft was saved in local stash `5b584b7d99f45186126919467ee536e22ad47d05`, main fast-forwarded to the concurrent Safari-return fix `88040a6`, then the draft reapplied without discarding upstream behavior. Immediately before publication, additional concurrent login-transition commits were found; a second checkpoint stash and ff-only main update to `fe94f2261899916f42927d457bb8c6586ec6e225` retained the spring/no-overlap correction and its source test. Only competing prepended history blocks conflicted; both histories were combined without discarding either side. Reconciled full baseline increased by that one upstream test (66/63); Stage 4.1 adds seven gates (73/70). The stash and the older CI stash remain retained. Original branding/login/assets, Safari-return behavior and all unrelated source/transport methods are protected. Incremental external Graphify maintenance retains old graph/manifest/history and unrelated graphs, uses the reviewed public allowlist and zero LLM tokens. Stop after Stage 4.1; OAuth and APNs remain unimplemented.
