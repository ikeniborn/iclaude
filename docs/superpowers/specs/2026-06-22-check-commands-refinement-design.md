---
review:
  spec_hash: 1a033472e1df25cd
  last_run: 2026-06-22
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  findings:
    - id: F-001
      phase: coverage
      severity: WARNING
      section: "Area C — verbosity reduction (in place, self-containment preserved)"
      section_hash: f3948c5f88393a24
      text: >-
        Task part (a) asks to audit "redundancy when validating prepared
        documents". The spec addresses redundancy only as restated PROSE
        (C2/C3 verbosity, C1 self-containment). It does not evaluate whether any
        validation PHASE or check is itself redundant (e.g. overlapping checks
        across the 4 phases). Partial coverage of the redundancy axis — confirm
        prose-level redundancy is the intended scope, or add a requirement.
      verdict: fixed
      verdict_at: 2026-06-22
    - id: F-002
      phase: clarity
      severity: INFO
      section: "Area C — verbosity reduction (in place, self-containment preserved)"
      section_hash: f3948c5f88393a24
      text: >-
        C2 ("MUST be compressed") and C3 ("MUST be tightened in wording") give
        no quantified verbosity target. Acceptable: verbosity reduction is
        qualitative and the Out-of-scope guards + Success criteria bound it
        (bash verbatim, checklists untouched, git diff scope). No DoD gap that
        blocks review.
      verdict: open
      verdict_at: null
    - id: F-003
      phase: clarity
      severity: INFO
      section: "Area A — HTML-report contract correctness (priority 1)"
      section_hash: 05ea7d50470517aa
      text: >-
        A3 offers two acceptance outcomes ("Replace it with a pointer ... or
        remove the line"). Both are valid DoD and Success criteria pins the
        result ("broken external gold-standard reference is gone"), so this is
        an acceptable either/or, not an ambiguity.
      verdict: open
      verdict_at: null
chain:
  intent: null
---
# Design: Refinement of `check-{intent,spec,plan,result}` commands

**Status:** draft

## Objective

Improve the four IDD→SDD validator commands in
`.nvm-isolated/.claude-isolated/commands/` along four axes the audit surfaced:

1. **HTML-report contract correctness** (priority 1) — the Step "HTML report"
   instructions do not align with the `html-report` skill they call.
2. **Schema / dependency completeness** (priority 2) — the diagrams the commands
   request are uneven across the four documents.
3. **Verbosity reduction** — trim restated prose without losing review context and
   without breaking each command's self-containment.
4. **Validation-phase redundancy** — collapse the one place where a validation phase
   re-does work an earlier step already performed (the original task asks to audit
   "redundancy when validating", not only restated prose).

Each command is executed by a clean-context subagent that reads exactly ONE command
file (per the IDD check-runner protocol in `CLAUDE.md`). Self-containment is a
feature, so cross-file factoring is deliberately out of scope.

## Context

- Files: `check-intent.md` (195 L), `check-spec.md` (185 L), `check-plan.md` (190 L),
  `check-result.md` (168 L) — 738 lines total.
- intent/spec/plan are phase-model validators that persist a `review:` block in the
  artifact frontmatter; check-result is a diff-reconciliation that persists a
  `result_check:` block. Both feed `hooks/idd-gate.py`.
- Each command ends with an "HTML report" step that invokes the `html-report` skill
  (`.nvm-isolated/.claude-isolated/skills/html-report/SKILL.md`) to produce one
  self-contained `.html` artifact for the user.

### Audit findings driving this design

- **F1 (path contract conflict).** Commands write the report to
  `docs/superpowers/reports/<kind>/` and call this "an explicit override of
  html-report's proposal-first". The skill itself declares `docs/reports/` as the
  ONLY allowed directory and classifies writing anywhere else as **No-go → refuse**,
  not proposal-first. The commands override the wrong autonomy zone; the skill may
  legitimately refuse.
- **F2 (data-passing model mismatch).** Commands say "pass the skill three blocks"
  (ready data). The skill is configured to "Read ONLY the sources the user named …
  halt if a source is unreadable". The hand-off form is unspecified, so the skill may
  try to read the artifact itself / halt.
- **F3 (broken gold-standard reference).** The skill points to
  `~/Документы/Project/ecom1-agent/docs/agent-architecture.html` — a path outside this
  project, likely absent → degrades non-trivial diagram quality.
- **F4 (schema asymmetry).** intent = 4 diagrams, spec = 3, plan = 2, result = 0.
- **F5 (uneven dependency graph spec).** check-plan defines it precisely (nodes =
  steps, edges = "result of step M used in step N", cycle highlighting); check-spec is
  vague ("dependencies between requirements/components", node undefined).
- **F6 (check-plan self-containment break).** check-plan's findings-handling section
  says "Identical to check-spec" — but the check-plan subagent never reads check-spec.
  This violates one-file self-containment.

## Requirements

Grouped by area. Each requirement is independently verifiable.

### Area A — HTML-report contract correctness (priority 1)

- **A1.** `html-report/SKILL.md` MUST accept a caller-supplied output path:
  - Autonomy Zones table: writing to a path EXPLICITLY passed by the calling command
    is **Full** zone (proceed, no pause). The No-go entry remains for arbitrary writes
    with no explicit override.
  - Hard Constraint #5 and Workflow step 6: `MUST be docs/reports/` →
    `default docs/reports/; if the caller passed an explicit output path, write there`.
  - Self-Validation checklist: the path item → "under `docs/reports/` OR the explicit
    caller-supplied path".
- **A2.** All four commands MUST, in their HTML step, pass the output path to the skill
  as an explicit argument AND state that the three data blocks are provided inline in
  the call — the skill MUST NOT read sources itself and MUST NOT halt on a missing
  source. This resolves F2.
- **A3.** `html-report/SKILL.md` MUST drop the broken external gold-standard reference
  (`~/Документы/Project/ecom1-agent/...`). Replace it with a pointer to the in-skill
  `references/svg-diagrams.md` (and siblings), or remove the line. This resolves F3.

### Area B — schema / dependency completeness (priority 2)

- **B1.** check-spec's "dependency graph" MUST be defined as precisely as check-plan's:
  explicit nodes (requirements/components), explicit edges ("depends on" / "uses"),
  edge direction, and cycle highlighting when the phase found cycles. Resolves F5.
- **B2.** check-intent's "constraints↔outcomes link" stays (intent has no real
  dependencies — correct), but is specified as a `Constraint × Desired Outcome` matrix
  with explicit cells.
