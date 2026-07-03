---
name: governance
description: Use when you need a cross-run dashboard over all docs/loen/ runs, or --triage to turn failing runs into proposed next actions (proposals only; never launches loops or edits runs).
---

# loen:governance — cross-run dashboard + triage proposals

Invoke as `/loen:governance [--triage]`. Aggregates the audit trail every loen run
already leaves under `docs/loen/` (`loop.yaml`, `state.md`,
`iterations/iter-NN/{gates.log,verifier.md}`, `experiments.jsonl`) into the ACROSS-runs
view the governance loop calls for. Offline-first: no network, no LLM in the aggregation.

## Steps

1. **Aggregate.** Run `python3 <skill-base>/../../scripts/loen_stats.py` (the skill base
   directory is printed when this skill is invoked; the script resolves `docs/loen/`
   from the CWD, `--root` overrides). Non-zero exit → abort and show the script's stderr
   verbatim. Parse the JSON from stdout; an empty summary (zero runs) is valid — render
   the dashboard anyway.
2. **Render `docs/loen/governance.html`** via the `html-report` skill (same flow
   `loen:audit` uses for `report.html`). Dashboard blocks per the methodology §10.3
   minimal table:
   - **Loop success rate** — `totals.success_rate` plus `totals.runs_by_mode` counts;
   - **Metric delta** (research runs) — per run with `research` extras:
     `research.primary`, `primary_first` → `primary_last`, keep/revert counts;
   - **Handoff reasons** — `totals.handoff_reasons`, verbatim;
   - **Failure taxonomy** — `totals.failure_taxonomy` (REJECT verdicts' numbered
     `REQUIRED FIXES:` items with occurrence counts);
   - **Protected-path alerts** — `totals.protected_alerts`;
   - **Layout drift** — the `foreign` list (direct children of `docs/loen/` that are
     neither run-ids nor the canon top-level set);
   - **Cost/tokens** and **Latency/VRAM** — always rendered as
     "n/a — loen artifacts carry no cost/token or inference-infra data"; never
     fabricate (latency appears only if a research run's eval recorded it as a metric).
   Self-contained single file, dark/light, opens by double-click.
3. **`--triage` variant** — additionally list every run whose `last_verdict` is
   `REJECT`, or `null` while `iterations > 0`. For each, give one line of evidence
   quoted from the artifacts (the REJECT's first `REQUIRED FIXES:` item, or
   "no verifier.md while iterations exist") and the suggested next action:
   - the failure names a failing command/test → propose
     `/loen:loop-repair <failing command>`;
   - anything else → propose "review contract/budget" for that run.
   Proposals ONLY — never launch loops, never edit runs, never auto-fix.

## Scheduling (optional, user-owned)

`/loop 30m /loen:governance --triage` re-runs triage this session; the recurring job is
session-scoped and dies with the session — re-arm it per session or use your own cron.

## Rules

- Read-only everywhere except exactly ONE write: `docs/loen/governance.html` (canonical
  top-level path — the loop-guard hook allows it).
- Restate what `loen_stats.py` reports; add no scores, never fabricate the unavailable
  rows.
