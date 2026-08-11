---
name: audit
description: Use when a loen loop stage — plan, act, check, or result — must be manually validated and gated. Mode-aware for delivery/repair/research/review; the manual re-validator. Inside loop-run this gating is automatic (hooks + verifier).
---

# loen:audit — manual loop stage validator

Invoke as `loen:audit <stage>` where `stage ∈ plan | act | check | result`. Resolve the
active topic from `docs/loen/current` (or a `status: active` `loop.yaml`) and read `mode`
from `loop.yaml`. Each stage returns `OK` / `needs_work`, and regenerates
`docs/loen/<topic>/audit.html` via `loen_artifacts.render_audit`.

Inside `loop-run` this gating happens automatically (the PreToolUse loop-gate/scope/tool/
permission hooks, the Stop evidence-gate, and the independent `verifier`). Use this skill for
a manual, human-driven re-check of a single stage.

## Stage checks (all modes)

- **plan** — `3_plan.md` has `## Steps` + `## Checks`; `loop.yaml` parses and passes
  `loen_artifacts.validate_run_contract` (approved, `plan_hash` matches, mode valid, usable
  `mutable_scope`, `quality_gates`, positive budget, `rollback_policy`). `verifier_isolation`
  must be `subagent` or `microvm`; for `microvm` validate the host with
  `scripts/verify_microvm.sh preflight docs/loen/<topic>/loop.yaml` — no silent downgrade.
  `needs_work` blocks act.
- **act** — `4_act.md` exists with `## Changed Paths`; the diff touches only `mutable_scope`
  and no `protected_scope` path (cross-check `scripts/guard_protected.sh`); the topic dir
  passes `scripts/check_layout.sh` (the deterministic net for Bash-written artifacts).
- **check** — `5_check.md` `## Result` is `PASS` (gates green) and
  `evidence/verifier-verdict.md` carries `VERDICT: APPROVE`. Dispatch the `verifier` per
  `verifier_isolation` (`microvm` → `scripts/verify_microvm.sh check`). `OK` iff gates green
  and verdict APPROVE.
- **result** — `7_result.md` `## Outcome` is `Done`, `5_check.md` is `PASS`, `evidence/` is
  non-empty. On `OK`: regenerate `audit.html` and mark the `docs/TODO.md` row
  (`Result: OK`, `Status: done`, `Closed: <today>`) keyed by `<topic>`.

## Mode notes

- **repair** — `quality_gates` include the originally-failing command; `check` confirms the
  regression test fails without the fix and passes with it (logged inversion evidence).
- **research** — `eval_command` non-empty; a `stop_conditions` `target:` line; for every
  `keep` the verifier re-runs `eval_command` to confirm the delta.
- **review** — a non-empty review scope (`context_sources`); findings in `5_check.md`, the
  disposition in `6_reflect.md`.

## Rules

- Never edit the artifacts you are judging. Never weaken a gate to pass.
- All writes land at canonical `docs/loen/<topic>/` paths; the report is `audit.html`.
