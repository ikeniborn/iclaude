---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-02-loen-governance-observability-design.md
review:
  spec_hash: 830b7b31f9d4d264
  last_run: 2026-07-02
  runner: "clean-context subagent (check-runner protocol)"
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  findings:
    - { id: F-001, phase: consistency, severity: CRITICAL, verdict: fixed, note: "§4 canon_patterns-only edit could not allow top-level governance.html (hook blocks at run-id gate first; RUNBOOK.md allowed by early guard) → early 'path ==' allow guard specified as the operative change" }
    - { id: F-002, phase: coverage, severity: WARNING, verdict: fixed, note: "§10.3 Latency/VRAM row neither implemented nor marked unavailable → explicitly n/a alongside cost/tokens (§2 + §3)" }
    - { id: F-003, phase: coverage, severity: WARNING, verdict: fixed, note: "foreign-list would flag canonical top-level entries incl. own output → known canon set (current, RUNBOOK.md, governance.html) excluded; files+dirs scope pinned" }
    - { id: F-004, phase: clarity, severity: WARNING, verdict: fixed, note: "protected-alert match token pinned to '^ERROR: protected path changed:' (guard_protected.sh literal)" }
    - { id: F-005, phase: clarity, severity: WARNING, verdict: fixed, note: "gates.log free-form parse dropped from taxonomy: verifier.md REQUIRED FIXES is the sole format-pinned taxonomy source" }
    - { id: F-006, phase: clarity, severity: INFO, verdict: wontfix, note: "§1 shorthand paths vs full plugin/loen/... in section headings — consistent pattern" }
  verdict: OK
---
# loen backlog step 4 — governance / observability — Design Spec

- **Topic:** `loen-governance-observability`
- **Date:** 2026-07-02
- **Status:** design draft — defaults chosen during brainstorming (user AFK on the option
  poll; every default is explicitly overridable at spec review / plan time)
- **Parent spec:** `docs/superpowers/specs/2026-07-01-loen-loop-engineering-plugin-design.md` §15
  (spec 3, optional; noted tension with the iclaude offline/PII posture)
- **Source methodology:** `docs/superpowers/notes/final_loop_engineering_methodology.md`
  §2 (governance loop row), §7.5 (scheduled triage), §10.3 (observability schema +
  minimal dashboards table), §11 (zero-cloud / sensitive-data policy)
- **Scope:** loen backlog step 4 only — cross-run governance over the artifacts the loop
  already produces under `docs/loen/`. Backlog steps 2–3 are separate specs.

---

## 1. Summary

Every loen run already leaves a machine-readable audit trail (`loop.yaml`, `state.md`,
`iterations/iter-NN/{gates.log,verifier.md,diff.patch}`, research streams). What is
missing is the ACROSS-runs view the methodology's governance loop calls for: success
rate, metric drift, handoff reasons, failure taxonomy, protected-path alerts. This spec
adds it **offline-first**:

- **`scripts/loen_stats.py`** (new, deterministic) — scans `docs/loen/*/` and emits one
  JSON summary; no network, no LLM.
- **`skills/governance/SKILL.md`** (new) — `/loen:governance`: runs the aggregator,
  renders `docs/loen/governance.html` via the `html-report` skill, and (triage variant)
  turns findings into proposed next actions for the HUMAN.
- **+1 canonical path** `docs/loen/governance.html` in the loop-guard hook.

**Design decision (default, overridable): offline-first aggregator, no external trace
backend.** Chosen over (a) *Langfuse push* (self-hosted infra exists — minipc LiteLLM
callback per `docs/superpowers/specs/langfuse-project-tagging-spec.md` — but it reopens
the offline/PII tension §11 warns about, adds a network dependency to a publishable
plugin, and duplicates what `experiments.jsonl` already persists) and (b) *dropping step
4 entirely* (the parent spec allowed it, but the aggregation is cheap, fully local, and
directly consumes artifacts we already guarantee). Langfuse export stays a possible later
increment (§8).

## 2. Component: `plugin/loen/scripts/loen_stats.py` (new, deterministic)

