# FindHaus — Stage 2: account settings and job management

Scope: explicit Stage 2 on main, based on `9bbe76ce490bda76b4e4636a55c37438bc19d696`. Source implementation and available offline checks; not an Apple compilation or authenticated native mutation test. No redesign, new branch, runner dispatch or IPA. The prior stage checklist assigns OAuth/MCP authorization to Stage 4; this stage implements the four account-preference/profile pages, not that separate integration.

## Inspected installed Fredy 31.0.0 contracts

Read-only inspection: `lib/api/api.js`, `lib/api/routes/userSettingsRoute.js`, `jobRouter.js`, `providerRouter.js`, storage/access helpers, application placeholders/phrases/templates/preview, and POI category IDs. No Fredy implementation or real account/listing fixtures were imported. Normal API writes occur only after the app user's explicit confirmation, not from development tools.

| Operation | Method/path | Body / actual response contract |
|---|---|---|
| Current account values | GET `/api/user/settings/` | Plain object keyed by setting name, not a wrapper. `getUserSettings` reads user-specific SQLite rows on each call. Missing entries remain unset, not invented stored defaults. |
| Account theme | POST `/api/user/settings/theme` | `{theme: "light"|"dark"}` → 200 JSON `{success:true}`. |
| Deletion preference | POST `/api/user/settings/listing-deletion-preference` | `{listing_deletion_preference:{skipPrompt:Bool,hardDelete:Bool}}` → 200 JSON acknowledgement. FindHaus only submits `hardDelete:false`; this is a preference save, never a delete. |
| Addresses/place categories | POST `/api/user/settings/home-address` | `{home_addresses:[...]}` → 200 `{success:true,home_addresses:[...],queued}`. Up to 20; labels/addresses up to 300 UTF-16 units, unique normalized labels; known category; transit/car/bike/walk, optional `{departure:{time:"HH:mm"}}`. Server geocodes, normalizes/rebuilds entries, may recompute distances and queue geo/travel-time work. Empty list reads back as absent/null or empty. |
| Provider detail preferences | POST `/api/user/settings/provider-details` | `{provider_details:[providerId...]}` → 200 JSON acknowledgement. No listing backfill endpoint is called. |
| Blacklist-on-details | POST `/api/user/settings/blacklist-filter-on-details` | `{blacklist_filter_on_provider_details:Bool}` → 200 JSON acknowledgement. |
| Applicant profile | POST `/api/user/settings/applicant-profile` | `{applicant_profile:Object}` → 200 `{success:true,applicant_profile}`. Stored serialized length limited to 20,000 UTF-16 units. Existing unknown profile fields retained. Profile email is text for letters, not an email-sending action. |
| Template overrides | POST `/api/user/settings/application-templates` | `{application_templates:{de|en|it:{rent|buy:String}}}` → 200 acknowledgement/echo. Each override ≤20,000 UTF-16 units. Editing the rental slot retains other languages and buy slots; removing that slot in the draft uses the same supported save endpoint, not a hard delete. |
| Provider metadata | GET `/api/jobs/provider/` | Actual provider array; failure blocks provider selection, not a fabricated empty catalog. Previously saved unknown IDs are retained until deliberately changed. |
| Full editable job documents | GET `/api/jobs/` | Disabled jobs included. Raw provider objects, filters, userId, `shared_with_user`, redacted channel references and `isOnlyShared` are needed; the display DTO intentionally omits much of this. |
| Job Edit / Duplicate | POST `/api/jobs/` | Same supported full-field upsert; **empty HTTP 200**, not a returned ID/object. Required client identity followed by independent exact GET verification. No guessed PUT job/edit or duplicate route. |

Setting writes can reject with 400/403 or fail with 500; authentication/rate/network failures retain safe messages through the existing helper. Raw server bodies, personal profile text and channel/session secrets are not logged. All requests use the one login-owned ephemeral URLSession, original cookies/User-Agent, TLS/redirect and session-generation protections.

## Connected settings pages

