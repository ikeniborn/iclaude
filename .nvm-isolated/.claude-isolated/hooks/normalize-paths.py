#!/usr/bin/env python3
"""
Pre/PostToolUse hook — нормализация путей в GRAPHIFY_OUT/ для портативности.

abs2rel: абсолютные пути → относительные  (PostToolUse, для git)
rel2abs: относительные пути → абсолютные  (PreToolUse, для graphifyy runtime)

Прямой вызов (stdin пустой/не JSON):
  python3 normalize-paths.py abs2rel < /dev/null
"""
import sys
import json
import os
import re
import subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor


def get_project_root(gout: Path) -> Path:
    # abs2rel: читаем сохранённый путь из .graphify_root (самый точный источник)
    root_file = gout / ".graphify_root"
    if root_file.exists():
        content = root_file.read_text(encoding="utf-8").strip()
        if content and content.startswith("/") and Path(content).exists():
            return Path(content)
    # rel2abs / fallback: git rev-parse или CWD
    try:
        root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL, text=True
        ).strip()
        return Path(root)
    except Exception:
        return Path.cwd()


def normalize_manifest(gout: Path, project_root: Path, mode: str) -> None:
    manifest_path = gout / "manifest.json"
    if not manifest_path.exists():
        return
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception:
        return

    new_data: dict = {}
    changed = False

    for key, value in data.items():
        if mode == "abs2rel":
            if key.startswith("/"):
                try:
                    rel = os.path.relpath(key, project_root)
                    if rel.startswith("../"):
                        new_data[key] = value
                    else:
                        new_data[rel] = value
                        changed = True
                except ValueError:
                    new_data[key] = value
            else:
                new_data[key] = value
        else:  # rel2abs
            if key and not key.startswith("/"):
                new_data[str(project_root / key)] = value
                changed = True
            else:
                new_data[key] = value

    if changed:
        manifest_path.write_text(json.dumps(new_data, indent=2), encoding="utf-8")


def normalize_root(gout: Path, project_root: Path, mode: str) -> None:
    root_path = gout / ".graphify_root"
    if not root_path.exists():
        return
    content = root_path.read_text(encoding="utf-8").strip()
    if mode == "abs2rel":
        if content.startswith("/"):
            root_path.write_text(".", encoding="utf-8")
    else:  # rel2abs
        if not content.startswith("/"):
            root_path.write_text(str(project_root), encoding="utf-8")


def normalize_cache_file(cache_file: Path, project_root: Path, mode: str) -> None:
    try:
        data = json.loads(cache_file.read_text(encoding="utf-8"))
    except Exception:
        return

    changed = False

    for container in (data.get("nodes", []), data.get("edges", [])):
        for item in container:
            sf = item.get("source_file", "")
            if not sf:
                continue
            if mode == "abs2rel" and sf.startswith("/"):
                try:
                    rel = os.path.relpath(sf, project_root)
                    if not rel.startswith("../"):
                        item["source_file"] = rel
                        changed = True
                except ValueError:
                    pass
            elif mode == "rel2abs" and sf and not sf.startswith("/"):
                item["source_file"] = str(project_root / sf)
                changed = True

    if changed:
        cache_file.write_text(json.dumps(data), encoding="utf-8")


def normalize_cache(gout: Path, project_root: Path, mode: str) -> None:
    cache_dir = gout / "cache" / "ast"
    if not cache_dir.exists():
        return
    files = list(cache_dir.glob("*.json"))
    if not files:
        return
    with ThreadPoolExecutor() as ex:
        list(ex.map(lambda f: normalize_cache_file(f, project_root, mode), files))


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] not in ("abs2rel", "rel2abs"):
        sys.exit(0)

    mode = sys.argv[1]
    raw = sys.stdin.read()

    if raw.strip():
        try:
            data = json.loads(raw)
        except (json.JSONDecodeError, ValueError):
            sys.exit(0)
        if data.get("tool_name") != "Bash":
            sys.exit(0)
        command = data.get("tool_input", {}).get("command", "")
        # Match graphify as command invocation, not as path component (.graphify/).
        # Negative lookbehind for "." excludes ".graphify" directory references.
        if not re.search(r"(?<!\.)\bgraphify\b", command):
            sys.exit(0)

    # Определяем gout через git/CWD (project_root нужен ещё до чтения .graphify_root)
    graphify_out = os.environ.get("GRAPHIFY_OUT", "graphify-out")
    try:
        git_root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL, text=True
        ).strip()
        gout = Path(git_root) / graphify_out
    except Exception:
        gout = Path.cwd() / graphify_out

    if not gout.exists():
        sys.exit(0)

    # get_project_root читает .graphify_root для abs2rel (точнее git)
    project_root = get_project_root(gout)

    normalize_manifest(gout, project_root, mode)
    normalize_root(gout, project_root, mode)
    normalize_cache(gout, project_root, mode)


if __name__ == "__main__":
    main()
