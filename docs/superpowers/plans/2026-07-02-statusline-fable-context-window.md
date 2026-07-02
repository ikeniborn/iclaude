---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-02-statusline-fable-context-window-design.md
review:
  plan_hash: b1014ea02c62c526
  last_run: 2026-07-02
  phases:
    structure:
      status: passed
    coverage:
      status: passed
    dependencies:
      status: passed
    verifiability:
      status: passed
    consistency:
      status: passed
  findings:
    - id: F-001
      phase: coverage
      severity: INFO
      section: "## File structure"
      section_hash: 76b074f9f2bfa625
      fragment: "Do NOT touch `.nvm-isolated/scripts/claude-statusline.sh`"
      text: "Spec §4 (out of scope) был покрыт только запретительной заметкой, без проверяемого шага."
      fix: "Добавлен Task 6 Step 1: git diff --stat dev -- .nvm-isolated/scripts/ → пустой вывод."
      verdict: fixed
      verdict_at: 2026-07-02
    - id: F-002
      phase: consistency
      severity: INFO
      section: "### Task 4: Fix the hit-rate rounding (floor)"
      section_hash: a99f753ff6e33cd8
      fragment: "claude-statusline.sh:~224"
      text: "Точный якорь строки 224 сместится после Task 2 (+2 строки)."
      fix: "Якорь заменён на ~224 (≈226 после Task 2) + поиск по содержимому HIT_RATE."
      verdict: fixed
      verdict_at: 2026-07-02
    - id: F-003
      phase: verifiability
      severity: INFO
      section: "### Task 5: Verify in a live session + update docs"
      section_hash: 9ddb4dcfbf8c22f4
      fragment: "Then `wiki_lint`"
      text: "Шаг wiki_lint не фиксировал ожидаемый результат."
      fix: "Дописано ожидание: без broken [[refs]], orphan/stale для страницы statusline."
      verdict: fixed
      verdict_at: 2026-07-02
result_check:
  verdict: OK
  plan_hash: b1014ea02c62c526
  last_run: 2026-07-02
---
# Statusline Claude 5 Context Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Statusline shows the real 1M context window for the Claude 5 family (Fable/Mythos/Sonnet 5) instead of 200K, and the cache hit-rate segment stops rounding 99.5%+ up to a misleading 100%.

**Architecture:** Two point edits in the single active statusline script (`detect_real_context_window()` model→window mapping and the `CACHE_DISPLAY` hit-rate format), driven by a new black-box regression test that pipes synthetic Claude Code session JSON into the script and asserts on the rendered segments.

**Tech Stack:** bash, awk, jq (script runtime); plain-bash test in `tests/` (project convention: `set -euo pipefail`, `PASS`/`FAIL` lines, non-zero exit on failure).

**Spec:** `docs/superpowers/specs/2026-07-02-statusline-fable-context-window-design.md`
**Branch:** `dev-fix-statusline-context-window` (already created from `dev`, pushed). PR into `dev`.

---

## File structure

| File | Action | Responsibility |
|---|---|---|
| `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` | Modify (2 hunks: ~line 143 and ~line 224) | The ONLY active statusline script (`settings.json` → `$CLAUDE_CONFIG_DIR/scripts/...`). Fix 1: model→window mapping. Fix 2: hit-rate floor. |
| `tests/test_statusline_context_window.sh` | Create | Black-box regression test: model→window mapping (spec §2) + hit-rate floor (spec §3). |

Do NOT touch `.nvm-isolated/scripts/claude-statusline.sh` — stale copy, not referenced (spec §4).

Context you need about the script under test:

- It reads one JSON object on stdin (Claude Code statusline payload) and prints one status line.
- `ICLAUDE_SL_NO_CACHE=1` disables its /tmp result cache (mandatory in tests — otherwise it returns cached output of a previous run and forks a background updater).
- `STATUSLINE_ADAPTIVE=0` forces full display mode (otherwise a narrow test terminal can drop segments).
- Claude Code always reports `context_window.context_window_size = 200000`, which is why the script maps the real window by model name — that mapping is what Fix 1 extends.
- Rendered segments we assert on: `Σ <remaining> ↓ | 📊 <active> (<percent>%)` and `📦 <hit-rate>% · R…/W…`. Percent = `total_input_tokens * 100 / window`, remaining = `window − total_input_tokens`.

---

### Task 1: Failing regression test for the model→window mapping

**Files:**
- Create: `tests/test_statusline_context_window.sh`

- [ ] **Step 1: Write the test file (window-mapping cases only)**

