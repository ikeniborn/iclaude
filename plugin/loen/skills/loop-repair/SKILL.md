---
name: loop-repair
description: Use when a specific test, CI job, or regression is failing and must be fixed under a reproduce-first controlled loop with proven regression coverage. Not for delivering a change (use loop-delivery) or metrics (use loop-autoresearch).
---

# Loop Repair (mode: repair)

Fix ONE failing test / CI / regression through the cycle
`failure → reproduce → isolate → minimal fix → regression test`. You are the **worker**
and the **only writer**. This skill is a specialization of `loop-delivery`: same run
layout, contract, audit gates, subagents, and hook. Shared templates live at
`<skill-base>/../loop-delivery/assets/` (single source — never copy them).

## Steps

1. **Bootstrap** — identical to `loop-delivery` steps 1–3, with these deltas:
   - `mode: repair` in `loop.yaml`.
   - **Record the failing command** (from the user's invocation — the source of truth) in
     the Baseline section of `docs/loen/<run-id>/state.md` BEFORE `loen:audit plan`; the
     plan stage deterministically checks that this recorded command appears among
     `quality_gates`.
   - The `planner` dispatch prompt MUST instruct: `mode: repair`; a NARROW `mutable_scope`
     (the failing area + its tests); the recorded failing command among `quality_gates`;
     block-style YAML scope lists (`guard_protected.sh` parses block-style only); leave
     `eval_command` empty.
2. **Human approval gate**, then **`loen:audit plan`** — must return `OK` before any edit.
3. **Reproduce first (iter-01).** BEFORE any edit, run the failing command; capture output
   + exit code into `docs/loen/<run-id>/iterations/iter-01/gates.log`. For a suspected
   flaky failure run the command up to 3 times (attempts recorded in `state.md`); any
   failing run counts as reproduced. **No reproduction → stop and report** — never "fix"
   what cannot be reproduced. Python targets: purge `__pycache__` (or point
   `PYTHONPYCACHEPREFIX` at a temp dir) before repro, inversion, and gate runs — a stale
   `.pyc` of identical size and mtime second can mask the fix or the failure.
4. **Isolate + minimal fix.** The smallest diff that makes the failing command pass. Save
   `iterations/iter-NN/diff.patch` (`git diff > …`, `iter-NN` zero-padded). Every non-test
   hunk must be required for the failing command to pass; tests change only by ADDING the
   regression test. Use `explorer` for code evidence without loading files here.
5. **Regression coverage.** Either (a) a new/extended test in the diff, or (b) the
   originally-failing test IS the regression test. For case (a) YOU (the worker — the
   verifier stays read-only) produce inversion evidence into `gates.log`:
   `git stash push -- <fix files>` → run the regression test (must FAIL) →
   `git stash pop` → run it again (must PASS).
6. **Check.** Run the `quality_gates` into `iterations/iter-NN/gates.log`, then run
   **`loen:audit check`** — it dispatches the `verifier` and writes
   `iterations/iter-NN/verifier.md`.
7. **Fix.** Address only verifier-confirmed issues. Repeat Act→Check within
   `budget.max_iterations` (default 3 — the methodology default for repair).
8. **Report.** On green gates + verifier APPROVE run **`loen:audit result`**.
   `pr-summary.md` MUST state the root cause and a rollback note.

## Done condition (gated by `loen:audit result`)

1. The originally-failing command exits 0 (evidence in the final `gates.log`).
2. Regression coverage evidenced — case (a) new/extended test with logged inversion
   evidence, or case (b) the originally-failing test itself; the verifier states which
   case applies.
3. The diff is minimal — no test changes except the added regression test; every non-test
   hunk required for the originally-failing command to pass.
4. Verifier `APPROVE`.

## Stop conditions

- The failure does not reproduce → stop BEFORE any edit, report.
- `budget.max_iterations` exhausted → stop; report root-cause analysis, best attempt, and
  the blocker.
- Any `handoff_conditions` trigger → hard stop, ask the human. Never auto-merge.

No new artifacts: `iterations/iter-NN/{diff.patch,gates.log,verifier.md}` suffice. The
research streams (`metrics.jsonl`, `experiments.jsonl`) are simply absent in repair — the
hook allows them, no audit stage requires or reads them.

## Red Flags — STOP

- "Fixing" a failure you have not reproduced → stop; no reproduction, no fix.
- A non-test hunk not required for the failing command to pass → out of scope, drop it.
- Changing tests beyond ADDING the regression test → not allowed.
- Claiming regression coverage without the logged inversion evidence (stash, regression test FAILS, pop, it PASSES) → not proven.
- Reporting the failure fixed without the originally-failing command exiting 0 in the final `gates.log` → not fixed.
- A `handoff_conditions` trigger → hard stop, ask the human; never auto-merge.
- `budget.max_iterations` exhausted → stop; report the root cause, best attempt, and the blocker.
