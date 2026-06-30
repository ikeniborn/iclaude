Check the specification against the tasks, using the phase model and the state in frontmatter.

Supported arguments:
- Path to the specification file — if not provided, the file is resolved automatically
- The tasks are taken from the conversation context

## Algorithm

### Canonical hashing algorithm (MANDATORY)

All hashes via a single pipeline (frontmatter must stay live, otherwise quick-exit won't match). Run bash through the Bash tool; never recompute "in your head".

- **Document body hash** (excludes frontmatter):
  ```bash
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
  ```
- **Section hash** — the section body from a `##`/`###` heading up to the next heading of the same or higher level (exclusive), piped through `sha256sum | cut -c1-16`.
- If frontmatter is absent (`fm` < 2) — hash the whole file: `sha256sum <FILE> | cut -c1-16`.

### Step 0. Quick exit by state

If there is frontmatter with a `review:` block and `current_body_hash == review.spec_hash` AND:
- `∀ phase ∈ phases: status == passed`
- `∀ finding: verdict ∈ {accepted, wontfix, fixed}`
- `count(severity == CRITICAL ∧ verdict == open) == 0`

→ output `OK (cached, hash match)` and finish. Otherwise — continue.

### Step 1. Determine scope

- If the task name/topic is known from context — find the file by name in `docs/superpowers/specs/`
- If a path is passed in `$ARGUMENTS` — work with the specified file
- Otherwise — the most recently modified file in `docs/superpowers/specs/`
- If not found — report: «Не найдена спецификация. Укажи путь: `/check-spec path/to/spec.md`»

Additionally — determine the path to the intent doc:
- If `$ARGUMENTS` contains a second path (to a `*intent.md` file) — use it
- If the intent doc is mentioned in the conversation context — use it
- Otherwise — extract `<topic>` from the spec filename (`YYYY-MM-DD-<topic>-design.md`) and run:
  ```bash
  find docs/superpowers/intents/ -name "*<topic>*intent.md" 2>/dev/null | head -1
  ```
- If not found — remember `intent_path = null`, continue without blocking

### Step 2. Confirm the file and initialize state

1. Report: «Буду проверять: `<путь>`. Верно?»
2. After confirmation:
   - Read the frontmatter. If there is no `review:` block — initialize an empty one:
     ```yaml
     review:
       spec_hash: <sha256 of the body>
       last_run: <today>
       phases:
         structure:    { status: pending }
         coverage:     { status: pending }
         clarity:      { status: pending }
         consistency:  { status: pending }
       findings: []
     ```
   - Compute hashes of all sections (by `##`/`###` headings)
   - For each existing finding whose `section_hash != current_section_hash` — reset `verdict: open`
   - Update `spec_hash` and `last_run`
   - If there is no `chain:` block in the frontmatter — add:
     ```yaml
     chain:
       intent: <intent_path or null>
     ```
   - If `chain:` already exists — update `chain.intent` to the resolved value

### Step 3. Phase execution

Phases run strictly sequentially. Phase N+1 starts only if phase N has no CRITICAL with `verdict: open`.

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

### Finding-handling logic in each phase

1. Read this phase's existing findings from frontmatter
2. Apply the phase checklist to the spec body
3. For each potential finding:
   - If a finding already exists with the same `section` and matching `text` AND `section_hash` is unchanged → do NOT duplicate
   - Otherwise — create a new one: `id: F-NNN` (monotonically next), `phase`, `severity`, `section`, `section_hash`, `fragment` (a quote of the offending text from the section, ≤140 chars; `null` for a structural finding without a specific line), `text` (what the problem is), `fix` (proposed fix), `verdict: open`, `verdict_at: null`
4. Write the updated frontmatter to the file
5. Output the phase report
6. Ask the user for a verdict on the new findings:
   - CRITICAL — mandatory (`accepted | wontfix | fixed`)
   - WARNING — desirable
   - INFO — optional
7. Record the verdicts. If all CRITICAL of the phase are closed → `phase.status = passed`, move to the next
8. Otherwise → `phase.status = in_progress`, stop and ask to fix and rerun

### Step 4. Final verdict

Apply the exit criterion from Step 0. Output `OK` or «требует доработки: <N> critical open, <M> warning open».

### Step 5. HTML report for the user

After the final verdict (including the quick-exit branch `OK (cached, hash match)`) invoke the `html-report` skill via the Skill tool (`skill: "html-report"`) and assemble one self-contained `.html` — a human-readable artifact for the user.

Report goal: describe the spec's **solution** with diagrams and show the **dependencies** of its parts with graphs, not just list findings. Pass the skill three blocks (all mandatory):

1. **Резюме спецификации** — requirements (by section) and Success Criteria; each requirement on its own table row.
2. **Схемы решения и зависимостей** (mandatory; use the skill's CSS block/flow or C4 diagrams, and an SVG node-edge graph for arbitrary edges):
   - **Схема решения** — a block/flow or C4 diagram of the components/modules of the solution described by the spec and their links (data/control flow).
   - **Граф зависимостей** — an SVG node-edge graph: **nodes** are individual spec requirements/components (each labeled), **edges** are directed "depends on" / "uses" (A→B = A depends on B). Highlight cycles if the graph has any.
   - **Карта покрытия** — a matrix/table "task → spec requirement(s)" that cover it.
3. **Результаты проверки** — for each of the 4 phases (structure / coverage / clarity / consistency) its `status`; a findings table (`id`, `severity`, `section`, `fragment`, `text`, `fix`, `verdict`); a summary (CRITICAL open / WARNING open); the final verdict; the chain (`intent → spec`, if `intent_path` is known).

**Determine `<topic>` (the shared chain key — all 4 `check-*` commands must converge on one file).** Take the basename of the specification file without `.md`, then:
1. strip the date prefix `^[0-9]{4}-[0-9]{2}-[0-9]{2}-`;
2. strip the stage suffix — `-intent`, `-design`, or `-plan` — **if present** (on a plan `-plan` is optional: `…-foo.md` and `…-foo-plan.md` both yield one `<topic> = foo`);
3. the remainder is `<topic>`.
**Fallback:** if the basename is not recognized (no date/suffix matching the pattern) — `<topic>` = the basename without `.md` as-is. Do NOT include the date in `<topic>` (chain stages may have different dates).

Artifact parameters (pass them to the skill explicitly):
- **Mode:** `mode: chain`, `tab: spec`. The skill updates ONLY the `spec` tab; it preserves the other 3 tabs (Intent / Spec / Plan / Result) verbatim. If the file does not exist — it creates all 4 (unvisited ones with the placeholder «Этап ещё не проверен»).
- **Output path (explicit argument):** `docs/superpowers/reports/<topic>-results.html` — a single chain report, without a subdirectory and without a date prefix. This is a caller-supplied path (Full zone): the skill creates the `docs/superpowers/reports/` directory if absent; the first run creates the file with 4 tabs, a rerun merges only its own tab.
- **Data — inline:** the three blocks above are passed in the call itself. The skill does NOT read the sources itself and does NOT halt over an "unreadable source" — the data is already provided.
- Language — Russian: all report text (headings, descriptions, findings, summaries) is in Russian.

After writing, tell the user the path to the `.html`.

### Step 6. Register the task in docs/TODO.md

After the final verdict (including the quick-exit branch `OK (cached, hash match)`), upsert this chain's task into `docs/TODO.md` — see the **Task Log** section in CLAUDE.md for the table format. Key the row by the `<topic>` determined in Step 5:
- If `docs/TODO.md` is absent — create it with the header row first.
- If no row for `<topic>` exists yet (no intent was checked) — append one with `Status: in-progress`, `Intent: n/a`, `Opened: <today>`; this is the case where the spec opens the task.
- Mark `Spec: ✓` when the verdict is `OK` (`–` if it still needs work); keep `Status: in-progress`.

## Rules

**Prohibited:**
- Extending the phase checklists (closed list only) — an open list makes the check non-deterministic and breaks the hash-cache/quick-exit, so findings are not reproducible between runs
- Inventing tasks that were not in the original description — the validator checks the spec against the given tasks, it does not invent them; an extra task = a false finding the author cannot close
- Editing the specification body (frontmatter is the exception, updated by the command) — the body is the check input; editing it invalidates hashes and mixes the reviewer and author roles
- Writing «вероятно подразумевается» without a reference to the text — a finding without a textual anchor is unprovable and the author cannot resolve it

## Report format

```
## Проверка спецификации [дата]

### Файл
- <путь>
- spec_hash: <sha256:short>
- prev_hash: <sha256:short>

### Фаза 1: structure — passed | in_progress | skipped
- Новые findings: N
  - F-001 [CRITICAL] §X.Y — <text>
    - fragment: «<цитата>» (или «—» для структурных находок)
    - fix: <предложение>

### Фаза 2: coverage — ...
### Фаза 3: clarity — ...
### Фаза 4: consistency — ...

### Сводка
- CRITICAL open: N
- WARNING open: M
- Вердикт: OK | требует доработки
```

If `intent_path` is known — append to the end of the report:
```
---
Previous step: <intent_path>
```

$ARGUMENTS
