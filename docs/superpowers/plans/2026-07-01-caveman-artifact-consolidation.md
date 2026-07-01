---
review:
  plan_hash: cc6c59c070db82c9
  last_run: 2026-07-01
  phases:
    structure: {status: passed}
    coverage: {status: passed}
    dependencies: {status: passed}
    verifiability: {status: passed}
    consistency: {status: passed}
  findings:
    - id: F-001
      phase: coverage
      severity: INFO
      section: "Task 1 Step 3 — cavemanDir vs spec Components/Affected Files"
      section_hash: null
      fragment: "cavemanDir(claudeDir) — pure builder, no mkdir side effect"
      text: "Plan deliberately diverges from the spec: cavemanDir is a pure path builder (no mkdir) and caveman-config.js is left untouched. Safe and self-consistent — safeWriteFlag/appendFlag and migrateLegacy create .caveman/; the atomic-write temp follows its target. Documented in Global Constraints + Self-Review."
      fix: "Accepted as intentional deviation; no change required."
      verdict: accepted
      verdict_at: 2026-07-01
chain:
  intent: n/a
  spec: docs/superpowers/specs/2026-07-01-caveman-artifact-consolidation-design.md
---

# Caveman Artifact Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all caveman runtime artifacts into `$CLAUDE_CONFIG_DIR/.caveman/`, delete a session's per-session statusline-suffix at SessionEnd, and lower the age-prune from 7 to 5 days — so the config root stays clean and dead files don't accumulate.

**Architecture:** A new `hooks/caveman-paths.js` module is the single source of truth for artifact paths on the JS side (pure path builders + a one-time idempotent `migrateLegacy` + a shared `pruneSessionSuffixes`). Every JS hook requires it; `scripts/claude-statusline.sh` holds the directory once in a `CAVEMAN_DIR` variable. A new `hooks/caveman-cleanup.js` SessionEnd hook deletes the current session's suffix file and runs the prune.

**Tech Stack:** Node.js (built-in `fs`/`path`/`os` only, no new deps), Bash (statusline), JSON (settings.json), Bash integration tests.

## Global Constraints