```bash
#!/usr/bin/env bash
# Regression: detect_real_context_window() must know the Claude 5 family —
# Fable/Mythos/Sonnet 5 have a 1M input window (Claude Code still reports
# context_window_size=200000). Haiku stays at 200K. Observed bug: a Fable
# session rendered "Σ 0 ↓ | 📊 228K (114%) ⚠️" against the false 200K window.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
SL="$repo_root/.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh"

# run_sl <display_name> <total_input> <cache_read> <cache_creation> <input_tokens>
# Pipes a synthetic Claude Code statusline payload into the script.
# ICLAUDE_SL_NO_CACHE=1 — bypass the /tmp result cache (no stale output, no bg fork).
# STATUSLINE_ADAPTIVE=0 — force full display mode regardless of terminal width.
run_sl() {
    ICLAUDE_SL_NO_CACHE=1 STATUSLINE_ADAPTIVE=0 bash "$SL" <<EOF
{"session_id":"sl-ctx-test","transcript_path":"","cwd":"/tmp",
 "workspace":{"project_dir":"/tmp"},
 "model":{"display_name":"$1"},
 "cost":{"total_cost_usd":0},
 "context_window":{"total_input_tokens":$2,"total_output_tokens":1000,
   "context_window_size":200000,"used_percentage":50,
   "current_usage":{"input_tokens":$5,"cache_read_input_tokens":$3,"cache_creation_input_tokens":$4}}}
EOF
}

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- window mapping (spec §2) ---

# Fable 5 = 1M: 228K active → 23%, 772K remaining, no overflow warning
out="$(run_sl "Fable 5" 228000 228000 448 0)"
[[ "$out" == *"(23%)"* ]]  || fail "Fable: expected (23%) of 1M window, got: $out"
[[ "$out" != *"⚠️"* ]]     || fail "Fable: unexpected overflow warning: $out"
[[ "$out" == *"772K"* ]]   || fail "Fable: expected 772K remaining, got: $out"

# Mythos 5 = 1M (same Claude 5 root cause)
out="$(run_sl "Mythos 5" 228000 228000 448 0)"
[[ "$out" == *"(23%)"* ]]  || fail "Mythos: expected (23%) of 1M window, got: $out"

# Sonnet 5 = 1M (outer *sonnet* branch matches but no 4.x version pattern)
out="$(run_sl "Sonnet 5" 100000 100000 0 0)"
[[ "$out" == *"(10%)"* ]]  || fail "Sonnet 5: expected (10%) of 1M window, got: $out"

# Opus 4.8 = 1M (regression: already worked before the fix)
out="$(run_sl "Opus4.8" 459000 457000 2000 0)"
[[ "$out" == *"(46%)"* ]]  || fail "Opus4.8: expected (46%) of 1M window, got: $out"

# Haiku 4.5 = 200K (regression: must NOT become 1M)
out="$(run_sl "Haiku 4.5" 100000 100000 0 0)"
[[ "$out" == *"(50%)"* ]]  || fail "Haiku: expected (50%) of 200K window, got: $out"

echo "PASS test_statusline_context_window.sh"
```

- [ ] **Step 2: Make it executable and run it — expect FAIL on the Fable case**

Run:
```bash
chmod +x tests/test_statusline_context_window.sh
./tests/test_statusline_context_window.sh
```
Expected: `FAIL: Fable: expected (23%) of 1M window, got: … (114%) … ⚠️ …` and exit code 1
(228000 against the false 200K window renders 114% + warning).

If instead it fails with jq/parse noise or `[Status line: awaiting session data...]`, the synthetic JSON is malformed — fix the heredoc before proceeding; do not touch the script yet.

---

### Task 2: Fix `detect_real_context_window()` (window mapping)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh:141-153`
- Test: `tests/test_statusline_context_window.sh`

- [ ] **Step 1: Replace the `case` block inside `detect_real_context_window()`**

Current code (lines 141–153):

```bash
detect_real_context_window() {
    local model="$1" reported="${2:-200000}" known=0
    case "${model,,}" in
        *haiku*) known=200000 ;;                                  # Haiku 4.5 = 200K
        *opus*|*sonnet*)
            case "${model,,}" in
                *4-8*|*4.8*|*4-7*|*4.7*|*4-6*|*4.6*|*4-5*|*4.5*) known=1000000 ;;  # 1M
                *) known=0 ;;                                     # 4.0/4.1 → reported
            esac ;;
    esac
    [[ "$reported" =~ ^[0-9]+$ ]] || reported=200000
    (( known > reported )) && echo "$known" || echo "$reported"
}
```

New code (only the outer `case` changes — the guard and `max()` lines stay):

