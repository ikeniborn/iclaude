---
chain:
  intent: null
review:
  spec_hash: 4efe4cc9a04e9765
  last_run: 2026-06-23
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: clarity
      severity: WARNING
      section: "Success criteria"
      section_hash: 408f3870e430f9b0
      text: >-
        Criterion #2 (statusline precedence) prescribes feeding stdin and
        observing the badge, but claude-statusline.sh caches its rendered
        output per session for 3s (/tmp/iclaude-sl-cache-${SESSION_ID},
        _SL_TTL=3, statusline :87-89). An immediate read after writing a
        suffix file may return a stale cached render. The acceptance test
        should bypass the cache (ICLAUDE_SL_NO_CACHE=1) or account for the TTL;
        otherwise the test is flaky. Status-quo behavior, but the DoD does not
        name the cache.
      verdict: fixed
      verdict_at: 2026-06-23
    - id: F-002
      phase: clarity
      severity: INFO
      section: "C3 — claude-statusline.sh (caveman block, :311-320)"
      section_hash: c79113ffe879e862
      text: >-
        "the extra ` · Σ110M` is ~8 chars; acceptable" asserts the badge
        survives the compact adaptive tier without stating the tier's width
        budget or where it is enforced. The claim is plausible but lacks a
        verifiable bound; consider citing the tier threshold or marking it as
        an assumption to validate at impl time.
      verdict: fixed
      verdict_at: 2026-06-23
---

# Design: session-scoped caveman token savings in statusline

**Date:** 2026-06-23
**Status:** draft
**Branch base:** `dev` → PR into `dev` (the `caveman-stats-stop.js` Stop hook this
design depends on lives on `dev`, not yet on `master`).

## Problem

The caveman statusline badge shows the **lifetime cumulative** token savings
summed across every session ever recorded — e.g. `⛏ 110.2M`. There is no
per-session figure, so the user cannot see how much the *current* session has
saved.

The cumulative number comes from `caveman-stats.js`, which on every Stop hook
recomputes the badge text from the lifetime history aggregate:

```js
// caveman-stats.js:326-328
const agg = aggregateHistory(historyPath, null);                 // ALL sessions
const suffix = agg.estSavedTokens > 0 ? `⛏ ${humanizeTokens(agg.estSavedTokens)}` : '';
safeWriteFlag(path.join(claudeDir, '.caveman-statusline-suffix'), suffix);
```

## Established facts

- **The per-session figure is already computed and then discarded.** Inside the
  same `if (parsed.turns > 0)` block, `caveman-stats.js:310` derives this
  session's savings before the cumulative aggregate is built:

  ```js
  // caveman-stats.js:310-311
  const { estSavedTokens, estSavedUsd } = deriveSavings({ ...parsed, mode });
  const sessionId = path.basename(sessionFile, '.jsonl');
  ```

  `estSavedTokens` here is the current session's savings; it is currently only
  appended to the history log, never surfaced to the badge.

- **The Stop hook refreshes the suffix every turn.** `caveman-stats-stop.js`
  (Stop hook, registered in `settings.json`) runs
  `caveman-stats.js --session-file <transcript_path>` after every assistant turn
  when `.caveman-active` exists. So the suffix file is rewritten each turn, not
  only on manual `/caveman-stats`. This hook exists on `dev`, **not** on `master`.

- **The statusline already knows the current session id.** `claude-statusline.sh`
  parses `.session_id` from stdin into `SESSION_ID` (jq read block, ~`:65`), and
  already uses it for its per-session render cache (`/tmp/iclaude-sl-cache-<id>`).

- **The suffix file is global.** `claude-statusline.sh:315` reads a single
  `$CLAUDE_CONFIG_DIR/.caveman-statusline-suffix`. With the cumulative number this
  is correct for everyone; for a session-scoped number a single global file would
  show one session's figure to all concurrent sessions.

- **Savings formula** (unchanged, in `deriveSavings` / `aggregateHistory`):
  `R = COMPRESSION[mode]` (`full = 0.65`; other modes `null` → 0 savings);
  `estNormal = round(output / (1 - R))`; `estSaved = estNormal - output`.
  Session output = this session's `outputTokens`; cumulative = sum of
  latest-per-session `est_saved_tokens` across the history log.

## Goal

Badge shows the **current session** savings first, the lifetime cumulative
second:

```
now:    ... | ⛏ 110.2M        | ...
target: ... | ⛏ 12k · Σ110M   | ...
                  ^session  ^cumulative (Σ marks the lifetime total)
```

Feasible by reusing the already-computed session figure and the existing Stop
hook — no new hook, no second formula.

## Architecture

Single source of truth stays in `caveman-stats.js` (one formula, JS). The
statusline remains a dumb reader that `cat`s a pre-rendered string. The only
structural change: the pre-rendered suffix becomes **per-session**, keyed by
`session_id`, so concurrent sessions don't clobber each other's figure. The
global file is retained as a cumulative-only fallback for the window before a
session's first Stop hook has run.

