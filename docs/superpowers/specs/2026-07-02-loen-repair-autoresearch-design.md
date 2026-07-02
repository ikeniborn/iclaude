---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-02-loen-repair-autoresearch-design.md
review:
  spec_hash: 57df8606707c9dcd
  last_run: 2026-07-02
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - { id: F-001, phase: structure, severity: INFO, verdict: fixed, note: "bare §7.3 qualified as methodology §7.3" }
    - { id: F-002, phase: coverage, severity: WARNING, verdict: fixed, note: "research plan check strengthened: protected_scope must COVER eval assets, non-empty alone insufficient (§4.3 + §5.4)" }
    - { id: F-003, phase: clarity, severity: WARNING, verdict: fixed, note: "verifier re-run trigger defined: re-runs eval_command for every keep decision; revert records trusted as logged" }
    - { id: F-004, phase: clarity, severity: WARNING, verdict: fixed, note: "metrics_before defined = last kept state (baseline while none kept); delta computed against it" }
    - { id: F-005, phase: clarity, severity: INFO, verdict: fixed, note: "deviation from fixed seed/dataset/model MUST be logged in the experiment record" }
    - { id: F-006, phase: clarity, severity: INFO, verdict: fixed, note: "secondary tolerances MUST be numeric lines in stop_conditions" }
    - { id: F-007, phase: clarity, severity: INFO, verdict: fixed, note: "repair minimal-diff criterion: every non-test hunk required for the failing command to pass" }
    - { id: F-008, phase: clarity, severity: INFO, verdict: fixed, note: "one experiment = one iter-NN; max_iterations ignored in research mode" }
    - { id: F-009, phase: clarity, severity: INFO, verdict: fixed, note: "template keys present with trailing comments, not commented out (keeps §9 parse test valid)" }
    - { id: F-010, phase: consistency, severity: WARNING, verdict: fixed, note: "scope line corrected: deferred backlog steps are 2-4, not 3-4" }
    - { id: F-011, phase: consistency, severity: WARNING, verdict: fixed, note: "baseline eval target defined: iterations/iter-00/metrics.jsonl (iter-00 reserved for baseline; experiments start at iter-01; existing canon regex covers it)" }
  verdict: OK
---
# loen spec 2 — loop-repair + loop-autoresearch — Design Spec

