---
review:
  spec_hash: bd526fc2f6b04dd4
  last_run: 2026-06-15
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: clarity
      severity: INFO
      section: Triggers — dispatch by `(tool, path)`
      section_hash: 1e607295faa0c2c8
      text: >-
        The plan→impl trigger is labeled "code edit", but the actual rule matches
        any path outside docs/superpowers/ (README, lat.md/, config files
        included). "Code" is a slight misnomer for "non-artifact file"; consider
        renaming for precision.
      verdict: fixed
      verdict_at: 2026-06-15
chain:
  intent: null
---

# Design: gate spec→plan and plan→impl via artifact-write triggers

**Date:** 2026-06-15
**Status:** draft

## Objective

`hooks/idd-gate.py` is a `PreToolUse` hook on the `Skill` tool. It reliably
blocks the **intent→spec** transition (the user types `/brainstorm`, a guaranteed
`Skill` invocation). It does **not** block **spec→plan** or **plan→impl**: those
transitions happen inline — the model continues writing the plan, then the code,
without issuing a separate `Skill` call. With no `Skill` event, a `PreToolUse`
`Skill` hook physically cannot fire.

The candidate-selection logic is not the problem. The fix is to **change the
interception point**: gate on the action the model performs even inline — the
**write of the downstream artifact**:

- spec→plan = the model writes the plan file → `Write` into `docs/superpowers/plans/*.md`.
- plan→impl = the model writes code → `Write`/`Edit` into a path outside `docs/superpowers/`.

## Approach

Single hook, tool-aware dispatch (chosen over a separate hook + shared lib, and
over soft "force a `Skill` call" reinforcement). The gate predicate is identical
across transitions ("has the upstream artifact passed validation?"); only the
**trigger** differs. Keeping one file means one predicate, zero duplication, and
the existing `evaluate_gate` / `body_hash` / `read_frontmatter` helpers are reused
as-is.

The `Skill` triggers stay (belt-and-suspenders for the case where a `Skill` call
*is* made). The `Write`/`Edit` triggers are the reliable path for the inline case.

## Triggers — dispatch by `(tool, path)`

| Transition | Trigger | Upstream check | Fix command |
|---|---|---|---|
| (existing) | `Skill` in `GATE_MAP` | existing `GATE_MAP` row | unchanged |
| **spec→plan** | `Write` into `docs/superpowers/plans/*.md` (plan creation) | parse the written content's frontmatter → `chain.spec` → validate that exact spec (fallback: newest spec) | `/check-spec` |
| **plan→impl** | `Write`/`Edit`/`MultiEdit` into a **non-artifact path** (any path outside `docs/superpowers/`) | newest plan, **recency-gated**: if plan mtime older than `IMPL_GATE_FRESH_SECONDS` (default 2h) → allow; else evaluate the plan predicate | `/check-plan` |

**"Non-artifact path"** means any file outside `docs/superpowers/` — source code,
but also `README`, `lat.md/`, config files, etc. Editing any of them counts as
entering implementation. (Earlier drafts called this "code edit"; the rule has
always been path-based, not language-based.)

Non-transition writes pass through (`exit 0`):

- `Edit`/`MultiEdit` of an existing plan (checkbox ticks `[ ]→[x]`, refinement) —
  spec→plan triggers on `Write` (creation) only, never on `Edit`.
- Writes into `docs/superpowers/specs/` or `docs/superpowers/intents/` — not a
  gated transition here (intent→spec stays on the `Skill` gate, which works).
- The check-runner subagent's writes land in `docs/superpowers/` (the `review:` /
  `result_check:` blocks) → never matched by the plan→impl code trigger. No
  self-block, no recursion.

## Candidate resolution

- **spec→plan:** the hook has the full plan content in `tool_input.content`. Parse
  its frontmatter `chain.spec` (a path like `docs/superpowers/specs/<x>-design.md`).
  If present and the file exists → that is the candidate spec (topic-accurate, no
  mtime guessing). Otherwise fall back to the newest `specs/*-design.md`.
- **plan→impl:** newest plan by mtime (topic-blind — see Known limitations),
  bounded by the recency window so only an *actively-worked* unvalidated plan
  gates code edits.

`fresh(path, seconds)` = `time.time() - os.path.getmtime(path) <= seconds`. The
hook is a plain `python3` process, so wall-clock is available.

## Latent bug fixed in passing: plan glob

`GATE_MAP` resolves plans with the glob `*-plan.md`, but plan files are named
inconsistently (`*-command.md`, `*.md`, only a couple end in `-plan.md`).
Measured: **2 of 37** plan files match `*-plan.md`. The `plans/` directory holds
only plans, so the correct glob is `*.md`. Fix it in both the new write-trigger
code and the existing `GATE_MAP` plan rows (`executing-plans`,
`subagent-driven-development`, `finishing-a-development-branch`). Specs
(`*-design.md`) and intents (`*-intent.md`) are uniform — left unchanged.

