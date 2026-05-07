# graphify manifest path bug — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `graphify-out/manifest.json` from appearing when `GRAPHIFY_OUT` is set to a non-default value (e.g. `.graphify`).

**Architecture:** Three-pronged fix: (A) auto-patch the upstream library's `watch.py` after every `uv tool install/upgrade` so `save_manifest` uses the correct path; (B) harden `graphify/SKILL.md` `save-result` calls with explicit `--memory-dir`; (C) harden `graphify-context/SKILL.md` CLI calls with explicit `--graph`. Upstream PR filed separately.

**Tech Stack:** bash (`lib/graphify/install.sh`), Markdown SKILL.md files, Python `graphify/watch.py` (uv-managed)

---

### Task 1: Add `_patch_graphify_watch()` to install.sh

**Files:**
- Modify: `lib/graphify/install.sh`

The function finds the installed `watch.py` via uv, checks if the unpatched line still exists (idempotent), applies sed, and prints a status line. It is called:
1. After `uv tool install graphifyy` in `install_graphify()`.
2. Defensively at the start of `_graphify_rebuild_graph()` — covers the case where the user ran `uv tool upgrade graphifyy` outside iclaude.

- [ ] **Step 1: Add `_patch_graphify_watch()` before `_graphify_rebuild_graph()`**

Open `lib/graphify/install.sh`. Add the new function after `_graphify_resolve_uv()` (after line 23), before `_graphify_rebuild_graph()` (before line 30):

```bash
#######################################
# Patch graphify watch.py to pass explicit manifest_path to save_manifest.
# Idempotent — no-op if already patched or file not found.
# Upstream bug: watch._rebuild_code() calls save_manifest(detected["files"])
# without manifest_path, falling through to hardcoded "graphify-out/manifest.json".
#######################################
_patch_graphify_watch() {
    local uv_bin
    uv_bin=$(_graphify_resolve_uv)
    [[ -z "$uv_bin" ]] && return 0

    local watch_py
    watch_py=$(UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        "$uv_bin" tool run --from graphifyy python3 \
        -c "import graphify.watch; print(graphify.watch.__file__)" 2>/dev/null || echo "")
    [[ -z "$watch_py" || ! -f "$watch_py" ]] && return 0

    # Idempotent: only patch when the unpatched line is present
    if grep -qF 'save_manifest(detected["files"])' "$watch_py"; then
        sed -i 's|save_manifest(detected\["files"\])|save_manifest(detected["files"], manifest_path=str(out / "manifest.json"))|' "$watch_py"
        print_info "Patched graphify watch.py: save_manifest now uses explicit manifest_path"
    fi
}
```

- [ ] **Step 2: Call `_patch_graphify_watch()` after `uv tool install` in `install_graphify()`**

In `install_graphify()`, find the line:
```bash
    print_success "graphifyy installed"
```
Add the call immediately after it:
```bash
    print_success "graphifyy installed"
    _patch_graphify_watch
```

- [ ] **Step 3: Call `_patch_graphify_watch()` defensively in `_graphify_rebuild_graph()`**

In `_graphify_rebuild_graph()`, find the existing guard:
```bash
    if ! detect_graphify; then
        print_error "graphify not installed. Run: ./iclaude.sh --install-graphify"
        return 1
    fi
```
Add the defensive patch call immediately after the `fi`:
```bash
    if ! detect_graphify; then
        print_error "graphify not installed. Run: ./iclaude.sh --install-graphify"
        return 1
    fi
    _patch_graphify_watch
```

- [ ] **Step 4: Verify the sed pattern works**

Run this in the project root to confirm the pattern matches exactly one line in the current watch.py:

```bash
WATCH_PY=$(UV_TOOL_DIR=".nvm-isolated/.claude-isolated/graphify" \
  .nvm-isolated/bin/uv tool run --from graphifyy python3 \
  -c "import graphify.watch; print(graphify.watch.__file__)" 2>/dev/null)
echo "watch.py: $WATCH_PY"
grep -n 'save_manifest(detected\["files"\])' "$WATCH_PY"
```

