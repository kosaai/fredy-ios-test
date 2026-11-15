# Stage 4.2 — Real OAuth Connections

Source implementation on main from `4e37a03bce8c55623eae5f7dfb49c84356a47912`. Scope: read existing OAuth connections/scopes and explicitly revoke one client for the current account. No OAuth registration/consent/token exchange, scope upgrade, manual MCP-token management, APNs, provider calls or backend/configuration changes.

## Installed Fredy 31.0.0 contract

Read installed `api.js`, `security.js`, `mcpOAuthGrantsRoute.js`, `mcpOAuthStorage.js`, `mcpOAuthRoute.js` and `mcpAuthentication.js`. No module was executed to load private storage; no credentials, cookies, tokens, live grants or raw private responses were read for implementation/indexing.

| Operation | Actual contract |
|---|---|
| List | **GET `/api/user/mcp-oauth-grants`** → JSON **array**, each `{clientId: String, clientName: String|null, grantedAt: integer epoch milliseconds, scopes: [String]}`. Not a wrapped object or MCP JSON-RPC request. |
| Revoke | **DELETE `/api/user/mcp-oauth-grants/:clientId`**, no body → HTTP **200** `{success:true}`; **404** `{error:"No such grant."}` if this account has no currently revocable grant for that client. |
| Identity | Both routes behind existing web-session **authHook**, always keyed by `request.session.currentUser`; no caller-supplied userId, admin-only requirement or OAuth Bearer token for management. Missing/expired/deleted-user sessions → 401. |
| Policy | Unlike MCP-settings POST, this installed grant-revocation route contains **no demo/admin gate**. Read scopes do not prohibit account owners managing their own grants through their web session. No invented canRevoke field or scope-edit endpoint. Generic 403/429/server/network/redirect/TLS errors are still handled safely. |

The native client reuses its existing ephemeral URLSession, in-memory networking cookies, disabled URL cache, redirect rejection, generation checks, session-expiry handling and recently added device-only Keychain session persistence. The original transport/authentication/storage methods are unchanged; only two feature methods were inserted before the Stage 4.1 methods. Neither OAuth credentials nor grant lists are added to persisted storage or logs.

## Meaning of the list, scopes and revocation

`listGrants` joins registered clients with **unrevoked, unexpired refresh tokens**, grouped by client ID for the current user. It returns the **union** of parsed scopes across those live refresh tokens, not scopes for every individual access token or effective access to every resource. Known OAuth scopes are **mcp:read** and **mcp:write**; authorization requires read and separately requests optional write. Actual write access also requires account/tool policy, resource authorization and demo checks. Unknown scopes remain visible verbatim with no invented read/write description; an empty scope list is unknown metadata, not a read-only assurance.

`grantedAt` is SQL **MIN(created_at) over currently live refresh tokens**. Because rotation revokes the previous refresh token, that reported time may advance. The page explicitly labels it server-reported and explains it is not a guaranteed first-consent history. The millisecond value is converted to Date and formatted in Arabic, with raw IDs/scope strings intentionally LTR. Nullable/blank client names fall back to the exact real client ID, not a fabricated app name.

`revokeGrant` transactionally selects this account/client's currently live refresh-token families and marks live refresh/access tokens in those families revoked. There is no delete of a client, account, listing or job, nor change to MCP enabled/tool settings. Validation of access tokens checks expiry, resource/audience, revocation and read scope. The inspected OAuth implementation uses authorization codes, PKCE S256, resource-bound tokens, refresh rotation and replay-family revocation; none of those creation/exchange operations is added or invoked by this feature.

**Do not overstate revocation:** an empty list proves only no qualifying refresh grants in that read. It does not enumerate manual MCP tokens, every historical/orphan access token, outstanding authorization codes or in-flight operations. The selection does not include expired/revoked refresh families, and a previously issued authorization code/new consent may establish access again. Another client can refresh/authorize/revoke between preflight, DELETE and verification; no CAS/ETag/idempotency contract exists. Revocation does not undo work or cancel a tool that already passed authorization.

## Native page and safety state machine

