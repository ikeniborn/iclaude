---
review:
  plan_hash: 9124282b68bd83cb
  spec_hash: a1ff07f9d0b0c609
  last_run: 2026-06-14
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings: []
chain:
  intent: docs/superpowers/intents/2026-06-14-cicd-pull-binary-delivery-intent.md
  spec:   docs/superpowers/specs/2026-06-14-cicd-pull-binary-delivery-design.md
---

# CI/CD Pull Binary Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After `git pull` bumps `claudeCodeVersion`, automatically bring the on-disk gitignored `claude.exe` to match the lockfile — no manual `iclaude --update` required.

**Architecture:** Two surgical pieces, both compare the lockfile version against the **real binary** (`claude --version`, not the git-tracked `package.json`), both prompt `y/N`, both reuse `iclaude.sh --install-from-lockfile`. **Component A** is a new `.githooks/post-merge` hook (proactive, fires after `git pull`). **Component B** fixes a false-negative in `check_lockfile_changes()` (reactive safety net at iclaude launch, for pulls that bypass git hooks).

**Tech Stack:** Bash, git hooks (`core.hooksPath=.githooks`, already configured), `grep -oP` (jq-free in the hook), npm postinstall (native binary fetch). Tests are standalone bash scripts under `tests/`.

**Spec:** [docs/superpowers/specs/2026-06-14-cicd-pull-binary-delivery-design.md](../specs/2026-06-14-cicd-pull-binary-delivery-design.md)

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `.githooks/post-merge` | Self-contained post-pull binary refresh; opt-out, guard, version compare, y/N prompt. ~55 lines, executable. | Create |
| `lib/lockfile/save.sh` | `check_lockfile_changes()` — swap the installed-version probe from `package.json` to the real binary (~10 lines + a comment). | Modify |
| `tests/test_post_merge.sh` | Bash test harness for the hook: opt-out, in-sync, unchanged-lockfile guard, mismatch non-TTY. | Create |
| `tests/test_check_lockfile_binary_probe.sh` | Function-level test for the Component B probe: the bug case (binary old, `package.json` matches) + in-sync regression. | Create |
| `CLAUDE.md` | Add pull-time refresh + `ICLAUDE_NO_AUTO_UPDATE` opt-out to the Native Binary section. | Modify |
| `lat.md/launch-flow.md` | Document the pull-time refresh flow. | Modify |

**Conventions observed:**
- `.githooks/` files use **2-space** indentation (match the sibling `.githooks/pre-push`).
- `lib/` bash files use **tab** indentation (match `save.sh`).
- The isolated binary lives at `.nvm-isolated/npm-global/bin/claude` (a symlink to `.../@anthropic-ai/claude-code/bin/claude.exe`). `claude --version` prints e.g. `2.1.177 (Claude Code)`.

---

## Task 1: Component A — `.githooks/post-merge` hook

Build the hook test-first. The test harness creates throwaway git repos with mocked lockfiles and a stub `claude` binary, so it never touches the real environment. The interactive y/N path is covered by a manual step (a pty cannot be scripted portably); the automated test covers the four deterministic branches.

**Files:**
- Create: `tests/test_post_merge.sh`
- Create: `.githooks/post-merge`

- [ ] **Step 1: Write the failing test harness**

Create `tests/test_post_merge.sh`:

