---
chain:
  intent: null
---

# Design: IDD→SDD phase gates via `PreToolUse` Skill hook

**Date:** 2026-06-14
**Status:** draft

## Objective

The IDD→SDD chain (intent → spec → plan → result) has phased validators
(`check-intent`, `check-spec`, `check-plan`, `check-result`), but running them
is **manual and optional**. Nothing prevents advancing from one phase to the
next while the upstream artifact still has open CRITICAL findings — a spec can
hand off to planning unvalidated, a plan to implementation, an implementation
to merge.

This feature adds **hard gates**: a transition from one IDD→SDD skill to the
next is blocked until the upstream artifact has passed its validator (no open
CRITICAL). The gate is enforced by a single `PreToolUse` hook on the `Skill`
tool — the actual choke point of every phase transition.

## Three roles: hook gates, subagent validates, main session collects verdicts

Each role is matched to the only mechanism that fits it:

- **Gate = `PreToolUse` hook.** A gate must *block* a transition the main loop is
  about to make; a hook is the only thing that can deny a tool call. (An agent
  does work and returns — it cannot block the parent flow.) The hook never
  validates: it reads the upstream artifact's state, blocks (`exit 2`) or allows
  (`exit 0`).
- **Validation = subagent (clean context).** A validator reads a full document
  and runs multi-phase analysis — expensive context that should not pollute the
  main session, especially after a long brainstorming/planning conversation. A
  subagent starts with a fresh context window, so dispatching the check to a
  subagent gives clean-context validation **by construction — no `/clear`
  needed**. (Claude cannot invoke `/clear` itself: it is a built-in CLI command,
  excluded from the Skill tool. `/clear` would also destroy the very tasks
  `check-spec` needs and the orchestration state needed to resume — the subagent
  sidesteps both.)
- **Verdict collection = main session.** Resolving CRITICAL findings is
  interactive (the user chooses `accepted` / `wontfix` / `fixed`). A subagent
  runs autonomously and cannot conduct this round-trip, so verdicts are collected
  back in the main session — a small, cheap exchange (findings list + verdicts)
  that keeps the main context lean.

The hook never validates; the subagent never blocks and never asks for verdicts;
the main session never re-reads the full document. They communicate through the
doc's `review:` / `result_check:` frontmatter.

## Scope

In scope:

1. **`hooks/idd-gate.py`** — the `PreToolUse` Skill gate (the core new artifact).
2. **`commands/check-result.md`** — extended to stamp a machine-readable
   `result_check:` block into the plan frontmatter (the merge gate's pass signal).
3. **`settings.json`** — wire `idd-gate.py` as a `PreToolUse` hook with
   `matcher: "Skill"`.
4. **`CLAUDE.md`** — document the clean-context check-runner protocol (subagent
   validation + main-session verdicts) that the gate's block message references.

Out of scope (dependencies, not redefined here):

- **`/check-intent` command** — already designed in
  [2026-06-14-check-intent-design.md](2026-06-14-check-intent-design.md) and
  planned in
  [`../plans/2026-06-14-check-intent-command.md`](../plans/2026-06-14-check-intent-command.md).
  The intent→brainstorm gate depends on that command existing and writing the
  `review:` block it specifies. If `/check-intent` is not yet implemented when
  the gate ships, the intent gate degrades gracefully (see Edge cases).
- The internal logic of `check-spec` / `check-plan` — unchanged.

## Architecture

All artifacts live under `.nvm-isolated/.claude-isolated/` and survive plugin
cache updates (no edits to the plugin-owned `brainstorming` / `writing-plans`
skills).

| File | Type | Role |
|------|------|------|
| `hooks/idd-gate.py` | new | `PreToolUse` Skill gate: map skill → upstream artifact, evaluate predicate, allow / block |
| `commands/check-result.md` | edit | Append `result_check:` state to the plan frontmatter |
| `settings.json` | edit | New `PreToolUse` entry, `matcher: "Skill"` → `idd-gate.py` |
| `CLAUDE.md` | edit | Document the check-runner protocol (subagent validation + main-session verdicts) |

**Separation of concerns:** the hook is *only* a gate (block / allow, reads
state). The validators are *only* validation (write state). The hook never
validates; a validator never blocks flow. They communicate exclusively through
the `review:` (and, for result, `result_check:`) frontmatter.

**Hash parity (critical):** the hook MUST compute the document body hash with
the *same* canonical algorithm the validators use. To avoid implementation
drift, the hook **shells out to the identical bash pipeline** rather than
reimplementing it in Python:

```bash
awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
```

Guarantee: if `/check-X` would print `OK (cached, hash match)`, the gate is open.

## Gate predicate

For a candidate artifact file, the gate is **OPEN** (allow, `exit 0`) iff **(1)**
OR **(2)**:

**(1) Artifact absent** — no file matching the glob in the upstream dir → allow.
This is the chosen escape hatch ("gate only if the artifact exists"): a hotfix
with no IDD docs passes freely.

**(2) Artifact present AND validated:**

- frontmatter contains the expected state block (`review:` / `result_check:`),
  AND
- `<state>.<kind>_hash == current body hash` (recomputed via the pipeline), AND
- `∀ phase: status == passed` (for `review:`-based gates), AND
- `count(severity == CRITICAL ∧ verdict == open) == 0` (for `review:`-based
  gates), OR `result_check.verdict == OK` (for the merge gate).

Otherwise (present but: no state block / stale hash / open CRITICAL / a phase not
`passed`) → **BLOCK** (`exit 2`).

**What blocks:** only open `CRITICAL` findings block. Open `WARNING` / `INFO` do
not. This matches the validators' final verdict (`OK` = no open critical). It is
the single tunable: a constant `BLOCK_ON = {"CRITICAL"}` in the hook — add
`"WARNING"` to tighten.

**Advisory phases:** validators may carry advisory phases (e.g.
`check-intent`'s `alignment`) that never produce CRITICAL findings. Such a phase
still reaches `status: passed` on a completed run (its prior `passed` is trusted
on quick-exit), so `∀ phase: status == passed` holds without special-casing. The
hook treats only the literal value `passed` as passing and counts open CRITICAL
findings; it needs no knowledge of which phases are advisory.

## Skill → artifact map

The hook keys on the `Skill` tool's `tool_input.skill`. The name may be
namespaced (`superpowers:brainstorming`) or bare (`brainstorming`) — the hook
matches on the suffix after the last `:`.

| Intercepted skill | Upstream dir / glob | State block / hash key | Fix command |
|-------------------|---------------------|------------------------|-------------|
| `brainstorming` | `intents/*-intent.md` | `review` / `intent_hash` | `/check-intent` |
| `writing-plans` | `specs/*-design.md` | `review` / `spec_hash` | `/check-spec` |
| `executing-plans` | `plans/*-plan.md` | `review` / `plan_hash` | `/check-plan` |
| `subagent-driven-development` | `plans/*-plan.md` | `review` / `plan_hash` | `/check-plan` |
| `finishing-a-development-branch` | `plans/*-plan.md` | `result_check` / `plan_hash` | `/check-result` |

A skill not in the map → immediate `exit 0`.

## Candidate selection

The hook does not know the task topic at interception time. v1 heuristic: the
**most-recently-modified** file matching the glob in the upstream dir is the
candidate. At each transition the relevant artifact was just authored, so it is
the newest file:

- `brainstorming` invoked → newest `intents/*-intent.md`
- `writing-plans` invoked → newest `specs/*-design.md` (brainstorming just wrote it)
- `executing-plans` / `subagent-driven-development` → newest `plans/*-plan.md`
- `finishing-a-development-branch` → newest `plans/*-plan.md`

**Known limitation:** working on two topics in parallel can make the gate check
the wrong file. Documented; the refinement path (match `<topic>` via git branch
name or the `chain:` frontmatter) is deferred (YAGNI for v1).

## `idd-gate.py` logic

Input: stdin JSON `{tool_name, tool_input}`. Reads `tool_input.skill`.

1. Parse stdin. Normalize the skill name (suffix after the last `:`).
2. Skill not in `GATE_MAP` → `exit 0`.
3. Resolve the candidate file (newest match in the upstream dir). No file →
   `exit 0` (escape).
4. Read its frontmatter; compute the body hash via the bash pipeline (subprocess).
5. Evaluate the predicate. Open → `exit 0`. Blocked → print the reason to stderr,
   `exit 2`.

**Block message (stderr):**

```
🚧 IDD gate: <artifact_path> has not passed validation.
Reason: <no review: block | hash stale (edited after last check) | open CRITICAL: F-003, F-007 | phase coverage: in_progress>
Action: dispatch a subagent to run <fix_command> on <artifact_path> (clean-context
check-runner protocol), collect verdicts in the main session, resolve the CRITICAL
findings, then retry the skill invocation.
```

Claude reads stderr and follows the check-runner protocol (below): dispatch the
validation to a subagent, collect verdicts in the main session, then retry the
`Skill` call → the gate opens.

**Fail-open on hook errors (workflow-safety requirement):** any internal
exception (malformed stdin JSON, missing `docs/`, subprocess failure, unparseable
frontmatter) → `exit 0` + a diagnostic to stderr. The hard gate applies only to
the *known* unvalidated-artifact case. A bug in the hook must NOT block every
`Skill` invocation in the session. This is the opposite of `block-secrets.py`
(which fails closed on secrets — a different risk profile).

**Working directory:** the project root is the launch dir. The hook resolves
`docs/superpowers/<dir>/` relative to the current working directory (the project
root at launch), consistent with how the validators locate docs.

## Check-runner protocol (clean-context subagent)

When the gate blocks, the main session does **not** run the check inline. It
dispatches a subagent so the validation runs on a fresh context:

1. **Dispatch.** The main session calls the Agent tool with a prompt: read
   `commands/check-<X>.md` and execute its algorithm against `<doc_path>`; run
   all deterministic phases; compute hashes via the canonical bash pipeline;
   write the `review:` frontmatter block with any new findings as `verdict:
   open`; **do NOT request verdicts interactively** — instead return the findings
   (`id, phase, severity, section, text`) as structured output.
2. **Subagent runs on a fresh context** — it reads only the doc(s) it is pointed
   at, writes the `review:` block (and `result_check:` for `check-result`), and
   returns the findings. No brainstorming/planning bloat enters its context. This
   is the clean context the user asked for, achieved without `/clear`.
3. **Verdicts (main session).** If the subagent returns open CRITICAL findings,
   the main session presents them and collects verdicts. `accepted` / `wontfix` →
   written to the frontmatter (gate opens — the predicate counts only CRITICAL
   with `verdict == open`). `fixed` → the user edits the doc body (hash changes)
   → re-dispatch the subagent to re-validate.
4. **Retry.** The main session re-invokes the gated skill; the gate re-reads the
   now-passing state and allows the transition.

**Frontmatter ownership:** the subagent writes the full `review:` block (phases,
hashes, new findings as `verdict: open`); the main session only patches verdict
values. Writes are sequential (subagent finishes, then main edits) — no race.

**`check-spec` task source.** `check-spec`'s coverage phase compares the spec
against "tasks from the conversation" — the one input not derivable from the doc
alone, and unavailable to a fresh subagent. The main session therefore includes a
concise requirements/task summary in the dispatch prompt, or points the subagent
at the spec's `## Acceptance (from intent)` section (carried in by the intent
skill handoff). Extraction is cheap and stays in the main session; the expensive
full-doc analysis runs clean in the subagent.

**Subagent failure fallback.** If the subagent dies (terminal error) or returns
nothing, the main session falls back to running the check inline. A subagent
failure must not wedge the gate — it only loses the clean-context benefit for
that run.

The protocol is documented in `CLAUDE.md` (IDD→SDD section); the gate's block
message references it. The check-runner dispatch is **never gated** — it is not
one of the five transition skills, and it invokes Read/Bash/Edit (and the Agent
tool), never a gated `Skill`.

## `check-result.md` extension

`check-result` currently produces a read-only report with no machine-readable
state, so the merge gate has nothing to key on. Extend it: after the report step,
write a state block into the **plan** frontmatter (the plan is the durable anchor
of the chain). The plan body is not touched.

```yaml
result_check:
  verdict: OK | needs_work
  plan_hash: <body hash of the plan>
  last_run: <today>
```

Merge-gate predicate: `result_check.verdict == OK` AND `result_check.plan_hash ==
current plan body hash`. The gate is **not** tied to the git diff hash (too
volatile — any new commit would invalidate it). Known limitation: a
`result_check` that is stale relative to a newer diff still passes; acceptable
because `check-result` is run right before merge. `plan_hash` reuses the same
canonical body-hash pipeline.

## settings.json wiring

Append a new entry to the existing `PreToolUse` array (the current matchers
`Read|Edit|Write|MultiEdit|Bash` do not cover `Skill`):

```json
{
  "matcher": "Skill",
  "hooks": [
    { "type": "command", "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/idd-gate.py\"" }
  ]
}
```

## Edge cases

1. Skill not in `GATE_MAP` → allow.
2. No upstream dir / no matching file → allow (escape).
3. Internal hook exception → allow (fail-open) + stderr diagnostic.
4. The check-runner (subagent + verdict collection) never invokes a gated
   `Skill` — it uses Read/Bash/Edit and the Agent tool → no recursion / self-block.
5. Subagent dies / returns nothing → main session falls back to running the
   check inline (clean-context benefit lost for that run, gate not wedged).
6. Namespaced vs bare skill name → match on the suffix after the last `:`.
7. `/check-intent` not yet implemented: the newest intent doc has no `review:`
   block → by the predicate the gate would BLOCK `brainstorming`. To degrade
   gracefully until `check-intent` ships, the intent→brainstorm row keys on a
   `review:` block that only `check-intent` writes; if the dependency is absent,
   the operator either implements `check-intent` first (recommended ordering) or
   temporarily omits the `brainstorming` row from `GATE_MAP`. This ordering
   dependency is called out in the plan.
8. `BLOCK_ON = {"CRITICAL"}` — the single severity knob.

## Testing / acceptance

Hook unit tests follow the existing hook-test pattern (stdin JSON → exit code):

```bash
# skill not gated → exit 0
echo '{"tool_name":"Skill","tool_input":{"skill":"systematic-debugging"}}' \
  | python3 hooks/idd-gate.py; echo $?            # 0

# no artifact present → exit 0 (escape)
echo '{"tool_name":"Skill","tool_input":{"skill":"writing-plans"}}' \
  | python3 hooks/idd-gate.py; echo $?            # 0 when specs/ empty

# spec present without review: block → exit 2
#   (fixture: docs/superpowers/specs/<topic>-design.md, no review: frontmatter)
... | python3 hooks/idd-gate.py; echo $?          # 2

# spec passed (review: + hash match + no open CRITICAL) → exit 0
... | python3 hooks/idd-gate.py; echo $?          # 0

# namespaced skill name resolves → same result as bare
echo '{"tool_name":"Skill","tool_input":{"skill":"superpowers:writing-plans"}}' \
  | python3 hooks/idd-gate.py; echo $?

# malformed stdin → exit 0 (fail-open)
echo 'garbage' | python3 hooks/idd-gate.py; echo $?   # 0
```

Acceptance criteria:

1. `python3 -m py_compile hooks/idd-gate.py` passes.
2. A spec with an open CRITICAL finding blocks `writing-plans` (`exit 2`); after
   `/check-spec` resolves the finding, re-invoking `writing-plans` is allowed.
3. A plan stamped `result_check.verdict: OK` with a matching `plan_hash` allows
   `finishing-a-development-branch`; editing the plan body (hash drift) blocks it.
4. Removing the candidate doc (or an empty upstream dir) always allows the
   transition (escape verified).
5. A forced hook exception (e.g. unreadable frontmatter) results in `exit 0`, not
   a wedged session (fail-open verified).
6. End-to-end: a full intent → spec → plan run where each `/check-*` passes lets
   the chain proceed uninterrupted; skipping a check at any phase blocks the next
   skill until the check passes.
7. Check-runner: on a block, the validation runs in a dispatched subagent (fresh
   context — it reads only the target doc), the subagent writes the `review:`
   block and returns findings, and verdicts are collected in the main session.
   A simulated subagent failure falls back to an inline check without wedging the
   gate.
