---
name: loop-autoresearch
description: Use when improving ONE numeric metric under a controlled research loop with a fixed eval and kept/reverted experiments. Not for a feature (use loop-delivery) or a failing test (use loop-repair).
---

# Loop AutoResearch (mode: research)

Improve ONE numeric metric through the cycle
`baseline → hypothesis → one bounded change → fixed eval → compare → keep/revert`.
You are the **worker** and the **only writer**. This skill is a specialization of
`loop-delivery`: same run layout, contract, audit gates, subagents, and hook. Shared
templates live at `<skill-base>/../loop-delivery/assets/` (single source — never copy).

## Bootstrap + contract

1. **Bootstrap** — identical to `loop-delivery` steps 1–3, with these deltas:
   - `mode: research` in `loop.yaml`.
   - The loop starts from a **clean committed tree** — uncommitted user changes → stop
     and ask (as MVP).
   - The `planner` dispatch prompt MUST instruct: fill `eval_command` (the fixed eval
     command that appends JSONL to `$LOEN_METRICS_PATH`); exactly ONE `metrics.primary`
     entry of the form `<name>:max` or `<name>:min`; a direction (`<name>:max|min`) on
     every `metrics.secondary` entry; one `target: <primary-name> <op> <number>` line
     (`<op>` ∈ `>=`/`<=` matching the direction) and `tolerance: <name> regression <=
     <number>[%]` lines in `stop_conditions`; the eval assets (eval script, datasets,
     ground truth) into `protected_scope`; `budget.max_experiments`; block-style YAML
     scope lists (`guard_protected.sh` parses block-style only).
2. **Eval-contract compliance is a pre-loop responsibility.** `eval_command` MUST append
   JSON Lines to `$LOEN_METRICS_PATH`: free typed events plus exactly one authoritative
   line `{"type": "summary", "metrics": {"<name>": <number>, ...}}`. Adapting an existing
   eval happens BEFORE contract approval — the sanctioned adapter is a thin wrapper
   command living OUTSIDE `protected_scope`; the real eval script and data stay protected.
3. **Human approval gate**, then **`loen:audit plan`** — must return `OK` (research plan
   checks: see Hard rules).

## Cycle (one experiment = one `iter-NN`; `max_iterations` is ignored in research mode)

4. **Baseline (`iter-00` — reserved; experiments start at `iter-01`).** BEFORE any change:
   `export LOEN_METRICS_PATH=docs/loen/<run-id>/iterations/iter-00/metrics.jsonl`, run
   `eval_command` once. It MUST exit 0 and yield exactly one `summary` line — this run IS
   the eval-contract compliance check; otherwise STOP and report (broken/non-compliant
   eval; zero experiments run). Log it as the first `experiments.jsonl` record via
   `log_experiment.py` (`type: baseline`). No separate baseline file — the baseline is an
   event in the stream.
5. **Hypothesis.** ONE hypothesis with a predicted metric movement and risk; record it in
   `state.md` (optionally as the record's `predicted` field).
6. **One bounded change.** The smallest diff testing that hypothesis — one main variable
   per experiment. Capture the diff BEFORE the keep/revert decision executes:
   `git diff HEAD -- . ':(exclude)docs/loen' > docs/loen/<run-id>/iterations/iter-NN/diff.patch`
   (HEAD always equals the last kept state; run artifacts are excluded, so streams and
   logs survive reverts).
7. **Fixed eval + gates.** Run the contract's `quality_gates` (including
   `guard_protected.sh`) into `iterations/iter-NN/gates.log` — correctness and the
   protected-data guard fire on EVERY experiment. Then
   `export LOEN_METRICS_PATH=docs/loen/<run-id>/iterations/iter-NN/metrics.jsonl` and run
   `eval_command` (fixed command, dataset, seed, and model version; any deviation from
   the fixed setup MUST be logged in the experiment record).
