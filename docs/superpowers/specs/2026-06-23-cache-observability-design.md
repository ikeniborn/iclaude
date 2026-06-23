---
chain:
  intent: null
review:
  spec_hash: 0ca5f95ab1a32493
  last_run: 2026-06-23
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  findings:
    - id: F-001
      phase: consistency
      severity: INFO
      section: "## Component 2 — SessionEnd cache report"
      section_hash: f86bf13eaf572175
      text: >-
        Illustrative report-shape mock (lines ~121-128) is internally
        inconsistent: cache-read 1.2M / (1.2M + 180k + 12k) = 86.2% which rounds
        to 86%, but the mock prints "(87%)". Cosmetic only — the two binding
        Success Criteria (#1=90%, #2=80%) are arithmetically correct against the
        hit_rate formula. Suggest changing the mock to 86% for consistency.
      verdict: fixed
      verdict_at: 2026-06-23
---

# Cache Observability for iclaude

**Date:** 2026-06-23
**Status:** Design approved, pending spec review
**Topic:** Surface Anthropic prompt-cache health (hit-rate, read/write split) in the iclaude statusline and an end-of-session report.

## Problem

Claude Code with Anthropic models uses prompt caching. A healthy cache (high
`cache_read` share) is the single biggest lever on input cost and latency, but
the user currently has no visibility into cache health:

- The statusline shows `📦 <read+write summed>` — a raw volume number that does
  **not** reveal hit-rate and does **not** separate cheap reads (0.1×) from
  expensive writes (1.25–2×). A prefix bust is invisible.
- There is no session-level summary of how well the cache performed.

## Cache mechanics (established facts)

These constrain the design — recorded so the implementation plan does not
re-derive them:

- **Cache key = exact prefix match:** `system prompt → CLAUDE.md/project context
  → conversation`. A HIT bills the matched prefix at ~0.1× input; a MISS rewrites
  it at 1.25× (5m TTL) or 2× (1h TTL).
- **Hooks that inject `additionalContext` do NOT bust the cached prefix** — they
  append to the conversation tail. So iclaude's existing injectors (iwiki-recall,
  caveman SessionStart, idd-nudge, UserPromptSubmit) are cache-safe. The premise
  "hooks hurt the cache" is largely false.
- **Real cache busters:** model switch, `/effort` change, `/compact`, MCP
  enable/disable, Claude Code upgrade, and idle longer than the TTL.
- **Hooks cannot** emit `cache_control` directives or warm the cache on a timer.
  They **can** read the transcript and surface metrics.