- No new npm dependencies — Node built-ins only (`fs`, `path`, `os`).
- Every filesystem operation is best-effort: wrapped in try/catch, never throws out of a hook.
- All artifact **writes** go through the existing symlink-safe helpers in `caveman-config.js` (`safeWriteFlag`, `appendFlag`) — never raw `fs.writeFileSync`.
- Artifacts directory: `$CLAUDE_CONFIG_DIR/.caveman/` (hidden). Files inside: `active`, `history.jsonl`, `statusline-suffix`, `suffix-<sessionId>`.
- Per-session suffix prune retention: `MAX_AGE_MS = 5 * 86_400_000` (5 days).
- Session id is `path.basename(transcript_path, '.jsonl')` — identical to `caveman-stats.js`.
- Docs, code comments, commit messages: English. Conventional-commit style (`feat:`, `refactor:`, `test:`).
- Surgical changes only — do not touch `caveman-config.js` (its `.caveman-active.<pid>.<ts>` temp name is a generic atomic-write temp in the target's parent dir, not the artifact path; it follows the target into `.caveman/` automatically).

---

### Task 1: `caveman-paths.js` — shared paths, migration, prune

**Files:**
- Create: `.nvm-isolated/.claude-isolated/hooks/caveman-paths.js`
- Test: `tests/test_caveman_paths.sh`

**Interfaces:**
- Consumes: nothing (foundation module).
- Produces:
  - `cavemanDir(claudeDir: string) -> string` — `<claudeDir>/.caveman` (pure, no side effect).
  - `activeFlag(claudeDir) -> string` — `<dir>/active`
  - `history(claudeDir) -> string` — `<dir>/history.jsonl`
  - `baseSuffix(claudeDir) -> string` — `<dir>/statusline-suffix`
  - `sessionSuffix(claudeDir, sessionId: string) -> string` — `<dir>/suffix-<sessionId>`
  - `migrateLegacy(claudeDir) -> void` — one-time idempotent move of legacy root artifacts.
  - `pruneSessionSuffixes(claudeDir) -> void` — delete `suffix-*` older than `MAX_AGE_MS`.
  - `MAX_AGE_MS: number` = `5 * 86_400_000`
  - `SESSION_SUFFIX_PREFIX: string` = `'suffix-'`

- [ ] **Step 1: Write the failing test**

Create `tests/test_caveman_paths.sh`:

```bash
#!/usr/bin/env bash
# Tests for caveman-paths.js — path builders, migration, prune.
# Run: bash tests/test_caveman_paths.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATHS="$REPO_ROOT/.nvm-isolated/.claude-isolated/hooks/caveman-paths.js"

FAILED=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }
assert_eq() { if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1"; echo "    expected: [$2]"; echo "    actual:   [$3]"; fi; }

# ---- path builders ----
t_paths() {
  echo "[paths] builders return .caveman/ paths"
  local out
  out="$(node -e '
    const p = require(process.argv[1]);
    const d = "/tmp/cc";
    console.log(p.cavemanDir(d));
    console.log(p.activeFlag(d));
    console.log(p.history(d));
    console.log(p.baseSuffix(d));
    console.log(p.sessionSuffix(d, "abc"));
    console.log(String(p.MAX_AGE_MS));
    console.log(p.SESSION_SUFFIX_PREFIX);
  ' "$PATHS")"
  assert_eq "cavemanDir"   "/tmp/cc/.caveman"                 "$(sed -n 1p <<<"$out")"
  assert_eq "activeFlag"   "/tmp/cc/.caveman/active"          "$(sed -n 2p <<<"$out")"
  assert_eq "history"      "/tmp/cc/.caveman/history.jsonl"   "$(sed -n 3p <<<"$out")"
  assert_eq "baseSuffix"   "/tmp/cc/.caveman/statusline-suffix" "$(sed -n 4p <<<"$out")"
  assert_eq "sessionSuffix" "/tmp/cc/.caveman/suffix-abc"     "$(sed -n 5p <<<"$out")"
  assert_eq "MAX_AGE_MS 5d" "432000000"                       "$(sed -n 6p <<<"$out")"
  assert_eq "prefix"       "suffix-"                          "$(sed -n 7p <<<"$out")"
  # cavemanDir is pure — must NOT create the dir as a side effect
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  node -e 'require(process.argv[1]).cavemanDir(process.argv[2])' "$PATHS" "$cc"
  [[ -d "$cc/.caveman" ]] && fail "cavemanDir is pure (no mkdir)" || pass "cavemanDir is pure (no mkdir)"
}
t_paths

# ---- migrateLegacy ----
t_migrate() {
  echo "[migrate] legacy root artifacts move into .caveman/"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  printf 'LIFETIME' > "$cc/.caveman-history.jsonl"
  printf 'BASE'     > "$cc/.caveman-statusline-suffix"
  printf 'full'     > "$cc/.caveman-active"
  printf 'stale1'   > "$cc/.caveman-statusline-suffix-old1"
  printf 'stale2'   > "$cc/.caveman-statusline-suffix-old2"

  node -e 'require(process.argv[1]).migrateLegacy(process.argv[2])' "$PATHS" "$cc"

  assert_eq "history moved (content preserved)" "LIFETIME" "$(cat "$cc/.caveman/history.jsonl" 2>/dev/null)"
  assert_eq "base suffix moved"                 "BASE"     "$(cat "$cc/.caveman/statusline-suffix" 2>/dev/null)"
  assert_eq "active moved"                      "full"     "$(cat "$cc/.caveman/active" 2>/dev/null)"
  [[ -e "$cc/.caveman-history.jsonl" ]]          && fail "legacy history removed"     || pass "legacy history removed"
  [[ -e "$cc/.caveman-statusline-suffix" ]]      && fail "legacy base removed"        || pass "legacy base removed"
  [[ -e "$cc/.caveman-active" ]]                 && fail "legacy active removed"      || pass "legacy active removed"
  [[ -e "$cc/.caveman-statusline-suffix-old1" ]] && fail "legacy per-session1 removed" || pass "legacy per-session1 removed"
  [[ -e "$cc/.caveman-statusline-suffix-old2" ]] && fail "legacy per-session2 removed" || pass "legacy per-session2 removed"

  # idempotent: a second run is a no-op and preserves the new files
  node -e 'require(process.argv[1]).migrateLegacy(process.argv[2])' "$PATHS" "$cc"
  assert_eq "history intact after 2nd run" "LIFETIME" "$(cat "$cc/.caveman/history.jsonl" 2>/dev/null)"

  # dest already exists → legacy dropped, dest NOT overwritten
  printf 'STALE' > "$cc/.caveman-history.jsonl"
  node -e 'require(process.argv[1]).migrateLegacy(process.argv[2])' "$PATHS" "$cc"
  assert_eq "existing dest not overwritten" "LIFETIME" "$(cat "$cc/.caveman/history.jsonl" 2>/dev/null)"
  [[ -e "$cc/.caveman-history.jsonl" ]] && fail "stale legacy dropped when dest exists" || pass "stale legacy dropped when dest exists"
}
t_migrate

# ---- pruneSessionSuffixes ----
t_prune() {
  echo "[prune] removes >5d, keeps <5d, keeps base"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"
  printf 'x' > "$cc/.caveman/suffix-old";  touch -d '6 days ago' "$cc/.caveman/suffix-old"
  printf 'x' > "$cc/.caveman/suffix-new";  touch -d '4 days ago' "$cc/.caveman/suffix-new"
  printf 'x' > "$cc/.caveman/statusline-suffix"; touch -d '9 days ago' "$cc/.caveman/statusline-suffix"

  node -e 'require(process.argv[1]).pruneSessionSuffixes(process.argv[2])' "$PATHS" "$cc"

  [[ -e "$cc/.caveman/suffix-old" ]]        && fail "6d suffix pruned"      || pass "6d suffix pruned"
  [[ -e "$cc/.caveman/suffix-new" ]]        && pass "4d suffix kept"        || fail "4d suffix kept"
  [[ -e "$cc/.caveman/statusline-suffix" ]] && pass "base suffix kept"      || fail "base suffix kept"
}
t_prune

echo
[[ $FAILED -eq 0 ]] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $FAILED
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_caveman_paths.sh`
Expected: FAIL — `Cannot find module '.../caveman-paths.js'` / all assertions fail (module missing).

- [ ] **Step 3: Write minimal implementation**

Create `.nvm-isolated/.claude-isolated/hooks/caveman-paths.js`:

```js
#!/usr/bin/env node
// caveman-paths — single source of truth for on-disk caveman artifact paths.
//
// All caveman artifacts live under $CLAUDE_CONFIG_DIR/.caveman/ so they don't
// clutter the config root:
//   active              — mode flag (was .caveman-active)
//   history.jsonl       — lifetime savings log (was .caveman-history.jsonl)
//   statusline-suffix   — cumulative-only fallback (was .caveman-statusline-suffix)
//   suffix-<sessionId>  — per-session badge (was .caveman-statusline-suffix-<id>)
//
// This module holds pure path builders plus two maintenance helpers
// (migrateLegacy, pruneSessionSuffixes). Every function is best-effort and must
// never throw out of a hook.

const fs = require('fs');
const path = require('path');

// Per-session suffix files older than this are pruned so .caveman/ doesn't grow
// without bound. 5 days keeps a working window while a session may still be open.
const MAX_AGE_MS = 5 * 86_400_000;
// Basename prefix for per-session suffix files (suffix-<sessionId>). The base
// fallback file is 'statusline-suffix', which does NOT start with this prefix,
// so the prune never touches it.
const SESSION_SUFFIX_PREFIX = 'suffix-';

// Pure path builder — no side effects, so readers/guards can compute a path
// without creating the directory. Writers (safeWriteFlag/appendFlag) and
// migrateLegacy create .caveman/ on demand.
function cavemanDir(claudeDir) {
  return path.join(claudeDir, '.caveman');
}
function activeFlag(claudeDir) { return path.join(cavemanDir(claudeDir), 'active'); }
function history(claudeDir)    { return path.join(cavemanDir(claudeDir), 'history.jsonl'); }
function baseSuffix(claudeDir) { return path.join(cavemanDir(claudeDir), 'statusline-suffix'); }
function sessionSuffix(claudeDir, sessionId) {
  return path.join(cavemanDir(claudeDir), SESSION_SUFFIX_PREFIX + sessionId);
}

// One-time, idempotent migration of legacy root-level artifacts into .caveman/.
// Best-effort: any failure leaves the legacy file in place (harmless — readers
// only look in .caveman/). Persistent files (history, base suffix, active) are
// moved when the destination is absent, otherwise the stale legacy copy is
// dropped. Legacy per-session suffix files are always deleted — their sessions
// are over and the current session regenerates its own on the next Stop.
function migrateLegacy(claudeDir) {
  const dir = cavemanDir(claudeDir);
  try { fs.mkdirSync(dir, { recursive: true }); } catch {}

  const moves = [
    ['.caveman-history.jsonl',     path.join(dir, 'history.jsonl')],
    ['.caveman-statusline-suffix', path.join(dir, 'statusline-suffix')],
    ['.caveman-active',            path.join(dir, 'active')],
  ];
  for (const [legacyName, dest] of moves) {
    const src = path.join(claudeDir, legacyName);
    try {
      if (!fs.existsSync(src)) continue;
      if (!fs.existsSync(dest)) fs.renameSync(src, dest);
      else fs.unlinkSync(src); // dest already present — drop the stale legacy copy
    } catch {}
  }

  try {
    for (const name of fs.readdirSync(claudeDir)) {
      if (name.startsWith('.caveman-statusline-suffix-')) {
        try { fs.unlinkSync(path.join(claudeDir, name)); } catch {}
      }
    }
  } catch {}
}

// Delete per-session suffix files older than MAX_AGE_MS. Never throws — a prune
// failure must not break stats or session cleanup.
function pruneSessionSuffixes(claudeDir) {
  const dir = cavemanDir(claudeDir);
  const now = Date.now();
  let names;
  try { names = fs.readdirSync(dir); } catch { return; }
  for (const name of names) {
    if (!name.startsWith(SESSION_SUFFIX_PREFIX)) continue;
    const p = path.join(dir, name);
    try {
      if (now - fs.statSync(p).mtimeMs > MAX_AGE_MS) fs.unlinkSync(p);
    } catch {}
  }
}

module.exports = {
  cavemanDir, activeFlag, history, baseSuffix, sessionSuffix,
  migrateLegacy, pruneSessionSuffixes, MAX_AGE_MS, SESSION_SUFFIX_PREFIX,
};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_caveman_paths.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/caveman-paths.js tests/test_caveman_paths.sh
git commit -m "feat(caveman): add caveman-paths module for .caveman/ artifacts, migration, prune"
```

---

### Task 2: Rewire `caveman-stats.js` to `.caveman/` paths

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js` (lines 13, 185-202, 301, 323, 359-365)
- Test: `tests/test_caveman_session_savings.sh` (t1, t2 rewritten)

**Interfaces:**
- Consumes: `caveman-paths.js` — `history`, `activeFlag`, `baseSuffix`, `sessionSuffix`, `pruneSessionSuffixes`.
- Produces: writes `.caveman/history.jsonl`, `.caveman/statusline-suffix`, `.caveman/suffix-<id>`; reads `.caveman/active`.

- [ ] **Step 1: Update t1 and t2 in the failing test**

In `tests/test_caveman_session_savings.sh`, replace the `t1_session_suffix` function (lines 25-54) with:

```bash
t1_session_suffix() {
  echo "[t1] per-session composed suffix (in .caveman/)"
  local cc; cc="$(mktemp -d)"
  trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"

  # caveman active in 'full' mode (ratio 0.65)
  printf 'full' > "$cc/.caveman/active"
  # pre-seed history with a prior session worth 110.0M saved tokens
  printf '%s\n' '{"ts":1,"session_id":"old-session","mode":"full","model":"claude-opus-4-8","output_tokens":59230000,"est_saved_tokens":110000000,"est_saved_usd":0}' > "$cc/.caveman/history.jsonl"
  # synthetic session: 35000 output tokens, opus → est_saved = round(35000/0.35)-35000 = 65000
  printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"output_tokens":35000}}}' > "$cc/sess-A.jsonl"

  CLAUDE_CONFIG_DIR="$cc" node "$STATS" --session-file "$cc/sess-A.jsonl" >/dev/null 2>&1

  local per glob
  per="$(cat "$cc/.caveman/suffix-sess-A" 2>/dev/null)"
  glob="$(cat "$cc/.caveman/statusline-suffix" 2>/dev/null)"
  # cumulative = 110000000 + 65000 = 110065000 → humanizeTokens → "110.1M"
  assert_eq "t1 per-session = session · cumulative" "⛏ 65.0k · Σ110.1M" "$per"
  assert_eq "t1 global = cumulative-only"           "⛏ Σ110.1M"        "$glob"

  # root stays clean — no legacy files leak into the config root
  [[ -e "$cc/.caveman-statusline-suffix-sess-A" ]] && fail "t1 no legacy file in root" || pass "t1 no legacy file in root"
  [[ -e "$cc/.caveman-history.jsonl" ]]            && fail "t1 history not in root"    || pass "t1 history not in root"

  # concurrency: a second session writes its OWN per-session file; first untouched.
  printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"output_tokens":350000}}}' > "$cc/sess-C.jsonl"
  CLAUDE_CONFIG_DIR="$cc" node "$STATS" --session-file "$cc/sess-C.jsonl" >/dev/null 2>&1
  # sess-C est_saved = round(350000/0.35)-350000 = 650000 → "650.0k"
  # cumulative now = 110000000 + 65000 + 650000 = 110715000 → "110.7M"
  assert_eq "t1 concurrent session has its own file" "⛏ 650.0k · Σ110.7M" "$(cat "$cc/.caveman/suffix-sess-C" 2>/dev/null)"
  assert_eq "t1 first session file untouched by 2nd" "⛏ 65.0k · Σ110.1M"  "$(cat "$cc/.caveman/suffix-sess-A" 2>/dev/null)"
}
```

Replace the `t2_prune` function (lines 59-79) with:

```bash
t2_prune() {
  echo "[t2] prune stale per-session suffix files (>5 days)"
  local cc; cc="$(mktemp -d)"
  trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"

  printf 'full' > "$cc/.caveman/active"
  printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"output_tokens":35000}}}' > "$cc/sess-B.jsonl"

  # a stale per-session file (6 days old, > 5) that must be pruned
  printf '⛏ 1k · Σ1k' > "$cc/.caveman/suffix-zombie"
  touch -d '6 days ago' "$cc/.caveman/suffix-zombie"
  # a recent per-session file (4 days old, < 5) that must SURVIVE
  printf '⛏ 2k · Σ2k' > "$cc/.caveman/suffix-fresh"
  touch -d '4 days ago' "$cc/.caveman/suffix-fresh"
  # the base file is old but must SURVIVE (no 'suffix-' prefix match)
  printf '⛏ Σ1k' > "$cc/.caveman/statusline-suffix"
  touch -d '9 days ago' "$cc/.caveman/statusline-suffix"

  CLAUDE_CONFIG_DIR="$cc" node "$STATS" --session-file "$cc/sess-B.jsonl" >/dev/null 2>&1

  [[ -e "$cc/.caveman/suffix-zombie" ]]        && fail "t2 stale (6d) per-session file removed" || pass "t2 stale (6d) per-session file removed"
  [[ -e "$cc/.caveman/suffix-fresh" ]]         && pass "t2 recent (4d) per-session file kept"   || fail "t2 recent (4d) per-session file kept"
  [[ -e "$cc/.caveman/statusline-suffix" ]]    && pass "t2 base file survives (not matched)"    || fail "t2 base file survives (not matched)"
  [[ -e "$cc/.caveman/suffix-sess-B" ]]        && pass "t2 current session file present"        || fail "t2 current session file present"
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_caveman_session_savings.sh`
Expected: FAIL — t1/t2 read `.caveman/...` but `caveman-stats.js` still writes to root; suffix/history files not found.

- [ ] **Step 3: Update `caveman-stats.js`**

Edit line 13 — add the paths require:

```js
const { readFlag, appendFlag, readHistory, safeWriteFlag } = require('./caveman-config');
const paths = require('./caveman-paths');
```

Delete the entire `pruneOldSessionSuffixes` function and its doc comment (lines 185-202) — the shared `paths.pruneSessionSuffixes` replaces it.

Edit line 301:

```js
  const historyPath = paths.history(claudeDir);
