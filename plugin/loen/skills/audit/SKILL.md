---
name: audit
description: Validate a loen loop stage (plan|act|check|result), gate progression, and regenerate the human-readable docs/loen/<run-id>/report.html via the html-report skill. Mirrors check-chain for the execution loop.
---

# loen:audit — loop stage validator + live report

Invoke as `loen:audit <stage>` where `stage ∈ plan | act | check | result`. Read the active
run from `docs/loen/current`. Every stage returns a verdict `OK` / `needs_work`, gates the
next stage, and **regenerates `docs/loen/<run-id>/report.html`** (via the `html-report`
skill) plus appends to `state.md`.

## Stage checks

- **plan** — `loop.yaml` parses; `objective` measurable; `mutable_scope`/`protected_scope`
  non-empty and disjoint; `quality_gates` non-empty; `budget` present; human approval
  recorded. `needs_work` blocks Act.
- **act** — the latest `iterations/iter-NN/diff.patch` exists and touches only
  `mutable_scope`; no `protected_scope` path present (cross-check with this plugin's
  `scripts/guard_protected.sh` via the run's loop.yaml, resolved from the skill base dir);
  and the run dir passes this plugin's `scripts/check_layout.sh` — the deterministic net
  that catches any Bash-written non-canonical artifact that bypassed the PreToolUse hook.
- **check** — dispatch the `verifier` subagent (isolated); write its verdict to
  `iterations/iter-NN/verifier.md`; confirm `gates.log` shows the gates ran. `OK` iff the
  verdict is APPROVE and gates are green.
- **result** — every plan step is done, gates green, verifier APPROVE across the final
  iteration. On `OK`: finalize `report.html`, ensure `pr-summary.md` exists, and mark the
  `docs/TODO.md` row (`Result: OK`, `Status: done`, `Closed: <today>`) keyed by `<topic>`.

## report.html (every stage)

Invoke the `html-report` skill targeting `docs/loen/<run-id>/report.html` with: the
contract (`loop.yaml`), an iterations table (diff summary, gates pass/fail, verifier
verdict), metrics before/after (research mode), budget spend, current stage/verdict, and
handoff reasons. Self-contained, opens by double-click.

## Rules
- Never edit the diff you are judging. Never weaken a gate to pass.
- All writes land at canonical `docs/loen/<run-id>/` paths (the loop-guard hook enforces
  this); the report is `report.html`, nothing else.
