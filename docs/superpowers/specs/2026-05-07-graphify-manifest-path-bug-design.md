# Design: graphify manifest.json writes to wrong directory

**Date:** 2026-05-07
**Status:** Approved

## Problem

`graphify-out/manifest.json` periodically appears in the project root even though `GRAPHIFY_OUT=.graphify` is configured. The user has deleted `graphify-out/` at least 3 times (evidence: `~/.local/share/Trash/files/graphify-out (3)/`).

## Root Cause

`graphify/watch.py::_rebuild_code()` line 148:

```python
# Correctly computes out = watch_path / _GRAPHIFY_OUT = watch_path / ".graphify"
out = watch_path / _GRAPHIFY_OUT  # line 92

# BUG: calls save_manifest without explicit manifest_path
save_manifest(detected["files"])  # line 148
```

`detect.py` line 19 has a hardcoded module-level default:

```python
_MANIFEST_PATH = "graphify-out/manifest.json"
```

`save_manifest(files)` with no second argument falls through to this default, writing
`./graphify-out/manifest.json` regardless of `GRAPHIFY_OUT`.

All other outputs (`graph.json`, `GRAPH_REPORT.md`, `graph.html`) go to the correct `.graphify/`
because they use `out / "filename"` explicitly. Only `save_manifest` lacks the explicit path.

## Trigger path

```
graphify-context/SKILL.md Phase 0
  → warns "Граф устарел, запусти graphify update ."
  → Claude or user runs: graphify update .
  → __main__.py cmd="update"
  → watch._rebuild_code(watch_path)
  → out = watch_path / _GRAPHIFY_OUT  (.graphify/) ✓
  → save_manifest(detected["files"])              ← hardcoded graphify-out/manifest.json ✗
```

Same path triggers from `lib/graphify/install.sh::_graphify_rebuild_graph()` if `--graphify`
flag is used.

## Secondary issues (same category, lower impact)

| Location | Bug | Impact |
|----------|-----|--------|
| `__main__.py:1360` `save-result --memory-dir` | default `"graphify-out/memory"` | creates `graphify-out/memory/` |
| `__main__.py:1295` `graphify query` | default `graph_path = "graphify-out/graph.json"` | CLI query fails when `GRAPHIFY_OUT != graphify-out` |
| `__main__.py:1380` `graphify path` | same hardcoded default | same failure |
| `__main__.py:2093` `graphify extract` | `graphify_out = out_root / "graphify-out"` | extract always writes to graphify-out/ |

## Architecture

Two fix components, applied in parallel:

### Component A: Auto-patch in `lib/graphify/install.sh`

Apply a one-line sed patch to `watch.py` immediately after `uv tool install graphifyy` and after
any future upgrade. The patch function is called from `install_graphify()` and any
`--update-graphify` path.

```python
# watch.py line 148 — BEFORE:
save_manifest(detected["files"])

# AFTER:
save_manifest(detected["files"], manifest_path=str(out / "manifest.json"))
```

The sed command locates the correct Python file via `graphify.watch.__file__` so it works
regardless of uv tool path changes.

**Why auto-patch and not manual:** `uv tool upgrade graphifyy` overwrites the installed file.
Applying the patch in the install script means any upgrade automatically re-patches. Zero
ongoing maintenance.

### Component B: Upstream PR to `graphifyy`

Submit a PR to the upstream `graphifyy` repository fixing `watch.py` line 148.
After merge + release, the patch in Component A becomes a no-op (sed finds no match → silent
skip) and can eventually be removed.

### Component C: SKILL.md hardening (secondary)

While not the primary trigger, fix the secondary issues to prevent `graphify-out/` from being
created by any codepath:

1. `graphify/SKILL.md` — add `--memory-dir "${GRAPHIFY_OUT}/memory"` to all three `save-result`
   calls (query, path, explain sections).
2. `graphify-context/SKILL.md` Phase 1 — add `--graph "${GRAPHIFY_OUT}/graph.json"` to CLI
   `graphify query/path/explain` calls.

## Implementation plan overview

1. `lib/graphify/install.sh` — add `_patch_graphify_watch()` function and call it after install
2. `graphify/SKILL.md` — patch three `save-result` call sites
3. `graphify-context/SKILL.md` — patch CLI query/path/explain call sites
4. Open upstream GitHub issue + PR

## Verification

After fix:
```bash
./iclaude.sh                        # launch session
# inside session:
/graphify --update                  # or: bash tool: graphify update .
# check: graphify-out/ must NOT exist
# check: .graphify/manifest.json must be updated
ls -la .graphify/manifest.json      # exists, fresh mtime
ls -la graphify-out/ 2>&1           # "No such file or directory"
```

## Files changed

| File | Change |
|------|--------|
| `lib/graphify/install.sh` | add `_patch_graphify_watch()`, call after uv install |
| `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md` | `--memory-dir` in 3 save-result calls |
| `.nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md` | `--graph` in CLI calls |
| upstream `graphifyy` | PR: fix `watch.py:148` |
