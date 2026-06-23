---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-23-caveman-session-savings-design.md
review:
  plan_hash: ca30004e63fa6aef
  spec_hash: 4efe4cc9a04e9765
  last_run: 2026-06-23
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings: []
---

# Session-scoped Caveman Token Savings — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the current session's caveman token savings in the statusline badge, alongside the lifetime cumulative (`⛏ 12k · Σ110M`), instead of only the cumulative total.

**Architecture:** The per-session savings figure is already computed in `caveman-stats.js` (and discarded). Redirect it into a per-session pre-rendered suffix file keyed by `session_id`; keep the global file as a cumulative-only fallback. The Stop hook (`caveman-stats-stop.js`) already re-runs `caveman-stats.js` every turn, so the badge auto-refreshes. The statusline stays a dumb reader: it picks the per-session file by its known `SESSION_ID`, falling back to the global file.

**Tech Stack:** Node.js (caveman hooks), Bash (statusline + tests). No new dependencies.

## Global Constraints

- **Branch base `dev`; PR into `dev`.** The `caveman-stats-stop.js` Stop hook this design relies on exists on `dev`, not `master`. (Spec header.)
- **Single source of truth = `caveman-stats.js`.** All savings math and badge-string formatting live in JS; the statusline only `cat`s a pre-rendered string. Do not duplicate the compression formula into bash. (Spec → Architecture.)
- **`humanizeTokens` is the only number formatter** (`caveman-stats.js:178`): `≥1e6 → "N.NM"`, `≥1e3 → "N.Nk"`, else integer; `≤0 → "0"`.
- **Prune glob must use the trailing dash** `.caveman-statusline-suffix-` so it never matches the global `.caveman-statusline-suffix` (no session id). (Spec → C2.)
- **Per-session badge format:** `⛏ <session> · Σ<cumulative>` (session first; `Σ` marks the lifetime total). Separator is `" · "` (U+00B7). (Spec → Goal.)
- **Statusline ignores the `CLAUDE_CONFIG_DIR` env var** — it derives `CLAUDE_CONFIG_DIR` from `BASH_SOURCE` (`SCRIPT_DIR/..` when `../settings.json` or `../router.json` exists; else `$HOME/.claude`). Statusline tests MUST therefore run a copy of the script placed under a temp `scripts/` dir with a sibling `settings.json`. (`claude-statusline.sh:16-25`.)
- **Statusline render cache:** the script caches per session at `/tmp/iclaude-sl-cache-<id>` (TTL 3 s). Statusline tests MUST set `ICLAUDE_SL_NO_CACHE=1` to avoid a stale badge.
- **Node hooks honor `CLAUDE_CONFIG_DIR`** (`caveman-stats.js:281`, `caveman-config.js`), so node-driven tests set it to a temp dir.
- **Commit message trailer:** end every commit body with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure

- **Modify** `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js`
  - suffix-writing block (`:322-328`) → write per-session composed string + cumulative-only global (Task 1).
  - add `pruneOldSessionSuffixes()` helper + call it (Task 2).
- **Modify** `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
  - caveman badge block (`:311-320`) → per-session-first, global fallback (Task 3).
- **Create** `tests/test_caveman_session_savings.sh`
  - one bash harness, one test function per task; grows across Tasks 1–3.
- **Update** `docs/wiki/caveman.md`, `docs/wiki/statusline.md` via iwiki (Task 4).

Task order is sequential: Task 3 (statusline fallback format) depends on Task 1's global `⛏ Σ…` format.

---

## Task 1: Per-session composed suffix + cumulative-only global

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js:322-328`
- Test: `tests/test_caveman_session_savings.sh`

