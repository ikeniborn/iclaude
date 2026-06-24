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

import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

WIKI_DIR = "docs/wiki"
INDEX_REL = os.path.join(WIKI_DIR, ".iwiki", "index.jsonl")
LOG_REL = os.path.join(WIKI_DIR, ".iwiki", "log.jsonl")

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

# Agent-instruction files are never wiki source — excluded in ANY directory.
EXCLUDE_BASENAMES = ("CLAUDE.md", "AGENTS.md", "GEMINI.md")
# Project meta-docs are not wiki source at the repo ROOT (a subdir README.md may
# still document a component, so it stays documentable).
EXCLUDE_ROOT_DOCS = ("README.md", "CHANGELOG.md", "CONTRIBUTING.md", "LICENSE.md")

# Test files are never wiki source — iwiki generates no page for tests, so a
# changed test could never become "covered" and would nag forever.
_TEST_SEGMENTS = {"tests", "test", "__tests__", "spec"}
_TEST_BASENAME_RE = re.compile(
    r"^(conftest\.py|test_.*\.py|.*_test\.py|.*\.test\.[jt]s|.*\.spec\.[jt]s)$")


def _is_test_path(p: str) -> bool:
    """A repo-relative path that is a test file (test dir segment, or a
    conventional test basename) — never wiki source."""
    parts = p.split("/")
    if any(seg in _TEST_SEGMENTS for seg in parts[:-1]):   # any dir segment
        return True
    return bool(_TEST_BASENAME_RE.match(parts[-1]))


def cd_project() -> None:
    """chdir to the project root so relative wiki/git paths resolve. Plugin
    hooks do not guarantee cwd == project dir, and some SessionStart invocations
    arrive with CLAUDE_PROJECT_DIR unset — fall back to the git toplevel of the
    current cwd so git/wiki paths still resolve."""
    pd = os.environ.get("CLAUDE_PROJECT_DIR")
    if pd and os.path.isdir(pd):
        try:
            os.chdir(pd)
            return
        except Exception:
            pass
    try:
        p = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, timeout=5)
        root = p.stdout.strip()
        if p.returncode == 0 and root and os.path.isdir(root):
            os.chdir(root)
    except Exception:
        pass


def resolve_uv() -> str | None:
    """uv binary: $UV_BIN, then PATH, then the isolated bin/ (per the
    iwiki-ingest skill). None if uv is unavailable."""
    for cand in (os.environ.get("UV_BIN"), shutil.which("uv")):
        if cand and os.path.exists(cand) and os.access(cand, os.X_OK):
            return cand
    ccd = os.environ.get("CLAUDE_CONFIG_DIR")
    if ccd:
        cand = os.path.normpath(os.path.join(ccd, "..", "bin", "uv"))
        if os.path.exists(cand) and os.access(cand, os.X_OK):
            return cand
    return None


def _cache_version_key(engine_path: str) -> tuple:
    """Sort key from the <version> path segment of a plugin-cache engine dir
    (.../cache/<market>/iwiki/<version>/engine). Numeric-aware so 0.10 > 0.9."""
    ver = os.path.basename(os.path.dirname(engine_path))
    return tuple(int(t) if t.isdigit() else -1 for t in ver.split("."))


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
        cache = glob.glob(os.path.join(ccd, "plugins", "cache", "*", "iwiki",
                                       "*", "engine"))
        # Newest version first so a stale cached copy never shadows the current one.
        cache.sort(key=_cache_version_key, reverse=True)
        cands += cache
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


def is_documentable(p: str) -> bool:
    """A repo-relative path that the wiki should describe: a source ext, outside
    the wiki/IDD/command/VCS noise, and not an agent-instruction file (any dir)
    or a repo-root meta-doc. Existence is checked separately by callers."""
    if not p.endswith(SOURCE_EXTS):
        return False
    if p.startswith(EXCLUDE_PREFIXES):
        return False
    if any(s in p for s in EXCLUDE_SUBSTR):
        return False
    base = os.path.basename(p)
    if base in EXCLUDE_BASENAMES:
        return False
    if "/" not in p and base in EXCLUDE_ROOT_DOCS:   # repo-root only (git uses '/')
        return False
    if _is_test_path(p):
        return False
    return True


def changed_sources() -> list[str]:
    """Documentable source files changed since HEAD (uncommitted, staged, and
    untracked), excluding the wiki/IDD/command/VCS noise. Sorted, deduped."""
    raw = set(_git(["diff", "--name-only", "HEAD"]))
    raw |= set(_git(["ls-files", "--others", "--exclude-standard"]))
    return sorted(p for p in raw if is_documentable(p) and os.path.exists(p))


def git_head() -> str:
    """Current HEAD sha, or '' if not a git repo / no commits."""
    r = _git(["rev-parse", "HEAD"])
    return r[0] if r else ""


def committed_sources(since: str) -> list[str]:
    """Documentable source files changed in commits `since`..HEAD that still
    exist — i.e. the agent committed them this session (catches commit-evasion).
    Empty if `since` is unset, equal to HEAD, or unknown to git."""
    if not since:
        return []
    raw = _git(["diff", "--name-only", f"{since}..HEAD"])
    return sorted(p for p in raw if is_documentable(p) and os.path.exists(p))


