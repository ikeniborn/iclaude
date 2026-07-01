---
name: check-chain
description: Use to validate the IDD→SDD chain (intent → spec → plan → result). Triggers on "/check-chain", "check chain", "validate intent/spec/plan/result", and is the remediation the chain-gate hook points to. Runs the whole chain (sequential gate) with no argument, or a single stage with "/check-chain <stage>".
---

# check-chain — unified IDD→SDD chain validator

One skill, two run modes, four stage profiles over one shared core. Replaces the
former `check-intent`, `check-spec`, `check-plan`, `check-result` commands.

## Invocation & argument parsing

```
/check-chain                       → whole chain (sequential gate)
/check-chain <stage>               → that stage only      (stage ∈ intent|spec|plan|result)
/check-chain <stage> <path>        → that stage, explicit file
/check-chain <path>                → infer stage from the file's directory, single-stage
```

Parse `$ARGUMENTS`:
- First token in `intent|spec|plan|result` → the target stage.
- A token that is a path → the explicit artifact file.
- No stage and no path → whole-chain mode.
- A lone path with no stage → resolve the stage from the directory (`intents/`→intent,
  `specs/`→spec, `plans/`→plan). `result` is never inferred from a path (it shares
  `plans/` with `plan`); it must be named explicitly.

## Shared core (applied by every stage)

### Canonical hashing (MANDATORY)

Run bash via the Bash tool; never recompute "in your head".
- **Body hash** (excludes frontmatter):
  ```bash
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
  ```
- **Section hash** — the body from a `##`/`###` heading to the next heading of the same
  or higher level (exclusive), piped through `sha256sum | cut -c1-16`.
- If frontmatter is absent (`fm` < 2) — hash the whole file: `sha256sum <FILE> | cut -c1-16`.

### Step 0 — quick exit by state

If frontmatter has a `review:` block, `current_body_hash == review.<hash_key>` AND every
phase `status == passed` AND no finding with `severity == CRITICAL ∧ verdict == open` →
output `OK (cached, hash match)` and finish. (`result` uses `result_check.verdict == OK`
with a matching `plan_hash`.) Otherwise continue. The advisory `alignment` phase is not
recomputed on a hash match — trust the previous run.

### Step 1 — scope resolution

Locate the stage artifact by: explicit path arg → by `<topic>` in the stage dir → the
most-recently-modified file in the stage dir. If not found, report
«Не найден <stage>. Укажи путь: `/check-chain <stage> path/to/file.md`» and stop.

### Step 2 — confirm & init state

Report «Буду проверять: `<путь>`. Верно?» and, after confirmation: read the frontmatter;
if there is no `review:` block, scaffold one for the stage's phase set; compute section
hashes; reset any finding whose `section_hash` changed to `verdict: open`; update the
stage hash + `last_run`; maintain the `chain:` block for downstream stages
(`spec` → `chain.intent`; `plan` → `chain.intent` + `chain.spec`; `intent` writes none).
Never edit the artifact body — only its frontmatter.

### Step 3 — phase execution & finding-handling

Phases run strictly sequentially; phase N+1 starts only when phase N has no CRITICAL with
`verdict: open`. For each phase apply its **closed checklist** (do NOT extend) to the
body. For each finding: dedupe by `section + text + section_hash`; otherwise create
`id: F-NNN` (monotonic), `phase`, `severity`, `section`, `section_hash`, `fragment`
(≤140-char quote, `null` for structural), `text`, `fix`, `verdict: open`, `verdict_at: null`.
Write the updated frontmatter; report the phase; request verdicts (CRITICAL mandatory
`accepted|wontfix|fixed`, WARNING desirable, INFO optional). All CRITICAL closed →
`phase.status = passed`; else `in_progress`, stop and ask to fix and rerun.

### Step 4 — final verdict

Apply the Step 0 exit criterion: `OK` or «требует доработки: <N> critical open, <M> warning open».

### Step 5 — HTML report

After the verdict (including the cached quick-exit), invoke the `html-report` skill
(`skill: "html-report"`) with `mode: chain`, `tab: <stage>`, output
`docs/superpowers/reports/<topic>-results.html` (one file, four tabs Intent/Spec/Plan/Result;
update only this stage's tab, preserve the others; create all four if absent with the
placeholder «Этап ещё не проверен»; data passed inline; all report text in Russian).
Determine `<topic>`: basename minus `.md`, strip the `^YYYY-MM-DD-` date prefix, strip a
trailing `-intent`/`-design`/`-plan` suffix if present; fallback to the bare basename.

### Step 6 — TODO.md upsert

After the verdict, upsert the chain's row in `docs/TODO.md` keyed by `<topic>` (see the
Task Log convention in `CLAUDE.md`). Create the file with the header row if absent. Mark
this stage's cell `✓` on `OK` (`–` if it still needs work); `intent` opens the row, a
missing upstream stage is `n/a`; `result` on `OK` closes the row (`Result: OK`,
`Status: done`, `Closed: <today>`).