**Interfaces:**
- Consumes (already in scope at the edit site): `estSavedTokens` (this session's savings, from `deriveSavings` at `:310`), `sessionId` (`:311`), `agg` (`aggregateHistory(historyPath, null)` at `:326`), `humanizeTokens` (`:178`), `safeWriteFlag` (imported `:13`).
- Produces:
  - File `$CLAUDE_CONFIG_DIR/.caveman-statusline-suffix-<sessionId>` containing `⛏ <session> · Σ<cumulative>` (or `⛏ Σ<cumulative>` when session savings are 0, or empty string when both are 0).
  - File `$CLAUDE_CONFIG_DIR/.caveman-statusline-suffix` containing `⛏ Σ<cumulative>` (or empty when cumulative is 0).

- [ ] **Step 1: Write the failing test**

Create `tests/test_caveman_session_savings.sh` with the harness and the Task 1 test:

```bash
#!/usr/bin/env bash
# Tests for session-scoped caveman statusline savings.
# Run: bash tests/test_caveman_session_savings.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.nvm-isolated/.claude-isolated/hooks"
STATUSLINE="$REPO_ROOT/.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh"
STATS="$HOOKS_DIR/caveman-stats.js"

FAILED=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }
assert_eq() { # desc expected actual
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1"; echo "    expected: [$2]"; echo "    actual:   [$3]"; fi
}
assert_contains() { # desc haystack needle
  if [[ "$2" == *"$3"* ]]; then pass "$1"; else fail "$1"; echo "    missing [$3] in: [$2]"; fi
}
assert_not_contains() { # desc haystack needle
  if [[ "$2" != *"$3"* ]]; then pass "$1"; else fail "$1"; echo "    unexpected [$3] in: [$2]"; fi
}

# ---- Task 1: per-session composed suffix + cumulative-only global ----
t1_session_suffix() {
  echo "[t1] per-session composed suffix"
  local cc; cc="$(mktemp -d)"
  trap 'rm -rf "$cc"' RETURN

  # caveman active in 'full' mode (ratio 0.65)
  printf 'full' > "$cc/.caveman-active"
  # pre-seed history with a prior session worth 110.0M saved tokens
  printf '%s\n' '{"ts":1,"session_id":"old-session","mode":"full","model":"claude-opus-4-8","output_tokens":59230000,"est_saved_tokens":110000000,"est_saved_usd":0}' > "$cc/.caveman-history.jsonl"
  # synthetic session: 35000 output tokens, opus → est_saved = round(35000/0.35)-35000 = 65000
  printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"output_tokens":35000}}}' > "$cc/sess-A.jsonl"

  CLAUDE_CONFIG_DIR="$cc" node "$STATS" --session-file "$cc/sess-A.jsonl" >/dev/null 2>&1

  local per glob
  per="$(cat "$cc/.caveman-statusline-suffix-sess-A" 2>/dev/null)"
  glob="$(cat "$cc/.caveman-statusline-suffix" 2>/dev/null)"
  # cumulative = 110000000 + 65000 = 110065000 → humanizeTokens → "110.1M"
  assert_eq "t1 per-session = session · cumulative" "⛏ 65.0k · Σ110.1M" "$per"
  assert_eq "t1 global = cumulative-only"           "⛏ Σ110.1M"        "$glob"

  # concurrency (spec success criterion #3): a second session writes its OWN
  # per-session file; the first session's file is left untouched.
  printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"output_tokens":350000}}}' > "$cc/sess-C.jsonl"
  CLAUDE_CONFIG_DIR="$cc" node "$STATS" --session-file "$cc/sess-C.jsonl" >/dev/null 2>&1
  # sess-C est_saved = round(350000/0.35)-350000 = 650000 → "650.0k"
  # cumulative now = 110000000 + 65000 + 650000 = 110715000 → "110.7M"
  assert_eq "t1 concurrent session has its own file" "⛏ 650.0k · Σ110.7M" "$(cat "$cc/.caveman-statusline-suffix-sess-C" 2>/dev/null)"
  assert_eq "t1 first session file untouched by 2nd" "⛏ 65.0k · Σ110.1M"  "$(cat "$cc/.caveman-statusline-suffix-sess-A" 2>/dev/null)"
}

t1_session_suffix

echo
[[ $FAILED -eq 0 ]] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $FAILED
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `bash tests/test_caveman_session_savings.sh`
Expected: FAIL — current code writes only `$cc/.caveman-statusline-suffix` as `⛏ 110.1M` (no `Σ`, no per-session file). `t1 per-session …` fails (file absent → empty) and `t1 global …` fails (`⛏ 110.1M` ≠ `⛏ Σ110.1M`).

- [ ] **Step 3: Implement the per-session + global writes**

In `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js`, replace the block at `:322-328`:

```js
    // Statusline suffix: tiny pre-rendered string the shell statusline can
    // cat without parsing JSONL. Updated on every /caveman-stats run.
    // Routed through safeWriteFlag — the suffix path is predictable and
    // user-owned, same symlink-clobber surface as the .caveman-active flag.
    const agg = aggregateHistory(historyPath, null);
    const suffix = agg.estSavedTokens > 0 ? `⛏ ${humanizeTokens(agg.estSavedTokens)}` : '';
    safeWriteFlag(path.join(claudeDir, '.caveman-statusline-suffix'), suffix);
```

with:

```js
    // Statusline suffixes: tiny pre-rendered strings the shell statusline can
    // cat without parsing JSONL. The per-session file carries THIS session's
    // savings first, the lifetime cumulative second (⛏ 12k · Σ110M). The global
    // file stays cumulative-only — a fallback the statusline uses before a
    // session's first Stop has written its per-session file. Both go through
    // safeWriteFlag (predictable, user-owned paths, same symlink-clobber surface
    // as the .caveman-active flag). agg already includes this session's snapshot,
    // appended just above, so Σ is the true lifetime total.
    const agg = aggregateHistory(historyPath, null);
    const cum = humanizeTokens(agg.estSavedTokens);
    let perSession;
    if (estSavedTokens > 0) {
      perSession = `⛏ ${humanizeTokens(estSavedTokens)} · Σ${cum}`;
    } else if (agg.estSavedTokens > 0) {
      perSession = `⛏ Σ${cum}`;
    } else {
      perSession = '';
    }
    safeWriteFlag(path.join(claudeDir, `.caveman-statusline-suffix-${sessionId}`), perSession);
    safeWriteFlag(
      path.join(claudeDir, '.caveman-statusline-suffix'),
      agg.estSavedTokens > 0 ? `⛏ Σ${cum}` : ''
    );
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `bash tests/test_caveman_session_savings.sh`
Expected: PASS — `t1 per-session = session · cumulative` and `t1 global = cumulative-only` both pass; `ALL TESTS PASSED`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/test_caveman_session_savings.sh .nvm-isolated/.claude-isolated/hooks/caveman-stats.js
git commit -m "feat(caveman): per-session statusline savings suffix

Write .caveman-statusline-suffix-<session_id> = '⛏ <session> · Σ<cumulative>'
(reusing the per-session estSavedTokens already computed in caveman-stats.js);
keep the global .caveman-statusline-suffix as a cumulative-only fallback.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Prune per-session suffix files older than 7 days

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js` (add helper near other module functions, e.g. after `humanizeTokens` at `:183`; call it in `main()` right after the suffix writes from Task 1)
- Test: `tests/test_caveman_session_savings.sh`

**Interfaces:**
- Consumes: `fs`, `path` (already required at top), `claudeDir` (in `main()` scope, `:281`).
- Produces: `pruneOldSessionSuffixes(claudeDir)` — deletes `.caveman-statusline-suffix-*` files with `mtime` older than 7 days; never throws; leaves the global `.caveman-statusline-suffix` untouched.

- [ ] **Step 1: Write the failing test**

Append this function and its call in `tests/test_caveman_session_savings.sh`, immediately before the `echo` / final summary lines:

```bash
# ---- Task 2: prune per-session suffix files older than 7 days ----
t2_prune() {
  echo "[t2] prune stale per-session suffix files"
  local cc; cc="$(mktemp -d)"
  trap 'rm -rf "$cc"' RETURN

  printf 'full' > "$cc/.caveman-active"
  printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"output_tokens":35000}}}' > "$cc/sess-B.jsonl"

  # a stale per-session file (8 days old) that must be pruned
  printf '⛏ 1k · Σ1k' > "$cc/.caveman-statusline-suffix-zombie"
  touch -d '8 days ago' "$cc/.caveman-statusline-suffix-zombie"
  # the global file is recent and must SURVIVE (no trailing-dash match)
  printf '⛏ Σ1k' > "$cc/.caveman-statusline-suffix"
  touch -d '8 days ago' "$cc/.caveman-statusline-suffix"

  CLAUDE_CONFIG_DIR="$cc" node "$STATS" --session-file "$cc/sess-B.jsonl" >/dev/null 2>&1

  [[ -e "$cc/.caveman-statusline-suffix-zombie" ]] && fail "t2 stale per-session file removed" || pass "t2 stale per-session file removed"
  [[ -e "$cc/.caveman-statusline-suffix" ]] && pass "t2 global file survives (not matched by prune)" || fail "t2 global file survives (not matched by prune)"
  [[ -e "$cc/.caveman-statusline-suffix-sess-B" ]] && pass "t2 current session file present" || fail "t2 current session file present"
}