```

Edit line 323:

```js
  const mode = readFlag(paths.activeFlag(claudeDir));
```

Edit lines 359-365 (the suffix writes + prune call) to:

```js
    safeWriteFlag(paths.sessionSuffix(claudeDir, sessionId), perSession);
    safeWriteFlag(
      paths.baseSuffix(claudeDir),
      agg.estSavedTokens > 0 ? `⛏ Σ${cum}` : ''
    );

    paths.pruneSessionSuffixes(claudeDir);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_caveman_session_savings.sh`
Expected: t1 and t2 groups PASS. (t3 statusline still targets `.caveman/` files it writes itself — but statusline.sh is not yet updated, so t3 will FAIL here. That is expected and fixed in Task 5.)

Run only t1/t2 focus check:
Run: `bash tests/test_caveman_session_savings.sh 2>&1 | grep -E '^\s+(PASS|FAIL): t[12]'`
Expected: only `PASS:` lines for t1/t2.

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/caveman-stats.js tests/test_caveman_session_savings.sh
git commit -m "refactor(caveman): write stats artifacts under .caveman/, prune via caveman-paths"
```

---

### Task 3: Rewire activation hooks (`activate`, `mode-tracker`, `stats-stop`)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/hooks/caveman-activate.js` (lines 12-16)
- Modify: `.nvm-isolated/.claude-isolated/hooks/caveman-mode-tracker.js` (lines 9, 15-16)
- Modify: `.nvm-isolated/.claude-isolated/hooks/caveman-stats-stop.js` (lines 16, 22-24)
- Test: `tests/test_caveman_activation_paths.sh`

