# check-{intent,spec,plan,result} Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the HTML-report contract, even out the diagram/dependency requests, trim restated prose, and remove one duplicated validation step across the four IDD validator commands and the `html-report` skill they call.

**Architecture:** Pure prompt/markdown edits. The four `check-*.md` files are command prompts executed by a clean-context subagent that reads exactly ONE file; `html-report/SKILL.md` is a shared skill. No code, no tests in the pytest sense — each task verifies with `grep`/`diff` assertions, and a final task runs one command end-to-end through a subagent to confirm the skill no longer refuses the caller-supplied path.

**Tech Stack:** Markdown command prompts, the `html-report` skill, `idd-gate.py` frontmatter contract, bash `sha256sum` hashing pipeline.

## Global Constraints

- Bash commands inside the hashing block are copied **verbatim** — never altered (any drift breaks the quick-exit hash convergence and the `idd-gate.py` merge gate).
- The `review:` / `result_check:` frontmatter contract stays byte-compatible with `hooks/idd-gate.py`.
- Each command file stays **self-contained**: no command may instruct reading another command file. No `_check-common.md` extraction.
- Cross-file duplication of the hashing block is kept on purpose — do NOT factor it out.
- The phase checklists are closed ("do NOT extend"); the ONLY permitted change is Area D, which **removes** the duplicated hash-recompute line from the `consistency` phase.
- Report bodies the commands emit stay in Russian (unchanged); this plan, code comments, and commit messages are English.
- Final `git diff` must touch only the four `check-*.md` files and `html-report/SKILL.md` — nothing else.
- Work on the `dev` branch; merge to `master` only via PR.

**Path reference (all paths relative to repo root `/home/ikeniborn/Documents/Project/iclaude`):**
- Commands dir: `.nvm-isolated/.claude-isolated/commands/`
- Skill: `.nvm-isolated/.claude-isolated/skills/html-report/SKILL.md`

---

### Task 1: `html-report` skill — caller-supplied output path + drop broken gold-ref (A1, A3)

The skill must be fixed FIRST: the commands (Tasks 2–5) tell it to write outside `docs/reports/`, which the skill currently classifies as No-go → refuse. Until the skill accepts a caller path, an end-to-end run would have the skill refuse.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/html-report/SKILL.md`

**Interfaces:**
- Produces: a skill contract where "an output path explicitly passed by the calling command" is a **Full**-autonomy write target (not No-go), and the default `docs/reports/` behaviour is preserved when no caller path is passed. Tasks 2–5 rely on this.

- [ ] **Step 1: Edit Hard Constraint #5 (default-vs-caller path).**

Find (lines ~25–27):

```
5. **Mandatory output directory.** Every report MUST be written to `docs/reports/`
   in the project where the skill runs (the current working directory's project
   root). Create the directory if it does not exist. Never write the report
   anywhere else.
