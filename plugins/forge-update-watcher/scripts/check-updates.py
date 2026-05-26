#!/usr/bin/env python3
"""
SessionStart hook: scan sibling plugins for `.upstream-source.json` files,
check if their upstream `plugin.json` reports a newer `version`, and emit
`additionalContext` so the user sees an unobtrusive notification at session start.

Caches results in /tmp/claude-update-watcher-cache.json (TTL 24h) so we don't
hammer the GitHub API.

Output contract: a single JSON object on stdout. On any internal failure we
emit an empty `{}` — never block session start, never error visibly.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

CACHE_PATH = "/tmp/claude-update-watcher-cache.json"
CACHE_TTL_SECONDS = 24 * 60 * 60  # 24h


def _emit_empty() -> None:
    print("{}")


def _read_json(path: Path) -> Optional[dict]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def _load_cache() -> dict:
    if not os.path.isfile(CACHE_PATH):
        return {}
    try:
        with open(CACHE_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def _save_cache(cache: dict) -> None:
    try:
        with open(CACHE_PATH, "w", encoding="utf-8") as f:
            json.dump(cache, f)
    except Exception:
        pass


def _fetch_upstream_plugin_json(repo: str, plugin_path: str) -> Optional[dict]:
    """Fetch the upstream plugin.json. Tries `gh api` first, falls back to curl."""
    upstream_file = f"{plugin_path}/.claude-plugin/plugin.json"

    if shutil.which("gh"):
        try:
            r = subprocess.run(
                ["gh", "api", f"repos/{repo}/contents/{upstream_file}",
                 "--jq", ".content"],
                capture_output=True, text=True, timeout=8,
            )
            if r.returncode == 0 and r.stdout.strip():
                import base64
                decoded = base64.b64decode(r.stdout.strip()).decode("utf-8", errors="replace")
                return json.loads(decoded)
        except Exception:
            pass

    if shutil.which("curl"):
        try:
            url = f"https://raw.githubusercontent.com/{repo}/main/{upstream_file}"
            r = subprocess.run(
                ["curl", "-sfL", "--max-time", "8", url],
                capture_output=True, text=True, timeout=10,
            )
            if r.returncode == 0 and r.stdout.strip():
                return json.loads(r.stdout)
        except Exception:
            pass

    return None


def _check_plugin(plugin_dir: Path, cache: dict) -> Optional[dict]:
    """
    Returns {plugin, local_version, upstream_version, repo} when an update is
    available, else None.
    """
    upstream_src = _read_json(plugin_dir / ".upstream-source.json")
    if not upstream_src:
        return None

    repo = upstream_src.get("repo")
    plugin_path = upstream_src.get("plugin_path")
    if not repo or not plugin_path:
        return None

    local_manifest = _read_json(plugin_dir / ".claude-plugin" / "plugin.json")
    local_version = (local_manifest or {}).get("version") or upstream_src.get("tracked_version")
    if not local_version:
        return None

    cache_key = f"{repo}::{plugin_path}"
    now = int(time.time())
    cached = cache.get(cache_key)
    if cached and now - cached.get("ts", 0) < CACHE_TTL_SECONDS:
        upstream_version = cached.get("version")
    else:
        upstream_manifest = _fetch_upstream_plugin_json(repo, plugin_path)
        upstream_version = (upstream_manifest or {}).get("version")
        if upstream_version:
            cache[cache_key] = {"version": upstream_version, "ts": now}

    if not upstream_version:
        return None

    if upstream_version == local_version:
        return None

    return {
        "plugin": plugin_dir.name,
        "local_version": local_version,
        "upstream_version": upstream_version,
        "repo": repo,
        "plugin_path": plugin_path,
    }


def main() -> None:
    try:
        _ = sys.stdin.read()
    except Exception:
        pass

    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if not plugin_root:
        _emit_empty()
        return

    plugins_dir = Path(plugin_root).parent
    if not plugins_dir.is_dir():
        _emit_empty()
        return

    cache = _load_cache()
    updates = []
    for child in sorted(plugins_dir.iterdir()):
        if not child.is_dir():
            continue
        if child.name == Path(plugin_root).name:
            continue  # skip the watcher itself
        result = _check_plugin(child, cache)
        if result:
            updates.append(result)
    _save_cache(cache)

    if not updates:
        _emit_empty()
        return

    lines = ["📦 **Plugin updates available:**", ""]
    for u in updates:
        lines.append(
            f"- `{u['plugin']}`: {u['local_version']} → **{u['upstream_version']}** "
            f"(source: {u['repo']}/{u['plugin_path']})"
        )
    lines.append("")
    lines.append(
        "Apply with: `/forge-update-watcher:update-apply <plugin>` "
        "(or review with `/forge-update-watcher:update-check`)."
    )
    additional_context = "\n".join(lines)

    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": additional_context
        }
    }))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        _emit_empty()