- **Metric source:** each `type:"assistant"` line in the session transcript
  `.jsonl` carries `message.usage.{cache_read_input_tokens,
  cache_creation_input_tokens, input_tokens, output_tokens}`. Claude Code also
  passes the current request's `context_window.current_usage.{cache_read,
  cache_creation, input}_tokens` and `transcript_path` on the statusline stdin.

## Goals

- Show **per-turn cache hit-rate %** and a **read/write split** in the statusline,
  replacing the uninformative summed `📦` number.
- Emit an **end-of-session report** with cumulative hit-rate and read/write split.

## Non-goals (YAGNI)

- No `$ saved` estimate (would require a per-model price table — deferred).
- No active cache warming / keep-alive pinger (wrapper-level, separate effort).
- No `/cache-report` on-demand command and no degradation warning hook.
- No change to cache TTL configuration.

## Architecture: A1 — two independent readers

Each surface reads the cheapest correct source; no shared state.

- **Statusline (per-turn):** computes hit-rate from `current_usage` already on
  stdin — zero extra I/O.
- **SessionEnd hook (cumulative):** scans the transcript `.jsonl` — accurate, no
  state file to maintain or drift.

Rejected alternatives:
- **A2 (stateful Stop-hook aggregate):** adds a per-session state file that
  duplicates and can drift from the transcript. More moving parts.
- **A3 (transcript scan everywhere):** statusline scans `.jsonl` on every render;
  heavier than reading `current_usage` for no benefit at the live surface.

**Per-turn tradeoff (accepted):** a single turn that reads a large file shows a
momentarily low hit-rate even when the cache is healthy. This is acceptable —
per-turn is exactly what best flags a `cache_creation` spike (prefix bust). The
steady cumulative picture is the job of the end-of-session report.

## Component 1 — Statusline cache segment

**File:** `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` (tracked
in git; this is the active, source-of-truth script. `lib/statusline/install.sh`
only installs it; `lib/statusline/status.sh` is an unrelated status checker.)

**Current** (~lines 197–216): `CACHE_DISPLAY=" | 📦 ${CACHE_FMT}"` where
`CACHE_FMT` formats `read + creation` summed.

**New:** `📦 87% · R1.2M/W12k`
- `hit_rate = read / (read + creation + input)`, rounded to integer percent.
- `R<read>` / `W<creation>` using the existing humanize helper (K/M suffix).
- Compute from `current_usage`: reads (`cache_read_input_tokens`), writes
  (`cache_creation_input_tokens`), uncached input (`input_tokens`). The one-shot
  jq parse (~lines 56–66) already extracts read and creation; **add
  `current_usage.input_tokens`** to it.
- Optional color thresholds **only if** the script already applies color to this
  segment: ≥80% green, 50–80% yellow, <50% red. If it does not, skip color to
  keep the change surgical.

**Edge cases:** when `read + creation + input == 0` (no usage yet), keep the
segment hidden (current behavior already hides on zero total).

## Component 2 — SessionEnd cache report

**New file:** `.nvm-isolated/.claude-isolated/hooks/cache-report.py` (Python
stdlib only, matching `block-secrets.py` / `redact-secrets.py` / `idd-*.py`).

**Registration:** add a `SessionEnd` entry in
`.nvm-isolated/.claude-isolated/settings.json` `hooks` running
`python3 "$CLAUDE_CONFIG_DIR/hooks/cache-report.py"`.

**Input:** hook stdin JSON → `transcript_path`, `session_id`.

**Logic:**
1. Read the `.jsonl` line by line; for each `type == "assistant"` line sum
   `message.usage.{cache_read_input_tokens, cache_creation_input_tokens,
   input_tokens, output_tokens}`.
2. `hit_rate = read / (read + creation + input)` (cumulative).

**Output (human-readable):**
- **Primary sink:** write the report to
  `$CLAUDE_CONFIG_DIR/logs/cache-report-<session_id>.txt` (always works; create
  `logs/` if absent).
- **Best-effort:** echo the report to `/dev/tty` if writable, so it prints in the
  terminal as the session closes. Never fatal if unavailable.

Report shape:
```
iclaude cache report — session <id>
  cache-read   1.2M tok   (86%)
  cache-write  180k tok
  uncached in  12k tok
  output       45k tok
  turns        37
```

## Component 3 — Data contract & failure modes

- Transcript `.jsonl` = canonical source for cumulative numbers;
  `current_usage` (statusline stdin) = per-turn live numbers.
- Missing / empty / unreadable transcript → report skipped silently, `exit 0`.
- `read + creation + input == 0` → render hit-rate as `n/a` (no division).
- Multiple models in one session → read/write split stays valid (token counts are
  model-agnostic; we report no per-model price, so no model lookup needed).
- **Fail-soft everywhere:** any error in the statusline edit or the hook must
  `exit 0` and never break the Claude Code UI, matching `block-secrets.py` and the
  statusline's existing `jq`-missing guard.

## Component 4 — Testing & docs

- **Hook test** (`tests/test_cache_report.py`, pytest style like
  `tests/test_patterns_examples.py`): feed a synthetic `.jsonl` with known
  `usage` values, assert computed hit-rate, read/write split, and turn count;
  assert graceful skip on a missing transcript path.
- **Statusline:** manual verification via `DEBUG_STATUSLINE=1` and a synthetic
  stdin JSON carrying `current_usage`; confirm `📦 NN% · R../W..` renders and that
  a zero-usage payload hides the segment.
- **Docs (post-task, via iwiki):** update `docs/wiki/statusline.md` and
  `docs/functions/STATUSLINE.md` through `iwiki:iwiki-ingest`; run `/iwiki-lint`.

## File inventory

| File | Change |
|------|--------|
| `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` | edit: hit-rate % + R/W split; add `input_tokens` to jq parse |
| `.nvm-isolated/.claude-isolated/hooks/cache-report.py` | new: SessionEnd cumulative report |
| `.nvm-isolated/.claude-isolated/settings.json` | edit: register `SessionEnd` hook |
| `tests/test_cache_report.py` | new: hook unit test |
| `docs/wiki/statusline.md`, `docs/functions/STATUSLINE.md` | update via iwiki (post-task) |

## Success criteria (verifiable)

1. Feed the statusline a synthetic stdin with `current_usage` of read=900,
   creation=50, input=50 → segment shows `📦 90% · R900/W50`.
2. Feed `cache-report.py` a synthetic `.jsonl` (read=1000, creation=200,
   input=50 across N assistant lines) → report file shows hit-rate `80%`,
   `cache-read 1000`, `cache-write 200`, `turns N`.
3. Point the hook at a non-existent transcript path → `exit 0`, no output, no
   error.
