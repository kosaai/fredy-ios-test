# Graphify maintenance

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

Use `PROJECT_HISTORY.md` for evidence-qualified history and `HANDOFF.md` for remaining work. Update those documents **before** refreshing so the graph is not stale. Do not run a full upstream semantic extraction over the whole Oracle workspace.
