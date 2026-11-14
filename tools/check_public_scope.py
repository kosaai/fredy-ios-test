#!/usr/bin/env python3
"""Check the explicit public file boundary without printing secret values."""
import json
import hashlib
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def checked_files():
    manifest = json.loads((ROOT / "tools/public-scope.json").read_text())
    allowed = set(manifest["files"])
    if len(allowed) != len(manifest["files"]):
        raise RuntimeError("Duplicate public path")
    graph = set(manifest["graph_files"])
    binary_assets = manifest.get("binary_assets", {})
    if not graph <= allowed:
        raise RuntimeError("Graph corpus is not a subset of public files")
    if not set(binary_assets) <= allowed or set(binary_assets) & graph:
        raise RuntimeError("Binary assets must be explicitly allowlisted, outside the Graphify text index")
    patterns = [
        r"-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----",
        r"(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})",
        r"eyJ[A-Za-z0-9_+/=-]{60,}",
        r"(?im)^\s*(?:authorization|cookie|set-cookie)\s*:\s*\S+",
        r"(?i)(?:postgres(?:ql)?|redis)://[^\s/]+:[^\s@]+@",
        r"(?im)^\s*(?:password|api_key|secret|access_token)\s*[:=]\s*['\"]?[^\s'\"]{8,}",
        r"\b(?:100\.(?:6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])|192\.168|10\.[0-9]{1,3})\.[0-9]{1,3}\.[0-9]{1,3}\b",
    ]
    failures = []
    for relative in sorted(allowed):
        path = ROOT / relative
        if Path(relative).is_absolute() or ".." in Path(relative).parts or path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(ROOT):
            failures.append((relative, "invalid public path")); continue
        if any(part.lower() in {"private", "secrets", "sessions", "cookies", "reports", "graphify-out", ".git"} for part in path.relative_to(ROOT).parts):
            failures.append((relative, "private path")); continue
        if relative in binary_assets:
            if path.suffix.lower() != ".png" or path.stat().st_size > 1_000_000:
                failures.append((relative, "unsupported or oversized binary asset"))
            elif hashlib.sha256(path.read_bytes()).hexdigest() != binary_assets[relative]:
                failures.append((relative, "binary content hash mismatch"))
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeError:
            failures.append((relative, "unreviewed binary")); continue
        for number, pattern in enumerate(patterns, 1):
            if re.search(pattern, text):
                failures.append((relative, f"sensitive pattern {number}"))
    if (ROOT / ".git").exists():
        commands = [["git", "ls-files", "-z"], ["git", "diff", "--cached", "--name-only", "-z"]]
        for command in commands:
            names = subprocess.check_output(command, cwd=ROOT).decode().split("\0")
            failures.extend((p, "not public-allowlisted") for p in names if p and p not in allowed)
        for relative in subprocess.check_output(["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z"], cwd=ROOT).decode().split("\0"):
            if not relative or relative not in allowed:
                continue
            staged_bytes = subprocess.check_output(["git", "show", ":" + relative], cwd=ROOT)
            if relative in binary_assets:
                if hashlib.sha256(staged_bytes).hexdigest() != binary_assets[relative]:
                    failures.append((relative, "staged binary content hash mismatch"))
                continue
            staged = staged_bytes.decode("utf-8")
            for number, pattern in enumerate(patterns, 1):
                if re.search(pattern, staged):
                    failures.append((relative, f"staged sensitive pattern {number}"))
    if failures:
        for path, reason in failures:
            print(f"BLOCKED: {path}: {reason}", file=sys.stderr)
        raise RuntimeError("Public-scope check failed; matched values suppressed")
    return manifest


if __name__ == "__main__":
    try:
        value = checked_files()
        print(json.dumps({"public_scope": "PASS", "public_files": len(value["files"]), "graph_input_files": len(value["graph_files"])}))
    except Exception as exc:
        print(type(exc).__name__ + ": " + str(exc), file=sys.stderr)
        sys.exit(1)