Expected output: one matching line number (e.g. `148:        save_manifest(detected["files"])`).

- [ ] **Step 5: Apply the patch manually to verify it works**

```bash
source lib/core/init.sh 2>/dev/null || true
source lib/graphify/install.sh 2>/dev/null || true
_patch_graphify_watch
```

Then verify:

```bash
WATCH_PY=$(UV_TOOL_DIR=".nvm-isolated/.claude-isolated/graphify" \
  .nvm-isolated/bin/uv tool run --from graphifyy python3 \
  -c "import graphify.watch; print(graphify.watch.__file__)" 2>/dev/null)
grep -c 'manifest_path=str(out / "manifest.json")' "$WATCH_PY"
```

Expected: `1`

- [ ] **Step 6: Verify idempotency**

Run `_patch_graphify_watch` a second time. It must not error and must not duplicate the added argument:

```bash
_patch_graphify_watch
grep -c 'manifest_path=str(out / "manifest.json")' "$WATCH_PY"
```

Expected: still `1` (not `2`).

- [ ] **Step 7: Validate bash syntax**

```bash
bash -n lib/graphify/install.sh
```

Expected: no output (syntax OK).

- [ ] **Step 8: Commit**

```bash
git add lib/graphify/install.sh
git commit -m "fix(graphify): auto-patch watch.py save_manifest to use explicit manifest_path

watch._rebuild_code() called save_manifest(detected['files']) without manifest_path,
falling through to hardcoded 'graphify-out/manifest.json' regardless of GRAPHIFY_OUT.
Patch applied after uv install and defensively before each rebuild.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Harden `graphify/SKILL.md` — add `--memory-dir` to `save-result` calls

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md`

`graphify save-result` defaults `--memory-dir` to `"graphify-out/memory"` (hardcoded in `__main__.py:1360`). SKILL.md calls it without the flag → creates `graphify-out/memory/`. Fix: pass explicit `--memory-dir "${GRAPHIFY_OUT}/memory"` in all three call sites.

- [ ] **Step 1: Patch the `query` save-result call (line 963)**

Find:
```
$(cat "${GRAPHIFY_OUT}/.graphify_python") -m graphify save-result --question "QUESTION" --answer "ANSWER" --type query --nodes NODE1 NODE2
```

Replace with:
```
$(cat "${GRAPHIFY_OUT}/.graphify_python") -m graphify save-result --question "QUESTION" --answer "ANSWER" --type query --nodes NODE1 NODE2 --memory-dir "${GRAPHIFY_OUT}/memory"
```

- [ ] **Step 2: Patch the `path` save-result call (line 983)**

Find:
```
$(cat "${GRAPHIFY_OUT}/.graphify_python") -m graphify save-result --question "Path from NODE_A to NODE_B" --answer "ANSWER" --type path_query --nodes NODE_A NODE_B
```

Replace with:
```
$(cat "${GRAPHIFY_OUT}/.graphify_python") -m graphify save-result --question "Path from NODE_A to NODE_B" --answer "ANSWER" --type path_query --nodes NODE_A NODE_B --memory-dir "${GRAPHIFY_OUT}/memory"
```

- [ ] **Step 3: Patch the `explain` save-result call (line 1001)**

Find:
```
$(cat "${GRAPHIFY_OUT}/.graphify_python") -m graphify save-result --question "Explain NODE_NAME" --answer "ANSWER" --type explain --nodes NODE_NAME
```

Replace with:
```
$(cat "${GRAPHIFY_OUT}/.graphify_python") -m graphify save-result --question "Explain NODE_NAME" --answer "ANSWER" --type explain --nodes NODE_NAME --memory-dir "${GRAPHIFY_OUT}/memory"
```

- [ ] **Step 4: Verify exactly 3 `--memory-dir` occurrences in save-result context**

```bash
grep -c 'memory-dir' .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
```

