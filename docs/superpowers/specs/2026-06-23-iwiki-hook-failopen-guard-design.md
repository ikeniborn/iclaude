---
review:
  spec_hash: da0a6658f79adc61
  last_run: 2026-06-23
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: clarity
      severity: INFO
      section: Overview
      section_hash: 7d6abc3233ef8a64
      text: >-
        "a tiny inline POSIX guard" — "tiny" is a descriptive adjective, not a
        measurable criterion. Non-blocking: the guard itself is fully specified
        verbatim (exact shell string in "The fix", JSON-escaped form in "Files
        changed") with a complete per-case behaviour table, so nothing is left
        ambiguous about what gets built.
      verdict: open
      verdict_at: null
chain:
  intent: null
---
# iwiki plugin hooks: fail-open guard against a missing/unrunnable hook script

## Overview

The iwiki plugin registers five hooks in `plugin/iwiki/hooks/hooks.json`, each a
`python3 "${CLAUDE_PLUGIN_ROOT}/hooks/<script>.py"` command. When a hook's script
file is **absent or cannot start**, the command exits non-zero before the script's
own fail-open logic can run. For the `PreToolUse` hook (`iwiki-validate.py`) that
means **every** `Write`/`Edit`/`MultiEdit` is blocked, because `python3 missing.py`
exits `2` and an exit code of `2` from a `PreToolUse` hook tells Claude Code to
block the tool call.

This spec wraps each of the five hook commands in a tiny inline POSIX guard that
makes a missing/crashing script **fail open** (allow the operation) while
preserving a script's intentional `exit 2` (a real block) and its stdout-based
decisions. The only file changed is `hooks.json`.

## Background — root cause (verified)

- **Where the hooks live.** `plugin/iwiki/hooks/hooks.json` registers:
  `iwiki-bootstrap.py` (`SessionStart`), `iwiki-recall.py` (`UserPromptSubmit`),
  `iwiki-validate.py` (`PreToolUse`, matcher `Write|Edit|MultiEdit`),
  `iwiki-reindex.py` (`PostToolUse`, same matcher), `iwiki-sync.py` (`Stop`).
- **The blocking mechanism is precise.** `python3` exits with code `2` when the
  target file does not exist (`can't open file '...': No such file or directory`).
  Claude Code treats a `PreToolUse` exit code of `2` as "block the tool call". The
  validator *also* uses `exit 2` deliberately for a real section-formation
  violation — the two collide.
- **The script's internal fail-open is unreachable when the file is gone.**
  `iwiki-validate.py` wraps its logic in `try/except` and returns `0` on any
  internal error (and a prior fix guarded the `iwiki_common` import). But if the
  **file itself** is missing, Python never loads it — exit `2` happens at
  interpreter start, upstream of all that.
- **How the file disappears.** `plugin/iwiki/hooks/__pycache__/` is git-ignored
  (`.gitignore` line `__pycache__/`); the `.py` files are tracked.
  `iwiki-validate.py` was added in commit `5cc56eb1` and exists only on the `dev`
  lineage (`dev`, `dev-cache-observability`); it is **absent** on `master`,
  `iwiki-phaseb`, `feat/lat-integration`, and `test`. A checkout/switch to a branch
  without the file removes the tracked `.py` while the ignored `__pycache__/`
  survives — exactly the reported symptom ("only `__pycache__/` left"). Claude Code
  caches the hook config at `SessionStart`, so after such a switch every edit in
  the session invokes the now-missing script → exit `2` → all editing blocked
  (the matcher is `Write|Edit|MultiEdit`, not scoped to `docs/wiki/`, so the blast
  radius is *all* edits, not just wiki pages).
- **Latent siblings.** `iwiki-recall.py` (`UserPromptSubmit`) would block prompt
  submission, and `iwiki-sync.py` (`Stop`) would block stop, under the same
  missing-file condition. `iwiki-reindex.py` (`PostToolUse`) and
  `iwiki-bootstrap.py` (`SessionStart`) are non-blocking-on-failure but share the
  fragility.
- **Sibling exit/stdout semantics (verified).** Only `iwiki-validate.py` ever
  returns `2`. The other four always `return 0`; `bootstrap`, `recall`, and `sync`
  communicate via **stdout JSON** (`hookSpecificOutput`, a printed nudge, and
  `{"decision":"block",...}` respectively) with exit `0`. The guard preserves all
  of this because it passes stdout through untouched and only remaps the exit code.

## The fix

Replace each `command` value in `hooks.json` with the same inline guard, varying
only the script name. Shell form (shown unescaped for readability):

```sh
f="${CLAUDE_PLUGIN_ROOT}/hooks/iwiki-validate.py"; [ -f "$f" ] || exit 0; python3 "$f"; [ $? -eq 2 ] && exit 2 || exit 0
```

Behaviour:

| Script state | Command exit | Effect |
|---|---|---|
| file missing | `0` | allow (no-op) |
| present, real violation (python `exit 2`) | `2` | block — preserved |
| present, crash (syntax err `1`, no `python3` `127`, etc.) | `0` | allow |
| present, normal (`exit 0`, optional stdout JSON) | `0` | allow; stdout passed through |

The `[ -f "$f" ] || exit 0` short-circuits *before* invoking Python, so the
`python3`-missing-file `exit 2` is never reached and never collides with the
validator's intentional `exit 2`. The final `[ $? -eq 2 ] && exit 2 || exit 0`
maps **only** `exit 2` to a block; any other non-zero (a crash) becomes allow.

The guard is applied **uniformly to all five** hooks. For the four that never
return `2`, the guard is transparent — it only adds the missing-file fail-open. It
**complements**, not replaces, each script's internal `try/except` fail-open
(defense in depth: the guard covers "file gone / interpreter won't start"; the
internal handler covers "started, then errored mid-logic").

### Why inline (not a shared wrapper)

A shared `run-hook.sh` would be DRYer but is itself a tracked file that vanishes on
a branch switch exactly like `iwiki-validate.py` did — reintroducing the same class
of bug. The inline guard lives entirely in `hooks.json`, which **must** exist for
any hook to be registered at all. Nothing additional can go missing. The cost is
the one-line guard repeated five times, each naming a different script.

## Files changed

- `plugin/iwiki/hooks/hooks.json` — the five `command` string values only.
  Everything else (matchers, timeouts, structure, the five `.py` scripts) is
  untouched. JSON escaping of the inner quotes follows the current file
  (`\"$f\"`, `\"${CLAUDE_PLUGIN_ROOT}/...\"`).

JSON-escaped form of one command (as it appears in `hooks.json`):

```
"f=\"${CLAUDE_PLUGIN_ROOT}/hooks/iwiki-validate.py\"; [ -f \"$f\" ] || exit 0; python3 \"$f\"; [ $? -eq 2 ] && exit 2 || exit 0"
```

The five scripts, in file order: `iwiki-bootstrap.py`, `iwiki-recall.py`,
`iwiki-validate.py`, `iwiki-reindex.py`, `iwiki-sync.py`.

## Verification

1. **JSON validity** — `python3 -m json.tool plugin/iwiki/hooks/hooks.json`
   parses without error.
2. **Guard unit behaviour** — run the guard string directly in a shell (simulating
   Claude Code's invocation), three cases:
   - point `$f` at a non-existent path, pipe a `Write` payload on stdin → exit `0`;
   - point `$f` at the real `iwiki-validate.py`, pipe a `docs/wiki/` `Write` whose
     content has a `###` deep heading → exit `2`;
   - same but a well-formed page → exit `0`.
3. **Original-bug repro** — rename `iwiki-validate.py` aside; the guarded command
   returns exit `0` (pre-fix it returned `2`); restore the file.
4. **Shell-expansion sanity** — confirm the runtime shell parses `$f` and `$?`
   (Claude Code substitutes only `${CLAUDE_PLUGIN_ROOT}`; `$f`/`$?` must reach the
   shell literally).

Note: the *live* session uses the hook config cached at its `SessionStart` from the
active `CLAUDE_PLUGIN_ROOT`; the in-session effect of the new `hooks.json` requires
a session restart / plugin reload. Verification therefore exercises the guard at
the shell level (deterministic, reload-independent) rather than relying on
re-triggering the installed hook mid-session.

## Scope / non-goals

- **Not** fixing *why* the `.py` disappears (branch switch leaving `__pycache__/`).
  That is git hygiene and is independent; the guard makes the hooks resilient
  regardless of cause. (Optional future follow-up, not in this change.)
- **Not** changing the validator's blocking logic, regexes, or kill switch
  (`IWIKI_VALIDATE_SECTIONS`).
- **Not** touching `settings.json` hooks (`block-secrets.py`, `redact-secrets.py`,
  IDD gate) — a separate hook contour under `.claude-isolated/`.

## Branch / PR

- Branch `dev-fix-iwiki-hook-failopen` (dash, not slash: the existing `dev` branch
  occupies the `refs/heads/dev` name and blocks a `dev/` namespace), created from
  up-to-date `origin/dev`.
- Worktree `iclaude.worktrees/dev-fix-iwiki-hook-failopen`.
- PR opened against `dev`.