- **General:** load/edit/save actual account theme and supported soft-deletion policy/skip-prompt value. Theme only applies from confirmed server data, including real light override on a dark system. The native app remains Arabic; the existing Arabic label does not pretend to change the server's saved language. The account language is shown read-only. Listing cards retain explicit confirmation and soft removal regardless of Fredy web policy.
- **Travel time:** load actual saved addresses/categories, edit labels/address/mode/departure, add/remove draft entries, explicit save. No fabricated geocoding or travel estimates. Read-back compares every routing input in order while permitting server-generated coordinates. Save confirmation warns about recalculation; persistence is not proof of a completed geocode/sweep. No autocomplete/geocode request is made by typing.
- **Listing details:** actual provider list and selected IDs, real blacklist flag with explicit unset/unknown states, separate scoped saves. Enabling enrichment can affect future provider requests; it does not repair old missing descriptions or call listing details/backfill.
- **Application:** load/edit/save real profile fields, correct Boolean tri-state flags and employment keys, and per-language rental overrides. Unknown/unexposed profile fields, other languages and purchase overrides are preserved. The language selector chooses an override slot; it is not a claim that all letters use that language. No email is sent and no application is submitted.

The authenticated shell owns AccountSettingsModel, so closing/reopening Settings does not reset a pending write or silently discard drafts. The original vertical navigation, native cards, FindHaus art, RTL and login animation are retained. Each card saves one key/endpoint; there is no multi-endpoint transaction or false "all settings saved". Other dirty cards retain BOTH their draft and original comparison baseline; a later save cannot silently overwrite a remote change just because another card was refreshed.

Before writing, a fresh GET must match that key's original baseline. A 200 acknowledgement is followed by a separate GET and value comparison. Unknown delivery/read-back mismatch locks writing; recovery performs GET only. A 403/429 after an acknowledged POST, or a failed recovery GET, is NOT evidence that the original write was rejected and does not unlock replay. An expired session clears personal state and reaches the shell's existing global expiry UI. Dirty reload is explicit and confirmed.

## Real Job Edit and Duplicate

Only the existing pencil/copy controls are connected. A new native form loads the selected job's **full** document and permits name and existing provider URL edits. It does not offer unsupported advanced-filter/sharing/provider replacement editors. Those settings are retained, not dropped or defaulted.

- Original ID, enabled state, provider ordering/IDs/extra options, blacklists, exclusions, share list, channel references, spatial/spec/commute filters and deal type are preserved for Edit. Even a future editor cannot drop non-URL provider fields: a changed entry must equal the old object with only its URL replaced. Unchanged URL strings are not translated, canonicalized or shortened. New URL input must be valid HTTPS with intact percent escapes; server-side provider-host validation remains authoritative.
- Only owner/admin-editable jobs (`isOnlyShared:false`, known owner) can enter this workflow. The original owner is never reassigned. A preflight GET checks full mutable fields and owner; conflicts abort before writing. Editing a running/unknown-running job is blocked. Enabled jobs with saved channels must first be disabled using Stage 1 controls; we neither send alerts nor silently clear their channels.
- Duplicate carries the same full configuration and shares but gets one fresh collision-checked UUID, **enabled false**, and no run request. The new owner is the authenticated creator, as required by the real API; the original job/owner/listings remain untouched. Creating a deliberate duplicate of the same URLs is expected, distinct from accidental repeated submits.
- A shared-model-owned task sets its attempt guard before POST. UI confirmation/double-tap guards and pending-model reuse across sheet dismissal prevent automatic replays. An uncertain duplicate always reconciles the **same pending ID**, never generates another ID or deletes a job as rollback.
- Success requires an independent GET matching all writable target fields and editable permission. Duplication also checks that the source's writable fields/owner still match the baseline. Jobs then reload from the real API, not a synthetic appended row/count.

No atomic compare-and-swap/idempotency/URL-uniqueness contract exists on v31's upsert. The preflight/read-back reduce races but do not guarantee distributed exactly-once or protect the GET→POST window against other clients. Pending state is memory-only, not crash/reinstall durability. Concurrent source changes after a copy can leave reconciliation uncertain; no automatic rollback or forced overwrite is attempted.

## Unsupported, excluded, or deliberately deferred