Expected: `3`

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
git commit -m "fix(graphify-skill): pass explicit --memory-dir to save-result calls

save-result default --memory-dir is hardcoded 'graphify-out/memory', creating
a spurious graphify-out/ directory when GRAPHIFY_OUT points elsewhere.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Harden `graphify-context/SKILL.md` — add `--graph` to CLI calls

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md`

`graphify query/path/explain` CLI commands default `graph_path` to `"graphify-out/graph.json"` (hardcoded). When `GRAPHIFY_OUT=.graphify`, the graph is at `.graphify/graph.json` → the CLI fails to find it. Fix: add `--graph "${GRAPHIFY_OUT}/graph.json"` to all CLI call examples in Phase 1.

- [ ] **Step 1: Patch the 5 CLI calls in Phase 1 (lines 83–95)**

Find the entire block:
```bash
# Широкий обзор компонентов (BFS)
graphify query "What are the core components and how do they connect?" --budget 1200

# Трассировка конкретного пути (DFS)
graphify query "How does <entry_point> reach <target>?" --dfs --budget 1000

# Связь между двумя конкретными узлами
graphify path "ComponentA" "ComponentB"

# Полный контекст одного узла
graphify explain "ClassName"

# Любой вопрос по архитектуре
graphify query "<вопрос от пользователя>" --budget 1500
```

Replace with:
```bash
# Широкий обзор компонентов (BFS)
graphify query "What are the core components and how do they connect?" --budget 1200 --graph "${GRAPHIFY_OUT}/graph.json"

# Трассировка конкретного пути (DFS)
graphify query "How does <entry_point> reach <target>?" --dfs --budget 1000 --graph "${GRAPHIFY_OUT}/graph.json"

# Связь между двумя конкретными узлами
graphify path "ComponentA" "ComponentB" --graph "${GRAPHIFY_OUT}/graph.json"

# Полный контекст одного узла
graphify explain "ClassName" --graph "${GRAPHIFY_OUT}/graph.json"

# Любой вопрос по архитектуре
graphify query "<вопрос от пользователя>" --budget 1500 --graph "${GRAPHIFY_OUT}/graph.json"
```

- [ ] **Step 2: Verify occurrences**

```bash
grep -c '\-\-graph' .nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md
```

Expected: `5` (5 patched CLI lines; the integration examples at lines 150/153 are prose examples and intentionally not changed).

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md
git commit -m "fix(graphify-context-skill): pass explicit --graph to CLI query/path/explain

CLI commands default to hardcoded 'graphify-out/graph.json', failing when
GRAPHIFY_OUT points elsewhere (e.g. .graphify). Pass explicit path.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Update `.graphify/manifest.json` (re-run graphify)

The currently-installed `watch.py` still has the bug (patch not applied yet at runtime). Run the patch and then verify no `graphify-out/` appears after a rebuild.

- [ ] **Step 1: Source install.sh functions and apply patch**

```bash
source lib/graphify/install.sh
_patch_graphify_watch
```

- [ ] **Step 2: Remove any stale `graphify-out/` if present**

```bash
[[ -d graphify-out ]] && rm -rf graphify-out && echo "removed stale graphify-out/"
```

- [ ] **Step 3: Trigger a rebuild via `graphify update .`**

`graphify` must be on PATH. With iclaude isolated env, use:

```bash
GRAPHIFY_OUT=.graphify \
  UV_TOOL_DIR=".nvm-isolated/.claude-isolated/graphify" \
  .nvm-isolated/.claude-isolated/graphify/graphifyy/bin/graphify update .
```

Expected output ends with: `[graphify watch] graph.json, graph.html and GRAPH_REPORT.md updated in .graphify`

- [ ] **Step 4: Verify manifest is in correct location only**

```bash
ls -la .graphify/manifest.json && echo "PASS: manifest in .graphify/"
ls -la graphify-out/ 2>&1 | grep -q "No such file" && echo "PASS: graphify-out/ absent" || echo "FAIL: graphify-out/ still exists"
```

Expected: both PASS lines.

- [ ] **Step 5: Commit updated manifest**

```bash
git add .graphify/manifest.json
git status  # confirm no graphify-out/ files staged
git commit -m "chore(graphify): rebuild manifest after watch.py patch

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 5: Open upstream PR to `graphifyy`

