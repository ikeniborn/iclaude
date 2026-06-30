Check the intent doc (root of the IDD→SDD chain) for self-consistency, using the phase model and the state in frontmatter.

Supported arguments:
- Path to the intent doc file — if not provided, the file is resolved automatically
- Conversation context is used by the advisory `alignment` phase

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

If there is frontmatter with a `review:` block and `current_body_hash == review.intent_hash` AND:
- `∀ phase ∈ {structure, completeness, clarity, consistency}: status == passed`
- `alignment.status == passed` (do NOT recompute — the phase is non-deterministic, trust the previous run)
- `∀ finding: verdict ∈ {accepted, wontfix, fixed}`
- `count(severity == CRITICAL ∧ verdict == open) == 0`

→ output `OK (cached, hash match)` and finish. Otherwise — continue.

### Step 1. Determine scope

- If a path is passed in `$ARGUMENTS` — work with the specified file
- Otherwise, if the task topic is known from context — find the file by name in `docs/superpowers/intents/`
- Otherwise — the most recently modified file in `docs/superpowers/intents/`
- If not found — report: «Не найден intent doc. Укажи путь: `/check-intent path/to/intent.md`»

The intent doc is the **root of the IDD→SDD chain**. There is no upstream document, so the `chain:` block is NOT added. The report footer looks forward (to brainstorm), not backward.

### Step 2. Confirm the file and initialize state

1. Report: «Буду проверять: `<путь>`. Верно?»
2. After confirmation:
   - Read the frontmatter. If there is no `review:` block — initialize:
     ```yaml
     review:
       intent_hash: <sha256 of the body>
       last_run: <today>
       phases:
         structure:    { status: pending }
         completeness: { status: pending }
         clarity:      { status: pending }
         consistency:  { status: pending }
         alignment:    { status: pending }   # advisory — outside the CRITICAL gate
       findings: []
     ```
   - Compute hashes of all sections (by `##`/`###` headings)
   - For each existing finding whose `section_hash != current_section_hash` — reset `verdict: open`
   - Update `intent_hash` and `last_run`
   - Do NOT add a `chain:` block (root of the chain)
   - Do NOT edit the intent doc body (including the `**Status:**` line) under any circumstances

### Step 3. Phase execution

Phases run strictly sequentially. Phase N+1 starts only if phase N has no CRITICAL with `verdict: open`. The `alignment` phase is always last and advisory — it does not block the transition or the final verdict.

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

### Finding-handling logic in each phase

1. Read this phase's existing findings from frontmatter
2. Apply the phase checklist to the intent doc body
3. For each potential finding:
   - If a finding already exists with the same `section` and matching `text` AND `section_hash` is unchanged → do NOT duplicate
   - Otherwise — create a new one: `id: F-NNN` (monotonically next), `phase`, `severity`, `section`, `section_hash`, `fragment` (a quote of the offending text from the section, ≤140 chars; `null` for a structural finding without a specific line), `text` (what the problem is), `fix` (proposed fix), `verdict: open`, `verdict_at: null`
4. Write the updated frontmatter to the file
5. Output the phase report
6. Ask the user for a verdict on the new findings:
   - CRITICAL — mandatory (`accepted | wontfix | fixed`)
   - WARNING — desirable
   - INFO — optional
7. Record the verdicts. If all CRITICAL of the phase are closed → `phase.status = passed`, move to the next. The `alignment` phase has no CRITICAL → after a run it is always `passed`.
8. Otherwise → `phase.status = in_progress`, stop and ask to fix and rerun

### Step 4. Final verdict

Apply the exit criterion from Step 0. Output `OK` or «требует доработки: <N> critical open, <M> warning open».

### Step 5. HTML report for the user

After the final verdict (including the quick-exit branch `OK (cached, hash match)`) invoke the `html-report` skill via the Skill tool (`skill: "html-report"`) and assemble one self-contained `.html` — a human-readable artifact for the user.

Report goal: describe the **requirements and intentions** of the intent doc and show the **process** of achieving them with diagrams, not just list findings. Pass the skill three blocks (all mandatory):

