---
review:
  spec_hash: 37cd9e035cde3bcf
  last_run: 2026-06-14
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  findings: []
chain:
  intent: null
---

# Design: `/check-intent` command — phased validation of IDD intent docs

**Date:** 2026-06-14
**Status:** draft

## Objective

The IDD→SDD chain has validation commands for every downstream link
(`check-spec` for the spec, `check-plan` for the plan, `check-result` for the
git diff) but **none for the intent doc itself** — the root of the chain. The
`intent/SKILL.md` carries a 4-item Validation checklist, but it runs only once
inline during authoring, with no state, no caching, and no re-runnable gate.

`/check-intent` fills that gap: a phased, stateful, cacheable validator for
`docs/superpowers/intents/*-intent.md`, built by analogy with `check-spec.md`
(same canonical hashing, quick-exit, frontmatter state model, closed-list
phases, findings with verdicts).

## Position in the IDD→SDD chain

The intent doc is the **root** — it has no upstream document to compare against.
This is the key structural difference from `check-spec` (compares spec vs tasks
from conversation) and `check-plan` (compares plan vs spec). The reference is
therefore three-layered:

| Layer | Reference source | Phase(s) | Severity | Gate? |
|-------|------------------|----------|----------|-------|
| Self | IDD template + Validation checklist in `intent/SKILL.md` | structure, completeness, clarity, consistency | CRITICAL / WARNING | **Yes — gates** |
| Conversation | original problem the user described in this conversation | alignment | INFO / WARNING | No — advisory |
| lat.md | `lat_search` / `lat_refs` MCP (when available) | alignment | INFO / WARNING | No — advisory |

Because the intent is the root, the report footer points **forward**
(`Next step: superpowers:brainstorming`), not backward. The backward chain link
is established downstream: `check-spec` writes `chain.intent` pointing back to
this intent file. `check-intent` itself adds **no** `chain:` block.

## Reference layers

### Self-validation (deterministic, hashable — the gate)

Validates the intent doc against the IDD template and the SKILL's Validation
checklist. Pure structural + quality + self-consistency checks, all derivable
from the doc body alone → reproducible across sessions → compatible with the
canonical hash + quick-exit caching inherited from `check-spec`.

### Conversation alignment (advisory)

Cross-checks Objective + Desired Outcomes against the original problem the user
described in the current conversation: did the intent capture what the user
actually asked for, and did it avoid inventing objectives the user never
stated? Conversation context is not hashable → these findings are **advisory
(INFO/WARNING), never CRITICAL**, and never gate the result.

### lat.md alignment (advisory)

When the `lat_search` / `lat_refs` MCP tools are available, checks whether the
intent contradicts documented architectural decisions, or whether Health
Metrics ignore components that reference this area (`lat_refs`). Advisory only.
When lat is unavailable, this is skipped silently (mirroring IDD Step 0) — never
block, never mention the absence.

## Canonical hashing + quick-exit

Reused **verbatim** from `check-spec` — any divergence breaks convergence
because the frontmatter is live and changes each run. The command MUST run these
via the Bash tool; never compute hashes "in head".

- Body hash (excludes frontmatter):
  ```bash
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
  ```
- Section hash: section body from a `##`/`###` heading up to the next heading of
  equal-or-higher level (exclusive), piped through `sha256sum | cut -c1-16`.
- No frontmatter (`fm < 2`) → hash the whole file: `sha256sum <FILE> | cut -c1-16`.

**Quick-exit (Step 0).** If the file has a `review:` block and:

- `current_intent_hash == review.intent_hash`, AND
- `∀ deterministic phase (structure, completeness, clarity, consistency): status == passed`, AND
- `alignment.status == passed` (carried from the prior run — NOT recomputed, since alignment is non-deterministic), AND
- `∀ finding: verdict ∈ {accepted, wontfix, fixed}`, AND
- `count(severity == CRITICAL ∧ verdict == open) == 0`

→ print `OK (cached, hash match)` and stop. Otherwise continue.

## State — frontmatter `review:` block

Added **above** the body. The body (`# Intent:` heading, `**Status:**` line, all
sections) is never edited. On first run the intent doc has no frontmatter, so
the block is inserted, mirroring how `check-spec` retroactively adds frontmatter
to specs.

```yaml
review:
  intent_hash: <sha256 of body>
  last_run: <today>
  phases:
    structure:    { status: pending }
    completeness: { status: pending }
    clarity:      { status: pending }
    consistency:  { status: pending }
    alignment:    { status: pending }   # advisory — outside the CRITICAL gate
  findings: []
```

No `chain:` block is added (the intent is the root). Findings handling is
identical to `check-spec`:

1. Don't duplicate an existing finding with the same `section + text + section_hash`.
2. New findings → `id: F-NNN` (monotonic), `phase`, `severity`, `section`, `section_hash`, `text`, `verdict: open`, `verdict_at: null`.
3. For each existing finding whose `section_hash` changed → reset `verdict: open`.
4. Write the updated frontmatter to the file; report; request verdicts.

## Phases (closed checklists — do NOT extend)

Phases run strictly sequentially. Phase N+1 starts only if phase N has no open
CRITICAL. The advisory `alignment` phase always runs last.

### Phase 1 — structure (CRITICAL)

- Placeholders: `TODO`, `TBD`, `???`, `FIXME`
- All 7 template sections present: Objective, Desired Outcomes, Health Metrics,
  Strategic Context, Constraints, Autonomy Zones, Stop Rules
