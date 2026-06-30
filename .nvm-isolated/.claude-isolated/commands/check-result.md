Reconcile the plan's execution results with the IDD→SDD chain: intent + spec + plan vs git diff.

Supported arguments:
- Path to the plan file — mandatory
- `--since=<ref>` — use the diff from the given ref instead of HEAD

## Algorithm

### Canonical hashing algorithm (MANDATORY)

The plan body hash for `result_check.plan_hash` — via the same pipeline used by the other validators and by idd-gate (otherwise the merge-gate won't match). Run bash through the Bash tool; never recompute "in your head":

```bash
awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <PLAN_FILE> | sha256sum | cut -c1-16
```

### Step 1. Load the plan

- Read the plan file from `$ARGUMENTS`
- Extract `chain.intent` and `chain.spec` from the frontmatter
- If absent — extract `<topic>` from the plan filename (`YYYY-MM-DD-<topic>-plan.md`) and run:
  ```bash
  find docs/superpowers/intents/ -name "*<topic>*intent.md" 2>/dev/null | head -1
  find docs/superpowers/specs/   -name "*<topic>*design.md" 2>/dev/null | head -1
  ```
- If the plan is not found — report: «Не найден план. Укажи путь: `/check-result path/to/plan.md`» and stop
- If the intent or spec is not found — warn the user, continue with the available documents

### Step 2. Load the documents

- **Intent doc:** read the Objective, Desired Outcomes, Constraints sections
- **Spec:** read the requirements sections and Success Criteria
- **Plan:** read all steps (both `[ ]` and `[x]`)

### Step 3. Get the git diff

```bash
git diff HEAD
```

If `--since=<ref>` is passed: `git diff <ref>`.

If the diff is empty — report: «Нет незакоммиченных изменений. Запусти после внесения изменений или передай `--since=<ref>`.»

### Step 4. Match plan steps against the diff

For each plan step:

1. Extract explicit file paths from the step text
2. Check for those files in `git diff HEAD`
3. For steps without explicit paths — semantic matching:
   - `DONE` — the changes in the diff clearly and fully match the step description
   - `PARTIAL` — the diff contains related changes but misses part of the described action (e.g. the step says "rename and rewrite X" but the diff only renames)
   - `MISSING` — there is no evidence of the step in the diff

Additionally — find `EXCESS`: files changed in the diff with no corresponding plan step.

### Step 5. Check intent + spec coverage

- For each Desired Outcome from the intent doc: is it reflected in the diff?
- For each requirement / Success Criterion from the spec: is it reflected in the diff?
- Uncovered → a finding referencing the specific outcome/requirement

### Step 6. Build the report

### Step 7. Write the state into the plan frontmatter

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

### Step 8. HTML report for the user

After writing `result_check`, invoke the `html-report` skill via the Skill tool (`skill: "html-report"`) and assemble one self-contained `.html` — a human-readable artifact for the user.

Pass the skill the data (both blocks mandatory):

1. **Резюме сверки** — the chain documents (plan / spec / intent), the diff base.
2. **Результаты проверки** — plan step coverage (DONE / PARTIAL / MISSING counts); a findings table (`severity`, step, Plan / Diff / Fix options); intent / spec coverage (Desired Outcomes N/M, requirements N/M); excess changes; a summary (CRITICAL / WARNING / INFO); the verdict; the chain (`intent → spec → plan`).

**Determine `<topic>` (the shared chain key — all 4 `check-*` commands must converge on one file).** Take the basename of the plan file without `.md`, then:
1. strip the date prefix `^[0-9]{4}-[0-9]{2}-[0-9]{2}-`;
2. strip the stage suffix — `-intent`, `-design`, or `-plan` — **if present** (on a plan `-plan` is optional: `…-foo.md` and `…-foo-plan.md` both yield one `<topic> = foo`);
3. the remainder is `<topic>`.
**Fallback:** if the basename is not recognized (no date/suffix matching the pattern) — `<topic>` = the basename without `.md` as-is. Do NOT include the date in `<topic>` (chain stages may have different dates).

Artifact parameters (pass them to the skill explicitly):
- **Mode:** `mode: chain`, `tab: result`. The skill updates ONLY the `result` tab; it preserves the other 3 tabs (Intent / Spec / Plan / Result) verbatim. If the file does not exist — it creates all 4 (unvisited ones with the placeholder «Этап ещё не проверен»).
- **Output path (explicit argument):** `docs/superpowers/reports/<topic>-results.html` — a single chain report, without a subdirectory and without a date prefix. This is a caller-supplied path (Full zone): the skill creates the `docs/superpowers/reports/` directory if absent; the first run creates the file with 4 tabs, a rerun merges only its own tab.
- **Data — inline:** both blocks above are passed in the call itself. The skill does NOT read the sources itself and does NOT halt over an "unreadable source" — the data is already provided.
- Language — Russian: all report text (headings, descriptions, findings, summaries) is in Russian.

After writing, tell the user the path to the `.html`.

### Step 9. Close the task in docs/TODO.md

After the HTML report, update this chain's task in `docs/TODO.md` — see the **Task Log** section in CLAUDE.md for the table format. Key the row by the `<topic>` determined in Step 8:
- If no row for `<topic>` exists — append one first (upsert), marking unchecked stages `n/a`.
- On verdict `OK`: set `Result: OK`, `Status: done`, `Closed: <today>`.
- On verdict `needs_work`: set `Result: needs_work`, keep `Status: in-progress`, leave `Closed` empty.
- This is the only command that closes a task; do NOT edit the plan body for this — only `docs/TODO.md`.

## Severity

| Severity | Condition |
|----------|-----------|
| `[CRITICAL]` | A plan step is entirely absent from the diff |
| `[WARNING]` | A step is partially done; or excess changes with no link to the plan |
| `[INFO]` | A semantic discrepancy; an intent outcome is partially reflected |

## Finding format

Each finding contains:
- **Plan:** what the plan step says
- **Diff:** what the git diff shows (or «изменений не найдено»)
- **Fix options:** fix options

## Report format

```
## Result Check [дата]

### Documents
- Plan:   <путь> (chain.intent: <путь>, chain.spec: <путь>)
- Spec:   <путь> или «не найдена»
- Intent: <путь> или «не найден»
- Diff base: git diff HEAD (<N> файлов изменено)

### Plan Step Coverage
- DONE:    N шагов
- PARTIAL: N шагов
- MISSING: N шагов

### Findings

#### [CRITICAL] Шаг N: <название шага>
**Plan:** <текст шага>
**Diff:** <что найдено в diff или «изменений не найдено»>
**Fix options:**
  1. <конкретное действие>
  2. <альтернатива>

### Intent / Spec Coverage
- Desired Outcomes покрыто: N/M
- Spec requirements покрыто: N/M
- [WARNING] Desired Outcome «...» — свидетельств в diff нет

### Excess Changes
- [WARNING] `path/to/file` изменён — нет соответствующего шага плана

### Summary
- CRITICAL: N  WARNING: N  INFO: N
- Вердикт: OK | требует доработки

---
Previous step: <plan_path>
Chain: <intent_path> → <spec_path> → <plan_path>
```

## Rules

**Prohibited:**
- Emitting a finding without a reference to a specific plan step or outcome — an unanchored finding is unprovable and the author cannot resolve it
- Running a code review (syntax, security) — that is not this command's purpose; it duplicates `/review` and dilutes the plan↔diff reconciliation focus
- Writing «вероятно выполнено» without evidence in the diff — a verdict without evidence yields a false OK and lets an unfinished step slip through

$ARGUMENTS
