---
name: audit
description: Use when a loen loop stage — plan, act, check, or result — must be validated and gated before the next one. Mode-aware for delivery/repair/research; the execution-loop analog of check-chain.
---

# loen:audit — loop stage validator + live report

Invoke as `loen:audit <stage>` where `stage ∈ plan | act | check | result`. Read the active
run from `docs/loen/current` and `mode` from its `loop.yaml`
(`delivery | repair | research`). Every stage returns a verdict `OK` / `needs_work`, gates
the next stage, and **regenerates `docs/loen/<run-id>/report.html`** (via the `html-report`
skill) plus appends to `state.md`.

## Stage checks (all modes)

- **plan** — `loop.yaml` parses; `objective` measurable; `mutable_scope`/`protected_scope`
  non-empty and disjoint; `quality_gates` non-empty; `budget` present; human approval
  recorded. `verifier_isolation`, when present, MUST be `subagent` or `microvm` — validate
  it AND the host capability with this plugin's
  `scripts/verify_microvm.sh preflight <run-dir>/loop.yaml` (resolved from the skill base
  dir): `microvm` on a host without KVM/Firecracker/images → `needs_work` with the
  script's "install microVM support or drop to `verifier_isolation: subagent`" hint. No
  silent downgrade at plan time. `needs_work` blocks Act.
- **act** — the latest `iterations/iter-NN/diff.patch` exists and touches only
  `mutable_scope`; no `protected_scope` path present (cross-check with this plugin's
  `scripts/guard_protected.sh` via the run's loop.yaml, resolved from the skill base dir);
  and the run dir passes this plugin's `scripts/check_layout.sh` — the deterministic net
  that catches any Bash-written non-canonical artifact that bypassed the PreToolUse hook.
- **check** — dispatch the verifier per the contract's `verifier_isolation` key
  (`subagent` when absent). `subagent` → dispatch the `verifier` subagent (isolated),
  exactly the MVP path. `microvm` → write the mode-specific checklist (the same text the
  subagent dispatch prompt would carry) to a temp file OUTSIDE the run dir, then run this
  plugin's `scripts/verify_microvm.sh check <run-dir> <iter-NN> <checklist-file>`
  (resolved from the skill base dir): it snapshots the tree, runs the verifier headless
  inside an iclaude Firecracker microVM, and writes the returned text to
  `iterations/iter-NN/verifier.md` unchanged — downstream consumers are agnostic to where
  the verdict was produced. A non-zero exit (VM boot/provision failure, silent host
  fallback, missing verdict, host-tree tripwire) → verdict `needs_work` quoting the
  script's failure log path — NEVER fall back to the in-session subagent; the human may
  edit the contract to `subagent` to proceed un-isolated. In both dispatch modes the
  verdict lands at `iterations/iter-NN/verifier.md`; confirm `gates.log` shows the gates
  ran. `OK` iff the verdict is APPROVE and gates are green.
- **result** — every plan step is done, gates green, verifier APPROVE across the final
  iteration. On `OK`: finalize `report.html`, ensure `pr-summary.md` exists, and mark the
  `docs/TODO.md` row (`Result: OK`, `Status: done`, `Closed: <today>`) keyed by `<topic>`.

## Mode: repair — additional checks

- **plan** — `quality_gates` include the failing command recorded in the Baseline section
  of `state.md` at bootstrap.
- **check** — when the diff claims a NEW/extended regression test, `gates.log` carries the
  worker's logged inversion evidence (stash the fix → the regression test FAILS → pop →
  it PASSES).
- **result** — regression coverage evidenced in the final diff: case (a) a new/extended
  test, or case (b) the originally-failing test itself — the verifier states which case
  applies; the originally-failing command exits 0; the diff is minimal (every non-test
  hunk required for that command to pass).
- **verifier dispatch prompt** carries the repair checklist: regression coverage case
  (a/b), validation of the LOGGED inversion evidence, minimal-diff confirmation. The
  verifier stays read-only — it never mutates the tree.

## Mode: research — additional checks

- **plan** — `eval_command` non-empty; EXACTLY ONE `metrics.primary` entry of the form
  `<name>:max` or `<name>:min`; `stop_conditions` carry one
  `target: <primary-name> <op> <number>` line (`<op>` ∈ `>=`/`<=` matching the direction)
  and only well-formed `tolerance: <name> regression <= <number>[%]` lines;
  `protected_scope` COVERS the eval assets (the `eval_command` script, eval datasets,
  ground truth) — non-empty alone is not enough.
- **check** — gates green (they run on every experiment);
  `iterations/iter-NN/metrics.jsonl` has exactly one `summary` line; `experiments.jsonl`
  has this iteration's record; for every `keep` decision the verifier RE-RUNS
  `eval_command` — exporting `LOEN_METRICS_PATH` to a throwaway temp path, never appending
  to canonical artifacts — and confirms the claimed delta. `revert` records are trusted
  as logged.
- **result** — kept changes are metric-backed (primary improved in its declared direction,
  secondaries within their stated tolerances) OR the budget is exhausted with a
  best-result report; the `experiments.jsonl` stream is consistent end-to-end with the
  per-iteration `metrics.jsonl` summaries.
- **verifier dispatch prompt** carries the research checklist: delta re-check via a
  throwaway `LOEN_METRICS_PATH`, stream cross-check (`experiments.jsonl` vs
  `metrics.jsonl`), protected eval assets untouched. The verifier stays read-only.

## report.html (every stage)

Invoke the `html-report` skill targeting `docs/loen/<run-id>/report.html` with: the
contract (`loop.yaml`), an iterations table (diff summary, gates pass/fail, verifier
verdict), metrics before/after — in research mode an experiments table (hypothesis,
before/after, delta, decision) — budget spend, current stage/verdict, and handoff
reasons. Self-contained, opens by double-click.

## Rules

- Never edit the diff you are judging. Never weaken a gate to pass.
- All writes land at canonical `docs/loen/<run-id>/` paths (the loop-guard hook enforces
  this); the report is `report.html`, nothing else.
