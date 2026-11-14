# Handoff

## Current deliverable

Public repository: https://github.com/kosaai/fredy-ios-test — branch `main`.

A local-only iPhone SwiftUI shell: one app target, five Swift source files, Home/About screens, English/Arabic localization, iOS 17+, Xcode 15+. No app functionality was added during the repository/history/indexing task.

Read `PROJECT_HISTORY.md` before interpreting earlier stages. Earlier Go/backend work is separate and **not implemented in this app**. Historical reports were reviewed and summarized; raw private reports and graph data were not imported into Git.

## Verified versus unverified

- Verified locally: source syntax parsing, native project structure and references, scheme XML, translations, explicit exclusion of network APIs, and no IPA artifact.
- Verified in this task: all five Swift sources byte-identical to the original shell; native scaffold validation passed. Public-scope tests accepted clean input and rejected a synthetic secret, a staged-only secret and an unauthorized graph input.
- Public-file allowlist and secret checks must pass before staging and before push.
- Incremental/no-change refresh behavior was exercised; the no-change run preserved graph bytes/history. The legacy Fredy graph checksum was unchanged.
- Graph indexing: installed Graphify AST, deterministic Markdown structure/reference nodes, offline sandbox, one worker, no LLM or subagents. The source is a sanitized allowlisted snapshot. See `docs/GRAPHIFY.md`.
- Unverified: Xcode compilation/type-checking, simulator/device rendering, VoiceOver, full accessibility, signing and distribution. No IPA exists.
- Historical API snapshots showed working authenticated REST and owner-disabled optional detail enrichment; do not equate historical test results with present server/provider health.

## Next steps (require an explicit new task)

1. Verify the existing shell with Xcode on an available authorized Mac; build/run for an iPhone simulator, inspect Arabic/RTL, light/dark appearance and accessibility text. Do not package an IPA unless requested.
2. Confirm whether the next scope is a client for existing Fredy or a client for the independent backend. Do not mix session contracts or assume the backend is ready.
3. If later authorized, design app configuration and secure authentication without embedding any deployment credential. Establish session lifecycle and error handling before data UI.
4. If later authorized, add tested DTO/network boundaries for nullable mixed-style fields and pagination, followed by listings/detail/image UI, then existing jobs.
5. Treat detail enrichment/backfill as a separately authorized Fredy write operation. The documented cause does not authorize changing settings, jobs or databases.
6. Resolve source/content rights and review source licensing before redistribution. Earlier native/backend design recommendations do not establish legal clearance.

## Finishing every future Codex task

Follow `AGENTS.md`: preserve existing work; validate scope; update history/handoff with evidence and remaining gaps; run the public-scope check; incrementally refresh Graphify; commit and push completed changes to main without force; verify the remote SHA matches local HEAD. Do not claim completion if checks or push are blocked.

## Oracle-only evidence and privacy

Original reports and the legacy Fredy graph remain in the external evidence stores documented in the operator's local context. Only report basenames/hashes and sanitized conclusions are public. Never copy raw responses, property/contact details, private addresses, session material or configuration into this repository or its graph input. Do not install tools, launch agents, run provider searches, alter Fredy/Cloudflare, or refresh the legacy graph as part of ordinary documentation maintenance.