- Empty bullets / empty sections
- Broken internal section references (§X.Y, `[link](#anchor)`)
- Duplicate section headings

### Phase 2 — completeness (CRITICAL) — IDD-specific, from the Validation checklist

- Every constraint maps to **steering XOR hard** (not both, not neither)
- Autonomy Zones cover all four zones (Full / Guarded / Proposal-first / No
  autonomy), or carry an explicit N/A for a zone
- Stop Rules contain at least one `Done when:` criterion
- Health Metrics is non-empty
- Strategic Context has both `Interacts with:` and a `Priority trade-off:`

### Phase 3 — clarity

- Desired Outcomes are observable / user-facing, NOT implementation steps. An
  outcome phrased as "implemented / code written / function added" →
  **CRITICAL**. Vague-but-still-outcome phrasing → WARNING.
- `Done when:` is a measurable result, not "code written / implemented" →
  **CRITICAL** if it names an implementation act instead of an observable result.
- Health Metrics are measurable (a named metric, not a mood) → WARNING.
- Vague terms without a criterion: «быстро», «удобно», «надёжно»,
  «достаточно», «при необходимости» → WARNING.

### Phase 4 — consistency (CRITICAL for contradictions)

- Section hashes vs the previous run; summary of changed sections.
- Intra-document contradictions: a constraint that contradicts a Desired
  Outcome; a Health Metric that contradicts the Objective → CRITICAL.
- **Status guard:** if the body has `**Status:** approved` while any CRITICAL
  finding is open → finding `[CRITICAL]` "approved but not valid". The command
  does **not** write `Status` itself (read-only on the body).

### Phase 5 — alignment (advisory — INFO/WARNING, NOT a gate)

Does not gate the result and is **not recomputed on a hash-match quick-exit**
(its prior `status: passed` is trusted).

- Conversation: do Objective / Desired Outcomes cover the problem the user
  originally described? Is there an objective the user never asked for? → INFO.
- lat.md: does the intent contradict a documented decision, or do Health Metrics
  ignore components surfaced by `lat_refs`? → WARNING.
- lat unavailable → skip silently. Alignment findings are never CRITICAL.

## Flow (mirrors `check-spec`)

- **Step 0 — Quick exit by state** (see above).
- **Step 1 — Determine scope.** Path from `$ARGUMENTS` if given; else the topic
  is known from conversation → find by name in `docs/superpowers/intents/`; else
  the most recently modified file in `docs/superpowers/intents/`. If none found:
  "Не найден intent doc. Укажи путь: `/check-intent path/to/intent.md`".
- **Step 2 — Confirm file + init state.** "Буду проверять: `<path>`. Верно?"
  After confirmation: read frontmatter, init the `review:` block if absent,
  compute section hashes, reset verdicts for changed sections, update
  `intent_hash` + `last_run`.
- **Step 3 — Run phases** strictly sequentially; each phase: apply its closed
  checklist, create non-duplicate findings, write frontmatter, report, request
  verdicts (CRITICAL mandatory, WARNING desired, INFO optional). All CRITICAL
  closed → `phase.status = passed`, advance; else → `in_progress`, stop with a
  fix-and-rerun message. `alignment` runs last and is advisory.
- **Step 4 — Final verdict.** Apply the Step 0 exit criterion. Output `OK` or
  `требует доработки: <N> critical open, <M> warning open`.

## Report format

```
## Проверка intent [дата]

### Файл
- <path>
- intent_hash: <sha256:short>
- prev_hash: <sha256:short>

### Фаза 1: structure — passed | in_progress | skipped
- Новые findings: N
  - F-001 [CRITICAL] §X — описание

### Фаза 2: completeness — ...
### Фаза 3: clarity — ...
### Фаза 4: consistency — ...
### Фаза 5: alignment — advisory
- INFO/WARNING notes (никогда не блокируют вердикт)

### Approval
- ready to approve | блокировано: N critical open

### Сводка
- CRITICAL open: N
- WARNING open: M
- alignment notes: K
- Вердикт: OK | требует доработки

---
Next step: superpowers:brainstorming
```

## Rules (forbidden — mirrors `check-spec`)

- Extend the phase checklists (closed lists only).
- Invent requirements not present in the intent doc or the conversation.
- Edit the **body** of the intent doc — including `**Status:**` (only a guard
  finding, never a write). Frontmatter `review:` is the sole exception.
- Write "вероятно подразумевается" without a reference to the text.

## File location

`.nvm-isolated/.claude-isolated/commands/check-intent.md` — alongside
`check-spec.md`, `check-plan.md`, `check-result.md`. Invoked as `/check-intent
[path]`.

## Testing / acceptance

1. Run `/check-intent` against an existing valid, approved intent doc (e.g.
   `2026-06-14-cicd-pull-binary-delivery-intent.md`) → after one full pass and
   verdicts, a second run prints `OK (cached, hash match)` without re-running
   phases.
2. Run against an intent doc with a seeded `TODO` and a constraint tagged both
   steering and hard → structure and completeness raise CRITICAL findings; the
   command stops and asks for verdicts before advancing.
3. Run against an intent doc whose `Done when:` says "code written" → clarity
   raises a CRITICAL finding.
4. Body `**Status:** approved` while a CRITICAL is open → consistency raises the
   Status-guard CRITICAL; the body `Status` line is left unchanged.
5. With lat MCP unavailable, alignment runs without error and emits no lat
   findings; the deterministic verdict is unaffected.
6. The body of the intent doc is byte-identical before and after the run except
   for the inserted/updated frontmatter `review:` block.
