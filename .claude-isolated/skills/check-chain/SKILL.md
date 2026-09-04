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
- `result` accepts either artifact: a plan (`full` route) or an intent (`execute` route,
  where no plan is written). `/check-chain result docs/superpowers/intents/<...>-intent.md`
  runs the reconciliation against the intent — see «result reconciliation».

## Shared core (Steps 0–4 and 6 apply to every stage; Step 5 is result-only)

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

### Step 5 — HTML report (result stage only)

Runs ONLY for the `result` stage, and only when the reconciled `git diff` is
non-empty. The `intent` / `spec` / `plan` stages produce NO HTML — they end after
Step 4 (verdict) and Step 6 (wiki task page). On an empty diff, `result` emits INFO
«result pending implementation» and produces no report.

After the result verdict, invoke the `html-report` skill (`skill: "html-report"`) in
its **default `standalone` mode** (NOT `mode: chain`) with output
`docs/superpowers/reports/<topic>-results.html` — one self-contained single-page
report, all text in Russian. The explicit caller-supplied path is the `html-report`
**Full** autonomy zone: create / overwrite (whole regeneration) without asking.
Determine `<topic>`: basename minus `.md`, strip the `^YYYY-MM-DD-` date prefix, strip
a trailing `-intent`/`-design`/`-plan` suffix if present; fallback to the bare basename.

**Report content contract (MANDATORY — the report explains the implementation
outcome, it is NOT a bare findings dump).** Pass every block below inline in the skill
call. Sections 1–4 are always present; section 5 is conditional (see the diagram
trigger). Use the `html-report` grammar: CSS block/flow + C4 (`references/css-diagrams.md`),
SVG node-edge graphs for looping / non-adjacent edges (`references/svg-diagrams.md`).

1. **Резюме внедрения** — `<topic>`; links to the chain docs (intent / spec / plan
   paths, `n/a` for a missing one); the diff base (`HEAD`, or `<ref>` when
   `--since=<ref>` was passed).
2. **Выполненные изменения** — a per-file table from the diff: path, change kind
   (added / modified / deleted), ± lines, and a one-line description of what the
   change does.
3. **Результаты** — the plan↔diff reconciliation from the result profile: per-step
   status (DONE / PARTIAL / MISSING) with diff evidence; intent Desired-Outcomes
   coverage N/M; spec requirements coverage N/M; excess changes (files changed with no
   matching plan step); the final verdict.