```bash
#!/bin/bash
# Tests for .githooks/post-merge — pull-time claude.exe refresh.
# Builds throwaway git repos; mocks the lockfile + claude binary; never touches
# the real isolated environment. The interactive y/N path is verified manually.
set -u

HOOK_SRC="$(git rev-parse --show-toplevel)/.githooks/post-merge"
if [[ ! -f "$HOOK_SRC" ]]; then
  echo "FAIL: hook not found at $HOOK_SRC"; exit 1
fi

pass=0; fail=0
assert_contains() { # <output> <substr> <name>
  if grep -qF "$2" <<<"$1"; then echo "ok: $3"; pass=$((pass+1));
  else echo "FAIL: $3"; echo "--- output ---"; echo "$1"; echo "---"; fail=$((fail+1)); fi
}
assert_empty() { # <output> <name>
  if [[ -z "${1//[[:space:]]/}" ]]; then echo "ok: $2"; pass=$((pass+1));
  else echo "FAIL: $2 (expected no output)"; echo "--- output ---"; echo "$1"; echo "---"; fail=$((fail+1)); fi
}

# make_repo <lockver> <binver|missing> <changed:yes|no> -> prints repo path.
# Builds 3 commits; sets ORIG_HEAD so the lockfile shows changed (yes) or not (no).
make_repo() {
  local lockver="$1" binver="$2" changed="$3" repo
  repo="$(mktemp -d)"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
  echo "1" > "$repo/filler"; git -C "$repo" add filler
  git -C "$repo" commit -qm c1
  local c1; c1="$(git -C "$repo" rev-parse HEAD)"
  printf '{"claudeCodeVersion":"%s"}\n' "$lockver" > "$repo/.nvm-isolated-lockfile.json"
  git -C "$repo" add .nvm-isolated-lockfile.json; git -C "$repo" commit -qm c2
  local c2; c2="$(git -C "$repo" rev-parse HEAD)"
  echo "2" > "$repo/filler"; git -C "$repo" add filler; git -C "$repo" commit -qm c3
  if [[ "$changed" == "yes" ]]; then
    git -C "$repo" update-ref ORIG_HEAD "$c1"   # diff c1..HEAD includes the lockfile
  else
    git -C "$repo" update-ref ORIG_HEAD "$c2"   # diff c2..HEAD = only filler
  fi
  if [[ "$binver" != "missing" ]]; then
    mkdir -p "$repo/.nvm-isolated/npm-global/bin"
    printf '#!/bin/bash\necho "%s (Claude Code)"\n' "$binver" \
      > "$repo/.nvm-isolated/npm-global/bin/claude"
    chmod +x "$repo/.nvm-isolated/npm-global/bin/claude"
  fi
  cp "$HOOK_SRC" "$repo/post-merge"; chmod +x "$repo/post-merge"
  echo "$repo"
}

# run_hook <repo> [env...] -> combined stdout+stderr. setsid drops the controlling
# terminal so /dev/tty is unavailable (the deterministic non-interactive path).
run_hook() {
  local repo="$1"; shift
  ( cd "$repo" && env "$@" setsid bash ./post-merge </dev/null ) 2>&1
}

# Case 1: opt-out → silent exit 0 even with a real mismatch.
r="$(make_repo 9.9.9 1.0.0 yes)"
assert_empty "$(run_hook "$r" ICLAUDE_NO_AUTO_UPDATE=1)" "opt-out is silent"

# Case 2: in-sync (lockver == binver) → silent exit 0.
r="$(make_repo 9.9.9 9.9.9 yes)"
assert_empty "$(run_hook "$r")" "in-sync is silent"

# Case 3: lockfile unchanged in this merge → guard skips, silent even if binary differs.
r="$(make_repo 9.9.9 1.0.0 no)"
assert_empty "$(run_hook "$r")" "unchanged-lockfile guard skips"

# Case 4: mismatch, non-TTY → warn-only with manual hint, never blocks.
r="$(make_repo 9.9.9 1.0.0 yes)"
out="$(run_hook "$r")"
assert_contains "$out" "install-from-lockfile" "mismatch non-TTY warns with manual hint"

# Case 5: binary missing, mismatch, non-TTY → still warns (missing == mismatch).
r="$(make_repo 9.9.9 missing yes)"
out="$(run_hook "$r")"
assert_contains "$out" "install-from-lockfile" "missing binary non-TTY warns"

echo "---"; echo "pass=$pass fail=$fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_post_merge.sh; echo "exit: $?"`
Expected: FAIL — prints `FAIL: hook not found at .../.githooks/post-merge` and `exit: 1` (the hook does not exist yet).

- [ ] **Step 3: Write the hook**

Create `.githooks/post-merge` (2-space indent to match `.githooks/pre-push`):