t2_prune
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `bash tests/test_caveman_session_savings.sh`
Expected: `t2 stale per-session file removed` FAILS (no pruning yet → `zombie` still present). The other two t2 assertions pass.

- [ ] **Step 3: Implement the prune helper + call**

In `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js`, add after `humanizeTokens` (`:183`):

```js
// Remove per-session statusline-suffix files older than 7 days so they don't
// accumulate in the config dir. The trailing '-' in the prefix keeps the global
// '.caveman-statusline-suffix' (no session id) out of the match. Never throws —
// a prune failure must not break stats.
function pruneOldSessionSuffixes(claudeDir) {
  const MAX_AGE_MS = 7 * 86_400_000;
  const prefix = '.caveman-statusline-suffix-';
  const now = Date.now();
  let names;
  try { names = fs.readdirSync(claudeDir); } catch { return; }
  for (const name of names) {
    if (!name.startsWith(prefix)) continue;
    const p = path.join(claudeDir, name);
    try {
      if (now - fs.statSync(p).mtimeMs > MAX_AGE_MS) fs.unlinkSync(p);
    } catch {}
  }
}
```

Then, in `main()`, immediately after the two `safeWriteFlag(...)` calls added in Task 1, add:

```js
    pruneOldSessionSuffixes(claudeDir);
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `bash tests/test_caveman_session_savings.sh`
Expected: PASS — all t1 + t2 assertions pass; `ALL TESTS PASSED`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/test_caveman_session_savings.sh .nvm-isolated/.claude-isolated/hooks/caveman-stats.js
git commit -m "feat(caveman): prune stale per-session statusline suffix files

Delete .caveman-statusline-suffix-<id> files older than 7 days on each stats
run; the trailing-dash prefix leaves the global suffix file untouched.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Statusline — per-session first, global fallback

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh:311-320`
- Test: `tests/test_caveman_session_savings.sh`