def source_page_map() -> dict[str, str]:
    """Map each source → its most recent wiki page from the ingest log
    (docs/wiki/.iwiki/log.jsonl). Last record wins per source. Same record
    predicate as the engine's lint._stale: any record carrying both `source`
    and `page` counts (no `op` filter). Fail-soft → {}."""
    out: dict[str, str] = {}
    try:
        with open(LOG_REL, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except Exception:
        return out
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
            if not isinstance(rec, dict):
                continue
        except Exception:
            continue
        src, page = rec.get("source"), rec.get("page")
        if src and page:
            out[src] = page          # last record wins
    return out


def covered_sources() -> set[str]:
    """Sources already covered by a fresh wiki page: the source's most recent
    page (per source_page_map) exists on disk and is at least as new as the
    source. The freshness test mtime(page) >= mtime(source) is the exact
    inverse of lint._stale, so for any (source, page) pair this calls "covered"
    exactly the pairs lint would not call stale. Fail-soft → empty set (subtract
    nothing → safe over-nag, bounded by MAX_ASK)."""
    covered: set[str] = set()
    for src, page in source_page_map().items():
        try:
            if os.path.isfile(src) and os.path.isfile(page) \
                    and os.path.getmtime(page) >= os.path.getmtime(src):
                covered.add(src)
        except Exception:
            continue
    return covered


def wiki_pages() -> list[str]:
    """All docs/wiki/*.md pages (repo-relative), excluding the .iwiki index dir."""
    out: list[str] = []
    for root, _dirs, files in os.walk(WIKI_DIR):
        if ".iwiki" in root.split(os.sep):
            continue
        for f in files:
            if f.endswith(".md"):
                out.append(os.path.join(root, f))
    return out


def has_documentable_source() -> bool:
    """True if the project has any documentable source file (so a bootstrap nudge
    is warranted). Uses git's tracked set, falling back to a shallow glob."""
    for p in _git(["ls-files"]):
        if is_documentable(p):
            return True
    for ext in SOURCE_EXTS:
        for p in glob.glob(f"*{ext}") + glob.glob(f"lib/**/*{ext}", recursive=True):
            if is_documentable(p):
                return True
    return False


def rel_to_project(path: str) -> str:
    """Normalise a tool-reported file path (often absolute) to a repo-relative
    path that matches git output. Returns the input unchanged on failure."""
    if not path:
        return path
    try:
        return os.path.relpath(os.path.abspath(path), os.getcwd())
    except Exception:
        return path


# --- shared session state (baseline + edit accumulator + nag dedup) ----------
# One file per session, reset by the SessionStart bootstrap hook. The record
# hook (PostToolUse) appends edits; the sync hook (Stop) reads it. Keeping it in
# CLAUDE_CONFIG_DIR/.cache (not the repo) keeps it out of the project's git.
_SESSION_DEFAULT = {
    "session_id": "",    # owning session; baseline reset only on a NEW id (resume-safe)
    "head": "",          # baseline HEAD at session start
    "wip": [],           # pre-existing dirty documentable files → not the agent's
    "edits": [],         # documentable sources the agent edited this session (F)
    "wiki_dirty": False, # a wiki page changed → needs one batched reindex at Stop
    "asked_sig": "",     # signature of the last nagged pending set (C dedup)
    "count": 0,          # consecutive nags for the same set (C bound vs wedge)
}


def session_path() -> str:
    ccd = os.environ.get("CLAUDE_CONFIG_DIR")
    base = os.path.join(ccd, ".cache") if ccd else ".git"
    try:
        os.makedirs(base, exist_ok=True)
    except Exception:
        base = "."
    return os.path.join(base, "iwiki-session.json")


def read_session() -> dict:
    out = dict(_SESSION_DEFAULT)
    try:
        with open(session_path(), encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            out.update({k: data[k] for k in _SESSION_DEFAULT if k in data})
    except FileNotFoundError:
        pass  # first run: no state yet — expected, stay silent
    except Exception as e:
        print(f"iwiki: ignoring unreadable session state ({e})", file=sys.stderr)
    return out


def write_session(sess: dict) -> None:
    try:
        with open(session_path(), "w", encoding="utf-8") as f:
            json.dump(sess, f)
    except Exception:
        pass


def signature(paths: list[str]) -> str:
    return hashlib.sha256("\n".join(paths).encode("utf-8")).hexdigest()[:16]


def decide_nag(sess: dict, sig: str, max_ask: int) -> tuple[str, dict]:
    """Decide whether the Stop nag should ask again or yield for the pending-set
    signature `sig`. Returns ("ask" | "yield", sess) with asked_sig/count updated.
    A stable sig is asked at most max_ask times, then yields — never wedging the
    stop. No wiki-state input: the bound is purely the ask count, so wiki/index
    churn between asks can no longer reset it."""
    if sig == sess.get("asked_sig"):
        if sess.get("count", 0) >= max_ask:
            return ("yield", sess)
        sess["count"] = sess.get("count", 0) + 1
    else:
        sess["asked_sig"] = sig
        sess["count"] = 1
    return ("ask", sess)


def render_pending_listing(pending: list[str], page_map: dict[str, str],
                           cap: int = 12) -> str:
    """Render the Stop-nag body, grouping pending sources by their target wiki
    page so N sources of one page read as one action. Sources with a known page
    → one line per page; sources with no page yet → one 'new' line. At most
    `cap` lines, with an '…and N more' overflow tail."""
    by_page: dict[str, list[str]] = {}
    new: list[str] = []
    for p in pending:
        page = page_map.get(p)
        if page:
            by_page.setdefault(page, []).append(p)
        else:
            new.append(p)
    lines: list[str] = []
    for page in sorted(by_page):
        srcs = ", ".join(sorted(by_page[page]))
        lines.append(
            f"  - {page} is stale — re-run iwiki-ingest (covers: {srcs})")
    if new:
        lines.append("  - new, needs a wiki page — run iwiki-ingest: "
                     + ", ".join(sorted(new)))
    shown = lines[:cap]
    more = "" if len(lines) == len(shown) \
        else f"\n  …and {len(lines) - len(shown)} more"
    return "\n".join(shown) + more
