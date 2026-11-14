# Rules for Codex and other contributors

## Scope

- Read `HANDOFF.md` and `PROJECT_HISTORY.md` first. Keep the existing local-only app behavior unless the current user explicitly authorizes a feature change.
- App source is independently authored. Never import Fredy implementation, assets, databases or real provider fixtures. Do not alter Fredy, jobs, Cloudflare or shared Oracle services without separate authority.
- Use installed SwiftUI and Apple HIG skills for UI tasks. Report missing toolchains honestly; syntax checks are not an Xcode build.

## Required completion order

For every completed, authorized task:

1. Inspect Git status and existing history; preserve unrelated work. Do not reset, force-push or overwrite an existing remote history.
2. Exercise the changed artifact using available tools and record exact results, limitations and remaining work.
3. Update `PROJECT_HISTORY.md` and `HANDOFF.md` with a concise sanitized record. Do not invent completion, CI results, provider access or build evidence.
4. Update `tools/public-scope.json` only for deliberately reviewed public files. Run `python3 tools/check_public_scope.py`.
5. Run `python3 tools/refresh_graph.py` to incrementally refresh the project-specific external Graphify index. It indexes only allowlisted code and public documentation, not the working directory wholesale. Preserve previous snapshots and all unrelated graphs. Do not reinstall tools or invoke semantic LLM extraction/subagents for this maintenance.
6. Review the diff and staged paths, run the public-scope check again, and commit the completed changes on **main**.
7. Push to `origin main` without force. Fetch/read the exact remote ref and verify its SHA equals local HEAD before saying the task is published. If a concurrent change exists, fetch and reconcile normally; never discard it.
8. Return the commit hash, checks and any remaining blockers. If a task is incomplete or a push/check is blocked, say so instead of labelling it done.

The authorized default repository is `kosaai/fredy-ios-test`. Branch protection or a more specific current user instruction takes precedence over direct-main publishing.

## Public information boundary

- Never commit or index passwords, tokens, authorization headers, Cookie/Set-Cookie values, session stores/transcripts, private keys, provisioning material, database files/dumps, private runtime configuration, raw property responses or sensitive reports.
- Never read credential stores or private reports merely to populate a graph. Only sanitized, reviewed facts belong in public history.
- Keep secrets, logs, external evidence, generated graphs/caches, builds and IPA files outside Git. `.gitignore` is defence in depth; the explicit file allowlist and staged scan are the publishing gate.
- The public-scope check is a bounded heuristic, not a guarantee. Review new content manually too. If a secret is detected, stop before staging/push; never echo the value.
- Do not enable Git hooks, background watchers, global graph merges, tool installs or modifications to shared Graphify tooling. Use the repository's explicit offline refresh command.