## Rules (prohibited)

- Extending a phase checklist — the closed list keeps the check deterministic and the
  hash-cache reproducible.
- Inventing requirements absent from the source (and the conversation, for `intent`).
- Editing the artifact body (frontmatter is the only exception).
- Writing «вероятно подразумевается» without a textual anchor.
- (`result`) Running a code review — that is `/review`, not this check.

## Stage profiles

| stage | dir | glob | hash key | state block | phases |
|---|---|---|---|---|---|
| intent | intents/ | *-intent.md | intent_hash | review | structure, completeness, clarity, consistency, alignment(advisory) |
| spec | specs/ | *-design.md | spec_hash | review | structure, coverage, clarity, consistency |
| plan | plans/ | *.md | plan_hash | review | structure, coverage, dependencies, verifiability, consistency |
| result | plans/ | *.md | plan_hash | result_check | non-phased: git diff reconciliation |

### intent checklist

#### Phase 1: structure (CRITICAL)

Closed checklist (do NOT extend):
- Placeholders: `TODO`, `TBD`, `???`, `FIXME`
- All 7 template sections present: Objective, Desired Outcomes, Health Metrics, Strategic Context, Constraints, Autonomy Zones, Stop Rules
- Empty bullets / empty sections
- Broken internal section links (§X.Y, [link](#anchor))
- Duplicate section headings

#### Phase 2: completeness (CRITICAL)

Closed checklist (do NOT extend):
- Each constraint is bound to steering XOR hard (not both, not neither)
- Autonomy Zones cover all 4 zones (Full / Guarded / Proposal-first / No autonomy) or carry an explicit N/A for a zone
- Stop Rules contain ≥1 `Done when:` criterion
- Health Metrics are non-empty
- Strategic Context contains both `Interacts with:` and `Priority trade-off:`

#### Phase 3: clarity

Closed checklist (do NOT extend):
- Desired Outcomes are observable / user-facing, NOT implementation steps. An outcome phrased as "implemented / code written / function added" → **CRITICAL**. Observable but vague → WARNING.
- `Done when:` — a measurable result, not "code written". If it names an act of implementation instead of an observable result → **CRITICAL**.
- Health Metrics are measurable (a named metric, not a mood) → WARNING.
- Vague terms without a criterion: «быстро», «удобно», «надёжно», «достаточно», «при необходимости» → WARNING.

#### Phase 4: consistency (CRITICAL for contradictions)

Closed checklist (do NOT extend):
- Use the diff of changed sections from Step 2 (init-state) — do NOT recompute hashes; provide a summary of changes
- Intra-doc contradictions: constraint vs Desired Outcome; Health Metric vs Objective → CRITICAL
- **Status-guard:** if the body contains `**Status:** approved` but there is an open CRITICAL finding → create a `[CRITICAL]` finding «approved, но документ не валиден». Do NOT edit the `**Status:**` line — only the finding.

#### Phase 5: alignment (advisory — INFO/WARNING, NOT a gate, do NOT recompute on hash match)

Closed checklist (do NOT extend). Never emits CRITICAL; never blocks a phase transition or the final verdict:
- Conversation: do Objective and Desired Outcomes cover the original task the user described in the conversation? Is there an objective the user did not ask for? → INFO
- lat.md: does the intent contradict a documented decision, or do Health Metrics ignore components that reference this area (`lat_refs`)? → WARNING. Requires the MCP tools `lat_search` / `lat_refs`.
- If `lat_search` / `lat_refs` are unavailable — skip silently (like IDD Step 0). Do not block, do not mention the absence.

---
Next step: superpowers:brainstorming

### spec checklist

#### Phase 1: structure

Closed checklist (do NOT extend):
- Placeholders: `TODO`, `TBD`, `???`, `FIXME`
- Broken internal section links (§X.Y, [link](#anchor))
- Section numbering (gaps, duplicate numbers)
- Duplicate section headings

#### Phase 2: coverage

Closed checklist:
- Each task from the conversation context is covered by ≥1 spec requirement
- Each spec requirement is bound to a task (no "extras")
- Contradictions between requirements (§X says A, §Y says ¬A)

#### Phase 3: clarity

Closed checklist:
- Ambiguous wording without a criterion: «быстро», «удобно», «при необходимости», «достаточно», «надёжно»
- Requirements without an explicit DoD / acceptance criterion
- Inconsistent terms (one entity — different names)

#### Phase 4: consistency

Closed checklist:
- Use the diff of changed sections already computed in Step 2 (init-state) — do NOT recompute hashes
- Summary of changed sections and related findings

### plan checklist

#### Phase 1: structure

Closed checklist:
- Placeholders: `TODO`, `TBD`, `???`, `FIXME`
- Step/task numbering (gaps, duplicates)
- Duplicate step headings

#### Phase 2: coverage

Closed checklist:
- Each spec requirement is covered by ≥1 plan step
- Each plan step is bound to a spec requirement (no "extras")

#### Phase 3: dependencies

Closed checklist:
- Step order: using the result of step M in step N → M < N
- Cyclic dependencies between steps
- Artifact availability (a file/function mentioned in a step is created in a previous step)

#### Phase 4: verifiability

Closed checklist:
- Each step has a measurable definition of done (DoD)
- Steps with no explicit result ("work through", "study", "improve" without an output)
- Steps with no verification command / expected output

#### Phase 5: consistency

Closed checklist:
- Use the diff of changed plan/spec sections already computed in Step 2 (init-state) — do NOT recompute hashes
- Summary of changed sections

### result reconciliation

#### Step 1. Load the plan

- Read the plan file from `$ARGUMENTS`
- Extract `chain.intent` and `chain.spec` from the frontmatter
- If absent — extract `<topic>` from the plan filename (`YYYY-MM-DD-<topic>-plan.md`) and run:
  ```bash
  find docs/superpowers/intents/ -name "*<topic>*intent.md" 2>/dev/null | head -1
  find docs/superpowers/specs/   -name "*<topic>*design.md" 2>/dev/null | head -1
  ```
- If the plan is not found — report: «Не найден план. Укажи путь: `/check-chain result path/to/plan.md`» and stop
- If the intent or spec is not found — warn the user, continue with the available documents

#### Step 2. Load the documents

- **Intent doc:** read the Objective, Desired Outcomes, Constraints sections
- **Spec:** read the requirements sections and Success Criteria
- **Plan:** read all steps (both `[ ]` and `[x]`)

#### Step 3. Get the git diff

```bash
git diff HEAD
```

If `--since=<ref>` is passed: `git diff <ref>`.

If the diff is empty — report: «Нет незакоммиченных изменений. Запусти после внесения изменений или передай `--since=<ref>`.»

#### Step 4. Match plan steps against the diff

For each plan step:

1. Extract explicit file paths from the step text
2. Check for those files in `git diff HEAD`
3. For steps without explicit paths — semantic matching:
   - `DONE` — the changes in the diff clearly and fully match the step description
   - `PARTIAL` — the diff contains related changes but misses part of the described action (e.g. the step says "rename and rewrite X" but the diff only renames)
   - `MISSING` — there is no evidence of the step in the diff

Additionally — find `EXCESS`: files changed in the diff with no corresponding plan step.

#### Step 5. Check intent + spec coverage

- For each Desired Outcome from the intent doc: is it reflected in the diff?
- For each requirement / Success Criterion from the spec: is it reflected in the diff?
- Uncovered → a finding referencing the specific outcome/requirement

#### Step 6. Build the report

#### Step 7. Write the state into the plan frontmatter

After the report, write a machine-readable block into the **plan frontmatter** (do NOT
touch the plan body — it is the merge-gate pass signal for idd-gate).

1. Compute the plan body hash via the canonical algorithm (see above).
2. Determine the verdict: `OK` if there are no CRITICAL findings (no MISSING steps);
   otherwise `needs_work`.
3. Create the `result_check:` block (or update the existing one) in the plan frontmatter:
   ```yaml
   result_check:
     verdict: OK | needs_work
     plan_hash: <plan body hash>
     last_run: <today>
   ```
   If the plan has no frontmatter — add it at the start of the file
   (`---` … `---`) without changing the body.

#### Severity

| Severity | Condition |
|----------|-----------|
| `[CRITICAL]` | A plan step is entirely absent from the diff |
| `[WARNING]` | A step is partially done; or excess changes with no link to the plan |
| `[INFO]` | A semantic discrepancy; an intent outcome is partially reflected |

## Run modes

### Whole chain (sequential gate) — no stage argument

1. Resolve `<topic>` from the argument or the most-recently-modified artifact; locate
   every existing stage file for that topic.
2. Confirm the set once: «Проверю chain `<topic>`: intent=…, spec=…, plan=…. Верно?»
3. For each stage in `[intent, spec, plan, result]`:
   - artifact absent → record it (`Intent: n/a` etc.) and continue;
   - Step 0 quick-exit passes → `✓ cached`, continue;
   - else run the stage's full Step 1–6 (findings → verdicts → frontmatter → HTML tab → TODO cell);
   - stage ends `needs_work` (open CRITICAL) → STOP: «chain остановлен на `<stage>`,
     почини и перезапусти». Do not run downstream stages.
4. `result` needs a `git diff`. Reached with an empty diff → emit INFO
   «result pending implementation», chain verdict «OK up to plan», leave the TODO
   `Result` cell `–` (not `done`). Non-empty diff → reconcile; on `OK` close the row.
5. Print the chain summary and the path to the HTML report.

### Single stage — `/check-chain <stage> [path]`

Run Step 0–6 for exactly that one stage. This reproduces the former per-command
behaviour 1:1 (same confirmation, findings, verdicts, frontmatter, HTML tab, TODO cell,
footer).