**Interfaces:**
- Consumes: `caveman-paths.js` — `activeFlag`, `migrateLegacy`.
- Produces: `.caveman/active` written on SessionStart / mode change; SessionStart migrates legacy root artifacts.

- [ ] **Step 1: Write the failing test**

Create `tests/test_caveman_activation_paths.sh`:

```bash
#!/usr/bin/env bash
# Tests that activation hooks read/write the active flag in .caveman/ and that
# SessionStart migrates legacy root artifacts.
# Run: bash tests/test_caveman_activation_paths.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.nvm-isolated/.claude-isolated/hooks"

FAILED=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }
assert_eq() { if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1"; echo "    expected: [$2]"; echo "    actual:   [$3]"; fi; }

# ---- activate writes .caveman/active and migrates legacy ----
t_activate() {
  echo "[activate] SessionStart writes .caveman/active + migrates legacy"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  # legacy artifacts present in root before upgrade
  printf 'LIFE' > "$cc/.caveman-history.jsonl"
  printf 'x'    > "$cc/.caveman-statusline-suffix-old"

  CLAUDE_CONFIG_DIR="$cc" CAVEMAN_DEFAULT_MODE=full node "$HOOKS_DIR/caveman-activate.js" >/dev/null 2>&1

  assert_eq "active flag written in .caveman/" "full" "$(cat "$cc/.caveman/active" 2>/dev/null)"
  assert_eq "legacy history migrated"          "LIFE" "$(cat "$cc/.caveman/history.jsonl" 2>/dev/null)"
  [[ -e "$cc/.caveman-history.jsonl" ]]          && fail "legacy history removed from root" || pass "legacy history removed from root"
  [[ -e "$cc/.caveman-statusline-suffix-old" ]]  && fail "legacy per-session removed"        || pass "legacy per-session removed"
  [[ -e "$cc/.caveman-active" ]]                 && fail "no legacy active in root"          || pass "no legacy active in root"
}
t_activate

# ---- mode-tracker reads .caveman/active for reinforcement ----
t_tracker() {
  echo "[tracker] UserPromptSubmit reinforcement reads .caveman/active"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"
  printf 'full' > "$cc/.caveman/active"

  local out
  out="$(printf '%s' '{"prompt":"hello"}' | CLAUDE_CONFIG_DIR="$cc" node "$HOOKS_DIR/caveman-mode-tracker.js" 2>/dev/null)"
  [[ "$out" == *"CAVEMAN MODE ACTIVE"* ]] && pass "tracker emits reinforcement from .caveman/active" || fail "tracker emits reinforcement from .caveman/active"
}
t_tracker

# ---- mode-tracker /caveman off deletes .caveman/active ----
t_tracker_off() {
  echo "[tracker] /caveman off removes .caveman/active"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"
  printf 'full' > "$cc/.caveman/active"

  printf '%s' '{"prompt":"/caveman off"}' | CLAUDE_CONFIG_DIR="$cc" node "$HOOKS_DIR/caveman-mode-tracker.js" >/dev/null 2>&1
  [[ -e "$cc/.caveman/active" ]] && fail "active flag removed on /caveman off" || pass "active flag removed on /caveman off"
}
t_tracker_off

echo
[[ $FAILED -eq 0 ]] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $FAILED
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_caveman_activation_paths.sh`
Expected: FAIL — hooks still use root `.caveman-active`; `.caveman/active` absent, legacy root files not migrated.

