# check-intent Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `/check-intent` slash command that phase-validates IDD intent docs (`docs/superpowers/intents/*-intent.md`), the root of the IDD→SDD chain, by analogy with `check-spec.md`.

**Architecture:** The deliverable is a single prompt-artifact markdown file — `.nvm-isolated/.claude-isolated/commands/check-intent.md` — mirroring the structure of `check-spec.md` (canonical hashing, quick-exit, frontmatter `review:` state, closed-list phases, findings with verdicts). It adds an IDD-specific phase set (structure → completeness → clarity → consistency, all CRITICAL-gating, deterministic + hashable) plus a non-gating advisory `alignment` phase (conversation + lat.md). Because the intent is the chain root, it writes no `chain:` block and its report footer points forward to brainstorming.

**Tech Stack:** Markdown command file (Claude Code custom command), bash (`awk`/`sha256sum` for canonical hashing — reused verbatim from `check-spec`), optional `lat_search`/`lat_refs` MCP tools.

---

## File Structure

| File | Responsibility |
|------|----------------|
| Create: `.nvm-isolated/.claude-isolated/commands/check-intent.md` | The entire deliverable — the command prompt. Built incrementally section by section. |
| Reference (read-only): `.nvm-isolated/.claude-isolated/commands/check-spec.md` | Pattern source. Canonical hashing block is copied **byte-identical** from here. |
| Reference (read-only): `.nvm-isolated/.claude-isolated/skills/intent/SKILL.md` | Source of the IDD template (7 sections) and Validation checklist the phases enforce. |
| Reference (read-only): `docs/superpowers/specs/2026-06-14-check-intent-design.md` | The approved spec this plan implements. |
| Fixture (test-only, ephemeral): `/tmp/smoke-intent*.md` | Copies of a real intent doc used for the smoke test; never committed. |

The command commits per task, growing one file. There are no repo test files — the existing `check-*` commands carry none, so verification is done via inline `grep`/`diff` assertions (ephemeral) plus a final manual smoke run, matching the established pattern.

**Insertion convention:** Task 1 creates the file ending with a final `$ARGUMENTS` line. Every later task inserts its section by replacing the unique trailing `$ARGUMENTS` with `<new section>\n\n$ARGUMENTS`, so sections append in order and `$ARGUMENTS` always stays last (as in `check-spec.md`).

---

## Task 1: Scaffold the command file (header + canonical hashing)

**Files:**
- Create: `.nvm-isolated/.claude-isolated/commands/check-intent.md`
- Reference: `.nvm-isolated/.claude-isolated/commands/check-spec.md:9-20` (hashing block)

- [ ] **Step 1: Confirm the file does not yet exist (red)**

Run:
```bash
ls -l .nvm-isolated/.claude-isolated/commands/check-intent.md
```
Expected: `ls: cannot access ... No such file or directory`

- [ ] **Step 2: Create the file with description, arguments, `## Алгоритм`, the verbatim hashing block, and a trailing `$ARGUMENTS`**

Create `.nvm-isolated/.claude-isolated/commands/check-intent.md` with exactly:

````markdown
Проверь intent doc (корень цепи IDD→SDD) на самосогласованность с фазовой моделью и state во frontmatter.

Поддерживаемые аргументы:
- Путь к файлу intent doc — если не передан, файл определяется автоматически
- Контекст разговора используется advisory-фазой alignment

## Алгоритм

### Канонический алгоритм хеширования (ОБЯЗАТЕЛЬНО)

ВСЕ хеши считаются ОДИНАКОВО — иначе сходимости не будет (frontmatter живой, меняется каждый прогон).

- **Хеш тела документа** (исключает frontmatter):
  ```bash
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
  ```
- **Хеш секции** — тело секции от заголовка `##`/`###` до следующего заголовка того же или более высокого уровня (не включая его), пропущенное через `sha256sum | cut -c1-16`.
- Если frontmatter отсутствует (`fm` < 2) — хеш всего файла: `sha256sum <FILE> | cut -c1-16`.

Команда ОБЯЗАНА запускать именно эти bash-команды через инструмент Bash. «В уме» не пересчитывать. Любое отклонение ломает quick-exit.

$ARGUMENTS
````

