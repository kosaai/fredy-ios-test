# Graphify maintenance

## Stage 3 corpus — 2026-11-15

Queried the existing graph before coding (initial truncated map traversal followed by the complete 45-node traversal). Reviewed scope: **78 public paths / 68 graph inputs**, adding two registered Swift sources, source guards and docs/STAGE3.md. Incremental maintenance uses only installed offline AST/Markdown tooling, with prior graph/manifest/history retention, unchanged unrelated historical graph and zero LLM tokens. First Stage 3 update: 28 changed inputs, none deleted, **1007 nodes / 1865 directed edges**; no missing/dangling endpoints, exact duplicates or directed collapsed edges. Graph shape is not compilation/runtime evidence. No coordinates, listing IDs, property/account fixtures, sessions or private reports enter this corpus.

Stage 3 diagnostics retain **six raw AST-resolution self-loops**: the three documented historical loops below plus AppDataModel.invalidate → its distinct home/filtered/map invalidate methods, AppDataModel.expireSession → the child-model expiry methods, and JobsModel.expireSession → management.expireSession. Inspected Swift confirms these are distinct receiver calls, not direct self-recursion. The raw graph is not edited to hide them. Final observed Stage 3 extraction: **1020 nodes / 1857 directed edges**, same six documented loops and no missing/dangling/exact-duplicate/directed-collapsed edges. Earlier update totals above are chronological, not current counts. Read the external last-refresh.json for the current extraction.

## Stage 2 corpus — 2026-11-15

The existing graph was queried before coding. The reviewed corpus now contains **74 public paths / 64 graph inputs**, including four new registered Swift sources, source-contract tests and docs/STAGE2.md. Maintenance continues through the existing offline incremental script: retained prior graph/manifest snapshots, no re-extraction of unrelated projects, no credentials/personal settings/real job responses, no tool install or semantic agents. LLM indexing token cost is **0 input / 0 output**. Current source compilation/runtime limitations are recorded in HANDOFF.md rather than inferred from graph shape.

## FindHaus Stage 1 incremental reconciliation — 2026-11-15

The existing external graph was queried first. Refresh now reconciles previously published FindHaus screen/dashboard changes as well as Jobs controls and docs/FUNCTIONAL_STAGES.md, using the existing allowlist/offline incremental tool, not a fresh/global extraction. Reviewed scope: **68 public paths / 58 graph inputs**. First update changed 39 inputs, deleted none and preserved older graph/manifest snapshots; source replacement also removed six old source-less orphan nodes. Token cost: **0 input / 0 output LLM tokens**.

Read-only diagnostics after that update: no missing/dangling endpoints, exact duplicate edges or directed collapsed edges; the same two documented AST symbol-resolution self-loops remain below. Hash verification preserves all prior history files and the unrelated historical Fredy graph. A final no-change refresh must leave graph bytes and history count unchanged. These structural checks do not prove Swift compilation or native API behavior.

## Corpus and privacy

`tools/public-scope.json` is the exact publication allowlist and defines its smaller graph corpus. Only reviewed Swift/Python source and public Markdown summaries enter the graph. Original Oracle reports, raw responses, account data, private runtime configuration, Git metadata and other project graphs never enter the source snapshot. Graphs/caches/history stay outside Git.

Run:

```sh
python3 tools/check_public_scope.py
python3 tools/refresh_graph.py
```

The script requires the **already installed** Graphify, its own interpreter and bubblewrap. It never installs anything and fails closed if prerequisites or privacy checks fail.

## Indexing and incremental behavior

- New project ID: `fredy-ios-test`, separate from the historical `fredy` graph.
- First AST extraction uses the installed `graphify-safe` wrapper with code-only/no-cluster/one-worker settings.
- Incremental updates use the installed Graphify AST and merge/export libraries in a project-specific offline bubblewrap sandbox. The source and system are read-only; only this index's external output/cache are writable. Inherited credentials and network access are absent. Shared Graphify tools are not modified.
- Markdown documents are indexed deterministically as document/heading nodes and explicit filename-reference edges. This is **structural documentation indexing**, not an LLM semantic graph or an assertion that every prose relationship was inferred.
- SHA-256 file manifests select only changed/new files. Changed sources replace their prior nodes; deleted sources are pruned. Unchanged nodes retain their IDs. A no-change refresh is a no-op.
- Before any changed update, prior graph and manifest snapshots are retained in the external project `history/` folder. The first code-only baseline is also retained before adding documentation. Deletions can reduce the current node count only after that backup; no unrelated graph is overwritten.
- No clustering, semantic API calls, paid model calls, additional agents, hooks, watchers or global graph merging occur. LLM token use is zero.

## External locations on Oracle

Relative to the operator's home directory:

- `.local/share/graphify/projects/fredy-ios-test/graphify-out/graph.json`
- `.local/share/graphify/projects/fredy-ios-test/public-index-manifest.json`
- `.local/share/graphify/projects/fredy-ios-test/last-refresh.json`
- `.local/share/graphify/projects/fredy-ios-test/history/`
- `.cache/fredy-ios-test-public-graph/source/` (allowlisted snapshot only)

Query through the installed safe wrapper:

```sh
graphify-safe --project fredy-ios-test query "AppRootView" --budget 700
graphify-safe --project fredy-ios-test query "API contract findings" --budget 700
graphify-safe --project fredy-ios-test diagnose
```

Known Swift AST symbol-resolution limitations: `LoginModel.signIn` delegates to `service.signIn`, but the extractor resolves that call as a self-loop on the model method. The Add Search stage adds a second self-loop on `SearchJob.regionLabel`, which calls the distinct `SearchURL.regionLabel` helper. Neither source calls itself. Stage 2 adds a third loop on `JSONValue.encode`, which calls the distinct encoding container method `c.encode`; nested Codable encoding is normal, not a direct `self.encode` call. These three raw extractor results are preserved, not hidden by editing the graph; no shared tooling or unrelated graph is changed. Follow Swift source for actual call targets. Diagnostics otherwise report no missing/dangling endpoints, exact duplicates or directed collapsed edges. Undirected projections can collapse reciprocal relationships; the stored graph is directed.

Use `PROJECT_HISTORY.md` for evidence-qualified history and `HANDOFF.md` for remaining work. Update those documents **before** refreshing so the graph is not stale. Do not run a full upstream semantic extraction over the whole Oracle workspace.