```

Replace with:

```
5. **Output directory.** Default target is `docs/reports/` in the project where the
   skill runs (the current working directory's project root). If the caller passed an
   EXPLICIT output path (e.g. an IDD `check-*` command), write to that path instead.
   Create the target directory if it does not exist. Never invent an unrequested path.
```

- [ ] **Step 2: Edit Workflow step 6 (overwrite + path).**

Find (lines ~56–58):

```
6. Write the file to `docs/reports/` (create the directory if missing). This is
   mandatory — reports go nowhere else. If the target file already exists, **ask
   first** before overwriting (proposal-first).
```

Replace with:

```
6. Write the file to the target directory — `docs/reports/` by default, or the
   explicit caller-supplied path when one was passed (create the directory if
   missing). If the caller passed the path, overwriting that path is **Full** zone
   (proceed — it is a regenerated artifact). Otherwise, if the target file already
   exists, **ask first** before overwriting (proposal-first).
```

- [ ] **Step 3: Edit the Autonomy Zones table (caller path = Full; No-go scoped to unrequested paths).**

Find (lines ~80–84):

```
| Full — generating HTML, choosing CSS layout, picking the diagram type | proceed, no pause |
| Guarded — using inline `<script>`/`<canvas>`/SVG, or approaching 5 MB | proceed, but **log** the structure CSS can't express / **warn** on size |
| Proposal-first — which data sources to read; overwriting an existing `docs/reports/` file | **ask before acting** |
| No-go — writing/deleting any file outside `docs/reports/`; fetching any external resource | **refuse** |
```

Replace with:

```
| Full — generating HTML, choosing CSS layout, picking the diagram type; writing to an output path EXPLICITLY passed by the calling command | proceed, no pause |
| Guarded — using inline `<script>`/`<canvas>`/SVG, or approaching 5 MB | proceed, but **log** the structure CSS can't express / **warn** on size |
| Proposal-first — which data sources to read; overwriting an existing default `docs/reports/` file with no caller path | **ask before acting** |
| No-go — writing/deleting a file outside `docs/reports/` with NO caller-supplied path; fetching any external resource | **refuse** |
```

- [ ] **Step 4: Edit the Self-Validation checklist path item.**

Find (line ~75):

```
- [ ] Output path is under `docs/reports/` in the current project — never elsewhere.
```

Replace with:

```
- [ ] Output path is under `docs/reports/` OR equals the explicit caller-supplied path — never an unrequested location.
```

- [ ] **Step 5: Remove the broken external gold-standard reference (A3).**

Find (lines ~46–48):

```
   **Gold-standard reference** — for a full, polished report that exercises the SVG node
   grammar, animated connectors, C4, two-axis tables, badges, and `.note` callouts end
   to end, study `~/Документы/Project/ecom1-agent/docs/agent-architecture.html` before
   assembling a non-trivial architecture report.
```

Replace with:

```
   **Gold-standard reference** — for the full SVG node grammar, animated connectors, C4,
   two-axis tables, badges, and `.note` callouts, study the in-skill `references/`
   files (`svg-diagrams.md`, `svg-fallback.md`, `css-diagrams.md`) before assembling a
   non-trivial architecture report.
```

- [ ] **Step 6: Verify the edits.**

Run:

```bash
cd /home/ikeniborn/Documents/Project/iclaude
SKILL=.nvm-isolated/.claude-isolated/skills/html-report/SKILL.md
grep -c 'ecom1-agent' "$SKILL"                       # expect 0
grep -c 'caller-supplied\|caller-supplied path\|EXPLICITLY passed' "$SKILL"  # expect >= 2
grep -c 'references/' "$SKILL"                         # expect >= 1 (gold-ref now points in-skill)
```

Expected: `ecom1-agent` count `0`; caller-path mentions `>= 2`; `references/` present.

- [ ] **Step 7: Commit.**

```bash
git add .nvm-isolated/.claude-isolated/skills/html-report/SKILL.md
git commit -m "fix(html-report): accept caller-supplied output path, drop broken gold-ref

A1: writing to an explicit caller-passed path is Full zone (was No-go).
Default docs/reports/ behaviour preserved when no path is passed.
A3: replace external ecom1-agent gold-ref with in-skill references/.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `check-spec.md` — HTML path/inline, dependency graph, verbosity, phase dedup (A2, B1, C2, C3, D2)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-spec.md`

**Interfaces:**
- Consumes: the Task 1 skill contract (caller path = Full).
- Produces: the canonical pattern for the HTML-step rewrite (A2) and the consistency-phase rewrite (D2) that Tasks 3 and 4 mirror per their own file.

- [ ] **Step 1: Compress the canonical-hashing preamble (C2). Bash stays verbatim.**

Find (lines ~9–20):

```
### Канонический алгоритм хеширования (ОБЯЗАТЕЛЬНО)

ВСЕ хеши считаются ОДИНАКОВО — иначе сходимости не будет (frontmatter живой, меняется каждый прогон).

- **Хеш тела документа** (исключает frontmatter):
  ```bash
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
  ```
- **Хеш секции** — тело секции от заголовка `##`/`###` до следующего заголовка того же или более высокого уровня (не включая его), пропущенное через `sha256sum | cut -c1-16`.
- Если frontmatter отсутствует (`fm` < 2) — хеш всего файла: `sha256sum <FILE> | cut -c1-16`.

Команда ОБЯЗАНА запускать именно эти bash-команды через инструмент Bash. «В уме» не пересчитывать. Любое отклонение ломает quick-exit.
```

Replace with:

```
### Канонический алгоритм хеширования (ОБЯЗАТЕЛЬНО)

Все хеши — одним пайплайном (frontmatter живой, иначе quick-exit не сойдётся). Запускай bash через инструмент Bash, «в уме» не пересчитывай.

- **Хеш тела документа** (исключает frontmatter):
  ```bash
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
  ```
- **Хеш секции** — тело секции от заголовка `##`/`###` до следующего заголовка того же или более высокого уровня (не включая его), пропущенное через `sha256sum | cut -c1-16`.
- Если frontmatter отсутствует (`fm` < 2) — хеш всего файла: `sha256sum <FILE> | cut -c1-16`.
```

- [ ] **Step 2: Tighten the quick-exit preamble (C3). Conditions unchanged.**

Find (lines ~22–31):

```
### Шаг 0. Quick exit по state

1. Если файл найден и содержит frontmatter с блоком `review:`:
   - Посчитать sha256 тела документа по каноническому алгоритму (см. выше)
   - Если `current_hash == frontmatter.review.spec_hash` И все condition'ы выполнены:
     - `∀ phase ∈ phases: status == passed`
     - `∀ finding ∈ findings: verdict ∈ {accepted, wontfix, fixed}`
     - `count(severity == CRITICAL ∧ verdict == open) == 0`
   - → вывести `OK (cached, hash match)` и завершить
2. Иначе — продолжить
```

Replace with:

```
### Шаг 0. Quick exit по state

Если есть frontmatter с блоком `review:` и `current_body_hash == review.spec_hash` И:
- `∀ phase ∈ phases: status == passed`
- `∀ finding: verdict ∈ {accepted, wontfix, fixed}`
- `count(severity == CRITICAL ∧ verdict == open) == 0`

→ вывести `OK (cached, hash match)` и завершить. Иначе — продолжить.
```

- [ ] **Step 3: Sharpen the dependency-graph diagram spec (B1).**

Find (lines ~135–136, inside Step 5 block 2):

```
   - **Граф зависимостей** — SVG node-edge граф зависимостей между требованиями/компонентами (узлы — требования/компоненты, рёбра — «зависит от» / «использует»).
```

Replace with:

```
   - **Граф зависимостей** — SVG node-edge граф (как в check-plan): **узлы** — отдельные требования/компоненты спеки (каждый подписан), **рёбра** — направленные «зависит от» / «использует» (A→B = A зависит от B). Подсветить циклы, если граф их содержит.
```

- [ ] **Step 4: Rewrite the HTML artifact params — explicit caller path + inline data (A2).**

Find (lines ~140–145, the "Параметры артефакта" block):

```
Параметры артефакта:
- Выход: `docs/superpowers/reports/specs/<basename спеки без .md>-check.html` (например `2026-06-17-foo-design-check.html`). Создай каталог `docs/superpowers/reports/specs/`, если его нет.
- Перезаписывать существующий файл **без подтверждения** — это автогенерируемый артефакт команды. Это явный override proposal-first навыка `html-report` для данного пути.
- Язык — русский: весь текст отчёта (заголовки, описания, findings, сводки) на русском языке.
```

Replace with:

```
Параметры артефакта (передай навыку явно при вызове):
- **Output path (явный аргумент):** `docs/superpowers/reports/specs/<basename спеки без .md>-check.html` (например `2026-06-17-foo-design-check.html`). Это caller-supplied путь — навык пишет туда (Full-зона), создаёт каталог `docs/superpowers/reports/specs/` при отсутствии, перезаписывает без подтверждения.
- **Данные — inline:** три блока выше переданы в самом вызове. Навык НЕ читает источники сам и НЕ останавливается (halt) из-за «нечитаемого источника» — данные уже предоставлены.
- Язык — русский: весь текст отчёта (заголовки, описания, findings, сводки) на русском языке.
```

- [ ] **Step 5: Dedup the consistency phase against init-state (D2).**

Find (lines ~101–105):

```
#### Фаза 4: consistency

Закрытый чек-лист:
- Проверка хешей секций: для каждой секции — изменилась ли с прошлого прогона
- Сводка по изменившимся секциям и связанным findings
```

Replace with:

```
#### Фаза 4: consistency

Закрытый чек-лист:
- Использовать diff изменившихся секций, уже вычисленный в Шаге 2 (init-state) — НЕ пересчитывать хеши заново
- Сводка по изменившимся секциям и связанным findings
```

- [ ] **Step 6: Verify check-spec edits.**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
F=.nvm-isolated/.claude-isolated/commands/check-spec.md
grep -c 'ВСЕ хеши считаются ОДИНАКОВО' "$F"        # expect 0 (preamble compressed)
grep -c "awk 'BEGIN{fm=0}" "$F"                     # expect 1 (bash verbatim, untouched)
grep -c 'caller-supplied\|Output path (явный аргумент)' "$F"  # expect >= 1 (A2)
grep -c 'inline\|навык НЕ читает источники' "$F"    # expect >= 1 (A2 inline)
grep -c 'уже вычисленный в Шаге 2' "$F"             # expect 1 (D2)
grep -c 'узлы.*требования/компоненты' "$F"          # expect 1 (B1)
```

Expected: old preamble `0`, bash block `1` (unchanged), A2 path + inline present, D2 present, B1 present.

- [ ] **Step 7: Commit.**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-spec.md
git commit -m "refactor(check-spec): explicit HTML path+inline, sharper dep graph, dedup consistency

A2: pass output path explicitly, mark data inline (skill no read/halt).
B1: dependency graph nodes/edges defined like check-plan.
C2/C3: compress hashing + quick-exit preambles (bash verbatim).
D2: consistency phase reuses Step 2 section diff (no recompute).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `check-plan.md` — self-containment, HTML path/inline, verbosity, phase dedup (A2, C1, C2, C3, D2)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-plan.md`

**Interfaces:**
- Consumes: Task 1 skill contract; the A2 + D2 rewrite pattern from Task 2.

- [ ] **Step 1: Remove the cross-file reference in findings handling (C1, resolves F6).**

Find (lines ~116–123):

```
### Логика обработки findings

Идентична check-spec:
1. Не дублировать existing findings с тем же `section + text + section_hash`
2. Новые → `id: F-NNN`, `verdict: open`
3. Записать frontmatter
4. Отчёт + запрос verdicts
5. Все CRITICAL закрыты → `passed`, переход; иначе → `in_progress`, остановка
```

Replace with:

```
### Логика обработки findings

1. Не дублировать existing findings с тем же `section + text + section_hash`
2. Новые → `id: F-NNN` (монотонно), `phase`, `severity`, `section`, `section_hash`, `text`, `verdict: open`, `verdict_at: null`
3. Записать обновлённый frontmatter в файл
4. Отчёт по фазе + запрос verdicts (CRITICAL обязателен: `accepted | wontfix | fixed`; WARNING желателен; INFO опционален)
5. Все CRITICAL фазы закрыты → `phase.status = passed`, переход; иначе → `in_progress`, остановка с просьбой исправить
```

- [ ] **Step 2: Compress the canonical-hashing preamble (C2). Bash verbatim.**

Find (lines ~9–20):

```
### Канонический алгоритм хеширования (ОБЯЗАТЕЛЬНО)

ВСЕ хеши считаются ОДИНАКОВО — иначе сходимости не будет (frontmatter живой, меняется каждый прогон).

- **Хеш тела документа** (исключает frontmatter):
  ```bash
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
  ```
- **Хеш секции** — тело секции от заголовка `##`/`###` до следующего заголовка того же или более высокого уровня (не включая его), пропущенное через `sha256sum | cut -c1-16`.
- Если frontmatter отсутствует (`fm` < 2) — хеш всего файла: `sha256sum <FILE> | cut -c1-16`.

Команда ОБЯЗАНА запускать эти bash-команды через инструмент Bash. «В уме» не пересчитывать. Любое отклонение ломает quick-exit.
```

Replace with:

```
### Канонический алгоритм хеширования (ОБЯЗАТЕЛЬНО)

Все хеши — одним пайплайном (frontmatter живой, иначе quick-exit не сойдётся). Запускай bash через инструмент Bash, «в уме» не пересчитывай.

- **Хеш тела документа** (исключает frontmatter):
  ```bash
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
  ```
- **Хеш секции** — тело секции от заголовка `##`/`###` до следующего заголовка того же или более высокого уровня (не включая его), пропущенное через `sha256sum | cut -c1-16`.
- Если frontmatter отсутствует (`fm` < 2) — хеш всего файла: `sha256sum <FILE> | cut -c1-16`.
```

- [ ] **Step 3: Dedup the consistency phase against init-state (D2).**

Find (lines ~110–114):

```
#### Фаза 5: consistency

Закрытый чек-лист:
- Сверка хешей секций плана и спеки
- Сводка по изменившимся секциям
```

Replace with:

```
#### Фаза 5: consistency

Закрытый чек-лист:
- Использовать diff изменившихся секций плана/спеки, уже вычисленный в Шаге 2 (init-state) — НЕ пересчитывать хеши заново
- Сводка по изменившимся секциям
```

- [ ] **Step 4: Rewrite the HTML artifact params — explicit caller path + inline data (A2).**

Find (lines ~141–144):

```
Параметры артефакта:
- Выход: `docs/superpowers/reports/plans/<basename плана без .md>-check.html` (например `2026-06-17-foo-plan-check.html`). Создай каталог `docs/superpowers/reports/plans/`, если его нет.
- Перезаписывать существующий файл **без подтверждения** — это автогенерируемый артефакт команды. Это явный override proposal-first навыка `html-report` для данного пути.
- Язык — русский: весь текст отчёта (заголовки, описания, findings, сводки) на русском языке.
```

Replace with:

```
Параметры артефакта (передай навыку явно при вызове):
- **Output path (явный аргумент):** `docs/superpowers/reports/plans/<basename плана без .md>-check.html` (например `2026-06-17-foo-plan-check.html`). Это caller-supplied путь — навык пишет туда (Full-зона), создаёт каталог `docs/superpowers/reports/plans/` при отсутствии, перезаписывает без подтверждения.
- **Данные — inline:** три блока выше переданы в самом вызове. Навык НЕ читает источники сам и НЕ останавливается (halt) из-за «нечитаемого источника» — данные уже предоставлены.
- Язык — русский: весь текст отчёта (заголовки, описания, findings, сводки) на русском языке.
```

- [ ] **Step 5: Verify check-plan edits.**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
F=.nvm-isolated/.claude-isolated/commands/check-plan.md
grep -c 'Идентична check-spec' "$F"                 # expect 0 (C1 — self-contained now)
grep -c 'check-spec' "$F"                            # expect 0 (no cross-file ref at all)
grep -c "awk 'BEGIN{fm=0}" "$F"                      # expect 1 (bash verbatim)
grep -c 'ВСЕ хеши считаются ОДИНАКОВО' "$F"          # expect 0 (preamble compressed)
grep -c 'уже вычисленный в Шаге 2' "$F"              # expect 1 (D2)
grep -c 'Output path (явный аргумент)' "$F"          # expect 1 (A2)
```

Expected: no `check-spec` reference, bash intact, D2 + A2 present.

- [ ] **Step 6: Commit.**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-plan.md
git commit -m "refactor(check-plan): self-contained findings logic, explicit HTML path+inline, dedup consistency

C1: inline the findings-handling list (drop 'Идентична check-spec' — F6).
A2: pass output path explicitly, mark data inline.
C2: compress hashing preamble (bash verbatim).
D2: consistency phase reuses Step 2 section diff.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `check-intent.md` — HTML path/inline, constraint×outcome matrix, verbosity, phase dedup (A2, B2, C2, C3, D2)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-intent.md`

**Interfaces:**
- Consumes: Task 1 skill contract; A2 + D2 pattern from Task 2.
- Note: check-intent's `consistency` phase ALSO holds contradiction + Status-guard checks — touch ONLY the hash-recompute bullet, leave the rest.

- [ ] **Step 1: Compress the canonical-hashing preamble (C2). Bash verbatim.**

Find (lines ~9–20):

```
### Канонический алгоритм хеширования (ОБЯЗАТЕЛЬНО)

ВСЕ хеши считаются ОДИНАКОВО — иначе сходимости не будет (frontmatter живой, меняется каждый прогон).

- **Хеш тела документа** (исключает frontmatter):
  ```bash
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
  ```
- **Хеш секции** — тело секции от заголовка `##`/`###` до следующего заголовка того же или более высокого уровня (не включая его), пропущенное через `sha256sum | cut -c1-16`.
- Если frontmatter отсутствует (`fm` < 2) — хеш всего файла: `sha256sum <FILE> | cut -c1-16`.

Команда ОБЯЗАНА запускать именно эти bash-команды через инструмент Bash. «В уме» не пересчитывать. Любое отклонение ломает quick-exit.
```

Replace with:

```
### Канонический алгоритм хеширования (ОБЯЗАТЕЛЬНО)

Все хеши — одним пайплайном (frontmatter живой, иначе quick-exit не сойдётся). Запускай bash через инструмент Bash, «в уме» не пересчитывай.

- **Хеш тела документа** (исключает frontmatter):
  ```bash
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
  ```
- **Хеш секции** — тело секции от заголовка `##`/`###` до следующего заголовка того же или более высокого уровня (не включая его), пропущенное через `sha256sum | cut -c1-16`.
- Если frontmatter отсутствует (`fm` < 2) — хеш всего файла: `sha256sum <FILE> | cut -c1-16`.
```

- [ ] **Step 2: Dedup ONLY the hash bullet of the consistency phase (D2). Keep contradictions + Status-guard.**

Find (lines ~96–101):

```
#### Фаза 4: consistency (CRITICAL для противоречий)

Закрытый чек-лист (НЕ расширять):
- Проверка хешей секций: для каждой секции — изменилась ли с прошлого прогона; сводка изменений
- Внутри-док противоречия: constraint против Desired Outcome; Health Metric против Objective → CRITICAL
- **Status-guard:** если тело содержит `**Status:** approved`, но есть открытый CRITICAL finding → создать finding `[CRITICAL]` «approved, но документ не валиден». Строку `**Status:**` НЕ редактировать — только finding.
```

Replace with:

```
#### Фаза 4: consistency (CRITICAL для противоречий)

Закрытый чек-лист (НЕ расширять):
- Использовать diff изменившихся секций из Шага 2 (init-state) — НЕ пересчитывать хеши заново; дать сводку изменений
- Внутри-док противоречия: constraint против Desired Outcome; Health Metric против Objective → CRITICAL
- **Status-guard:** если тело содержит `**Status:** approved`, но есть открытый CRITICAL finding → создать finding `[CRITICAL]` «approved, но документ не валиден». Строку `**Status:**` НЕ редактировать — только finding.
```

- [ ] **Step 3: Sharpen the constraints↔outcomes diagram into an explicit matrix (B2).**

Find (line ~140, inside Step 5 block 2):

```
   - **Связь ограничений и результатов** — матрица/таблица или SVG node-edge граф: какие Constraints (steering / hard) ограничивают какие Desired Outcomes.
```

Replace with:

```
   - **Связь ограничений и результатов** — матрица `Constraint × Desired Outcome`: строки — Constraints (steering / hard), столбцы — Desired Outcomes, явная отметка в ячейке там, где constraint ограничивает outcome (пустая ячейка = нет связи).
```

- [ ] **Step 4: Rewrite the HTML artifact params — explicit caller path + inline data (A2).**

Find (lines ~144–147):

```
Параметры артефакта:
- Выход: `docs/superpowers/reports/intents/<basename intent doc без .md>-check.html` (например `2026-06-17-foo-intent-check.html`). Создай каталог `docs/superpowers/reports/intents/`, если его нет.
- Перезаписывать существующий файл **без подтверждения** — это автогенерируемый артефакт команды. Это явный override proposal-first навыка `html-report` для данного пути.
- Язык — русский: весь текст отчёта (заголовки, описания, findings, сводки) на русском языке.
```

Replace with:

```
Параметры артефакта (передай навыку явно при вызове):
- **Output path (явный аргумент):** `docs/superpowers/reports/intents/<basename intent doc без .md>-check.html` (например `2026-06-17-foo-intent-check.html`). Это caller-supplied путь — навык пишет туда (Full-зона), создаёт каталог `docs/superpowers/reports/intents/` при отсутствии, перезаписывает без подтверждения.
- **Данные — inline:** три блока выше переданы в самом вызове. Навык НЕ читает источники сам и НЕ останавливается (halt) из-за «нечитаемого источника» — данные уже предоставлены.
- Язык — русский: весь текст отчёта (заголовки, описания, findings, сводки) на русском языке.
```

- [ ] **Step 5: Verify check-intent edits.**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
F=.nvm-isolated/.claude-isolated/commands/check-intent.md
grep -c 'ВСЕ хеши считаются ОДИНАКОВО' "$F"          # expect 0 (C2)
grep -c "awk 'BEGIN{fm=0}" "$F"                      # expect 1 (bash verbatim)
grep -c 'уже пересчитывать\|уже вычисленный\|diff изменившихся секций из Шага 2' "$F"  # expect 1 (D2)
grep -c 'Status-guard' "$F"                          # expect 1 (kept — not touched)
grep -c 'Внутри-док противоречия' "$F"               # expect 1 (kept)
grep -c 'Constraint × Desired Outcome' "$F"          # expect 1 (B2)
grep -c 'Output path (явный аргумент)' "$F"          # expect 1 (A2)
```

Expected: C2 done, bash intact, D2 hash bullet replaced, Status-guard + contradictions kept, B2 + A2 present.

- [ ] **Step 6: Commit.**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-intent.md
git commit -m "refactor(check-intent): explicit HTML path+inline, constraint×outcome matrix, dedup consistency hash

A2: pass output path explicitly, mark data inline.
B2: constraints↔outcomes as explicit Constraint × Desired Outcome matrix.
C2: compress hashing preamble (bash verbatim).
D2: replace consistency hash-recompute bullet with Step 2 diff reuse;
    contradiction + Status-guard checks left intact.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: `check-result.md` — HTML path/inline + compress hashing preamble (A2, C2)

check-result has no phase model (no quick-exit phases, no init-state `review:` block, no `consistency` phase) — so C3 and D2 do NOT apply. B3 = no diagrams (no change). Only A2 (its Step 8 HTML) and C2 (its shorter hashing preamble) apply.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-result.md`

**Interfaces:**
- Consumes: Task 1 skill contract; A2 pattern from Task 2.

- [ ] **Step 1: Compress the hashing preamble (C2). Bash verbatim.**

Find (lines ~9–19):

```
### Канонический алгоритм хеширования (ОБЯЗАТЕЛЬНО)

Хеш тела плана для `result_check.plan_hash` считается ТЕМ ЖЕ пайплайном, что у
остальных валидаторов и у idd-gate, иначе merge-gate не сойдётся:

```bash
awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <PLAN_FILE> | sha256sum | cut -c1-16
```

Команда ОБЯЗАНА запускать именно эту bash-команду через инструмент Bash. «В уме»
не пересчитывать.
```

Replace with:

```
### Канонический алгоритм хеширования (ОБЯЗАТЕЛЬНО)

Хеш тела плана для `result_check.plan_hash` — тем же пайплайном, что у остальных валидаторов и у idd-gate (иначе merge-gate не сойдётся). Запускай bash через инструмент Bash, «в уме» не пересчитывай:

```bash
awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <PLAN_FILE> | sha256sum | cut -c1-16
```
```

- [ ] **Step 2: Rewrite the HTML artifact params — explicit caller path + inline data (A2).**

Find (lines ~97–100):

```
Параметры артефакта:
- Выход: `docs/superpowers/reports/results/<basename плана без .md>-result-check.html` (например `2026-06-17-foo-plan-result-check.html`). Создай каталог `docs/superpowers/reports/results/`, если его нет.
- Перезаписывать существующий файл **без подтверждения** — это автогенерируемый артефакт команды. Это явный override proposal-first навыка `html-report` для данного пути.
- Язык — русский: весь текст отчёта (заголовки, описания, findings, сводки) на русском языке.
```

Replace with:

```
Параметры артефакта (передай навыку явно при вызове):
- **Output path (явный аргумент):** `docs/superpowers/reports/results/<basename плана без .md>-result-check.html` (например `2026-06-17-foo-plan-result-check.html`). Это caller-supplied путь — навык пишет туда (Full-зона), создаёт каталог `docs/superpowers/reports/results/` при отсутствии, перезаписывает без подтверждения.
- **Данные — inline:** оба блока выше переданы в самом вызове. Навык НЕ читает источники сам и НЕ останавливается (halt) из-за «нечитаемого источника» — данные уже предоставлены.
- Язык — русский: весь текст отчёта (заголовки, описания, findings, сводки) на русском языке.
```

- [ ] **Step 3: Verify check-result edits.**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
F=.nvm-isolated/.claude-isolated/commands/check-result.md
grep -c 'считается ТЕМ ЖЕ пайплайном' "$F"           # expect 0 (preamble compressed)
grep -c "awk 'BEGIN{fm=0}" "$F"                      # expect 1 (bash verbatim)
grep -c 'Output path (явный аргумент)' "$F"          # expect 1 (A2)
grep -c 'оба блока выше переданы' "$F"               # expect 1 (A2 inline — result has 2 blocks)
```

Expected: preamble compressed, bash intact, A2 present (note: result passes TWO data blocks, not three).

- [ ] **Step 4: Commit.**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-result.md
git commit -m "refactor(check-result): explicit HTML path+inline, compress hashing preamble

A2: pass output path explicitly, mark the two data blocks inline.
C2: compress hashing preamble (bash verbatim).
No phase model here, so C3/D2 N/A; B3 keeps result diagram-free.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: End-to-end verification + diff-scope guard

Confirm the skill no longer refuses the caller path, the bash hashing blocks are byte-identical to the pre-change versions, and the diff touched only the five intended files.

**Files:**
- No edits — verification only.

- [ ] **Step 1: Confirm diff scope (only the 5 intended files).**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
git diff --name-only origin/master...HEAD -- .nvm-isolated/.claude-isolated/ | sort
```

Expected: exactly
```
.nvm-isolated/.claude-isolated/commands/check-intent.md
.nvm-isolated/.claude-isolated/commands/check-plan.md
.nvm-isolated/.claude-isolated/commands/check-result.md
.nvm-isolated/.claude-isolated/commands/check-spec.md
.nvm-isolated/.claude-isolated/skills/html-report/SKILL.md
```
(Plus the spec/plan docs under `docs/superpowers/` — those are expected IDD artifacts, not part of this guard.)

- [ ] **Step 2: Confirm the bash hashing pipeline is byte-identical across all four commands.**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
grep -h "awk 'BEGIN{fm=0} /^---\$/{fm++; next} fm>=2{print}'" \
  .nvm-isolated/.claude-isolated/commands/check-*.md | sort -u
```

Expected: exactly ONE unique line (the pipeline differs only by `<FILE>` vs `<PLAN_FILE>` placeholder — if two unique lines, that placeholder difference is the only allowed variance; any other difference is a regression).

- [ ] **Step 3: Confirm no command references another command file (self-containment).**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
for f in check-intent check-spec check-plan check-result; do
  echo -n "$f references other commands: "
  grep -oE 'check-(intent|spec|plan|result)' ".nvm-isolated/.claude-isolated/commands/$f.md" \
    | grep -v "$f" | grep -v "check-" || echo "none"
done
```

Expected: each command references no OTHER command by name (the only `check-*` token allowed is its own self-reference in usage examples, if any).

- [ ] **Step 4: End-to-end skill smoke test (dispatch a clean-context subagent).**

Dispatch a subagent with this task (it confirms the skill honours a caller path without refusing):

> Read `.nvm-isolated/.claude-isolated/skills/html-report/SKILL.md`. Then, using ONLY the rules in that file, decide: if a calling command passes the explicit output path `docs/superpowers/reports/specs/test-design-check.html` and provides all report data inline, does the skill (a) proceed to write there as a Full-zone action, or (b) refuse / ask first because the path is outside `docs/reports/`? Answer with the zone classification and quote the exact table row and constraint that decide it. Do NOT write any file.

Expected subagent answer: **(a) proceed — Full zone**, quoting the updated Autonomy Zones row ("writing to an output path EXPLICITLY passed by the calling command") and Hard Constraint #5 ("if the caller passed an EXPLICIT output path … write to that path instead").

- [ ] **Step 5: Final commit (if any verification produced a fixup; otherwise skip).**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
git status --short
# If clean, nothing to commit — Task 6 is verification-only.
```

---

## Notes for the implementer

- **Apply edits with the Edit tool**, matching each `Find` block exactly (strip the line-number prefix the Read tool shows). Line numbers in this plan are approximate anchors — match on text, not line number.
- **Never touch the `awk 'BEGIN{fm=0} …'` bash line.** Every "compress preamble" step keeps it byte-for-byte.
- After all tasks, the iwiki post-task steps are **N/A**: the iwiki doc-graph excludes `commands/` and IDD artifacts (per project memory). No `iwiki-ingest` / `iwiki-lint` needed for these files.
- Branch: stay on `dev`; open a PR into `master` to close the branch.