- **Topic:** `loen-repair-autoresearch`
- **Date:** 2026-07-02
- **Status:** design approved (brainstorming); subagent model roster pending user confirmation (§7); ready for implementation planning
- **Parent spec:** `docs/superpowers/specs/2026-07-01-loen-loop-engineering-plugin-design.md` (MVP, shipped via PR #72)
- **Source methodology:** `docs/superpowers/notes/final_loop_engineering_methodology.md` (§2 loop types, §7.3 AutoResearch)
- **Scope of this spec:** increment 2 of the loen backlog — the `loop-repair` and `loop-autoresearch` skills. Backlog steps 2–4 (`/goal`+`/loop` wrapper, verifier microVM, governance) stay deferred.

---

## 1. Summary

Spec 2 adds two loop specializations to the shipped `loen` plugin:

- **`loop-repair`** (mode `repair`) — fix a failing test / CI / regression through the cycle
  `failure → reproduce → isolate → minimal fix → regression test`.
- **`loop-autoresearch`** (mode `research`) — improve a numeric metric through the cycle
  `baseline → hypothesis → one bounded change → fixed eval → compare → keep/revert`,
  logging every experiment as a JSONL event stream.

**Design decision (user-approved): both are specializations over the existing loop machinery.**
They reuse the MVP run layout `docs/loen/<run-id>/`, the `loop.yaml` contract (its `mode` field
already reserves `repair | research`), the `loen:audit` stage gates, the `planner`/`explorer`/
`verifier` subagents, the `loop-guard.py` hook, `guard_protected.sh`, and `check_layout.sh`.
Each skill adds only its own cycle and rules. No new subagents.

## 2. Delivery model

- Same plugin `plugin/loen/` in the `iclaude` marketplace; **version 0.1.0 → 0.2.0** in BOTH
  `plugin.json` and `marketplace.json` (enforced by `check-plugin-version-sync.sh`).
- Two new skill directories: `plugin/loen/skills/loop-repair/SKILL.md` and
  `plugin/loen/skills/loop-autoresearch/SKILL.md`.
- One new deterministic script: `plugin/loen/scripts/log_experiment.py` (§5.3).
- Zero new hard dependencies; publishable posture unchanged.

## 3. loop-repair (mode: repair)

Invoked as `/loen:loop-repair <failure description>`. Methodology §2 row "Repair loop".

- **Reproduce-first.** Iteration `iter-01` MUST start by reproducing the failure BEFORE any
  edit: run the failing command, capture output + exit code into
  `iterations/iter-01/gates.log` and record the repro command in `state.md`. No reproduction →
  stop and report (never "fix" what cannot be reproduced).
- **Contract specifics.** `planner` fills `loop.yaml` with `mode: repair`, a narrow
  `mutable_scope` (the failing area + its tests), and `quality_gates` that include the
  originally-failing command.
- **Done condition (gates `loen:audit result`):**
  1. the originally-failing command exits 0 (evidence in the final `gates.log`);
  2. a **regression test is present in the diff** (verifier confirms: a new/extended test that
     fails on the pre-fix code and passes on the fixed code);
  3. the diff is minimal — no changes to tests except adding the regression test, and the
     verifier confirms every non-test hunk is required for the originally-failing command to
     pass;
  4. verifier `APPROVE`.
- **Budget:** default `budget.max_iterations: 3` (methodology default for repair). Exhausted →
  stop, report root-cause analysis + best attempt + blocker.
- **No new artifacts.** `iterations/iter-NN/{diff.patch,gates.log,verifier.md}` suffice.

## 4. loop-autoresearch (mode: research)

Invoked as `/loen:loop-autoresearch <metric goal>`. Methodology §2 row "Research / AutoResearch
loop" and §7.3.

### 4.1 Cycle

1. **Baseline.** After the human approves `loop.yaml`, run `eval_command` once BEFORE any
   change, targeting `iterations/iter-00/metrics.jsonl` (`iter-00` is reserved for the
   baseline; experiments start at `iter-01` — the existing `iter-\d{2}` canon regex already
   covers it). Log the result as the first `experiments.jsonl` record (`type: baseline`).
   No separate `baseline.json` — the baseline is an event in the stream.
2. **Hypothesis.** Propose ONE hypothesis with a predicted metric movement and risk; record it
   in `state.md`.
3. **One bounded change.** The smallest diff testing that hypothesis. One main variable per
   experiment.
4. **Fixed eval.** Run `eval_command` (fixed command, dataset, seed and model version; any
   deviation from the fixed setup MUST be logged in the experiment record). It appends metric
   events to `iterations/iter-NN/metrics.jsonl` (§4.2).
5. **Compare + decide.** `metrics_before` = the metrics of the last KEPT state (the baseline
   while nothing is kept yet); `delta` is computed against it. Keep iff the primary metric
   improves without secondary regression beyond the numeric tolerances stated in
   `stop_conditions` (tolerances MUST be numeric lines there, so the verifier compares
   numbers, not prose); otherwise revert the change. Failed experiments are logged, never
   silently discarded — they are useful data.
6. **Log.** Append the experiment record to `experiments.jsonl` via `log_experiment.py`
   (§5.3), update `state.md`, proceed to the next hypothesis or stop.

### 4.2 Metrics contract (user decision: JSONL event streams, not one-shot JSON)

- **`loop.yaml` gains `eval_command`** (string): the fixed evaluation command. The command
  MUST append its results as JSON Lines to the canonical per-iteration file
  `docs/loen/<run-id>/iterations/iter-NN/metrics.jsonl`. Target-path contract: the worker
  exports `LOEN_METRICS_PATH=<that file>` before running `eval_command`; the eval script
  appends to `$LOEN_METRICS_PATH` (single fixed mechanism — no per-contract variation).
- **`metrics.jsonl` line shape:** free typed events (per-case results, timings) plus exactly
  one authoritative line `{"type": "summary", "metrics": {"<name>": <number>, ...}}`. The
  summary line is what the worker compares and copies into `experiments.jsonl`.
- **`experiments.jsonl`** (run root, already canonical in the MVP layout) is the run's
  analysis stream — one JSON line per event:
  - `{"type": "baseline", "ts": ..., "eval_command": ..., "metrics": {...}}`
  - `{"type": "experiment", "ts": ..., "iter": "iter-NN", "hypothesis": ...,
     "files_changed": [...], "eval_command": ..., "metrics_before": {...},
     "metrics_after": {...}, "delta": {...}, "decision": "keep"|"revert",
     "risks": ..., "next_hypothesis": ...}` (methodology §7.3 required-output set;
     `metrics_before` = last kept state per §4.1 step 5; one experiment = one `iter-NN`).
- Rejected alternatives: parsing eval stdout (breaks on any stray output, incl. redact hooks);
  free-form worker interpretation (worker becomes the judge of its own numbers).

### 4.3 Hard rules (encoded in SKILL.md, checked by verifier)

- One main variable per experiment.
- Eval data, ground truth, and the eval script are **`protected_scope`** — the `planner` MUST
  list them there in research mode; `loen:audit plan` fails a research contract whose
  `protected_scope` does not cover the eval assets (the `eval_command` script, eval datasets,
  ground truth) — non-empty alone is not enough.
- Never improve metrics by weakening validation, eval data, or the eval script (unless the
  task IS eval design — then it must be the explicit objective).
- Keep seed, model version, eval command, and dataset fixed when possible.
- **Budget:** new optional key `budget.max_experiments` (default 5) counts experiments in
  research mode (one experiment = one `iter-NN`); in research mode `max_iterations` is
  ignored — `max_experiments` governs. `max_iterations` keeps governing delivery/repair.
  Exhausted → stop, report the best kept state and the full experiment log.

## 5. Component changes

### 5.1 Hook + layout validator (+1 canonical path, three-way sync)

Add `docs/loen/<R>/iterations/iter-NN/metrics.jsonl` to the canonical set in ALL THREE places
that must not drift: `loop-guard.py` `canon_patterns()`, `scripts/check_layout.sh` case list,
and the layout table in docs. `experiments.jsonl` is already canonical.

### 5.2 Template `loop.template.yaml`

Add two optional keys, present in the template with explanatory trailing comments (NOT
commented out — the template must still parse with them, §9): `eval_command: ""` (research
mode: command that appends JSONL metrics) and `budget.max_experiments: 5` (research mode
budget). Delivery/repair contracts may omit both.

### 5.3 `scripts/log_experiment.py` (new, deterministic)

Appender + validator for `experiments.jsonl`: takes the target file and a JSON record
(stdin or arg), validates the required keys for its `type` (`baseline` | `experiment`),
appends exactly one line, refuses malformed input (exit 1, nothing written). Keeps the worker
from hand-editing the stream; the verifier re-checks the stream against `metrics.jsonl`.

### 5.4 `loen:audit` — mode-aware stage checks

Reads `mode` from the active `loop.yaml`; existing checks stay, per-mode additions:

| Stage | repair | research |
|---|---|---|
| plan | `quality_gates` include the failing command | `eval_command` non-empty; `metrics.primary` non-empty; `protected_scope` covers the eval assets (eval script, datasets, ground truth) |
| act | unchanged (+ `check_layout.sh` knows `metrics.jsonl`) | unchanged |
| check | gates green | `iterations/iter-NN/metrics.jsonl` has a `summary` line; `experiments.jsonl` has this iter's record; verifier re-runs `eval_command` for every `keep` decision and confirms the claimed delta (`revert` records are trusted as logged) |
| result | regression test evidenced in the final diff; originally-failing command green | kept changes are metric-backed (primary improved, secondary within stated tolerance) OR budget exhausted with best-result report; stream consistent end-to-end |

`report.html` gains an experiments table (hypothesis, before/after, delta, decision) in
research mode — rendered by the same `html-report` flow.

## 6. Data flow (research mode, end-to-end)

```
/loen:loop-autoresearch <metric goal>
  -> bootstrap run dir + current pointer (as MVP)
  -> planner fills loop.yaml (mode: research, eval_command, protected eval assets); human approves
  -> loen:audit plan  => OK
  -> baseline: run eval_command -> iterations/iter-00/metrics.jsonl; log_experiment.py appends {type: baseline}
  -> per experiment (<= budget.max_experiments):
       hypothesis -> one bounded change -> diff.patch
       eval_command -> iterations/iter-NN/metrics.jsonl (summary line)
       loen:audit check (verifier re-runs eval for keep decisions) -> verifier.md
       keep | revert; log_experiment.py appends {type: experiment, ...}
  -> loen:audit result: kept state metric-backed -> report.html (+experiments table) + pr-summary.md
  -> human PR review. No auto-merge.
```

Repair mode differs only in the cycle core: reproduce first, minimal fix, regression test —
same artifacts, same gates.

## 7. Subagent roster update — PENDING USER CONFIRMATION

Recommended defaults (frontmatter `model:` — always overridable):

| Subagent | MVP model | Spec 2 default | Rationale |
|---|---|---|---|
| `planner` | opus | **fable** | strongest reasoning where the contract and decomposition are authored |
| `explorer` | haiku | haiku | cheap evidence gathering, unchanged |
| `verifier` | sonnet | **opus** | stronger judge AND model-diverse from a (typically fable) worker session — preserves worker ≠ judge diversity |

Compatibility note: on Claude Code versions without the `fable` alias the frontmatter model
falls back per harness rules and can be overridden; the publishable plugin keeps working.
If the user prefers maximum compatibility, the roster stays as-is and this section shrinks to
"no change" — one-line edit at spec review.

## 8. Error handling

Inherits MVP §11 (budget, handoff, rollback) plus:

- `eval_command` fails (non-zero exit / no `summary` line) → the experiment is recorded as
  failed (`decision: revert`, metrics_after null), the change is reverted; never counted as
  a keep. Two consecutive eval failures → stop, report (broken eval ≠ research).
- `log_experiment.py` rejects a record → the worker fixes the record, never hand-appends.
- Repair reproduction fails (the failure does not reproduce) → stop before any edit, report.

## 9. Testing

Extends the existing flat `tests/` suites (shell + python, repo convention):

- `test_loen_hook.py` — +cases: canonical `iterations/iter-NN/metrics.jsonl` → allow;
  malformed iter segment with `metrics.jsonl` → block(2).
- `test_loen_layout.sh` — canonical tree with `metrics.jsonl` accepted; stray
  `metrics.json` (non-canonical) rejected.
- `test_loen_templates.sh` — template parses with `eval_command` + `budget.max_experiments`.
- `test_loen_plugin.sh` — skill frontmatter lint extended to `loop-repair` and
  `loop-autoresearch`; version sync 0.2.0.
- **`test_loen_experiment.py` (new)** — `log_experiment.py`: valid baseline/experiment
  records append one line each; missing required key → exit 1, file untouched; malformed
  JSON → exit 1; unknown `type` → exit 1.

## 10. Process obligations (per CLAUDE.md)

- Bump `plugin.json` + `marketplace.json` to 0.2.0.
- Update `docs/functions/LOEN.md` + the README "Loop Engineering (loen)" section (RU) with the
  two new loops.
- Update the iwiki `iclaude/loen-plugin` page (Components, Artifact model, loop.yaml contract,
  Roadmap and backlog: step 1 → done when shipped) + `wiki_lint`.
- `docs/TODO.md` row `loen-repair-autoresearch` (already opened 2026-07-02).

## 11. Out of scope (this spec)

- `/goal` + `/loop` wrapping (backlog step 2, `loen-goal-loop-wrapper`).
- Verifier microVM FS isolation (backlog step 3, `loen-verifier-microvm`) — iclaude already
  ships a microVM integration; reuse is a separate spec.
- Governance / observability (backlog step 4, `loen-governance-observability`).
- Langfuse/traces for experiments — `experiments.jsonl` is the offline-friendly substitute.

## 12. Resolved decisions log

1. Both skills are **specializations** over the MVP loop machinery (user-approved) — reuse
   layout, contract, audit, subagents, hook; no new subagents.
2. Metrics travel as **JSONL event streams** (user decision): eval appends
   `iterations/iter-NN/metrics.jsonl` (target passed via `LOEN_METRICS_PATH`); the run
   stream is `experiments.jsonl`; baseline is a stream event targeting `iter-00`, not a
   separate file.
3. Deterministic stream writer `log_experiment.py`; the worker never hand-edits the stream.
4. New optional contract keys: `eval_command`, `budget.max_experiments` (default 5).
5. Repair done-condition includes a regression test evidenced in the diff.
6. Eval assets live in `protected_scope` in research mode; audit fails a research plan
   without them.
7. Canonical-path set grows by exactly one (`metrics.jsonl`), synced three-way
   (hook / check_layout / docs).
8. Subagent model roster: planner→fable, verifier→opus recommended — **pending user
   confirmation** (§7).
9. Plugin version 0.2.0; publishable posture unchanged.