- Existing Settings Connections navigation/cards, vertical layout, adaptive colors and native controls remain, including MCP → Connections. Native shell/toolbars/automatic Liquid Glass and existing login/RTL are untouched. No redesign or new iOS-26-only dependency.
- Real load/progress/error/last-read/confirmed-empty states replace the disabled placeholder; before valid GET the UI never assumes no connections. Cards show actual client identity, Arabic reported time and every reported scope. Each card offers only explicit revocation; no edit/upgrade/reconnect/authorize action is fabricated.
- A shell-owned main-actor observable model survives leaving the page/closing Settings. It is independent of unrelated account-settings dirty/failed/uncertain state and never starts revocation from `.task` or a refresh. Page appear/manual refresh perform GET only.
- Revoke first records the actual displayed grant and opens an explicit destructive confirmation including client name, **exact ID** and scopes. Cancel, outside dismissal and leaving clear only the unsubmitted proposal. They do not write or clear an uncertain target.
- Confirmation synchronously locks duplicate requests. A fresh GET must still contain **that exact grant metadata** before one DELETE. Changed/disappeared identity/scopes/date/name requires a fresh read and new confirmation; unrelated grant changes do not authorize a different target or get overwritten.
- A 200 acknowledgement is not success. Independent GET must no longer contain that client before a verified-last-read notice and refreshed cards. No optimistic removal or fabricated success body is used.
- Lost/ambiguous DELETE, server/404 error or failed/mismatching read-back retains one uncertain target and prevents further writes across navigation. Recovery is **GET only**, never repeated DELETE, rollback, token creation or polling. A 403/429 on GET after an acknowledged DELETE remains uncertain, not proof of rejection of the original DELETE.
- Known rejection of a write/preflight requires an explicit fresh reload before another proposal. Session expiry cancels the task, increments generation, clears connections/proposal/pending/notice and reaches the existing shell-wide expiry handling; global expiry also clears this model. Late completions cannot restore it.
- If recovery finds absence without a confirmed DELETE acknowledgement, the message explicitly says absence is observed but its cause is unknown (expiration/another client could explain it). If the same client is reauthorized, pending state remains locked rather than deleting a new authorization without consent. Pending work is memory-only, not exactly-once across process restart.

## Checks actually run

Five new source/structure gates were each observed RED before implementing their slice and then GREEN: strict DTO/exact transport, guarded revocation/GET-only uncertainty recovery, native confirmation/shell lifetime/independent section wiring, target/public-corpus registration, and Arabic millisecond-date presentation. No mocks, real account fixtures, tokens or response dumps.

Full suite: **79 cases / 76 passing / identical inherited 2 failures + 1 error as exact baseline 74/71**. Existing failures remain the service-wide startAll prohibition, old logo digest in the Jobs structural gate and YAML-as-JSON workflow parser. No weakening/skipping/fixing these unrelated cases; only expected Swift source count changes **39 → 40**. Independent `validate_project.py` all **three pass** for syntax/target membership/current assets/localization/layout. Local swift/swiftc/xcodebuild absent; these are not Apple compilation or executed Swift/URLSession/revocation tests.

The initial legacy scratch PYTHONPATH was pruned and produced two dependency-import errors. Reused the **already installed** Graphify Python environment plus the **already cached** pure-Python OpenStep parser, without installing anything; baseline and final runs use the same working environment:

```
PYTHONPATH=/home/opc/.cache/uv/archive-v0/8ceHUr99vbtDF9VI \
  /home/opc/.local/share/uv/tools/graphifyy/bin/python \
  -m unittest discover -s Tests -p '*.py' -v
python3 -m unittest discover -s Tests -p test_oauth_connections_contract.py -v
```

Unauthenticated HTTPS GET grants returned **401**. No authenticated development-tool GET/DELETE, actual revocation, client authorization, token exchange, MCP invocation or notification was performed. Live persisted-state and native rendering remain **unverified**.

## Required authorized native acceptance

Compile/type-check on Apple tooling and test the real existing account: list/null name/duplicate-name IDs/Arabic dates, read/write/unknown/empty scopes; legitimate empty vs offline/denied/malformed response; cancel/outside-dismiss/leave with no write; confirm a deliberately chosen expendable real connection and fresh GET/reload/relaunch; repeated taps/closing/reopening without replay; another client's refresh/authorization before/during save; 401 at every await and global expiry, 403/404/429/500, lost DELETE acknowledgement and failed/mismatching verification/recovery. Verify accessibility, RTL/light-dark/Dynamic Type, current Liquid Glass, retained login animation/device-only session restoration, Safari return/map and Stages 1–4.1. Do not create clients/tokens or revoke a real user's connection merely to exercise development checks without their explicit confirmation.

## Preservation and handoff

All unrelated tracked paths, user logo/login/session-restore source and original auth/transport methods are protected against the task baseline. HANDOFF/history/stage checklist and the reviewed public corpus are updated. Graphify maintenance is incremental local AST/Markdown structure only, zero LLM tokens, preserving original graph/manifest/history and unrelated Fredy graph; no credentials/private runtime data enter the index. Diagnostics retain seven documented AST receiver-resolution loops (one new from indexing the unchanged concurrent LoginModel.restoreSession code, which calls service.restoreSession); zero missing/dangling/duplicate/directed-collapsed edges. One orphan source-less node was removed by incremental extraction; original graph and histories remain hash-preserved. No backend/Oracle/Cloudflare configuration changes, installs/extra agents, branch, force push, Apple/IPA build or workflow dispatch. **Stop at Stage 4.2; APNs and unrelated features remain excluded.**