```bash
detect_real_context_window() {
    local model="$1" reported="${2:-200000}" known=0
    case "${model,,}" in
        *haiku*) known=200000 ;;                                  # Haiku 4.5 = 200K
        *fable*|*mythos*) known=1000000 ;;                        # Claude 5 family = 1M
        *opus*|*sonnet*)
            case "${model,,}" in
                *4-8*|*4.8*|*4-7*|*4.7*|*4-6*|*4.6*|*4-5*|*4.5*) known=1000000 ;;  # 1M
                *sonnet*5*) known=1000000 ;;                      # Sonnet 5 = 1M
                *) known=0 ;;                                     # 4.0/4.1 → reported
            esac ;;
    esac
    [[ "$reported" =~ ^[0-9]+$ ]] || reported=200000
    (( known > reported )) && echo "$known" || echo "$reported"
}
```

Notes for the implementer:
- `*sonnet*5*` sits AFTER the `4-x` patterns on purpose: "Sonnet 4.5" already matched `*4-5*|*4.5*` (same 1M result either way), and this keeps the 4.x list authoritative for versioned names.
- Non-Claude router models (gemini/openai/ollama) match no branch → fall through to the reported value, unchanged behavior.

- [ ] **Step 2: Run the test — expect PASS**

Run: `./tests/test_statusline_context_window.sh`
Expected: `PASS test_statusline_context_window.sh`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh tests/test_statusline_context_window.sh
git commit -m "fix(statusline): map Claude 5 family (Fable/Mythos/Sonnet 5) to 1M context window

detect_real_context_window() only knew haiku/opus/sonnet-4.x, so Fable
sessions fell back to the reported 200K and rendered 228K (114%) with a
false overflow warning. Add fable/mythos and Sonnet 5 patterns (1M);
Haiku and non-Claude router models keep their previous behavior.

Covered by tests/test_statusline_context_window.sh (black-box: synthetic
statusline JSON piped into the script).

🤖 Generated with Claude Code

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Failing test cases for the cache hit-rate floor

**Files:**
- Modify: `tests/test_statusline_context_window.sh`

- [ ] **Step 1: Append hit-rate cases before the final `echo "PASS …"` line**

```bash
# --- cache hit-rate floor (spec §3) ---

# 457000/(457000+2000) = 99.56% → must render 99% (floor), not 100% (round)
out="$(run_sl "Opus4.8" 459000 457000 2000 0)"
[[ "$out" == *"📦 99%"* ]]  || fail "hit-rate floor: expected 📦 99%, got: $out"

# Fully cached request (creation=0, uncached input=0) → exactly 100%
out="$(run_sl "Opus4.8" 457000 457000 0 0)"
[[ "$out" == *"📦 100%"* ]] || fail "hit-rate full: expected 📦 100%, got: $out"
```

- [ ] **Step 2: Run the test — expect FAIL on the floor case**

Run: `./tests/test_statusline_context_window.sh`
Expected: `FAIL: hit-rate floor: expected 📦 99%, got: … 📦 100% …` and exit 1
(current `printf "%.0f"` rounds 99.56 up to 100).

---

### Task 4: Fix the hit-rate rounding (floor)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh:~224` (≈226 after Task 2 adds two lines; locate by the `HIT_RATE=` content inside the `CACHE_DISPLAY` block)
- Test: `tests/test_statusline_context_window.sh`

- [ ] **Step 1: Replace the `HIT_RATE` line**

Current code (inside the `CACHE_DISPLAY` block):

```bash
        HIT_RATE=$(awk "BEGIN {printf \"%.0f\", ($CACHE_READ * 100.0 / $HR_DENOM)}")
```

New code:

```bash
        # Floor, not round: 100% must mean a fully cached request.
        HIT_RATE=$(awk "BEGIN {printf \"%d\", int($CACHE_READ * 100.0 / $HR_DENOM)}")
```

- [ ] **Step 2: Run the test — expect PASS (all cases)**

Run: `./tests/test_statusline_context_window.sh`
Expected: `PASS test_statusline_context_window.sh`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh tests/test_statusline_context_window.sh
git commit -m "fix(statusline): floor cache hit-rate instead of rounding to 100%

printf %.0f rounded 99.5%+ up to a misleading 100% while writes were
non-zero (e.g. R457K/W2K). Use int() so 100% only appears for a fully
cached request.

🤖 Generated with Claude Code

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Verify in a live session + update docs

**Files:**
- Modify: iwiki domain `iclaude` (statusline page/section — via MCP tools, not files)
- Modify: `README.md` / `docs/README.ru.md` ONLY IF they document the statusline window mapping (check first)