- [ ] **Step 3: Update the three hooks**

In `caveman-activate.js`, edit line 12 to add the require:

```js
const { getDefaultMode, getLanguages, safeWriteFlag } = require('./caveman-config');
const paths = require('./caveman-paths');
```

Then edit lines 14-15 to migrate and resolve the flag path from the module:

```js
const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
paths.migrateLegacy(claudeDir);
const flagPath = paths.activeFlag(claudeDir);
```

In `caveman-mode-tracker.js`, edit line 9 to add the require:

```js
const { getDefaultMode, getLanguages, safeWriteFlag, readFlag, VALID_MODES } = require('./caveman-config');
const paths = require('./caveman-paths');
```

Then edit lines 15-16 to resolve the flag path from the module:

```js
const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
const flagPath = paths.activeFlag(claudeDir);
```

In `caveman-stats-stop.js`, edit line 16 to add the require:

```js
const { execFileSync } = require('child_process');
const paths = require('./caveman-paths');
```

Then edit line 24 (the cheap active-guard) to:

```js
    if (!fs.existsSync(paths.activeFlag(claudeDir))) return;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_caveman_activation_paths.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/caveman-activate.js .nvm-isolated/.claude-isolated/hooks/caveman-mode-tracker.js .nvm-isolated/.claude-isolated/hooks/caveman-stats-stop.js tests/test_caveman_activation_paths.sh
git commit -m "refactor(caveman): activation hooks use .caveman/active + migrate legacy on start"
```