## Invariants preserved

- **Fail-open** on any internal exception → `exit 0` + stderr diagnostic. The hook
  now runs on **every** `Write`/`Edit`, so the common case (write is not into
  `plans/`, or no fresh unvalidated plan) MUST take a fast `exit 0` path. A bug in
  the gate must never block routine editing. Opposite of `block-secrets.py`
  (fail-closed).
- **Escape hatch:** no upstream artifact (empty/absent dir, or no `chain.spec`
  target and no spec at all) → `exit 0`.
- **Hash parity:** the same canonical bash pipeline
  (`awk … | sha256sum | cut -c1-16`); no Python reimplementation.
- `evaluate_gate` (state block present, hash match, all phases `passed`, no open
  CRITICAL) reused unchanged. `BLOCK_ON = {"CRITICAL"}` remains the single knob.
- **Check-runner protocol** (subagent validates on a fresh context → main session
  collects verdicts → retry) unchanged. The block message names `/check-spec` or
  `/check-plan` and points at the resolved artifact.

## Hook logic (additions)

```
main():
  data = parse stdin                      # malformed → exit 0
  tool = data.tool_name
  if tool == "Skill":            handle_skill(data)   # existing path, unchanged
  elif tool in {Write,Edit,MultiEdit}: handle_write(data, tool)
  else: exit 0

handle_write(data, tool):
  path = tool_input.file_path             # missing → exit 0
  if tool == "Write" and path under docs/superpowers/plans/ and *.md:
      spec = resolve_spec_from_chain(tool_input.content) or newest spec
      if spec is None: exit 0             # escape
      gate on spec (SPEC rule) → /check-spec
      return
  if path not under docs/superpowers/:    # code edit
      plan = newest plan (glob *.md)
      if plan is None: exit 0             # escape
      if not fresh(plan, IMPL_GATE_FRESH_SECONDS): exit 0   # stale draft
      gate on plan (PLAN rule) → /check-plan
      return
  exit 0                                  # specs/intents edits, plan checkbox edits
```

`SPEC rule` / `PLAN rule` reuse the existing `GATE_MAP` dicts (block `review`,
hash keys `spec_hash` / `plan_hash`).

## settings.json wiring

Widen the existing `idd-gate` matcher from `"Skill"` to
`"Skill|Write|Edit|MultiEdit"` (one entry). `block-secrets.py` and
`redact-secrets.py` already run on `Write|Edit` — three PreToolUse hooks on those
tools is fine; all are fast Python and fail-open/independent.

## Testing / acceptance

Extends the existing stdin-JSON → exit-code hook test pattern:

```bash
# spec→plan: writing a plan whose chain.spec is unvalidated → 2
# spec→plan: chain.spec validated → 0
# spec→plan: no chain.spec, newest spec unvalidated → 2 ; validated → 0
# plan→impl: code edit + fresh unvalidated plan → 2
# plan→impl: code edit + stale (>N) unvalidated plan → 0
# plan→impl: code edit + validated plan → 0 ; no plan → 0
# non-transition: Edit of an existing plan (checkbox) → 0
# glob fix: an unvalidated *-command.md plan now resolves (was missed by *-plan.md)
# malformed stdin → 0 (fail-open)
```

Acceptance:

1. `python3 -m py_compile hooks/idd-gate.py` passes.
2. Writing a plan whose upstream spec has an open CRITICAL blocks the `Write`
   (`exit 2`); after `/check-spec` resolves it, re-writing the plan is allowed.
3. A code edit while a freshly-created unvalidated plan is newest blocks
   (`exit 2`); after `/check-plan` passes, code edits flow.
4. A code edit while the newest unvalidated plan is older than the recency window
   is allowed (no false block on unrelated work).
5. Editing an existing plan (checkbox tick) is never gated.
6. The plan glob fix: a plan file not ending in `-plan.md` is now a valid
   candidate.
7. A forced hook exception results in `exit 0` (fail-open verified); the `Skill`
   path is unchanged.

## Known limitations (documented)

- **plan→impl is topic-blind** (keys on the newest plan), mitigated by the recency
  window so only active work gates code edits.
- **Bash file writes bypass the gate**: `cat > file`, `sed -i`, heredocs do not
  go through the `Write`/`Edit` matcher. Out of scope for v1 (parsing arbitrary
  Bash for file targets is fragile).
- **Recency window is a speed-bump, not a vault**: an unvalidated plan older than
  `IMPL_GATE_FRESH_SECONDS` can be implemented without validation. Consistent with
  the hook's fail-open philosophy.
- **git operations can reset mtime**, making an old plan look fresh (or a fresh one
  stale). Minor; acceptable.