- [ ] **Step 3: Verify file exists and the hashing one-liner is byte-identical to check-spec (green)**

Run:
```bash
F=.nvm-isolated/.claude-isolated/commands
grep -F "awk 'BEGIN{fm=0} /^---\$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16" "$F/check-intent.md" \
  && grep -F 'Если frontmatter отсутствует (`fm` < 2) — хеш всего файла: `sha256sum <FILE> | cut -c1-16`.' "$F/check-intent.md" \
  && tail -n1 "$F/check-intent.md"
```
Expected: both `grep` lines print a match, and the last line is `$ARGUMENTS`.

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-intent.md
git commit -m "feat(commands): scaffold check-intent with canonical hashing"
```

---

## Task 2: Add Step 0 (quick-exit), Step 1 (scope), Step 2 (init state)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-intent.md`

- [ ] **Step 1: Confirm the steps are absent (red)**

Run:
```bash
grep -c 'intent_hash' .nvm-isolated/.claude-isolated/commands/check-intent.md
```
Expected: `0`

- [ ] **Step 2: Insert Steps 0–2 before `$ARGUMENTS`**

Replace the unique trailing line `$ARGUMENTS` with the following block followed by a blank line and `$ARGUMENTS`:

````markdown
### Шаг 0. Quick exit по state

1. Если файл найден и содержит frontmatter с блоком `review:`:
   - Посчитать sha256 тела документа по каноническому алгоритму (см. выше)
   - Если `current_hash == frontmatter.review.intent_hash` И все condition'ы выполнены:
     - `∀ phase ∈ {structure, completeness, clarity, consistency}: status == passed`
     - `alignment.status == passed` (НЕ пересчитывать — фаза недетерминирована, доверяем прошлому прогону)
     - `∀ finding ∈ findings: verdict ∈ {accepted, wontfix, fixed}`
     - `count(severity == CRITICAL ∧ verdict == open) == 0`
   - → вывести `OK (cached, hash match)` и завершить
2. Иначе — продолжить

### Шаг 1. Определи scope

- Если передан путь в `$ARGUMENTS` — работай с указанным файлом
- Иначе, если тема задачи известна из контекста — ищи файл по имени в `docs/superpowers/intents/`
- Иначе — последний изменённый файл в `docs/superpowers/intents/`
- Если не найден — сообщи: «Не найден intent doc. Укажи путь: `/check-intent path/to/intent.md`»

Intent doc — **корень цепи IDD→SDD**. Upstream-документа нет, блок `chain:` НЕ добавляется. Footer отчёта смотрит вперёд (на brainstorm), а не назад.

### Шаг 2. Подтверди файл и инициализируй state

1. Сообщи: «Буду проверять: `<путь>`. Верно?»
2. После подтверждения:
   - Прочитать frontmatter. Если блока `review:` нет — инициализировать:
     ```yaml
     review:
       intent_hash: <sha256 тела>
       last_run: <today>
       phases:
         structure:    { status: pending }
         completeness: { status: pending }
         clarity:      { status: pending }
         consistency:  { status: pending }
         alignment:    { status: pending }   # advisory — вне CRITICAL-gate
       findings: []
     ```
   - Посчитать хеши всех секций (по заголовкам `##`/`###`)
   - Для каждого существующего finding с `section_hash != current_section_hash` — сбросить `verdict: open`
   - Обновить `intent_hash` и `last_run`
   - Блок `chain:` НЕ добавлять (корень цепи)
   - Тело intent doc (включая строку `**Status:**`) НЕ редактировать ни при каких условиях
````

- [ ] **Step 3: Verify the three steps and the intent schema are present (green)**

Run:
```bash
F=.nvm-isolated/.claude-isolated/commands/check-intent.md
grep -q '### Шаг 0. Quick exit по state' "$F" \
  && grep -q '### Шаг 1. Определи scope' "$F" \
  && grep -q '### Шаг 2. Подтверди файл и инициализируй state' "$F" \
  && grep -q 'intent_hash:' "$F" \
  && grep -q 'alignment:    { status: pending }' "$F" \
  && grep -q 'Блок `chain:` НЕ добавлять' "$F" \
  && echo OK
```
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-intent.md
git commit -m "feat(commands): check-intent quick-exit, scope, init-state"
```

---

## Task 3: Add Step 3 phases 1–2 (structure, completeness)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-intent.md`

