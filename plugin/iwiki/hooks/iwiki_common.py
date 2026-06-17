#!/usr/bin/env python3
"""Shared helpers for the iwiki automation hooks (recall / reindex / sync).

A hook cannot run a slash command or an LLM-backed skill directly. What it CAN
do deterministically is drive the iwiki engine CLI (search / index) and shell
out to git. These helpers wrap that, resolving uv + the engine project the same
way lib/iwiki/detect.sh and the iwiki-ingest skill do, and fail soft on every
path (a documentation helper must never disrupt the session).

These hooks ship inside the iwiki plugin and run in ANY project the plugin is
enabled in, so paths are resolved against CLAUDE_PROJECT_DIR / CLAUDE_PLUGIN_ROOT
rather than assuming the iclaude repo layout.
"""
from __future__ import annotations

import os
import glob
import shutil
import subprocess

WIKI_DIR = "docs/wiki"
INDEX_REL = os.path.join(WIKI_DIR, ".iwiki", "index.jsonl")

# Changed paths under these prefixes are NOT source for the wiki:
#   the wiki itself, the IDD/SDD artifact chain, command artifacts (excluded
#   from the doc graph), the engine venv, and VCS/dependency noise.
EXCLUDE_PREFIXES = (
    "docs/wiki/",
    "docs/superpowers/",
    "commands/",
    ".git/",
    "node_modules/",
)
EXCLUDE_SUBSTR = ("/.iwiki/", "/.venv/", "/commands/", "/node_modules/")
SOURCE_EXTS = (".sh", ".py", ".js", ".ts", ".md")


def cd_project() -> None:
    """chdir to the project root so relative wiki/git paths resolve. Plugin
    hooks do not guarantee cwd == project dir."""
    pd = os.environ.get("CLAUDE_PROJECT_DIR")
    if pd and os.path.isdir(pd):
        try:
            os.chdir(pd)
        except Exception:
            pass


def resolve_uv() -> str | None:
    """uv binary: $GRAPHIFY_UV_BIN, then PATH, then the isolated bin/ (per the
    iwiki-ingest skill). None if uv is unavailable."""
    for cand in (os.environ.get("GRAPHIFY_UV_BIN"), shutil.which("uv")):
        if cand and os.path.exists(cand) and os.access(cand, os.X_OK):
            return cand
    ccd = os.environ.get("CLAUDE_CONFIG_DIR")
    if ccd:
        cand = os.path.normpath(os.path.join(ccd, "..", "bin", "uv"))
        if os.path.exists(cand) and os.access(cand, os.X_OK):
            return cand
    return None


def engine_dir() -> str | None:
    """The iwiki engine project (has pyproject.toml). Prefers the plugin root
    (CLAUDE_PLUGIN_ROOT/engine), then an in-repo plugin, then the plugin cache.
    None if not found."""
    cands: list[str] = []
    pr = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if pr:
        cands.append(os.path.join(pr, "engine"))
    cands.append(os.path.join("plugin", "iwiki", "engine"))
    ccd = os.environ.get("CLAUDE_CONFIG_DIR")
    if ccd:
        cands += glob.glob(os.path.join(ccd, "plugins", "cache", "*", "iwiki",
                                        "*", "engine"))
    for c in cands:
        if os.path.isfile(os.path.join(c, "pyproject.toml")):
            return c
    return None


def wiki_present() -> bool:
    return os.path.isdir(WIKI_DIR)


def index_exists() -> bool:
    return os.path.exists(INDEX_REL)


def run_engine(args: list[str], timeout: float) -> tuple[int, str]:
    """Run `iwiki_engine <args>` via uv. Returns (returncode, stdout).
    (127,'') if uv/engine missing, (124,'') on timeout, (1,'') on any error."""
    uv = resolve_uv()
    eng = engine_dir()
    if not uv or not eng:
        return (127, "")
    cmd = [uv, "run", "--project", eng, "python3", "-m", "iwiki_engine",
           "--wiki-dir", WIKI_DIR] + args
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return (p.returncode, (p.stdout or "").strip())
    except subprocess.TimeoutExpired:
        return (124, "")
    except Exception:
        return (1, "")


def _git(args: list[str]) -> list[str]:
    try:
        p = subprocess.run(["git"] + args, capture_output=True, text=True,
                           timeout=10)
        if p.returncode != 0:
            return []
        return [ln for ln in p.stdout.splitlines() if ln.strip()]
    except Exception:
        return []


def changed_sources() -> list[str]:
    """Documentable source files changed since HEAD (uncommitted, staged, and
    untracked), excluding the wiki/IDD/command/VCS noise. Sorted, deduped."""
    raw = set(_git(["diff", "--name-only", "HEAD"]))
    raw |= set(_git(["ls-files", "--others", "--exclude-standard"]))
    out = []
    for p in raw:
        if not p.endswith(SOURCE_EXTS):
            continue
        if p.startswith(EXCLUDE_PREFIXES):
            continue
        if any(s in p for s in EXCLUDE_SUBSTR):
            continue
        if not os.path.exists(p):
            continue
        out.append(p)
    return sorted(out)