This is a manual task. The upstream fix is a one-line change to `graphify/watch.py`.

- [ ] **Step 1: Find upstream repo and fork**

First verify the correct GitHub repo (check PyPI page for the source link):

```bash
pip show graphifyy 2>/dev/null | grep -i home
# or: https://pypi.org/project/graphifyy/
```

Then fork and clone (substitute OWNER/graphifyy with actual org/user):

```bash
gh repo fork OWNER/graphifyy --clone
cd graphifyy
git checkout -b fix/watch-manifest-path
```

- [ ] **Step 2: Apply the fix**

In `graphify/watch.py`, find line 148:
```python
        save_manifest(detected["files"])
```

Change to:
```python
        save_manifest(detected["files"], manifest_path=str(out / "manifest.json"))
```

- [ ] **Step 3: Commit and open PR**

```bash
git add graphify/watch.py
git commit -m "fix: pass explicit manifest_path in _rebuild_code()

save_manifest() defaults to 'graphify-out/manifest.json' regardless of
GRAPHIFY_OUT. When GRAPHIFY_OUT is set to a custom path (e.g. '.graphify'),
_rebuild_code() correctly writes all other outputs to the configured dir
but manifest.json always ends up in graphify-out/.

Fix: pass manifest_path=str(out / 'manifest.json') where out is already
computed as watch_path / _GRAPHIFY_OUT on line 92."
git push -u origin fix/watch-manifest-path
gh pr create --title "fix: pass explicit manifest_path in watch._rebuild_code()" \
  --body "$(cat <<'EOF'
## Problem

`watch._rebuild_code()` calls `save_manifest(detected["files"])` without an explicit
`manifest_path`. The default in `detect.py` is hardcoded `"graphify-out/manifest.json"`,
so `manifest.json` always lands in `./graphify-out/` regardless of the `GRAPHIFY_OUT`
environment variable.

All other outputs (`graph.json`, `GRAPH_REPORT.md`, `graph.html`) correctly use
`out = watch_path / _GRAPHIFY_OUT` — only `save_manifest` was missing the explicit path.

## Fix

One-line change in `watch.py` line 148:

```python
# Before
save_manifest(detected["files"])

# After
save_manifest(detected["files"], manifest_path=str(out / "manifest.json"))
```

`out` is already computed on line 92 as `watch_path / _GRAPHIFY_OUT`.

## Reproduction

Set `GRAPHIFY_OUT=custom-dir` and run `graphify update .`. Before this fix,
`graphify-out/manifest.json` is created. After this fix, `custom-dir/manifest.json`
is created.
EOF
)"
```

---

## Verification Checklist

After all tasks complete:

```bash
# 1. watch.py patched
WATCH_PY=$(UV_TOOL_DIR=".nvm-isolated/.claude-isolated/graphify" \
  .nvm-isolated/bin/uv tool run --from graphifyy python3 \
  -c "import graphify.watch; print(graphify.watch.__file__)" 2>/dev/null)
grep -q 'manifest_path=str(out / "manifest.json")' "$WATCH_PY" && echo "PASS: watch.py patched"

# 2. SKILL.md has --memory-dir
grep -q 'memory-dir' .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md && echo "PASS: save-result has --memory-dir"

# 3. graphify-context has --graph
grep -q '\-\-graph' .nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md && echo "PASS: CLI calls have --graph"

# 4. No graphify-out/ in project
[[ ! -d graphify-out ]] && echo "PASS: graphify-out/ absent"

# 5. Correct manifest exists
[[ -f .graphify/manifest.json ]] && echo "PASS: .graphify/manifest.json exists"
```