```
Stop hook ─► caveman-stats.js  (session_id from --session-file)
   ├─ estSavedTokens          (SESSION, :310 — already computed)
   ├─ agg.estSavedTokens      (Σ ALL, :326 — already computed)
   ├─► write .caveman-statusline-suffix-<session_id>  = "⛏ 12k · Σ110M"
   └─► write .caveman-statusline-suffix (global)       = "⛏ Σ110M"   (fallback)

claude-statusline.sh  (SESSION_ID from stdin)
   ├─ per-session file exists & non-empty? → use it
   ├─ else global file exists & non-empty? → use it      ("⛏ Σ110M")
   └─ else                                  → bare "⛏"
```

## Components

### C1 — `caveman-stats.js` (suffix block, `:322-328`)

Replace the single global cumulative write with a composed per-session string
plus a cumulative-only global fallback. Both inputs already exist in scope
(`estSavedTokens` from `:310`, `agg` from `:326`, `sessionId` from `:311`).

Compose (reusing `humanizeTokens`):

- `estSavedTokens > 0` → `⛏ ${humanizeTokens(estSavedTokens)} · Σ${humanizeTokens(agg.estSavedTokens)}`
- else `agg.estSavedTokens > 0` → `⛏ Σ${humanizeTokens(agg.estSavedTokens)}`
- else → `''`

Writes:

- `safeWriteFlag('.caveman-statusline-suffix-' + sessionId, composed)`
- `safeWriteFlag('.caveman-statusline-suffix', agg.estSavedTokens > 0 ? '⛏ Σ' + humanizeTokens(agg.estSavedTokens) : '')`
  — global stays cumulative-only, for the fallback path.

This block runs only inside `if (parsed.turns > 0)`; with 0 turns nothing is
written and the statusline falls back to the global file (status quo).

### C2 — `caveman-stats.js` (per-session file pruning)

Per-session suffix files accumulate in `$CLAUDE_CONFIG_DIR`. Prune on write
(no new hook): list `.caveman-statusline-suffix-*`, `unlink` any with `mtime`
older than 7 days. Wrapped in `try/catch`, never throws (a prune failure must not
break stats). Uses `Date.now()` (already used at `:313`).

### C3 — `claude-statusline.sh` (caveman block, `:311-320`)

Resolve the suffix with a two-file precedence, using the already-parsed
`SESSION_ID`:

1. if `SESSION_ID` is non-empty and `!= "unknown"`: try
   `$CLAUDE_CONFIG_DIR/.caveman-statusline-suffix-${SESSION_ID}`;
2. else / if missing or empty: try `$CLAUDE_CONFIG_DIR/.caveman-statusline-suffix`;
3. else: bare `⛏`.

The outer `[[ -f .caveman-active ]]` guard and the `tr -d '\n\r'` cleanup are
unchanged. Adaptive tiers select the caveman badge by **component membership,
not width-trimming** (`get_display_mode()`): it is included in the full (≥80
cols) and compact (40–79 cols) tiers and dropped only in minimal (<40 cols). The
added ` · Σ110M` therefore does not change whether the badge renders — it widens
the line but is not subject to per-component truncation (assumption to re-confirm
at impl time).

## Edge cases

- **New session before first Stop:** no per-session file yet → global fallback →
  `⛏ Σ110M`.
- **Mode with no benchmarked ratio** (lite/ultra/wenyan → `R` null → session
  savings 0): session part omitted → `⛏ Σ110M`. (Per-mode ratios are out of
  scope; unchanged.)
- **Both zero** (no history, nothing saved): empty suffix → bare `⛏` (badge still
  signals caveman active).
- **`SESSION_ID == "unknown"`** (statusline can't identify session): skip the
  per-session file, use global fallback.
- **Concurrent sessions:** each Stop hook writes its own
  `.caveman-statusline-suffix-<id>`; each statusline reads its own by
  `SESSION_ID`. The `Σ` cumulative part is identical across them (shared history).

## Success criteria

1. **Session figure rendered.** Run `caveman-stats.js --session-file <synthetic
   .jsonl>` with known `output_tokens` and `mode=full`; assert
   `.caveman-statusline-suffix-<id>` equals `⛏ <expected_session> · Σ<expected_cum>`
   with the expected `humanizeTokens` formatting.
2. **Statusline precedence.** Feed `claude-statusline.sh` stdin with
   `session_id=X` and `.caveman-active` present, **bypassing the 3 s per-session
   render cache** (`ICLAUDE_SL_NO_CACHE=1`; otherwise the cached line at
   `/tmp/iclaude-sl-cache-<id>` can return a stale badge and the test flakes):
   - per-session file present → badge shows its content;
   - per-session absent, global present → badge shows `⛏ Σ…`;
   - both absent → badge shows bare `⛏`.
3. **Concurrency.** Two session ids with different per-session files → each
   statusline shows its own session number and the shared `Σ`.
4. **Pruning.** A `.caveman-statusline-suffix-*` file with a >7-day-old mtime is
   removed on the next `caveman-stats.js` run; a fresh one is kept.
5. **Non-caveman session.** Without `.caveman-active`, the Stop hook exits early
   and writes no per-session file (status quo).

## Out of scope

- Per-mode compression ratios for lite/ultra/wenyan (still 0 until benchmarked).
- USD in the badge (tokens only, as today).
- Changing history aggregation semantics (latest-per-session) — unchanged.
- A SessionEnd cleanup hook (pruning is handled inline in C2).
- Porting `caveman-stats-stop.js` to `master` (separate in-flight work; this
  design targets `dev`).