- [ ] **Step 1: Live check against the real Fable session payload**

The statusline result cache holds real rendered lines. Clear this session's entry and re-render happens on the next Claude Code tick; or verify directly by replaying a real payload if one is logged:

```bash
rm -f /tmp/iclaude-sl-cache-*
```

Then read the fresh cache after the statusline updates (a few seconds inside a running iclaude session):

```bash
grep -l "Fable" /tmp/iclaude-sl-cache-* 2>/dev/null | head -1 | xargs cat
```

Expected: the Fable line shows `Σ <hundreds of K> ↓ | 📊 … (<double-digit>%)` with no `⚠️`, and `📦` ≤ 99% when W is non-zero. If no live Fable session is running, skip this step — the black-box test already covers the logic; note the skip in the final report.

- [ ] **Step 2: Check whether README documents the window mapping**

Run: `grep -in "context window\|200K\|1M" README.md docs/README.ru.md | head`
Expected: statusline sections describe segments, not per-model window sizes → no README change. If a hit describes the model→window mapping, update both files consistently (English in README.md, Russian in docs/README.ru.md).

- [ ] **Step 3: Update the iwiki `iclaude` domain**

Use the iwiki MCP tools (`wiki_status` → already bound; `wiki_list_pages`/`wiki_search "statusline"`). If a page covers the statusline, update its relevant `##` section via `wiki_update_page(domain="iclaude", slug=…, heading=…, new_body=…, source=".nvm-isolated/.claude-isolated/scripts/claude-statusline.sh")` describing: Claude Code always reports 200K; the script maps the real window by model name; Claude 5 family (fable/mythos/sonnet-5) → 1M; haiku → 200K; hit-rate is floored. If no page exists, create one with `wiki_write_page(domain="iclaude", slug="statusline", markdown=…, source=…)`. Then `wiki_lint` — expected: no broken `[[refs]]`, no orphan/stale flags for the statusline page.

- [ ] **Step 4: Run the full statusline-related test set (regression)**

```bash
./tests/test_statusline_context_window.sh
python3 -m pytest tests/test_statusline_cache.py -q 2>/dev/null || bash -n .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh
```

Expected: new test PASS; pre-existing cache test unaffected (it exercises the /tmp cache layer, untouched). `bash -n` is the syntax-check fallback if pytest is unavailable in the environment.

- [ ] **Step 5: Commit docs (only if Step 2/3 produced file changes)**

```bash
git add README.md docs/README.ru.md 2>/dev/null || true
git commit -m "docs: document statusline model-to-context-window mapping

🤖 Generated with Claude Code

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" || echo "nothing to commit — wiki-only update"
```

---

### Task 6: result check + PR into dev

- [ ] **Step 1: Confirm the stale copy is untouched (spec §4)**

Run: `git diff --stat dev -- .nvm-isolated/scripts/`
Expected: empty output (no changes under the stale scripts directory).

- [ ] **Step 2: Run `/check-chain result` on this plan** (reconciles the diff against plan/spec; writes `result_check:` into this frontmatter and closes the TODO row on OK)

- [ ] **Step 3: Push and open the PR**

```bash
git push
gh pr create --base dev --title "fix(statusline): 1M context window for Claude 5 family + cache hit-rate floor" --body "$(cat <<'EOF'
## Summary
- `detect_real_context_window()` now maps the Claude 5 family (Fable/Mythos/Sonnet 5) to the real 1M window — Fable sessions rendered `Σ 0 ↓ | 📊 228K (114%) ⚠️` against the false 200K fallback
- cache hit-rate is floored (`int()`), so `📦 100%` only appears for fully cached requests (was: 99.5%+ rounded up to 100%)
- new black-box regression test `tests/test_statusline_context_window.sh` (7 cases: Fable/Mythos/Sonnet 5/Opus/Haiku windows + hit-rate floor/full)

Spec: `docs/superpowers/specs/2026-07-02-statusline-fable-context-window-design.md` (check-chain: OK)

## Test plan
- [x] `./tests/test_statusline_context_window.sh` → PASS
- [ ] live Fable session shows a sane percent after statusline refresh

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed; base branch `dev`.

---

## Self-review (done at plan-writing time)

- Spec coverage: §1a/§2 → Tasks 1–2; §1b/§3 → Tasks 3–4; §5 (all 7 test cases) → Tasks 1+3; §4 (out of scope) → File structure note; §6 (delivery, docs) → Tasks 5–6. No gaps.
- No placeholders; every code step carries the exact code/commands.
- Consistency: test helper `run_sl` signature identical in Tasks 1 and 3; script path and line anchors match the spec.