1. **Резюме требований** — the intent doc's intentions as requirements: Objective, Desired Outcomes, Health Metrics, Constraints (steering / hard), Autonomy Zones, Stop Rules. Each Desired Outcome and Constraint on its own table row.
2. **Схемы намерений и процесса** (mandatory; use the skill's CSS diagrams, and an SVG graph for arbitrary edges):
   - **Карта намерения** — a block/flow diagram of the flow `Objective → Desired Outcomes → Health Metrics`: how the intention turns into an observable result and what measures it.
   - **Граф автономии** — a block diagram of the 4 zones (Full / Guarded / Proposal-first / No autonomy) with the items in each; an empty zone is marked `N/A`.
   - **Связь ограничений и результатов** — a `Constraint × Desired Outcome` matrix: rows are Constraints (steering / hard), columns are Desired Outcomes, with an explicit mark in a cell where a constraint limits an outcome (empty cell = no link).
   - **Stop Rules** — a list of `Done when:` criteria as process-completion conditions.
3. **Результаты проверки** — for each of the 5 phases (structure / completeness / clarity / consistency / alignment) its `status`; a findings table (`id`, `severity`, `section`, `fragment`, `text`, `fix`, `verdict`); a summary (CRITICAL open / WARNING open / alignment notes); the final verdict; the intent is the root of the chain, the footer looks forward (`Next step: superpowers:brainstorming`).

**Determine `<topic>` (the shared chain key — all 4 `check-*` commands must converge on one file).** Take the basename of the intent doc file without `.md`, then:
1. strip the date prefix `^[0-9]{4}-[0-9]{2}-[0-9]{2}-`;
2. strip the stage suffix — `-intent`, `-design`, or `-plan` — **if present** (on a plan `-plan` is optional: `…-foo.md` and `…-foo-plan.md` both yield one `<topic> = foo`);
3. the remainder is `<topic>`.
**Fallback:** if the basename is not recognized (no date/suffix matching the pattern) — `<topic>` = the basename without `.md` as-is. Do NOT include the date in `<topic>` (chain stages may have different dates).

Artifact parameters (pass them to the skill explicitly):
- **Mode:** `mode: chain`, `tab: intent`. The skill updates ONLY the `intent` tab; it preserves the other 3 tabs (Intent / Spec / Plan / Result) verbatim. If the file does not exist — it creates all 4 (unvisited ones with the placeholder «Этап ещё не проверен»).
- **Output path (explicit argument):** `docs/superpowers/reports/<topic>-results.html` — a single chain report, without a subdirectory and without a date prefix. This is a caller-supplied path (Full zone): the skill creates the `docs/superpowers/reports/` directory if absent; the first run creates the file with 4 tabs, a rerun merges only its own tab.
- **Data — inline:** the three blocks above are passed in the call itself. The skill does NOT read the sources itself and does NOT halt over an "unreadable source" — the data is already provided.
- Language — Russian: all report text (headings, descriptions, findings, summaries) is in Russian.

After writing, tell the user the path to the `.html`.

### Step 6. Register the task in docs/TODO.md

After the final verdict (including the quick-exit branch `OK (cached, hash match)`), upsert this chain's task into `docs/TODO.md` — see the **Task Log** section in CLAUDE.md for the table format. Key the row by the `<topic>` determined in Step 5. The intent is the root of the chain, so this run normally **opens** the task:
- If `docs/TODO.md` is absent — create it with the header row first.
- If no row for `<topic>` exists — append one: `Status: in-progress`, `Opened: <today>`, `Closed:` empty, `Spec`/`Plan`/`Result: –`, and `Intent: ✓` when the verdict is `OK` (`–` if it still needs work).
- If a row already exists — update only its `Intent` cell; do not change `Opened`.
- Do NOT edit the intent doc body for this — only `docs/TODO.md`.

## Rules

**Prohibited:**
- Extending the phase checklists (closed list only) — an open list makes the check non-deterministic and breaks the hash-cache/quick-exit, so findings are not reproducible between runs
- Inventing requirements absent from both the intent doc and the conversation context — the validator checks against the source, it does not generate; an invented requirement = a false finding the author cannot close
- Editing the intent doc body, including the `**Status:**` line (a guard-finding only, not a write) — the body is the check input and the signal for the other chain commands; editing it invalidates hashes and mixes the reviewer and author roles. The `review:` frontmatter is the only exception, updated by the command
- Writing «вероятно подразумевается» without a reference to the text — a finding without a textual anchor is unprovable and the author cannot resolve it

## Report format

```
## Проверка intent [дата]

### Файл
- <путь>
- intent_hash: <sha256:short>
- prev_hash: <sha256:short>

### Фаза 1: structure — passed | in_progress | skipped
- Новые findings: N
  - F-001 [CRITICAL] §X — <text>
    - fragment: «<цитата>» (или «—» для структурных находок)
    - fix: <предложение>

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
```

Append to the end of the report (intent is the root of the chain, the footer looks forward):
```
---
Next step: superpowers:brainstorming
```

$ARGUMENTS