- **Input:** the `docs/loen/` root (default: resolve from CWD; `--root` override).
- **Scan:** every direct child (file or dir) matching the run-id regex
  `^\d{4}-\d{2}-\d{2}-[a-z0-9-]+$` (same canon as the hook) is a run; the known
  top-level canon set — `current`, `RUNBOOK.md`, `governance.html` — is silently
  accepted; every OTHER direct child (file or dir alike) is listed as `foreign`
  (governance must surface layout drift, not hide it — and must not flag its own output
  or the shipped pointer files as drift).
- **Output (stdout):** one JSON document:
  - `runs[]` — per run: `run_id`, `mode`, iterations count, last verifier verdict
    (parsed from the latest `iterations/iter-NN/verifier.md` `VERDICT:` line — the ONLY
    format-pinned line the MVP guarantees), `gates.log` presence per iteration, research
    extras when `experiments.jsonl` exists (experiment count, keep/revert counts,
    primary-metric first/last values from the records).
  - `totals` — run counts by mode, **loop success rate** (runs whose final iteration has
    `VERDICT: APPROVE`), keep/revert ratio, **handoff/stop reasons** (lines matched from
    `state.md` Attempts blocks), **failure taxonomy** built from the REJECT verdicts'
    numbered `REQUIRED FIXES:` items (verifier.md is the format-pinned source;
    `gates.log` is free-form gate output and is deliberately NOT parsed for taxonomy),
    **protected alerts** (count of lines matching `^ERROR: protected path changed:` —
    the exact string `guard_protected.sh` emits — across `gates.log` files).
  - Absent inputs degrade to explicit `null`s/empty lists — an empty `docs/loen/` yields
    a valid empty summary, exit 0 (governance over zero runs is not an error).
- **Fidelity rule:** the aggregator only RESTATES evidence found in artifacts; it never
  infers or scores beyond the §10.3 field set. The §10.3 dashboard rows loen artifacts
  cannot back — cost/tokens AND latency/VRAM — are reported as `unavailable` (no
  fabrication); every other §10.3 row maps to a `totals` field above.
- stdlib only; read-only (never writes into run dirs).

## 3. Component: `plugin/loen/skills/governance/SKILL.md` (new)

Invoked as `/loen:governance [--triage]`:

1. Run `loen_stats.py` (resolved from `<skill-base>/../../scripts/`); abort with the
   script's stderr if it exits non-zero.