These are distinct, not mislabeled as missing APIs:

- **Application preview:** supported POST `/api/user/settings/application-preview` exists, but `preview.js` renders against a fixed `SAMPLE_LISTING`. It is deliberately NOT called/displayed under the no-mock-data constraint. The real saved-letter action on actual listing cards remains unchanged. Default shipped templates are not fabricated into the editor; an unset override is clearly labeled.
- **Hard delete:** excluded even though Fredy has destructive APIs. Job overflow delete/bulk removal remain informational; job delete cascades to listings. Saved hard-delete web preference can be displayed read-only, but never posted as true by this client.
- **Notifications/APNs:** existing disabled native notification settings remain disabled; no APNs contract was established and no Telegram/email/channel-test integration is added.
- **OAuth/MCP:** real GET/POST settings and GET/DELETE grant routes exist, as inspected. Live authorization/tool switches/grant revocation belong to the documented Stage 4 and are not newly enabled here. Their existing pages continue to disclose that they are not loaded/saved. This is a stage boundary, not an invented claim that the endpoints do not exist.
- No new global administration, finance persistence, provider backfill, public signup, map/feed redesign, search execution, branch or IPA.

## Verification and limits

- Thirteen new source-contract gates were observed failing before the corresponding implementation and then passing. They cover transport reuse, scoped settings/read-back, UI wiring, full-job preservation/collision/no-replay, model-owned editor, ambiguity after acknowledged writes, source membership, dirty-baseline retention, provider extra-field retention, confirmed light-theme application, canonical absent-key read-back after clearing addresses and preservation of Arabic POI labels with actual IDs and authenticated-shell reload of saved theme.
- All 36 Swift syntax trees, exact Xcode compiled-source membership, Arabic/English keys and original icon/logo dimensions/hashes pass through the independent project/source gate. Two existing source gates were updated only for the intended source count 32→36 and edit/copy no longer being placeholders; destructive-placeholder assertions remain.
- Exact baseline archive at `9bbe76ce490bda76b4e4636a55c37438bc19d696`: **36 checks / 33 pass / 2 failures + 1 error**. Stage 2: **49 checks / 46 pass / the identical three failing names and source locations**. Full suite is not green; no new failed case. Inherited issues: service-wide startAll prohibition conflicts with existing Dashboard; escaped PNG signature assertion; YAML workflow parsed as JSON. None was hidden/fixed outside scope.
- Installed version confirmed 31.0.0. Unauthenticated HTTPS GET settings/jobs each returned 401. No credential/session-store lookup, login, authenticated development-tool settings/job POST or database write was made. Successful native save/read-back remains unexecuted.
- Oracle has no swift/swiftc/Xcode. No online Mac peer was available; no Mac was started or workflow dispatched. AST/source checks are not native type checking, decoding, URLSession execution, persisted-value tests or rendered UI/accessibility proof.

### Required authorized Apple/iPhone acceptance

1. Compile all source against the target Apple SDK; exercise native forms, VoiceOver, Dynamic Type, light/dark, Arabic RTL, existing login animation/art and Dashboard/Stage 1 controls.
2. Load real settings, edit/save each scoped key, then close/reopen/re-login and verify the exact values from GET. Test unset/malformed fields, unknown profile/provider extras and all supported template languages without losing other overrides.
3. Dirty two sections, save one, change the other's server value independently, then verify conflict protection retains the second section's original baseline. No implicit save/discard across navigation.
4. Test address validation/duplicate names/known categories/custom departures, normalization, geocoding failure and background queue. Do not claim travel computation complete just from a persisted address.
5. Edit name/URL and duplicate an owned real test job without channels, verifying original ID/owner/URLs/config/shares, disabled new copy, no run, actual job list/count and no deletion. Verify shared, running, enabled-channel and stale-document refusal.
6. Exercise double taps, sheet closing/reopening, session expiry before/during/after POST, 400/403/409/429/500, lost acknowledgements and post-ack/recovery GET errors. Recovery must stay GET-only against the original pending key/ID. Do not intentionally rate-limit live services or expose personal data in logs/screenshots.