---

### Task 4: SessionEnd cleanup hook

**Files:**
- Create: `.nvm-isolated/.claude-isolated/hooks/caveman-cleanup.js`
- Modify: `.nvm-isolated/.claude-isolated/settings.json` (SessionEnd array, lines 181-190)
- Test: `tests/test_caveman_cleanup.sh`

**Interfaces:**
- Consumes: `caveman-paths.js` — `sessionSuffix`, `pruneSessionSuffixes`. Hook stdin JSON `{ transcript_path }`.
- Produces: deletes `.caveman/suffix-<sessionId>` for the ending session; prunes stale suffix files.

- [ ] **Step 1: Write the failing test**

Create `tests/test_caveman_cleanup.sh`:

```bash
#!/usr/bin/env bash
# Tests the SessionEnd cleanup hook: deletes this session's suffix file + prunes.
# Run: bash tests/test_caveman_cleanup.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLEANUP="$REPO_ROOT/.nvm-isolated/.claude-isolated/hooks/caveman-cleanup.js"

FAILED=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }

t_cleanup() {
  echo "[cleanup] SessionEnd deletes own suffix, prunes stale, keeps others"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"
  local sid="sess-END"
  printf 'x' > "$cc/.caveman/suffix-$sid"           # this session's file → deleted
  printf 'x' > "$cc/.caveman/suffix-other"          # another live session → kept
  touch -d '4 days ago' "$cc/.caveman/suffix-other"
  printf 'x' > "$cc/.caveman/suffix-zombie"         # stale → pruned
  touch -d '6 days ago' "$cc/.caveman/suffix-zombie"

  printf '%s' "{\"transcript_path\":\"$cc/projects/foo/$sid.jsonl\"}" \
    | CLAUDE_CONFIG_DIR="$cc" node "$CLEANUP" >/dev/null 2>&1

  [[ -e "$cc/.caveman/suffix-$sid" ]]    && fail "own suffix deleted"          || pass "own suffix deleted"
  [[ -e "$cc/.caveman/suffix-zombie" ]]  && fail "stale (6d) suffix pruned"    || pass "stale (6d) suffix pruned"
  [[ -e "$cc/.caveman/suffix-other" ]]   && pass "recent other session kept"   || fail "recent other session kept"
}
t_cleanup

# Missing transcript_path must not throw and must not delete anything wrongly.
t_no_transcript() {
  echo "[cleanup] no transcript_path → no crash, prune still runs"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"
  printf 'x' > "$cc/.caveman/suffix-keep"; touch -d '1 day ago' "$cc/.caveman/suffix-keep"
  printf '%s' '{}' | CLAUDE_CONFIG_DIR="$cc" node "$CLEANUP" >/dev/null 2>&1
  local rc=$?
  [[ $rc -eq 0 ]] && pass "exit 0 on empty input" || fail "exit 0 on empty input"
  [[ -e "$cc/.caveman/suffix-keep" ]] && pass "recent file kept" || fail "recent file kept"
}
t_no_transcript

echo
[[ $FAILED -eq 0 ]] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $FAILED
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_caveman_cleanup.sh`
Expected: FAIL — `Cannot find module '.../caveman-cleanup.js'`.

- [ ] **Step 3: Create the cleanup hook**

Create `.nvm-isolated/.claude-isolated/hooks/caveman-cleanup.js`:

```js
#!/usr/bin/env node
// caveman-cleanup — Claude Code SessionEnd hook.
//
// Deletes THIS session's per-session statusline-suffix file (it is useless once
// the session ends) and prunes any suffix files older than MAX_AGE_MS as a
// safety net for sessions that died without a SessionEnd (crash / kill -9).
//
// Best-effort and silent: never throws, emits nothing — SessionEnd must not fail
// over caveman cleanup.

const fs = require('fs');
const os = require('os');
const path = require('path');
const paths = require('./caveman-paths');

let input = '';
process.stdin.on('data', (chunk) => { input += chunk; });
process.stdin.on('end', () => {
  try {
    const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');

    let data = {};
    try { data = JSON.parse(input); } catch {}

    // Session id is the transcript basename, matching caveman-stats.js.
    if (data.transcript_path) {
      const sessionId = path.basename(data.transcript_path, '.jsonl');
      try { fs.unlinkSync(paths.sessionSuffix(claudeDir, sessionId)); } catch {}
    }

    paths.pruneSessionSuffixes(claudeDir);
  } catch {
    // Never break the SessionEnd hook chain over cleanup.
  }
});
```