2. Render **`docs/loen/governance.html`** via the `html-report` skill (same flow
   `loen:audit` uses for `report.html`): dashboard blocks per methodology §10.3's minimal
   table — loop success rate, metric delta (research runs), handoff reasons, failure
   taxonomy, protected-path alerts, plus the `foreign`-entries drift list; the
   cost/tokens AND latency/VRAM rows of §10.3 are explicitly rendered as
   "n/a — loen artifacts carry no cost/token or inference-infra data" (never fabricated;
   latency appears only if a research run's eval recorded it as a metric).
   Self-contained, dark/light, opens by double-click.
3. **`--triage` variant** (methodology §7.5 adapted to loen): additionally list the runs
   whose last verifier verdict is REJECT (or absent while iterations exist), each with a
   one-line evidence quote and the suggested next action (`/loen:loop-repair <failing command>` for
   repair-shaped failures; "review contract/budget" otherwise). Proposals ONLY — the
   skill never launches loops, never edits runs, never auto-fixes. Scheduling the triage
   (via `/loop`, cron, Routines) is the user's choice; the skill body carries a one-line
   recipe and the session-durability caveat, nothing more.
4. Read-only with exactly one write: `docs/loen/governance.html`.

## 4. Hook change (+1 canonical path, two-way sync)

`docs/loen/governance.html` lives at the TOP level of `docs/loen/` (not inside a run
dir), and the hook's control flow reaches `canon_patterns()` only AFTER the run-id
segment gate — top-level files never get there. The shipped hook allows `current` and
`RUNBOOK.md` via EARLY explicit `path ==` guards before that gate (their
`canon_patterns()` entries are unreachable for top-level paths); `governance.html` MUST
be allowed the same way:

- add an early guard `if path == "docs/loen/governance.html": sys.exit(0)` alongside the
  existing `current` / `RUNBOOK.md` guards (this is the change that actually opens the
  write path);
- add `^docs/loen/governance\.html$` to `canon_patterns()` for documentation symmetry
  with the other two top-level entries, and extend the hook's human-facing block-message
  path listing.

`check_layout.sh` is NOT touched — it validates INSIDE one run dir and `governance.html`
lives outside; the docs layout table (`docs/functions/LOEN.md`) is the second sync leg.
This is the only canonical-set change in this spec.

## 5. Privacy / offline posture

- No network I/O anywhere in the increment; everything reads and writes the local
  `docs/loen/` tree. Compatible with methodology §11 zero-cloud rows by construction.
- `governance.html` may embed repo paths and metric values (already present in the run
  artifacts committed to the repo) — no NEW data classes leave the machine.

## 6. Delivery model

- Same plugin `plugin/loen/`; **minor version bump** in both manifests (exact number
  resolved at implementation time — steps 2–4 have no fixed merge order; sync enforced by
  `check-plugin-version-sync.sh`).
- New: `scripts/loen_stats.py`, `skills/governance/SKILL.md`. Modified:
  `hooks/loop-guard.py` (+1 canon path + block message). Zero new hard dependencies.

## 7. Testing

- **`tests/test_loen_stats.py` (new)** — fixture `docs/loen/` trees: two runs (one
  APPROVE-final delivery, one research with keep+revert records) → totals assert success
  rate 0.5, keep/revert counts, primary first/last values; REJECT run with numbered
  `REQUIRED FIXES:` items → taxonomy buckets present; a
  `ERROR: protected path changed: …` line in a `gates.log` → protected-alerts count 1;
  a stray non-run-id dir AND file each listed in `foreign` while `current`/`RUNBOOK.md`/
  `governance.html` are not; empty root → valid empty JSON, exit 0.
- `tests/test_loen_hook.py` — +cases: `docs/loen/governance.html` → allow;
  `docs/loen/governance.txt` → block(2).
- `tests/test_loen_plugin.sh` — skill lint list extended with `governance`; version sync
  green after the bump.

## 8. Out of scope

- Langfuse / external trace backends (possible later increment: an exporter reading the
  same `loen_stats.py` JSON; requires its own privacy review against
  `langfuse-project-tagging-spec.md` infra).
- Cost/token accounting (loen artifacts carry none; `stats-cache.json` belongs to iclaude
  telemetry, not the publishable plugin).
- Auto-remediation (launching repair loops from triage) — proposals only, human executes.
- Cross-repo aggregation — one repo's `docs/loen/` per invocation.
- Scheduled-run infrastructure itself (Routines/cron/CI) — only the recipe line ships.

## 9. Process obligations (per CLAUDE.md, at implementation time)

- `docs/functions/LOEN.md` (Use section + Artifacts table row for `governance.html` —
  the docs leg of the canon sync) + `plugin/loen/README.md` + root `README.md` (RU) +
  iwiki `iclaude/loen-plugin` (Components, Artifact model, Roadmap) updated in the same
  increment; `docs/TODO.md` row `loen-governance-observability` driven by `/check-chain`.

## 10. Resolved decisions log

1. Architecture: **offline-first local aggregator**; Langfuse export explicitly deferred
   (default chosen with user AFK; alternatives recorded in §1 and reversible at review).
2. Aggregator restates artifact evidence only; unavailable §10.3 dashboards (cost/tokens)
   are marked `unavailable`, never fabricated (§2).
3. Governance output is ONE canonical file `docs/loen/governance.html`; canon set grows
   by exactly one, synced hook + docs table (`check_layout.sh` structurally unaffected) (§4).
4. Triage proposes, never executes; scheduling stays user-owned with a durability caveat
   (§3.3).
5. Empty/partial artifact trees are valid inputs (explicit nulls), foreign entries are
   surfaced as drift (§2).