```bash
#!/bin/bash
#
# post-merge — after `git pull` / merge, bring the on-disk Claude Code native
# binary (bin/claude.exe, gitignored, ~250MB) up to the version recorded in the
# lockfile. Self-contained: no sourcing of lib/ modules, no jq dependency.
# Always exits 0 — a binary refresh must never block or fail a git pull.
#
# Opt out:  export ICLAUDE_NO_AUTO_UPDATE=1
#

# 1. Opt-out.
[[ "${ICLAUDE_NO_AUTO_UPDATE:-}" == "1" ]] && exit 0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
LOCKFILE="$REPO_ROOT/.nvm-isolated-lockfile.json"
[[ -f "$LOCKFILE" ]] || exit 0

# 2. Cheap guard — only continue if this merge touched the lockfile. Default-safe:
#    if the diff cannot be computed, fall through to the version check.
changed=""
if git -C "$REPO_ROOT" rev-parse --verify -q ORIG_HEAD >/dev/null 2>&1; then
  changed="$(git -C "$REPO_ROOT" diff --name-only ORIG_HEAD HEAD 2>/dev/null)"
elif git -C "$REPO_ROOT" rev-parse --verify -q '@{1}' >/dev/null 2>&1; then
  changed="$(git -C "$REPO_ROOT" diff --name-only '@{1}' HEAD 2>/dev/null)"
fi
if [[ -n "$changed" ]] && ! grep -qx '.nvm-isolated-lockfile.json' <<<"$changed"; then
  exit 0
fi

# 3. Lockfile version (grep, not jq — keep the hook dependency-light).
lockver="$(grep -oP '"claudeCodeVersion":\s*"\K[^"]+' "$LOCKFILE" 2>/dev/null | head -n 1)"

# 4. Real on-disk binary version (authoritative — not the git-tracked package.json).
binver=""
claude_bin="$REPO_ROOT/.nvm-isolated/npm-global/bin/claude"
if [[ -x "$claude_bin" ]]; then
  binver="$("$claude_bin" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -n 1)"
fi

# 5. Already in sync — nothing to do.
[[ -n "$lockver" && "$lockver" == "$binver" ]] && exit 0

# 6. Non-interactive (CI, piped, GUI background) — warn only, never prompt or block.
if [[ ! -r /dev/tty ]]; then
  echo "iclaude: claude.exe ${binver:-missing} != lockfile ${lockver:-unknown}." >&2
  echo "iclaude: run './iclaude.sh --install-from-lockfile' to update the binary." >&2
  exit 0
fi

# 7. Prompt on the controlling terminal.
echo "iclaude: claude.exe version mismatch: ${binver:-missing} -> ${lockver}" >/dev/tty
printf '  Update on-disk binary now via --install-from-lockfile? [y/N]: ' >/dev/tty
read -r ans </dev/tty

# 8. Apply on yes; otherwise leave a hint.
if [[ "$ans" =~ ^[Yy]$ ]]; then
  "$REPO_ROOT/iclaude.sh" --install-from-lockfile >/dev/tty 2>&1 \
    || echo "iclaude: install failed — run './iclaude.sh --install-from-lockfile' manually." >/dev/tty
else
  echo "  Skipped. Run './iclaude.sh --install-from-lockfile' when ready." >/dev/tty
fi

exit 0
```

- [ ] **Step 4: Make the hook executable**

Run: `chmod +x .githooks/post-merge`

- [ ] **Step 5: Validate syntax**

Run: `bash -n .githooks/post-merge; echo "exit: $?"`
Expected: `exit: 0` (no syntax errors).

- [ ] **Step 6: Run the test to verify it passes**

Run: `bash tests/test_post_merge.sh; echo "exit: $?"`
Expected: PASS — `pass=5 fail=0` and `exit: 0`.

- [ ] **Step 7: Manual check of the interactive prompt (decline path)**

The y/N branch needs a real terminal. From the repo root:

```bash
tmp="$(mktemp -d)"; git -C "$tmp" init -q
git -C "$tmp" config user.email t@t; git -C "$tmp" config user.name t
echo 1 > "$tmp/filler"; git -C "$tmp" add filler; git -C "$tmp" commit -qm c1
c1="$(git -C "$tmp" rev-parse HEAD)"
printf '{"claudeCodeVersion":"9.9.9"}\n' > "$tmp/.nvm-isolated-lockfile.json"
git -C "$tmp" add .nvm-isolated-lockfile.json; git -C "$tmp" commit -qm c2
git -C "$tmp" update-ref ORIG_HEAD "$c1"
mkdir -p "$tmp/.nvm-isolated/npm-global/bin"
printf '#!/bin/bash\necho "1.0.0 (Claude Code)"\n' > "$tmp/.nvm-isolated/npm-global/bin/claude"
chmod +x "$tmp/.nvm-isolated/npm-global/bin/claude"
cp .githooks/post-merge "$tmp/post-merge"; chmod +x "$tmp/post-merge"
( cd "$tmp" && bash ./post-merge )   # type "n" at the prompt
rm -rf "$tmp"
```