- [ ] **Step 1: Confirm the phases are absent (red)**

Run:
```bash
grep -c 'steering XOR hard' .nvm-isolated/.claude-isolated/commands/check-intent.md
```
Expected: `0`

- [ ] **Step 2: Insert the Step 3 header and phases 1–2 before `$ARGUMENTS`**

Replace the unique trailing line `$ARGUMENTS` with the following block followed by a blank line and `$ARGUMENTS`:

````markdown
### Шаг 3. Выполнение фаз

Фазы выполняются строго последовательно. Фаза N+1 стартует только если в фазе N нет CRITICAL с `verdict: open`. Фаза `alignment` всегда последняя и advisory — не блокирует переход и финальный вердикт.

#### Фаза 1: structure (CRITICAL)

Закрытый чек-лист (НЕ расширять):
- Плейсхолдеры: `TODO`, `TBD`, `???`, `FIXME`
- Все 7 секций шаблона на месте: Objective, Desired Outcomes, Health Metrics, Strategic Context, Constraints, Autonomy Zones, Stop Rules
- Пустые буллеты / пустые секции
- Битые внутренние ссылки на разделы (§X.Y, [link](#anchor))
- Дублирующиеся заголовки секций

#### Фаза 2: completeness (CRITICAL)

Закрытый чек-лист (НЕ расширять):
- Каждый constraint привязан к steering XOR hard (не к обоим, не ни к одному)
- Autonomy Zones покрывают все 4 зоны (Full / Guarded / Proposal-first / No autonomy) либо несут явный N/A для зоны
- Stop Rules содержит ≥1 критерий `Done when:`
- Health Metrics непусты
- Strategic Context содержит и `Interacts with:`, и `Priority trade-off:`
````

- [ ] **Step 3: Verify phases 1–2 checklists are present (green)**

Run:
```bash
F=.nvm-isolated/.claude-isolated/commands/check-intent.md
grep -q '### Шаг 3. Выполнение фаз' "$F" \
  && grep -q '#### Фаза 1: structure (CRITICAL)' "$F" \
  && grep -q '#### Фаза 2: completeness (CRITICAL)' "$F" \
  && grep -q 'Все 7 секций шаблона' "$F" \
  && grep -q 'steering XOR hard' "$F" \
  && grep -q 'Done when:' "$F" \
  && echo OK
```
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-intent.md
git commit -m "feat(commands): check-intent phases structure + completeness"
```

---

## Task 4: Add Step 3 phases 3–5 (clarity, consistency, alignment), findings logic, Step 4

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-intent.md`

- [ ] **Step 1: Confirm the phases are absent (red)**

Run:
```bash
grep -c '#### Фаза 5: alignment' .nvm-isolated/.claude-isolated/commands/check-intent.md
```
Expected: `0`

- [ ] **Step 2: Insert phases 3–5, the findings logic, and Step 4 before `$ARGUMENTS`**

Replace the unique trailing line `$ARGUMENTS` with the following block followed by a blank line and `$ARGUMENTS`:

````markdown
#### Фаза 3: clarity

Закрытый чек-лист (НЕ расширять):
- Desired Outcomes наблюдаемы / user-facing, НЕ шаги реализации. Outcome, сформулированный как «implemented / code written / function added» → **CRITICAL**. Наблюдаемый, но размытый → WARNING.
- `Done when:` — измеримый результат, не «код написан». Если называет акт реализации вместо наблюдаемого результата → **CRITICAL**.
- Health Metrics измеримы (названная метрика, не настроение) → WARNING.
- Вагу-термины без критерия: «быстро», «удобно», «надёжно», «достаточно», «при необходимости» → WARNING.

#### Фаза 4: consistency (CRITICAL для противоречий)

Закрытый чек-лист (НЕ расширять):
- Проверка хешей секций: для каждой секции — изменилась ли с прошлого прогона; сводка изменений
- Внутри-док противоречия: constraint против Desired Outcome; Health Metric против Objective → CRITICAL
- **Status-guard:** если тело содержит `**Status:** approved`, но есть открытый CRITICAL finding → создать finding `[CRITICAL]` «approved, но документ не валиден». Строку `**Status:**` НЕ редактировать — только finding.

#### Фаза 5: alignment (advisory — INFO/WARNING, НЕ gate, НЕ пересчитывать при hash-match)

Закрытый чек-лист (НЕ расширять). Никогда не выдаёт CRITICAL; не блокирует переход фаз и финальный вердикт:
- Conversation: Objective и Desired Outcomes покрывают исходную задачу, описанную пользователем в разговоре? Есть ли objective, которого пользователь не просил? → INFO
- lat.md: intent противоречит задокументированному решению, либо Health Metrics игнорируют компоненты, ссылающиеся на эту область (`lat_refs`)? → WARNING. Требует MCP-инструментов `lat_search` / `lat_refs`.
- Если `lat_search` / `lat_refs` недоступны — пропустить молча (как IDD Step 0). Не блокировать, не упоминать отсутствие.

### Логика обработки findings в каждой фазе

1. Прочитать существующие findings этой фазы из frontmatter
2. Применить чек-лист фазы к телу intent doc
3. Для каждой потенциальной находки:
   - Если уже существует finding с тем же `section` и совпадающим `text` И `section_hash` не изменился → НЕ дублировать
   - Иначе — создать новый: `id: F-NNN` (монотонно следующий), `phase`, `severity`, `section`, `section_hash`, `text`, `verdict: open`, `verdict_at: null`
4. Записать обновлённый frontmatter в файл
5. Вывести отчёт по фазе
6. Запросить у пользователя verdict для новых findings:
   - CRITICAL — обязательно (`accepted | wontfix | fixed`)
   - WARNING — желательно
   - INFO — опционально
7. Записать verdicts. Если все CRITICAL фазы закрыты → `phase.status = passed`, переход к следующей. Фаза `alignment` не имеет CRITICAL → после прогона всегда `passed`.
8. Иначе → `phase.status = in_progress`, остановка с просьбой исправить и перезапустить

### Шаг 4. Финальный вердикт

Применить exit-критерий из шага 0. Вывести `OK` либо `требует доработки: <N> critical open, <M> warning open`.
````

- [ ] **Step 3: Verify phases 3–5, findings logic, Step 4 present (green)**

Run:
```bash
F=.nvm-isolated/.claude-isolated/commands/check-intent.md
grep -q '#### Фаза 3: clarity' "$F" \
  && grep -q '#### Фаза 4: consistency (CRITICAL для противоречий)' "$F" \
  && grep -q '#### Фаза 5: alignment' "$F" \
  && grep -q 'Status-guard:' "$F" \
  && grep -q 'НЕ пересчитывать при hash-match' "$F" \
  && grep -q '### Логика обработки findings в каждой фазе' "$F" \
  && grep -q '### Шаг 4. Финальный вердикт' "$F" \
  && echo OK
```
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-intent.md
git commit -m "feat(commands): check-intent phases clarity/consistency/alignment + verdict"
```

---

## Task 5: Add Rules and Report format (forward footer)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-intent.md`

- [ ] **Step 1: Confirm the report format is absent (red)**

Run:
```bash
grep -c 'Next step: superpowers:brainstorming' .nvm-isolated/.claude-isolated/commands/check-intent.md
```
Expected: `0`

- [ ] **Step 2: Insert Rules and Report format before `$ARGUMENTS`**

Replace the unique trailing line `$ARGUMENTS` with the following block followed by a blank line and `$ARGUMENTS`:

````markdown
## Правила

**Запрещено:**
- Расширять чек-листы фаз (только закрытый список)
- Придумывать требования, которых нет ни в intent doc, ни в контексте разговора
- Редактировать тело intent doc, включая строку `**Status:**` (только guard-finding, не запись). Frontmatter `review:` — единственное исключение, обновляется командой
- Писать «вероятно подразумевается» без ссылки на текст

## Формат отчёта

```
## Проверка intent [дата]

### Файл
- <путь>
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
```

В конец отчёта добавить (intent — корень цепи, footer смотрит вперёд):
```
---
Next step: superpowers:brainstorming
```
````

- [ ] **Step 3: Verify Rules and Report format present, `$ARGUMENTS` still last (green)**

Run:
```bash
F=.nvm-isolated/.claude-isolated/commands/check-intent.md
grep -q '## Правила' "$F" \
  && grep -q '## Формат отчёта' "$F" \
  && grep -q '### Approval' "$F" \
  && grep -q 'Next step: superpowers:brainstorming' "$F" \
  && grep -q 'включая строку `\*\*Status:\*\*`' "$F" \
  && [ "$(tail -n1 "$F")" = '$ARGUMENTS' ] \
  && echo OK
```
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-intent.md
git commit -m "feat(commands): check-intent rules + report format (forward footer)"
```

---

## Task 6: Smoke test against real intent docs (spec acceptance 1–6)

This validates observable behavior. The command is LLM-driven, so "expected" describes the behavior you should observe when you invoke `/check-intent`. Use a temp copy so no committed intent doc is mutated.

**Files:**
- Reference: `docs/superpowers/intents/2026-06-14-cicd-pull-binary-delivery-intent.md` (valid, approved fixture source)
- Fixture: `/tmp/smoke-intent.md`, `/tmp/smoke-intent-broken.md` (ephemeral)

- [ ] **Step 1: Create a clean fixture copy (valid doc)**

Run:
```bash
cp docs/superpowers/intents/2026-06-14-cicd-pull-binary-delivery-intent.md /tmp/smoke-intent.md
cp /tmp/smoke-intent.md /tmp/smoke-intent.before.md   # snapshot for acceptance #6
```
Expected: both files exist (`ls -l /tmp/smoke-intent*.md`).

- [ ] **Step 2: First run on the valid fixture — full pass (acceptance #1, first half)**

Invoke: `/check-intent /tmp/smoke-intent.md`
Observe:
- It confirms the file, initializes a `review:` block, runs phases 1–5.
- Phases 1–4 report `passed` with 0 CRITICAL (the cicd intent is well-formed); phase 5 alignment is advisory.
- Final verdict: `OK`.
- A `review:` frontmatter block now exists at the top of `/tmp/smoke-intent.md`, with `intent_hash` set.

- [ ] **Step 3: Second run — cached quick-exit (acceptance #1, second half)**

Invoke: `/check-intent /tmp/smoke-intent.md`
Expected behavior: prints `OK (cached, hash match)` and stops without re-running the phases (hash matches, all deterministic phases `passed`, alignment `passed`, no open CRITICAL).

- [ ] **Step 4: Verify the body was untouched except for frontmatter (acceptance #6)**

Run:
```bash
# strip the leading frontmatter block from the after-run file, compare to the before snapshot.
# `sed '/./,$!d'` drops leading blank lines so the blank that follows the inserted
# frontmatter does not register as a body change.
awk 'BEGIN{fm=0} /^---$/{fm++; if(fm<=2) next} fm>=2{print}' /tmp/smoke-intent.md \
  | sed '/./,$!d' > /tmp/smoke-intent.body.md
diff <(sed '/./,$!d' /tmp/smoke-intent.before.md) /tmp/smoke-intent.body.md
```
Expected: empty diff (body byte-identical; only the `review:` frontmatter was added). If `diff` shows differences, the command edited the body — a defect; stop and fix.

- [ ] **Step 5: Create a broken fixture (seed defects) and run (acceptance #2, #3, #4)**

Run:
```bash
cp docs/superpowers/intents/2026-06-14-cicd-pull-binary-delivery-intent.md /tmp/smoke-intent-broken.md
```
Then edit `/tmp/smoke-intent-broken.md` to seed three defects:
1. Insert a literal `TODO` line under `## Objective` (triggers Phase 1 structure CRITICAL).
2. Change the `Done when:` line under `## Stop Rules` to read `Done when: code written and committed` (triggers Phase 3 clarity CRITICAL).
3. Change `**Status:** approved` to remain `approved` while the above CRITICALs are open (triggers Phase 4 Status-guard CRITICAL).

Invoke: `/check-intent /tmp/smoke-intent-broken.md`
Expected behavior:
- Phase 1 raises a CRITICAL for the `TODO` placeholder and **stops**, asking for a verdict before advancing (sequential gate).
- After resolving Phase 1 (e.g. mark `fixed`), Phase 3 raises a CRITICAL for `Done when: code written`.
- Phase 4 raises the Status-guard CRITICAL («approved, но документ не валиден»).
- Final verdict: `требует доработки: N critical open, ...`.
- `grep '^**Status:**' /tmp/smoke-intent-broken.md` still shows `approved` — the command did NOT rewrite the Status line.

- [ ] **Step 6: Verify lat-absent path is silent (acceptance #5)**

During Steps 2–5, if `lat_search` / `lat_refs` MCP tools are unavailable, confirm phase 5 alignment ran without error and produced no lat findings, and the deterministic verdict was unaffected. (No separate command — observed during the runs above.)

- [ ] **Step 7: Clean up fixtures**

Run:
```bash
rm -f /tmp/smoke-intent.md /tmp/smoke-intent.before.md /tmp/smoke-intent.body.md /tmp/smoke-intent-broken.md
```
Expected: no `/tmp/smoke-intent*` files remain (`ls /tmp/smoke-intent* 2>/dev/null || echo clean` → `clean`).

---

## Task 7: Final verification of the full command file

**Files:**
- Reference: `.nvm-isolated/.claude-isolated/commands/check-intent.md`

- [ ] **Step 1: Verify section order and completeness**

Run:
```bash
grep -nE '^(#{2,4} |Проверь intent|\$ARGUMENTS)' .nvm-isolated/.claude-isolated/commands/check-intent.md
```
Expected (in this order): description line → `## Алгоритм` → `### Канонический алгоритм хеширования` → `### Шаг 0` → `### Шаг 1` → `### Шаг 2` → `### Шаг 3` → `#### Фаза 1`…`#### Фаза 5` → `### Логика обработки findings` → `### Шаг 4` → `## Правила` → `## Формат отчёта` → trailing `$ARGUMENTS`.

- [ ] **Step 2: Verify the hashing block still byte-matches check-spec (convergence guard)**

Run:
```bash
D=.nvm-isolated/.claude-isolated/commands
diff <(sed -n '/### Канонический алгоритм хеширования/,/Любое отклонение ломает quick-exit\./p' "$D/check-spec.md") \
     <(sed -n '/### Канонический алгоритм хеширования/,/Любое отклонение ломает quick-exit\./p' "$D/check-intent.md")
```
Expected: empty diff. Any difference breaks cache convergence — fix to match `check-spec` exactly.

- [ ] **Step 3: Commit (if Step 1/2 required any fix; otherwise skip)**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-intent.md
git commit -m "fix(commands): align check-intent hashing block with check-spec"
```

---

## Self-Review

**Spec coverage** (each spec section → task):

- Objective / Position in chain (forward footer, no `chain:`) → Task 2 (scope note), Task 5 (footer).
- Reference layers (self / conversation / lat, alignment advisory) → Task 4 (phase 5).
- Canonical hashing + quick-exit (verbatim, `alignment.status==passed` not recomputed) → Task 1 (block), Task 2 (Step 0), Task 7 (diff guard).
- State `review:` schema (`intent_hash`, 5 phases incl. alignment, no `chain:`, findings dedup) → Task 2.
- Phases 1–5 closed checklists → Tasks 3–4.
- Status guard (read-only body) → Task 4 (phase 4), Task 5 (Rules), Task 6 Step 5 (smoke).
- Flow (steps 0–4, sequential gate) → Tasks 2–4.
- Report format (forward footer, Approval line) → Task 5.
- Rules (forbidden) → Task 5.
- File location → Task 1.
- Testing / acceptance 1–6 → Task 6.

No gaps found.

**Placeholder scan:** The only `TODO`/`TBD`/`code written` strings in this plan are intentional command checklist content or deliberately-seeded smoke-test defects (Task 6 Step 5). No plan-level placeholders.

**Type/name consistency:** field `intent_hash` (Task 2 schema, Task 2 Step 0, report format Task 5); phase names `structure / completeness / clarity / consistency / alignment` identical across Tasks 2, 3, 4, 5; insertion anchor `$ARGUMENTS` consistent across Tasks 1–5. Verdict strings (`OK`, `OK (cached, hash match)`, `требует доработки`) consistent between Step 0 (Task 2) and Step 4 (Task 4).
