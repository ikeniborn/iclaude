---
chain:
  intent: null
---

# Design: session-scoped IDD gate

**Date:** 2026-06-22
**Status:** draft

## Problem

`idd-gate.py` blocks tool calls in sessions that never produced any IDD
artifact. Its candidate resolver is repo-global and session-agnostic:

```python
# idd-gate.py:77 resolve_candidate
matches = glob.glob(pattern)                 # every artifact across the repo
return max(matches, key=os.path.getmtime)    # newest, with no session scope
```

The gate therefore picks the single most-recently-modified artifact in the whole
`docs/superpowers/` tree, regardless of which session created it.

**Failure scenario.** Session A is mid-authoring a spec or plan (artifact not yet
validated). Session B — which created nothing IDD-related — does either:

- a code `Edit`/`Write` outside `docs/superpowers/` → the plan→impl branch calls
  `resolve_candidate(PLAN_RULE)`, finds Session A's fresh (<2h) unvalidated plan,
  and **blocks** Session B's unrelated edit;
- an invocation of a gated `Skill` (`writing-plans`, etc.) → `handle_skill` finds
  Session A's unvalidated artifact and **blocks**.

The plan→impl gate is the worst offender: it gates *every* non-docs file edit in
the repo whenever any fresh unvalidated plan exists anywhere.

The fix relies on `session_id`, which Claude Code passes in the hook stdin
payload for both PreToolUse and PostToolUse.

## Goals / Non-goals

**Goals**
- A session is gated only by IDD artifacts it owns (created, edited, or claimed
  for implementation). A session that owns no artifact in a category passes
  through (escape).
- Preserve the existing IDD→SDD enforcement *within* the session doing the work.

**Non-goals**
- No change to validation logic (`/check-*`), to the `review:`/`result_check:`
  frontmatter protocol, or to fail-open semantics.
- No change to `idd-nudge.py`: a PostToolUse nudge only fires for the very
  session that performed the Write, so it is already session-correct.

## Architecture

The change is concentrated in `idd-gate.py`. The gate stops being global. On each
invocation it does two things:

1. **Record** — if the tool touches an IDD artifact (or is a claim-Skill), stamp
   ownership of that artifact for the current `session_id` in a ledger.
2. **Evaluate** — resolve the gated candidate only among artifacts owned by the
   current session. No owned candidate → gate open (escape).

`idd-nudge.py` is left unchanged.

## Components (all inline in `idd-gate.py`, no new module)

### Ownership ledger

File: `$CLAUDE_CONFIG_DIR/state/idd-sessions.json`

```json
{ "docs/superpowers/plans/X.md": { "session": "<sid>", "ts": 1750000000 } }
```

- `load()` → `{}` on missing/corrupt JSON (fail-open). On load, prune entries
  whose artifact file no longer exists, plus a 7-day max-age backstop.
- `record(path, sid)` — last-writer-wins. Atomic write (temp file + `os.replace`).
  Any write error is swallowed (recording is best-effort).
- `owns(path, sid)` — `ledger.get(path, {}).get("session") == sid`.

If `CLAUDE_CONFIG_DIR` is unset the ledger is unreachable → every session owns
nothing → all gates open (consistent fail-open). In this repo the variable is
always exported before launch.

### Ownership-recording points (start of `main`, before gate logic)

- `Write` | `Edit` | `MultiEdit` on a file under
  `docs/superpowers/{intents,specs,plans}/` matching its glob → `record(path, sid)`.
- `Skill` = `executing-plans` | `subagent-driven-development` → **claim**:
  `record(<globally newest plan>, sid)`, so a session implementing a plan it did
  not author is still gated by it. Limitation: the Skill payload carries no plan
  path, so claim targets the globally newest plan — ambiguous only under two
  concurrent features; documented, accepted.

## Scoped resolution

`resolve_candidate(rule, sid)` — filter glob matches to those satisfying
`owns(m, sid)`, return the newest; `None` if none owned (escape).

Per-transition nuances:

- **spec→plan** (`handle_write`, Write of a plan): `chain.spec` (an explicit
  reference in the body of the plan being written) stays authoritative — it is
  session-local by construction. Only the fallback "newest spec" is scoped.
- **plan→impl** (`handle_write`, edit outside docs): `resolve_candidate(PLAN_RULE,
  sid)` among owned plans; the existing `fresh()` 2h window is retained as a
  secondary guard.
- **Skill gate** (`handle_skill`): same scoped resolution.
- Missing `session_id` → `owns` is always False → escape (fail-open).

## Data flow

```
PreToolUse → main:
  parse { session_id, tool_name, tool_input }
  record_ownership_if_applicable(sid)        # ledger written (best-effort)
  evaluate gate via resolve_candidate(rule, sid)
  → exit 2 (block) | exit 0 (allow)
```

## Error handling

- All logic stays under the existing top-level `try/except` → fail-open.
- Corrupt/missing ledger → `{}` → owns-nothing → escape.
- Concurrent ledger writes: `os.replace` is atomic; a lost update merely drops one
  ownership entry → that gate opens (fail-open), never a crash.

## Testing (`tests/test-idd-gate.sh`)

Payload helpers gain a `session_id` field; the ledger is seeded in a temporary
`state/` directory. New cases:

- **Bug regression**: Session B edits code; a fresh unvalidated plan owned by
  Session A exists → expect **0** (previously 2).
- Same session owns the unvalidated plan and edits code → **2**.
- No `session_id` → **0**.
- Claim: `executing-plans` by a session owning no plan, newest plan unvalidated →
  claim → **2**; newest plan validated → **0**.
- Prune: an entry for a deleted artifact is ignored.

## Scope estimate

~60–80 lines added to `idd-gate.py` plus the test extension. No new files beyond
the runtime ledger.