Expected: prints `version mismatch: 1.0.0 -> 9.9.9`, prompts `[y/N]:`; typing `n` prints the "Skipped" hint and exits cleanly. (Do not type `y` — it would run a real `--install-from-lockfile` against the throwaway dir's missing `iclaude.sh` and just print the install-failed hint.)

- [ ] **Step 8: Commit**

```bash
git add .githooks/post-merge tests/test_post_merge.sh
git commit -m "feat(cicd): add post-merge hook to refresh claude.exe after git pull"
```

---

## Task 2: Component B — fix the `check_lockfile_changes()` version probe

The launch-time safety net currently reads the git-tracked `package.json` to decide "what is installed". A `git pull` updates `package.json` to the new version while the real binary stays old, so the check wrongly reports "in sync" and skips the refresh. Replace the probe with the real binary version.

**Files:**
- Create: `tests/test_check_lockfile_binary_probe.sh`
- Modify: `lib/lockfile/save.sh:343-355`

- [ ] **Step 1: Write the failing test**

Create `tests/test_check_lockfile_binary_probe.sh`:

```bash
#!/bin/bash
# Function-level test for the check_lockfile_changes() version probe.
# Sources lib/lockfile/save.sh, stubs heavy deps, and asserts the bug case:
# binary is old while package.json (tracked) already matches the lockfile.
# Runs non-interactively (stdin from /dev/null) so a mismatch hits the warn-only branch.
set -u

ROOT="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1090
source "$ROOT/lib/lockfile/save.sh"

# Stubs (defined AFTER source so these definitions win).
compute_lockfile_hash() { echo "NEWHASH"; }
update_lockfile_hash()  { echo "UPDATE_HASH_CALLED"; }
install_from_lockfile() { echo "INSTALL_CALLED"; return 0; }
print_warning() { echo "WARN: $*"; }
print_info()    { echo "INFO: $*"; }
print_success() { echo "OK: $*"; }

pass=0; fail=0
assert_contains() { if grep -qF "$2" <<<"$1"; then echo "ok: $3"; pass=$((pass+1));
  else echo "FAIL: $3"; echo "--- output ---"; echo "$1"; echo "---"; fail=$((fail+1)); fi; }
assert_absent()   { if grep -qF "$2" <<<"$1"; then echo "FAIL: $3"; echo "--- output ---"; echo "$1"; echo "---"; fail=$((fail+1));
  else echo "ok: $3"; pass=$((pass+1)); fi; }

# setup_case <lockver> <pkgver> <binver>
setup_case() {
  local lockver="$1" pkgver="$2" binver="$3" dir pkgdir
  dir="$(mktemp -d)"
  ISOLATED_LOCKFILE="$dir/lockfile.json"
  printf '{"claudeCodeVersion":"%s"}\n' "$lockver" > "$ISOLATED_LOCKFILE"
  LOCKFILE_HASH_FILE="$dir/.last-lockfile-hash"
  echo "OLDHASH" > "$LOCKFILE_HASH_FILE"          # != NEWHASH → the "changed" gate passes
  ISOLATED_NVM_DIR="$dir/.nvm-isolated"
  pkgdir="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code"
  mkdir -p "$pkgdir"
  printf '{"version":"%s"}\n' "$pkgver" > "$pkgdir/package.json"   # tracked file — the trap
  mkdir -p "$ISOLATED_NVM_DIR/npm-global/bin"
  printf '#!/bin/bash\necho "%s (Claude Code)"\n' "$binver" \
    > "$ISOLATED_NVM_DIR/npm-global/bin/claude"
  chmod +x "$ISOLATED_NVM_DIR/npm-global/bin/claude"
}

# Case 1 (the bug): lockfile=9.9.9, package.json=9.9.9 (matches), real binary=1.0.0 (old).
#   OLD code reads package.json → "in sync" → NO warn  (this assertion FAILS pre-fix).
#   NEW code reads the binary   → mismatch  → warn.
setup_case "9.9.9" "9.9.9" "1.0.0"
out="$(check_lockfile_changes </dev/null 2>&1)"
assert_contains "$out" "Lockfile has changed" "old binary (pkg.json matches) reaches warn"
assert_absent  "$out" "INSTALL_CALLED"        "non-interactive mismatch does not auto-install"

# Case 2 (regression): everything 9.9.9 incl. the binary → no warn, hash refreshed.
setup_case "9.9.9" "9.9.9" "9.9.9"
out="$(check_lockfile_changes </dev/null 2>&1)"
assert_absent  "$out" "Lockfile has changed" "in-sync binary stays silent"
assert_contains "$out" "UPDATE_HASH_CALLED"   "in-sync refreshes the stored hash"

echo "---"; echo "pass=$pass fail=$fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_check_lockfile_binary_probe.sh; echo "exit: $?"`
Expected: FAIL — Case 1 reports `FAIL: old binary (pkg.json matches) reaches warn` and `exit: 1`. (Current code reads `package.json` 9.9.9 == lockfile 9.9.9 → no-ops, so no warn appears.) Case 2 passes.

- [ ] **Step 3: Apply the probe fix**

In `lib/lockfile/save.sh`, replace the comment + probe block. Find (lines 343-355):

```bash
	# Hash changed — check if installed version already matches lockfile
	# This handles git pull delivering CI updates: npm packages are updated in git,
	# so the environment is already in sync even though .last-lockfile-hash is stale.
	local lockfile_claude_ver
	lockfile_claude_ver=$(jq -r '.claudeCodeVersion // empty' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "")

	if [[ -n "$lockfile_claude_ver" && "$lockfile_claude_ver" != "unknown" ]]; then
		local package_json="${ISOLATED_NVM_DIR}/npm-global/lib/node_modules/@anthropic-ai/claude-code/package.json"
		local installed_claude_ver=""
		if [[ -f "$package_json" ]]; then
			installed_claude_ver=$(jq -r '.version // empty' "$package_json" 2>/dev/null || \
				grep -oP '"version":\s*"\K[^"]+' "$package_json" 2>/dev/null || echo "")
		fi
```

Replace with:

```bash
	# Hash changed — compare the lockfile version against the REAL on-disk binary.
	# package.json is git-tracked and bumped by the pull, so it is NOT a reliable
	# "what is installed" signal; the native binary (claude --version) is authoritative.
	local lockfile_claude_ver
	lockfile_claude_ver=$(jq -r '.claudeCodeVersion // empty' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "")

	if [[ -n "$lockfile_claude_ver" && "$lockfile_claude_ver" != "unknown" ]]; then
		local claude_bin="${ISOLATED_NVM_DIR}/npm-global/bin/claude"
		if [[ ! -x "$claude_bin" ]]; then
			claude_bin="${ISOLATED_NVM_DIR}/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
		fi
		local installed_claude_ver=""
		if [[ -x "$claude_bin" ]]; then
			installed_claude_ver=$("$claude_bin" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -n 1 || echo "")
		fi
```

The unchanged lines that follow (`if [[ -n "$installed_claude_ver" && "$installed_claude_ver" == "$lockfile_claude_ver" ]]; then ... update_lockfile_hash; return 0 ... fi`) stay exactly as they are. Only the *source of truth* changes.

- [ ] **Step 4: Validate syntax**

Run: `bash -n lib/lockfile/save.sh; echo "exit: $?"`
Expected: `exit: 0`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/test_check_lockfile_binary_probe.sh; echo "exit: $?"`
Expected: PASS — `pass=4 fail=0` and `exit: 0`.

- [ ] **Step 6: Commit**

```bash
git add lib/lockfile/save.sh tests/test_check_lockfile_binary_probe.sh
git commit -m "fix(lockfile): probe real binary version, not tracked package.json"
```

---

## Task 3: Documentation

Record the pull-time refresh and the opt-out env var in both `CLAUDE.md` and the lat.md graph.

**Files:**
- Modify: `CLAUDE.md` (Native Binary section, around line 129)
- Modify: `lat.md/launch-flow.md`

- [ ] **Step 1: Update `CLAUDE.md`**

Find this paragraph in the `### Native Binary (since v2.1.114)` section:

```markdown
After `git clone`, run `--repair-isolated` to download the binary via `npm install` + postinstall. Without it, detection falls through to the legacy `cli.js` path, or fails with a clear error.
```

Add immediately after it:

```markdown

**Pull-time refresh.** A tracked `.githooks/post-merge` hook (active via `core.hooksPath=.githooks`) runs after `git pull`/merge. When the pulled commit bumped `claudeCodeVersion`, it compares the lockfile version against the real on-disk binary (`claude --version`) and offers a `y/N` prompt to run `--install-from-lockfile`. It is fail-soft: silent when in sync, warn-only when non-interactive (CI/GUI), never blocks the pull. Opt out with `export ICLAUDE_NO_AUTO_UPDATE=1`. The launch-time `check_lockfile_changes()` is a fallback for pulls that bypass git hooks.
```

- [ ] **Step 2: Update `lat.md/launch-flow.md`**

Find the `## Binary-Absent Error Handling` section and the line ending with `delivered only via CI/CD (\`git pull\` + \`--install-from-lockfile\`).` Insert a new section immediately before `## Attribution Header`:

```markdown
## Pull-Time Binary Refresh

The native binary `bin/claude.exe` is gitignored (exceeds GitHub's 100MB limit), so `git pull` delivers the version bump in the 6 tracked metadata files but not the executable. Two pieces close the gap, both comparing the lockfile `claudeCodeVersion` against the **real binary** (`claude --version`, not the tracked `package.json`) and reusing `--install-from-lockfile`:

- **`.githooks/post-merge`** ([[../.githooks/post-merge]]) — proactive, fires after `git pull`. Opt-out via `ICLAUDE_NO_AUTO_UPDATE=1`; guards on the lockfile actually changing in the merge; fail-soft (silent in-sync, warn-only non-interactive, never blocks the pull).
- **`check_lockfile_changes()`** ([[../lib/lockfile/save.sh#check_lockfile_changes]]) — reactive fallback at iclaude launch, for pulls that bypass git hooks (GUI clients, opt-out, fresh clone before `--repair-isolated`).

```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md lat.md/launch-flow.md
git commit -m "docs(cicd): document pull-time binary refresh and opt-out"
```

---

## Task 4: Final verification

Confirm the whole change is coherent: syntax, both test suites, the existing security-hook suite (unaffected), and lat.md link integrity.

- [ ] **Step 1: Syntax check both changed bash files**

Run: `bash -n .githooks/post-merge && bash -n lib/lockfile/save.sh && echo "syntax OK"`
Expected: `syntax OK`.

- [ ] **Step 2: Run both new test suites**

Run: `bash tests/test_post_merge.sh && bash tests/test_check_lockfile_binary_probe.sh && echo "ALL GREEN"`
Expected: both print `fail=0`, then `ALL GREEN`.

- [ ] **Step 3: Confirm the existing hook suite still passes (regression guard)**

Run: `python3 -m pytest tests/test_patterns_examples.py -q`
Expected: all tests pass (this change touches neither the python hooks nor their patterns).

- [ ] **Step 4: Verify the hook carries the executable bit in git**

Run: `git ls-files -s .githooks/post-merge`
Expected: mode `100755` (executable) — matches `.githooks/pre-push`. If it shows `100644`, run `git update-index --chmod=+x .githooks/post-merge` and re-commit.

- [ ] **Step 5: lat.md link integrity (REQUIRED by project checklist)**

Invoke the `lat-check` skill (or run `./iclaude.sh --lat-check`).
Expected: all wiki links and code refs resolve — in particular the new `[[../.githooks/post-merge]]` and `[[../lib/lockfile/save.sh#check_lockfile_changes]]` refs. Fix any broken ref before finishing.

- [ ] **Step 6: Final commit (if Step 4/5 required fixes)**

```bash
git add -A
git commit -m "chore(cicd): finalize post-merge hook (exec bit + lat refs)"
```

---

## Self-Review Notes

- **Spec coverage:** Component A (`.githooks/post-merge`) → Task 1. Component B (`check_lockfile_changes()` probe) → Task 2. Docs (CLAUDE.md + lat.md) → Task 3. Spec's 7 test scenarios: opt-out, in-sync, non-TTY warn, unchanged-lockfile guard, missing-binary, and the Component B regression are automated (Tasks 1-2); the interactive y/N decline path is the manual Step 1.7; "CI unaffected" is asserted by Task 4 Step 3 + the non-TTY design.
- **Graceful-offline:** covered by the hook's step 6 (non-interactive warn-only) and step 8 (install failure prints a hint; the pull already completed since post-merge runs after the merge).
- **Type/name consistency:** `lockver`/`binver` (hook), `lockfile_claude_ver`/`installed_claude_ver`/`claude_bin` (save.sh) are used identically across their tasks; the binary path `.nvm-isolated/npm-global/bin/claude` and the version regex `\d+\.\d+\.\d+` match between hook, fix, and tests.
- **No placeholders:** every code and test block is complete and runnable.
