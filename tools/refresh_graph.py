#!/usr/bin/env python3
"""Offline incremental Graphify AST + deterministic Markdown structure index.

Uses installed tools only. The shared safe wrapper performs first AST extraction;
subsequent per-project updates run inside the same read-only/offline bwrap policy.
Only the explicit public corpus is copied; other projects/graphs are untouched.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
PROJECT_ID = "fredy-ios-test"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inside(source, project):
    from graphify.extract import extract
    from graphify.build import build_merge
    from graphify.export import to_json

    out = project / "graphify-out"
    graph = out / "graph.json"
    manifest_path = project / "public-index-manifest.json"
    old = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    current = {str(p.relative_to(source)): digest(p) + (":markdown-v2" if p.suffix == ".md" else "") for p in source.rglob("*") if p.is_file()}
    changed = sorted(p for p, h in current.items() if old.get(p) != h)
    deleted = sorted(set(old) - set(current))
    if not changed and not deleted:
        print(json.dumps({"status": "up-to-date", "changed_files": 0, "indexed_files": len(current)}))
        return
    history = project / "history"
    history.mkdir(exist_ok=True)
    stamp = str(time.time_ns())
    if graph.exists():
        shutil.copy2(graph, history / (stamp + "-graph.json"))
    if manifest_path.exists():
        shutil.copy2(manifest_path, history / (stamp + "-manifest.json"))

    code = [source / p for p in changed if Path(p).suffix in {".swift", ".py"}]
    chunk = extract(code, cache_root=project, root=source, parallel=False, max_workers=1) if code else {"nodes": [], "edges": []}
    # Stable document/heading nodes; no LLM inference or raw external reports.
    for relative in changed:
        if Path(relative).suffix != ".md":
            continue
        lines = (source / relative).read_text().splitlines()
        doc_id = "document:" + relative
        chunk["nodes"].append({"id": doc_id, "label": relative, "type": "document", "source_file": relative, "source_location": "L1", "_origin": "ast", "confidence": "EXTRACTED", "confidence_score": 1.0})
        stack = [(0, doc_id)]
        seen = {}
        for number, line in enumerate(lines, 1):
            match = re.match(r"^(#{1,6})\s+(.+)$", line)
            if not match:
                continue
            level, title = len(match[1]), match[2].strip()
            key = hashlib.sha256(title.encode()).hexdigest()[:16]
            seen[key] = seen.get(key, 0) + 1
            node_id = doc_id + ":heading:" + key + ":" + str(seen[key])
            chunk["nodes"].append({"id": node_id, "label": title, "type": "section", "source_file": relative, "source_location": f"L{number}", "_origin": "ast", "confidence": "EXTRACTED", "confidence_score": 1.0})
            while stack[-1][0] >= level:
                stack.pop()
            chunk["edges"].append({"source": stack[-1][1], "target": node_id, "relation": "contains", "context": "contains", "_origin": "ast", "confidence": "EXTRACTED", "confidence_score": 1.0, "source_file": relative})
            stack.append((level, node_id))
    # Explicit filename mentions link reviewed documents, not inferred concepts.
    docs = {p for p in current if p.endswith(".md")}
    for relative in changed:
        if relative not in docs:
            continue
        text = (source / relative).read_text()
        for other in sorted(docs - {relative}):
            if other in text:
                chunk["edges"].append({"source": "document:" + relative, "target": "document:" + other, "relation": "references", "context": "references", "_origin": "ast", "confidence": "EXTRACTED", "confidence_score": 1.0, "source_file": relative})
    ast_sources = [str(source / p) for p in changed]
    merged = build_merge([chunk], graph_path=graph, prune_sources=[str(source / p) for p in deleted] or None, root=source, directed=True, ast_sources=ast_sources)
    if merged.number_of_nodes() == 0:
        raise RuntimeError("Refusing an empty graph")
    # Per-source replacement may legitimately reduce nodes; a prior graph backup is mandatory above.
    if not to_json(merged, {}, str(graph), force=True):
        raise RuntimeError("Graph export failed")
    manifest_path.write_text(json.dumps(current, indent=2) + "\n")
    result = {"status": "updated", "changed_files": len(changed), "deleted_files": len(deleted), "indexed_files": len(current), "nodes": merged.number_of_nodes(), "built_edges": merged.number_of_edges(), "input_tokens": 0, "output_tokens": 0, "mode": "local-AST+Markdown-structure"}
    (project / "last-refresh.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inside", nargs=2, metavar=("SOURCE", "PROJECT"))
    args = parser.parse_args()
    if args.inside:
        inside(*(Path(p) for p in args.inside))
        return
    from check_public_scope import checked_files
    scope = checked_files()
    home = Path.home()
    wrapper = home / ".local/bin/graphify-safe"
    binary = home / ".local/bin/graphify"
    if not wrapper.exists() or not binary.exists() or not Path("/usr/bin/bwrap").exists():
        raise RuntimeError("Installed Graphify and bubblewrap are required; no install/fallback allowed")
    interpreter = binary.read_text().splitlines()[0].removeprefix("#!")
    if not Path(interpreter).is_file():
        raise RuntimeError("Installed Graphify interpreter unavailable")
    project = home / ".local/share/graphify/projects" / PROJECT_ID
    cache = home / ".cache/graphify" / PROJECT_ID
    source = home / ".cache/fredy-ios-test-public-graph/source"
    source.mkdir(parents=True, exist_ok=True)
    desired = set(scope["graph_files"])
    for path in source.rglob("*"):
        if path.is_file() and str(path.relative_to(source)) not in desired:
            path.unlink()
    for relative in sorted(desired):
        destination = source / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists() or digest(destination) != digest(ROOT / relative):
            shutil.copyfile(ROOT / relative, destination)
    project.mkdir(parents=True, exist_ok=True, mode=0o700)
    if not (project / "graphify-out/graph.json").exists():
        subprocess.run([str(wrapper), "--project", PROJECT_ID, "extract", "--source", str(source)], check=True)
    for path in [cache, cache / "home", cache / "tmp"]:
        path.mkdir(parents=True, exist_ok=True, mode=0o700)
    command = ["/usr/bin/bwrap", "--die-with-parent", "--unshare-net", "--new-session", "--ro-bind", "/", "/", "--dev", "/dev", "--proc", "/proc", "--bind", str(project), str(project), "--bind", str(cache), str(cache), "--chdir", str(cache), "--clearenv"]
    env = {"PATH": "/usr/bin:/bin", "HOME": str(cache / "home"), "TMPDIR": str(cache / "tmp"), "XDG_CACHE_HOME": str(cache), "PYTHONDONTWRITEBYTECODE": "1", "LANG": "C.UTF-8", "GRAPHIFY_OUT": str(project / "graphify-out")}
    for key, value in env.items():
        command += ["--setenv", key, value]
    command += ["--", interpreter, str(Path(__file__).resolve()), "--inside", str(source), str(project)]
    subprocess.run(command, check=True)


if __name__ == "__main__":
    main()