- [ ] **Step 4: Register the hook in `settings.json`**

Replace the SessionEnd block (lines 181-190) so the cleanup hook runs alongside the existing cache report:

```json
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/cache-report.py\""
          },
          {
            "type": "command",
            "command": "node \"$CLAUDE_CONFIG_DIR/hooks/caveman-cleanup.js\""
          }
        ]
      }
    ]
```

- [ ] **Step 5: Run test + validate settings.json**

Run: `bash tests/test_caveman_cleanup.sh`
Expected: `ALL TESTS PASSED`

Run: `node -e "JSON.parse(require('fs').readFileSync('.nvm-isolated/.claude-isolated/settings.json','utf8')); console.log('settings.json OK')"`
Expected: `settings.json OK`

- [ ] **Step 6: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/caveman-cleanup.js .nvm-isolated/.claude-isolated/settings.json tests/test_caveman_cleanup.sh
git commit -m "feat(caveman): SessionEnd cleanup hook deletes session suffix + prunes"
```

---

### Task 5: Rewire `claude-statusline.sh` to `.caveman/`

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` (lines 328-344)
- Test: `tests/test_caveman_session_savings.sh` (t3 rewritten)

**Interfaces:**
- Consumes: reads `.caveman/active`, `.caveman/suffix-<SESSION_ID>`, `.caveman/statusline-suffix`.
- Produces: the `⛏` badge string (unchanged format).

- [ ] **Step 1: Rewrite t3 in the test**

In `tests/test_caveman_session_savings.sh`, replace the `t3_statusline_precedence` function (lines 84-122) with the `.caveman/` variant:

```bash
t3_statusline_precedence() {
  echo "[t3] statusline suffix precedence (.caveman/)"
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/scripts" "$tmp/.caveman"
  cp "$STATUSLINE" "$tmp/scripts/claude-statusline.sh"
  : > "$tmp/settings.json"          # makes the script detect CLAUDE_CONFIG_DIR=$tmp
  printf 'full' > "$tmp/.caveman/active"

  local sid="sid-c3"
  local stdin_json
  stdin_json='{"session_id":"'"$sid"'","model":{"display_name":"Opus 4.8"},"cost":{"total_cost_usd":0.5},"context_window":{"total_input_tokens":1000,"total_output_tokens":35000,"context_window_size":200000,"current_usage":{"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"input_tokens":0}}}'
  run_sl() { printf '%s' "$stdin_json" | ICLAUDE_SL_NO_CACHE=1 bash "$tmp/scripts/claude-statusline.sh" 2>/dev/null; }

  # Case A: per-session file present → badge uses it
  printf '⛏ 65.0k · Σ110.1M' > "$tmp/.caveman/suffix-$sid"
  printf '⛏ Σ110.1M'         > "$tmp/.caveman/statusline-suffix"
  local outA; outA="$(run_sl)"
  assert_contains "t3A per-session badge wins" "$outA" "⛏ 65.0k · Σ110.1M"

  # Case B: per-session absent → global fallback
  rm -f "$tmp/.caveman/suffix-$sid"
  local outB; outB="$(run_sl)"
  assert_contains     "t3B global fallback shown"     "$outB" "⛏ Σ110.1M"
  assert_not_contains "t3B no session number in fallback" "$outB" "65.0k"

  # Case C: both absent → bare pick
  rm -f "$tmp/.caveman/statusline-suffix"
  local outC; outC="$(run_sl)"
  assert_contains     "t3C bare caveman icon" "$outC" "⛏"
  assert_not_contains "t3C no Σ when bare"     "$outC" "⛏ Σ"

  # Case D: caveman inactive → no badge at all
  rm -f "$tmp/.caveman/active"
  printf '⛏ Σ110.1M' > "$tmp/.caveman/statusline-suffix"
  local outD; outD="$(run_sl)"
  assert_not_contains "t3D no caveman badge when inactive" "$outD" "⛏"
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_caveman_session_savings.sh 2>&1 | grep -E '^\s+(PASS|FAIL): t3'`
Expected: FAIL lines for t3 — statusline still reads root `.caveman-active`, so the badge never renders from `.caveman/`.

- [ ] **Step 3: Update the statusline block**

In `scripts/claude-statusline.sh`, replace the caveman badge block (lines 328-344) with:

```bash
# Caveman badge — show ⛏ when active flag exists in $CLAUDE_CONFIG_DIR/.caveman/.
# Prefer THIS session's suffix (⛏ <session> · Σ<cumulative>), written by
# caveman-stats.js as .caveman/suffix-<session_id>; fall back to the global
# cumulative-only .caveman/statusline-suffix (e.g. before the first Stop).
CAVEMAN_ICON=""
CAVEMAN_DIR="$CLAUDE_CONFIG_DIR/.caveman"
if [[ -f "$CAVEMAN_DIR/active" ]]; then
    _CAVEMAN_SUFFIX=""
    if [[ -n "$SESSION_ID" && "$SESSION_ID" != "unknown" ]]; then
        _CAVEMAN_PS_FILE="$CAVEMAN_DIR/suffix-${SESSION_ID}"
        [[ -f "$_CAVEMAN_PS_FILE" ]] && _CAVEMAN_SUFFIX=$(cat "$_CAVEMAN_PS_FILE" 2>/dev/null | tr -d '\n\r')
    fi
    if [[ -z "$_CAVEMAN_SUFFIX" ]]; then
        _CAVEMAN_GLOBAL_FILE="$CAVEMAN_DIR/statusline-suffix"
        [[ -f "$_CAVEMAN_GLOBAL_FILE" ]] && _CAVEMAN_SUFFIX=$(cat "$_CAVEMAN_GLOBAL_FILE" 2>/dev/null | tr -d '\n\r')
    fi
    [[ -n "$_CAVEMAN_SUFFIX" ]] && CAVEMAN_ICON=" | ${_CAVEMAN_SUFFIX}" || CAVEMAN_ICON=" | ⛏"
fi
```

- [ ] **Step 4: Run the full savings test to verify it passes**

Run: `bash tests/test_caveman_session_savings.sh`
Expected: `ALL TESTS PASSED` (t1, t2, t3 all green).

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh tests/test_caveman_session_savings.sh
git commit -m "refactor(caveman): statusline reads badge from .caveman/ dir"
```

---

### Task 6: Full regression run + docs

**Files:**
- Run: all `tests/test_caveman_*.sh`
- Modify (if present): iwiki page / README only if they describe artifact locations (see Step 2).

**Interfaces:**
- Consumes: all prior tasks.
- Produces: green test suite; docs consistent with `.caveman/` layout.

- [ ] **Step 1: Run the full caveman test suite**

Run:
```bash
for t in tests/test_caveman_paths.sh tests/test_caveman_session_savings.sh tests/test_caveman_activation_paths.sh tests/test_caveman_cleanup.sh; do echo "== $t =="; bash "$t"; done
```
Expected: every file ends with `ALL TESTS PASSED`.

- [ ] **Step 2: Sync docs (iwiki + README) per CLAUDE.md**

Check whether any doc names the old artifact paths:
```bash
grep -rn "caveman-statusline-suffix\|caveman-active\|caveman-history" docs/ README.md docs/README.ru.md 2>/dev/null
```
For each hit that documents the on-disk location, update it to `.caveman/…`. If the iwiki MCP server reports a domain bound to this project (`wiki_status`), update the relevant section via `wiki_update_page`. If no docs reference the paths, note "no doc references — nothing to sync".

- [ ] **Step 3: Manual smoke of a live-shaped flow**

```bash
cc="$(mktemp -d)"
printf 'LIFE\n' > "$cc/.caveman-history.jsonl"          # legacy artifact pre-upgrade
CLAUDE_CONFIG_DIR="$cc" CAVEMAN_DEFAULT_MODE=full node .nvm-isolated/.claude-isolated/hooks/caveman-activate.js >/dev/null 2>&1
ls -a "$cc"; echo "--- .caveman ---"; ls -a "$cc/.caveman"
rm -rf "$cc"
```
Expected: config root shows `.caveman` (a dir) and NO `.caveman-*` files; `.caveman/` contains `active` and the migrated `history.jsonl`.

- [ ] **Step 4: Commit any doc changes**

```bash
git add -A
git commit -m "docs(caveman): document .caveman/ artifact directory" || echo "no doc changes to commit"
```

---

## Self-Review

**Spec coverage:**
- Goal 1 (consolidate into `.caveman/`) → Tasks 1-5 (paths module + all writers/readers).
- Goal 2 (delete per-session at SessionEnd) → Task 4 (`caveman-cleanup.js` + settings.json).
- Goal 3 (age-prune safety net, 7→5 days) → Task 1 (`MAX_AGE_MS`) + Task 2 (Stop-time prune) + Task 4 (SessionEnd prune).
- Goal 4 (preserve lifetime Σ across migration) → Task 1 `migrateLegacy` moves `history.jsonl`/base suffix; t1 asserts content preserved; Task 3 wires migration into SessionStart.
- Spec "Affected Files" table: `caveman-config.js` was listed but is **not** modified — its temp filename is a generic atomic-write temp created in the target's parent dir, which follows the target into `.caveman/` automatically. Documented in Global Constraints.
- Spec testing items (a)-(d): (a) root-clean → t1 asserts no root leak; (b) SessionEnd delete → Task 4 test; (c) prune >5d/<5d → t2 + Task 1 prune test; (d) migration → Task 1 migrate test + Task 3 activate test.

**Placeholder scan:** No TBD/TODO/"add error handling"/"similar to" — every step has full file contents or exact before/after edits.

**Type consistency:** `caveman-paths.js` exports `activeFlag`, `history`, `baseSuffix`, `sessionSuffix`, `migrateLegacy`, `pruneSessionSuffixes`, `MAX_AGE_MS`, `SESSION_SUFFIX_PREFIX` — the same names are consumed in Tasks 2-4. Prune is defined once in Task 1 and reused (not redefined) in stats.js and cleanup.js.
