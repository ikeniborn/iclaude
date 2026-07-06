---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-02-statusline-fable-context-window-design.md
review:
  spec_hash: 6f903a264cfdff20
  last_run: 2026-07-02
  phases:
    structure:
      status: passed
    coverage:
      status: passed
    clarity:
      status: passed
    consistency:
      status: passed
  findings:
    - id: F-001
      phase: coverage
      severity: INFO
      section: "## 2. Fix 1 — model → window mapping (approved variant A: explicit list)"
      section_hash: 732f441ea89585a2
      fragment: "*fable*|*mythos*) known=1000000 ;;"
      text: "Маппинг *mythos* привязан к задаче T1 только косвенно (через корневую причину «вся линейка Claude 5 = 1M», §1)."
      fix: "Зафиксировать производность от корневой причины T1 и покрыть тестом."
      verdict: fixed
      verdict_at: 2026-07-02
    - id: F-002
      phase: clarity
      severity: INFO
      section: "## 5. Verification"
      section_hash: c3b2d74ba3548319
      fragment: "| Fable 1M | `Fable 5` | 228000 |"
      text: "Ветка *mythos* → 1M не имела кейса в таблице тестов §5."
      fix: "Добавлена строка Mythos 1M в таблицу §5."
      verdict: fixed
      verdict_at: 2026-07-02
---
# Statusline context window for Claude 5 family (Fable) — Design Spec

- **Topic:** `statusline-fable-context-window`
- **Date:** 2026-07-02
- **Status:** design approved (brainstorming, variant A + cache-percent fix); ready for implementation planning
- **Scope of this spec:** two point fixes in the active statusline script
  `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` plus a regression test.

---

## 1. Problem

1. **Fable shows a 200K context window instead of 1M.** Claude Code reports
   `context_window.context_window_size = 200000` for every model, so the script maps the real
   window by model name in `detect_real_context_window()` (line ~141). The `case` only knows
   `*haiku*`, `*opus*`, `*sonnet*` (with a 4.x version sub-case). The model name for Fable is
   `Fable 5` / `claude-fable-5` — no branch matches, so the function falls back to the reported
   200000. Observed result in a live Fable session:
   `Σ 0 ↓ | 📊 228K (114%) ⚠️` — remaining clamped to 0, percent above 100, false warning.
   The real window for the whole Claude 5 family (`claude-fable-5`, `claude-mythos-5`,
   `claude-sonnet-5`) is **1M input tokens** (verified via the claude-api reference skill /
   Models catalog); only Haiku 4.5 remains 200K.
   The same gap hits **Sonnet 5**: `Sonnet 5` matches the outer `*sonnet*` branch but no
   `4-x` version pattern, so it also falls back to 200K.
2. **Cache hit-rate segment shows a misleading `📦 100%`.** The hit rate
   `cache_read / (cache_read + cache_creation + uncached_input)` is formatted with
   `printf "%.0f"`, which rounds 99.5%+ up to 100 even when writes are non-zero
   (e.g. `📦 100% · R457K/W2K`). Observed on both Fable and Opus sessions.

Non-problem (verified against live Opus session data): the active-context source
`context_window.total_input_tokens` correctly reflects current window content
(cache_read + cache_creation + uncached input) — no change needed there.

## 2. Fix 1 — model → window mapping (approved variant A: explicit list)

In `detect_real_context_window()`:

```bash
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
```

- Existing `max(known, reported)` fallback and the non-numeric guard stay as is.
- Non-Claude router models (gemini/openai/ollama) still match nothing → reported value, as today.
- Rejected alternatives: (B) inverted default "everything except Haiku → 1M" — risks granting 1M
  to non-Claude router models without extra guards; (C) live Models API lookup — network +
  auth per statusline render, overkill.

Expected effect for the observed Fable session: `Σ 772K ↓ | 📊 228K (23%)`, no `⚠️`.

## 3. Fix 2 — cache hit-rate truncation

In the `CACHE_DISPLAY` block (~line 224), replace round-half-up with floor so 100% appears only
when the request was fully served from cache:

```bash
HIT_RATE=$(awk "BEGIN {printf \"%d\", int($CACHE_READ * 100.0 / $HR_DENOM)}")
```

`99.56% → 99%`; `100%` only when `cache_creation == 0 && uncached_input == 0`.

## 4. Out of scope

- The stale copy `.nvm-isolated/scripts/claude-statusline.sh` — not referenced by
  `settings.json` (`statusLine` points at `$CLAUDE_CONFIG_DIR/scripts/...` =
  `.claude-isolated/scripts/`); left untouched.
- `ACTIVE_TOKENS` / `used_percentage` logic — verified correct.
- Any refactor of the statusline script beyond the two hunks above.

## 5. Verification

Add `tests/test_statusline_context_window.sh` (bash, same style as existing `tests/*.sh`):
feed synthetic statusline JSON to the script with `ICLAUDE_SL_NO_CACHE=1` and assert on output.

| Case | model | total_input | expect |
|---|---|---|---|
| Fable 1M | `Fable 5` | 228000 | `(23%)` present, `⚠️` absent, `Σ 772K` |
| Mythos 1M | `Mythos 5` | 228000 | `(23%)` present (same root cause as Fable, see §1) |
| Opus regression | `Opus4.8` | 459000 | `(46%)` present |
| Sonnet 5 | `Sonnet 5` | 100000 | `(10%)` present |
| Haiku regression | `Haiku 4.5` | 100000 | `(50%)` present (200K window kept) |
| Cache floor | any | R=457K W=2K in=0 | `📦 99%` (not 100%) |
| Cache full hit | any | R=457K W=0 in=0 | `📦 100%` |

Manual check: restart statusline in a live Fable session, confirm `Σ`/`📊` values.

## 6. Delivery

- Branch `dev-fix-statusline-context-window` (based on `dev`), PR into `dev` — per project
  history (PR #72 pattern). No worktree (small change).
- Docs to update at implementation time: iwiki `iclaude` domain (statusline behavior),
  `README.md` / `docs/README.ru.md` only if they document the statusline window logic.