**Interfaces:**
- Consumes: `SESSION_ID` (parsed from stdin earlier in the script, `:65`/jq read block), `CLAUDE_CONFIG_DIR` (derived from `BASH_SOURCE`), and the per-session / global suffix files produced by Tasks 1–2.
- Produces: `CAVEMAN_ICON` set to `" | <per-session suffix>"`, else `" | <global suffix>"`, else `" | ⛏"`.

- [ ] **Step 1: Write the failing test**

Append this function and its call in `tests/test_caveman_session_savings.sh`, before the final summary lines. It copies the real statusline into a temp `scripts/` dir (with a sibling `settings.json`) so the script's `BASH_SOURCE`-based config detection points at the temp dir:

```bash
# ---- Task 3: statusline per-session-first, global fallback ----
t3_statusline_precedence() {
  echo "[t3] statusline suffix precedence"
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/scripts"
  cp "$STATUSLINE" "$tmp/scripts/claude-statusline.sh"
  : > "$tmp/settings.json"          # makes the script detect CLAUDE_CONFIG_DIR=$tmp
  printf 'full' > "$tmp/.caveman-active"

  local sid="sid-c3"
  # stdin: native Anthropic session, non-zero tokens (avoids the new-session suppression)
  local stdin_json
  stdin_json='{"session_id":"'"$sid"'","model":{"display_name":"Opus 4.8"},"cost":{"total_cost_usd":0.5},"context_window":{"total_input_tokens":1000,"total_output_tokens":35000,"context_window_size":200000,"current_usage":{"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"input_tokens":0}}}'
  run_sl() { ICLAUDE_SL_NO_CACHE=1 printf '%s' "$stdin_json" | bash "$tmp/scripts/claude-statusline.sh" 2>/dev/null; }

  # Case A: per-session file present → badge uses it
  printf '⛏ 65.0k · Σ110.1M' > "$tmp/.caveman-statusline-suffix-$sid"
  printf '⛏ Σ110.1M'         > "$tmp/.caveman-statusline-suffix"
  local outA; outA="$(run_sl)"
  assert_contains "t3A per-session badge wins" "$outA" "⛏ 65.0k · Σ110.1M"

  # Case B: per-session absent → global fallback
  rm -f "$tmp/.caveman-statusline-suffix-$sid"
  local outB; outB="$(run_sl)"
  assert_contains     "t3B global fallback shown"     "$outB" "⛏ Σ110.1M"
  assert_not_contains "t3B no session number in fallback" "$outB" "65.0k"

  # Case C: both absent → bare pick
  rm -f "$tmp/.caveman-statusline-suffix"
  local outC; outC="$(run_sl)"
  assert_contains     "t3C bare caveman icon" "$outC" "⛏"
  assert_not_contains "t3C no Σ when bare"     "$outC" "Σ"

  # Case D (spec success criterion #5): caveman inactive → no badge at all
  rm -f "$tmp/.caveman-active"
  printf '⛏ Σ110.1M' > "$tmp/.caveman-statusline-suffix"
  local outD; outD="$(run_sl)"
  assert_not_contains "t3D no caveman badge when inactive" "$outD" "⛏"
}

t3_statusline_precedence
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `bash tests/test_caveman_session_savings.sh`
Expected: `t3A per-session badge wins` FAILS — current statusline reads only the global `.caveman-statusline-suffix` (`⛏ Σ110.1M`), ignoring the per-session file, so case A shows the global string, not `⛏ 65.0k · Σ110.1M`. (Cases B and C may already pass.)

- [ ] **Step 3: Implement per-session-first resolution**

In `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`, replace the block at `:311-320`:

```bash
# Caveman badge — show ⛏ when .caveman-active exists in $CLAUDE_CONFIG_DIR
# caveman-stats.js writes $CLAUDE_CONFIG_DIR/.caveman-statusline-suffix (e.g. "⛏ 5.2k")
CAVEMAN_ICON=""
if [[ -f "$CLAUDE_CONFIG_DIR/.caveman-active" ]]; then
    _CAVEMAN_SUFFIX_FILE="$CLAUDE_CONFIG_DIR/.caveman-statusline-suffix"
    if [[ -f "$_CAVEMAN_SUFFIX_FILE" ]]; then
        _CAVEMAN_SUFFIX=$(cat "$_CAVEMAN_SUFFIX_FILE" 2>/dev/null | tr -d '\n\r')
        [[ -n "$_CAVEMAN_SUFFIX" ]] && CAVEMAN_ICON=" | ${_CAVEMAN_SUFFIX}" || CAVEMAN_ICON=" | ⛏"
    else
        CAVEMAN_ICON=" | ⛏"
    fi