4. **Влияние на систему** — a table of what the change affects: components / files
   touched, behavioural changes, and risks / follow-ups (sourced from the diff and the
   intent's Desired Outcomes).
5. **Схемы** *(conditional — include ONLY when the structural-change trigger below
   fires)* — architecture / change-flow and/or an impact map
   (changed components → affected areas).

**Diagram trigger (closed checklist — evaluate against the diff).** Include section 5
when the diff does at least one of:
- adds a new module / file / component (a new source file, or a new public
  function/class other code will call), OR
- adds or changes dependency edges between components (new import/require wiring, a
  changed cross-module call graph), OR
- introduces a new data-flow / control-flow / state machine.
Otherwise (a point bugfix, a text/comment/config tweak, or edits contained within
existing files with no new cross-component wiring) → sections 1–4 only, no diagram.

### Step 6 — wiki task page (parent session only)

This step writes the wiki and therefore runs in the parent session — subagents are
read-only against the wiki (`wiki_search`, `wiki_read_page`, `wiki_related`). If the check
itself was delegated, the subagent returns the verdict, the findings and the proposed
event line, and the parent performs Step 6.

After the verdict, record the gate on the topic's wiki page
`reference/tasks/<topic>` in the domain reported by `wiki_status.primary` (see the
Task Log convention in `CLAUDE.md`). If the page is absent, create it with
`wiki_write_page` and the five required sections; otherwise `wiki_read_page` the
section you are about to change, then `wiki_update_page` it in full.

- Append one `verification` event to the `Events` section of the active history segment named in `Changelog` — `reference/task-history/<topic>-<sequence>`, created with the same frontmatter when absent: `- <today> — verification — <stage> <verdict> — key:<key>`, where `<key>` is derived from topic, event kind, and a hash of the recorded evidence. Skip the append when that key is already present in the segment chain. At 20 events open the next segment and point the current one's `Next` at it.
- Refresh the `Changelog` manifest on the task page (first segment, active segment, event count) — never copy the events themselves there.
- Tick the stage's line in `TODO`.
- On `result` `OK`: set `Current State` `Lifecycle: done` and `Closed: <today>`, and append the `close` event — but only after every queued event is delivered and `wiki_lint` reports no new finding for the task page or its segments, the expected `orphan` advisory for `reference/tasks/*` and `reference/task-history/*` aside. Otherwise set `Lifecycle: completion-pending`.
- If the MCP server is unreachable, append the event to the spool with the `task-ledger` skill's `scripts/task_spool.py` at `$CLAUDE_CONFIG_DIR/state/iwiki-task-spool/<project>/<topic>.json`, report `Tracking: unavailable`, and continue — the stage verdict itself is never blocked by the wiki channel.

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
| result (`full`) | plans/ | *.md | plan_hash | result_check | non-phased: git diff reconciliation |
| result (`execute`) | intents/ | *-intent.md | intent_hash | result_check | non-phased: git diff reconciliation against the intent |

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
- iwiki: does the intent contradict a documented decision, or do Health Metrics ignore components that reference this area? → WARNING. Requires the iwiki MCP tools `wiki_search` / `wiki_related` (apply the iwiki Project Binding protocol from `CLAUDE.md` first).
- If the iwiki MCP server / `wiki_search` are unavailable — skip silently (like IDD Step 0). Do not block, do not mention the absence.

---
Next step: report the continuation decision (`execute` or `full`) with evidence and wait
for the user (see Workflow Route Selection in `CLAUDE.md`). `execute` implements straight
from the approved intent and ends with `/check-chain result <intent>`; only `full` goes on
to `superpowers:brainstorming`.

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

#### Step 0. Pick the reconciliation source (plan or intent)

The `result` stage reconciles the diff against the **latest approved artifact of the
chosen continuation**:

- `full` route → the plan (`docs/superpowers/plans/`). Steps 1–7 below apply as written.
- `execute` route → the intent (`docs/superpowers/intents/`), because `execute` marks Spec
  and Plan `n/a` and writes neither. Resolution order: the explicit `$ARGUMENTS` path → a
  plan for `<topic>` → the intent for `<topic>`. If neither exists, report «Не найден ни
  план, ни интент. Укажи путь: `/check-chain result path/to/artifact.md`» and stop.

In intent mode the reconciliation unit is the **Desired Outcome**, not the plan step: read
Objective, Desired Outcomes, Constraints and Stop Rules, then run Steps 3–7 with each
Desired Outcome in place of a plan step (`DONE` / `PARTIAL` / `MISSING`, plus `EXCESS` for
changed files no outcome accounts for). Step 7 writes `result_check` into the **intent**
frontmatter with `intent_hash` instead of `plan_hash`. Skip Step 2's spec lookup.

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

#### Step 5b. Check GWT specification coverage

Wiki scenarios, not the chain's design spec. Run this only when the diff changes observable
domain behavior (a public contract, a business invariant, a bug reproduction) **and** the
bound domain's `wiki_status` `specifications` record reports a mode other than `disabled`.

- `wiki_spec_search(query="<changed behavior>")` — is a scenario already covering it?
- Found → `wiki_spec_context(domain, scenario_id)`: freshness `stale_spec` or `stale_graph`,
  or a binding that no longer points at the changed code, is a finding.
- Not found for new observable behavior → a finding naming the behavior. `strict` mode makes
  it `[CRITICAL]` (that domain blocks the next mutation of the specification page); `optional`
  makes it `[WARNING]`.
- This skill never authors or resolves a scenario — report the gap; the parent writes it per
  **Keep Specifications Current** in `CLAUDE.md`.
- No behavior change, `mode: "disabled"`, or an unreachable server → skip silently, no finding.

#### Step 6. Build the report

#### Step 7. Write the state into the plan frontmatter

After the report, write a machine-readable block into the frontmatter of the
reconciliation source (do NOT touch its body — the block is the merge-gate pass signal
read by `hooks/chain-gate.py`).

1. Compute the body hash of the reconciliation source via the canonical algorithm (see above).
2. Determine the verdict: `OK` if there are no CRITICAL findings (no MISSING steps /
   outcomes); otherwise `needs_work`.
3. Create the `result_check:` block (or update the existing one) in that artifact's
   frontmatter — the plan in `full` mode, the intent in `execute` mode:
   ```yaml
   result_check:
     verdict: OK | needs_work
     plan_hash: <plan body hash>      # full route
     # intent_hash: <intent body hash>  # execute route — use this key instead
     last_run: <today>
   ```
   If the artifact has no frontmatter — add it at the start of the file
   (`---` … `---`) without changing the body. The `chain-gate` hook reads exactly this
   block when `superpowers:finishing-a-development-branch` is invoked.

#### Severity

| Severity | Condition |
|----------|-----------|
| `[CRITICAL]` | A plan step is entirely absent from the diff; or new observable behavior has no GWT scenario in a `strict` domain |
| `[WARNING]` | A step is partially done; excess changes with no link to the plan; or a missing / stale GWT scenario in an `optional` domain |
| `[INFO]` | A semantic discrepancy; an intent outcome is partially reflected |

## Run modes

### Whole chain (sequential gate) — no stage argument

1. Resolve `<topic>` from the argument or the most-recently-modified artifact; locate
   every existing stage file for that topic.
2. Confirm the set once: «Проверю chain `<topic>`: intent=…, spec=…, plan=…. Верно?»
3. For each stage in `[intent, spec, plan, result]`:
   - artifact absent → record it (`Intent: n/a` etc.) and continue;
   - Step 0 quick-exit passes → `✓ cached`, continue;
   - else run the stage's Steps 1–4 + 6 (findings → verdicts → frontmatter → wiki task page); the `result` stage additionally runs Step 5 (single-page HTML report);
   - stage ends `needs_work` (open CRITICAL) → STOP: «chain остановлен на `<stage>`,
     почини и перезапусти». Do not run downstream stages.
4. When `spec` and `plan` are both `n/a` (the `execute` route), `result` reconciles
   against the intent per Step 0 of the result profile.
5. `result` needs a `git diff`. Reached with an empty diff → emit INFO
   «result pending implementation», chain verdict «OK up to plan», leave the page's
   `Lifecycle` at `completion-pending` (not `done`). Non-empty diff → reconcile; on `OK`
   close the task page per Step 6 (`Lifecycle: done`, `Closed: <today>`).
6. Print the chain summary, and the path to the HTML report when the `result` stage produced one.

### Single stage — `/check-chain <stage> [path]`

Run Steps 0–4 + 6 for exactly that one stage (confirmation, findings, verdicts,
frontmatter, wiki task page, footer). Only `/check-chain result` additionally runs Step 5
to produce the single-page HTML report; `/check-chain intent|spec|plan` produce no HTML.