8. **Compare + decide.** `metrics_before` = the metrics of the last KEPT state (the
   baseline while nothing is kept). KEEP iff gates are green AND the single primary
   metric improves in its declared direction AND no secondary regresses beyond its
   declared tolerance (a secondary WITHOUT a tolerance line = no regression allowed).
   A tie on the primary is NOT an improvement → revert.
   - **KEEP** → commit the kept change so HEAD equals the last kept state:
     `git add <files_changed> && git commit -m "loen(research): keep iter-NN — <short hypothesis>"`.
   - **REVERT** → `git apply -R docs/loen/<run-id>/iterations/iter-NN/diff.patch` — the
     deterministic inverse of exactly this experiment's change. The reverted experiment's
     `diff.patch` is never deleted (evidence). Failed experiments are logged, never
     silently discarded — they are useful data.
9. **Audit + log.** Run **`loen:audit check`** (for `keep` decisions the verifier re-runs
   `eval_command` against a throwaway `LOEN_METRICS_PATH`). Append the experiment record
   via `log_experiment.py` — NEVER hand-edit the stream — update `state.md`, then next
   hypothesis or stop.
10. **Report.** On success or budget exhaustion run **`loen:audit result`** — kept changes
    must be metric-backed; `report.html` gains the experiments table.

## Record shapes (`experiments.jsonl`, run root)

- `{"type": "baseline", "ts": ..., "eval_command": ..., "metrics": {...}}`
- `{"type": "experiment", "ts": ..., "iter": "iter-NN", "hypothesis": ...,
   "files_changed": [...], "eval_command": ..., "metrics_before": {...},
   "metrics_after": {...}, "delta": {...}, "decision": "keep"|"revert",
   "risks": ..., "next_hypothesis": ...}` — plus optional `predicted`
   (`{"<name>": <number>}`, the hypothesis' predicted movement).

## Hard rules (checked at `loen:audit plan` / by the verifier)

- One main variable per experiment.
- EXACTLY ONE `metrics.primary` entry `<name>:max|min` (`<name>` matches a key in the
  eval `summary.metrics`). Multi-objective research is out of scope — a composite metric
  computed by the eval script is the supported form.
- `stop_conditions` MUST contain one `target: <primary-name> <op> <number>` line;
  reaching it stops the run successfully BEFORE `max_experiments`.
- Secondary tolerances are `tolerance: <name> regression <= <number>[%]` lines — relative
  to `metrics_before`, direction from `<name>:max|min` in `metrics.secondary`.
- Eval data, ground truth, and the eval script are `protected_scope`; `loen:audit plan`
  FAILS a research contract whose `protected_scope` does not cover them.
- Never improve metrics by weakening validation, eval data, or the eval script (unless
  the task IS eval design — then it must be the explicit objective).
- Keep seed, model version, eval command, and dataset fixed across experiments; if any must change, log the deviation in the experiment record.
- **Budget:** `budget.max_experiments` (default 5) counts experiments; exhausted → stop,
  report the best kept state and the full experiment log.

## Error handling

- `eval_command` fails in an experiment (non-zero exit / no `summary` line) → record it
  as failed (`decision: revert`, `metrics_after: null`), revert the change; never counted
  as a keep. TWO consecutive eval failures → stop, report (broken eval ≠ research).
- `log_experiment.py` rejects a record → fix the record, never hand-append.
- Any `handoff_conditions` trigger → hard stop, ask the human. Never auto-merge.

## Red Flags — STOP

- Improving the metric by weakening validation, eval data, or the eval script → never (unless eval design IS the objective).
- More than one main variable changed in an experiment → not isolatable; one variable per experiment.
- Hand-editing `metrics.jsonl` / `experiments.jsonl` → never; append via `log_experiment.py`.
- Treating a tie on the primary as progress → a tie is not an improvement; revert.
- Treating a keep as final before `loen:audit check` re-confirms its metric delta → not confirmed.
- Two consecutive eval failures, or `budget.max_experiments` exhausted → stop; report the best kept state and the full experiment log.
- A `handoff_conditions` trigger → hard stop, ask the human; never auto-merge.