fi
```

with:

```bash
# Caveman badge — show ⛏ when .caveman-active exists in $CLAUDE_CONFIG_DIR.
# Prefer THIS session's suffix (⛏ <session> · Σ<cumulative>), written by
# caveman-stats.js as .caveman-statusline-suffix-<session_id>; fall back to the
# global cumulative-only .caveman-statusline-suffix (e.g. before the first Stop).
CAVEMAN_ICON=""
if [[ -f "$CLAUDE_CONFIG_DIR/.caveman-active" ]]; then
    _CAVEMAN_SUFFIX=""
    if [[ -n "$SESSION_ID" && "$SESSION_ID" != "unknown" ]]; then
        _CAVEMAN_PS_FILE="$CLAUDE_CONFIG_DIR/.caveman-statusline-suffix-${SESSION_ID}"
        [[ -f "$_CAVEMAN_PS_FILE" ]] && _CAVEMAN_SUFFIX=$(cat "$_CAVEMAN_PS_FILE" 2>/dev/null | tr -d '\n\r')
    fi
    if [[ -z "$_CAVEMAN_SUFFIX" ]]; then
        _CAVEMAN_GLOBAL_FILE="$CLAUDE_CONFIG_DIR/.caveman-statusline-suffix"
        [[ -f "$_CAVEMAN_GLOBAL_FILE" ]] && _CAVEMAN_SUFFIX=$(cat "$_CAVEMAN_GLOBAL_FILE" 2>/dev/null | tr -d '\n\r')
    fi
    [[ -n "$_CAVEMAN_SUFFIX" ]] && CAVEMAN_ICON=" | ${_CAVEMAN_SUFFIX}" || CAVEMAN_ICON=" | ⛏"