- **B3.** check-result gets NO diagrams (decision). Counters/tables remain. F4 is
  accepted as-is for result — it is a diff check, diagrams would be redundant.

### Area C — verbosity reduction (in place, self-containment preserved)

- **C1.** check-plan's findings-handling section MUST be a self-contained explicit list
  (not "Identical to check-spec"). Resolves F6.
- **C2.** The canonical-hashing preamble MUST be compressed (collapse the repeated "ALL
  hashes computed identically … else no convergence" + "do not recompute in your head"
  into one line). The bash commands themselves are copied verbatim — NOT changed.
- **C3.** The quick-exit and init-state preambles MUST be tightened in wording; their
  structure (conditions, phase lists, frontmatter shape) is preserved unchanged.

### Area D — validation-phase redundancy (resolves F-001)

A focused audit of overlap across the four phases (structure / coverage / clarity /
consistency), then consolidation of the single real duplicate found.

- **D1 (audit, documented in this spec).** Phase-overlap result: the phases are
  orthogonal EXCEPT the `consistency` phase, which re-states the section-hash work
  that init-state (Step 2) already performs — Step 2 computes every section hash and
  resets stale verdicts, then the `consistency` phase says again "check section hashes
  — changed since last run". structure (placeholders / broken links), coverage
  (task↔requirement), clarity (weasel-terms / DoD), and the intent-specific
  status-guard + contradiction checks are each unique — no consolidation there.
- **D2 (consolidation).** In check-intent / check-spec / check-plan, the `consistency`
  phase MUST reference the section-diff already computed in Step 2 rather than
  re-instructing a fresh hash pass. Reword its checklist from "check section hashes …
  changed?" to "report the changed-section diff from Step 2 (init-state) and its
  related findings". The phase still runs and still yields a `passed` status for the
  gate — only the duplicated hash-recompute instruction is removed. The bash hashing
  pipeline and the frontmatter contract are unchanged. check-intent's `consistency`
  contradiction + status-guard checks are NOT touched (they are not duplicates).

### Out of scope (explicitly not touched)

- Bash commands (executable — any drift breaks the quick-exit hash convergence).
- Phase checklists (closed lists, "do NOT extend" — anti-hallucination guardrails).
  Area D is the sole exception: it only REMOVES the duplicated hash-recompute line
  from the `consistency` phase (a reduction, never an extension), leaving every other
  check untouched.
- Artifact bodies, the `review:` / `result_check:` frontmatter contract, and
  `idd-gate.py` compatibility.
- Cross-file duplication of the hashing block — kept as the deliberate cost of
  one-file self-containment. No `_check-common.md` extraction.

## Success criteria

- check-plan no longer references check-spec; its findings-handling reads completely
  from its own file.
- The `html-report` skill and the commands agree on the output path: a live run of any
  command against a test artifact produces the `.html` under
  `docs/superpowers/reports/<kind>/` with no No-go refusal.
- Each command's HTML step passes the output path explicitly and marks the data as
  inline (skill does not read sources / does not halt).
- check-spec's dependency graph is defined with the same node/edge precision as
  check-plan's.
- The broken external gold-standard reference is gone from the skill.
- The `consistency` phase in check-intent / check-spec / check-plan no longer
  re-instructs a fresh section-hash pass — it points at the Step 2 init-state diff;
  the phase still yields a `passed` status and the frontmatter contract is unchanged.
- `git diff` touches only the four command files and three spots in
  `html-report/SKILL.md` — nothing else.

## Dependencies

- `.nvm-isolated/.claude-isolated/skills/html-report/SKILL.md` — modified by A1, A3
  (shared skill; changes must stay backward-compatible for other callers: the default
  `docs/reports/` behaviour is preserved when no caller path is passed).
- `hooks/idd-gate.py` — unchanged; the `review:` / `result_check:` frontmatter contract
  must remain byte-compatible.

## Verification approach

- `check-plan.md`: grep confirms no "check-spec" cross-reference remains.
- Skill change: re-read `SKILL.md`; confirm caller-path is Full-zone in the table,
  Constraint #5 + step 6 + checklist updated, gold-ref line gone.
- End-to-end: run one validator (e.g. `/check-plan`) on an existing plan; confirm the
  `.html` lands in `docs/superpowers/reports/plans/` and the skill does not refuse or
  halt.