fi
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `bash tests/test_caveman_session_savings.sh`
Expected: PASS — all t1 + t2 + t3 assertions pass; `ALL TESTS PASSED`, exit 0.

- [ ] **Step 5: Verify statusline syntax + commit**

```bash
bash -n .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh
git add tests/test_caveman_session_savings.sh .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh
git commit -m "feat(statusline): show per-session caveman savings, global fallback

Resolve the caveman badge from .caveman-statusline-suffix-<session_id> first
(using the already-parsed SESSION_ID), falling back to the global cumulative
suffix, then to a bare icon.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Update the wiki

**Files:**
- Modify: `docs/wiki/caveman.md`, `docs/wiki/statusline.md` (via iwiki skill — do not hand-edit the index)

The behavior of the caveman badge and the suffix files changed; the project's post-task checklist requires the wiki to stay current.

- [ ] **Step 1: Regenerate the caveman page**

Invoke the `iwiki:iwiki-ingest` skill on `.nvm-isolated/.claude-isolated/hooks/caveman-stats.js` (and, if prompted, `caveman-stats-stop.js`). Review the diff; confirm it documents the per-session suffix file + cumulative-only global + 7-day prune.

- [ ] **Step 2: Regenerate the statusline page**

Invoke the `iwiki:iwiki-ingest` skill on `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`. Confirm the diff documents the per-session-first badge resolution.

- [ ] **Step 3: Lint the wiki**

Invoke `iwiki:iwiki-lint`. Expected: no broken `[[refs]]`, no new orphan/stale pages introduced by these edits.

- [ ] **Step 4: Commit**

```bash
git add docs/wiki/
git commit -m "docs(wiki): session-scoped caveman statusline savings

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Done criteria

- `bash tests/test_caveman_session_savings.sh` → `ALL TESTS PASSED`, exit 0 (t1, t2, t3 all green).
- `bash -n .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` → clean.
- Manual smoke (optional): in a live caveman session, after one turn the badge reads `⛏ <session> · Σ<cumulative>`; a brand-new session before its first turn reads `⛏ Σ<cumulative>`.
- Wiki updated + lint clean.
- Branch `dev-caveman-session-savings` → PR into `dev` (use `superpowers:finishing-a-development-branch` / `@skill:git-workflow`).

## Notes / out of scope

- Per-mode compression ratios for lite/ultra/wenyan stay 0 until benchmarked (unchanged).
- No USD in the badge (tokens only).
- Pre-existing stale doc-comment in `claude-statusline.sh:756-758` (`get_display_mode()` says ≥130/70-129/<70; code branches at 80/40) is unrelated — mention, do not fix here.
