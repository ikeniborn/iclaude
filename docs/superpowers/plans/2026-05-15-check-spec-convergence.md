---
review:
  plan_hash: sha256:91e525c110573397
  spec_hash: sha256:ac53035535612070
  last_run: 2026-05-15
  phases:
    structure:     { status: passed, finished: 2026-05-15 }
    coverage:      { status: passed, finished: 2026-05-15 }
    dependencies:  { status: passed, finished: 2026-05-15 }
    verifiability: { status: passed, finished: 2026-05-15 }
    consistency:   { status: passed, finished: 2026-05-15 }
  findings:
    - id: F-001
      phase: verifiability
      severity: WARNING
      section: Task 3 / Step 5
      section_hash: sha256:pending
      text: "«те же гарантии» без конкретной verify-команды и ожидаемого вывода — критерий DoD неизмерим"
      verdict: accepted
      verdict_at: 2026-05-15
---

# Check-Spec / Check-Plan Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести команды `/check-spec` и `/check-plan` на 4/5-фазную модель с frontmatter state, sha-привязкой findings и машинным exit-критерием — устранить цикличность повторных проверок.

**Architecture:** Каждая команда — markdown-инструкция для LLM. Меняется алгоритм внутри markdown: добавляется шаг 0 (quick exit по хешу), фазы с закрытыми чек-листами, формат frontmatter `review:` с findings/verdicts, явный exit-критерий. Кода нет — только prompt engineering. Верификация ручная на реальной спеке.

**Tech Stack:** Markdown command files (`.nvm-isolated/.claude-isolated/commands/*.md`), YAML frontmatter в spec/plan документах, sha256 для хеширования секций.

**Reference:** [docs/superpowers/specs/2026-05-15-check-spec-convergence-design.md](../specs/2026-05-15-check-spec-convergence-design.md)

---

## File Structure

| Файл | Действие | Ответственность |
|------|----------|-----------------|
| `.nvm-isolated/.claude-isolated/commands/check-spec.md` | Modify (полная переработка) | Алгоритм проверки спецификации: 4 фазы + state |
| `.nvm-isolated/.claude-isolated/commands/check-plan.md` | Modify (полная переработка) | Алгоритм проверки плана: 5 фаз + state |
| `docs/superpowers/specs/<test-spec>.md` | Test artifact | Реальная спека для прогона e2e-проверок |

---

### Task 1: Переработать check-spec.md

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-spec.md` (полностью переписать содержимое)

- [ ] **Step 1: Прочитать текущий файл**

Run: `cat .nvm-isolated/.claude-isolated/commands/check-spec.md`
Expected: текущее содержимое (75 строк, один проход без фаз)

- [ ] **Step 2: Записать новое содержимое**

Заменить файл целиком:

````markdown
Проверь спецификацию на соответствие задачам с фазовой моделью и state во frontmatter.

Поддерживаемые аргументы:
- Путь к файлу спецификации — если не передан, файл определяется автоматически
- Задачи берутся из контекста разговора

## Алгоритм

### Шаг 0. Quick exit по state

1. Если файл найден и содержит frontmatter с блоком `review:`:
   - Посчитать sha256 тела документа (исключая frontmatter)
   - Если `current_hash == frontmatter.review.spec_hash` И все condition'ы выполнены:
     - `∀ phase ∈ phases: status == passed`
     - `∀ finding ∈ findings: verdict ∈ {accepted, wontfix, fixed}`
     - `count(severity == CRITICAL ∧ verdict == open) == 0`
   - → вывести `OK (cached, hash match)` и завершить
2. Иначе — продолжить

### Шаг 1. Определи scope

- Если имя/тема задачи известна из контекста — ищи файл по имени в `docs/superpowers/specs/`
- Если передан путь в `$ARGUMENTS` — работай с указанным файлом
- Иначе — последний изменённый файл в `docs/superpowers/specs/`
- Если не найден — сообщи: «Не найдена спецификация. Укажи путь: `/check-spec path/to/spec.md`»

### Шаг 2. Подтверди файл и инициализируй state

1. Сообщи: «Буду проверять: `<путь>`. Верно?»
2. После подтверждения:
   - Прочитать frontmatter. Если блока `review:` нет — инициализировать пустой:
     ```yaml
     review:
       spec_hash: <sha256 тела>
       last_run: <today>
       phases:
         structure:    { status: pending }
         coverage:     { status: pending }
         clarity:      { status: pending }
         consistency:  { status: pending }
       findings: []
     ```
   - Посчитать хеши всех секций (по заголовкам `##`/`###`)
   - Для каждого существующего finding с `section_hash != current_section_hash` — сбросить `verdict: open`
   - Обновить `spec_hash` и `last_run`

### Шаг 3. Выполнение фаз

Фазы выполняются строго последовательно. Фаза N+1 стартует только если в фазе N нет CRITICAL с `verdict: open`.

#### Фаза 1: structure

Закрытый чек-лист (НЕ расширять):
- Плейсхолдеры: `TODO`, `TBD`, `???`, `FIXME`
- Битые внутренние ссылки на разделы (§X.Y, [link](#anchor))
- Нумерация секций (пропуски, дубликаты номеров)
- Дублирующиеся заголовки секций

#### Фаза 2: coverage

Закрытый чек-лист:
- Каждая задача из контекста разговора покрыта ≥1 требованием спеки
- Каждое требование спеки привязано к задаче (нет «лишних»)
- Противоречия между требованиями (§X говорит A, §Y говорит ¬A)

#### Фаза 3: clarity

Закрытый чек-лист:
- Неоднозначные формулировки без критерия: «быстро», «удобно», «при необходимости», «достаточно», «надёжно»
- Требования без явного DoD / критерия приёмки
- Несогласованные термины (одна сущность — разные названия)

#### Фаза 4: consistency

Закрытый чек-лист:
- Проверка хешей секций: для каждой секции — изменилась ли с прошлого прогона
- Сводка по изменившимся секциям и связанным findings

### Логика обработки findings в каждой фазе

1. Прочитать существующие findings этой фазы из frontmatter
2. Применить чек-лист фазы к телу спеки
3. Для каждой потенциальной находки:
   - Если уже существует finding с тем же `section` и совпадающим `text` И `section_hash` не изменился → НЕ дублировать
   - Иначе — создать новый: `id: F-NNN` (монотонно следующий), `phase`, `severity`, `section`, `section_hash`, `text`, `verdict: open`, `verdict_at: null`
4. Записать обновлённый frontmatter в файл
5. Вывести отчёт по фазе
6. Запросить у пользователя verdict для новых findings:
   - CRITICAL — обязательно (`accepted | wontfix | fixed`)
   - WARNING — желательно
   - INFO — опционально
7. Записать verdicts. Если все CRITICAL фазы закрыты → `phase.status = passed`, переход к следующей
8. Иначе → `phase.status = in_progress`, остановка с просьбой исправить и перезапустить

### Шаг 4. Финальный вердикт

Применить exit-критерий из шага 0. Вывести `OK` либо `требует доработки: <N> critical open, <M> warning open`.

## Правила

**Запрещено:**
- Расширять чек-листы фаз (только закрытый список)
- Придумывать задачи, которых не было в исходном описании
- Редактировать тело спецификации (frontmatter — исключение, обновляется командой)
- Писать «вероятно подразумевается» без ссылки на текст

## Формат отчёта

```
## Проверка спецификации [дата]

### Файл
- <путь>
- spec_hash: <sha256:short>
- prev_hash: <sha256:short>

### Фаза 1: structure — passed | in_progress | skipped
- Новые findings: N
  - F-001 [CRITICAL] §X.Y — описание

### Фаза 2: coverage — ...
### Фаза 3: clarity — ...
### Фаза 4: consistency — ...

### Сводка
- CRITICAL open: N
- WARNING open: M
- Вердикт: OK | требует доработки
```

$ARGUMENTS
````

- [ ] **Step 3: Проверить syntax**

Run: `head -20 .nvm-isolated/.claude-isolated/commands/check-spec.md`
Expected: первые строки нового алгоритма видны, markdown валиден

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-spec.md
git commit -m "feat(commands): rewrite check-spec with phased model + frontmatter state

Replaces single-pass review with 4 ortogonal phases (structure,
coverage, clarity, consistency), each with closed checklist.
Adds frontmatter review block with spec_hash, per-phase status,
findings with section_hash and verdict. Quick exit on hash match
skips LLM entirely. Fixes cyclic findings problem described in
docs/superpowers/specs/2026-05-15-check-spec-convergence-design.md."
```

---

### Task 2: Переработать check-plan.md

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-plan.md`

- [ ] **Step 1: Прочитать текущий файл**

Run: `cat .nvm-isolated/.claude-isolated/commands/check-plan.md`
Expected: 77 строк, текущая логика одного прохода

- [ ] **Step 2: Записать новое содержимое**

````markdown
Проверь план на соответствие спецификации с фазовой моделью и state во frontmatter.

Поддерживаемые аргументы:
- Путь к файлу плана — если не передан, определяется автоматически
- Путь к спецификации — если не передан, определяется автоматически

## Алгоритм

### Шаг 0. Quick exit по state

1. Если файл плана найден и содержит frontmatter с блоком `review:`:
   - Посчитать sha256 тела плана (без frontmatter)
   - Посчитать sha256 тела связанной спеки
   - Если `plan_hash == frontmatter.review.plan_hash` И `spec_hash == frontmatter.review.spec_hash` И:
     - `∀ phase: status == passed`
     - `∀ finding: verdict ∈ {accepted, wontfix, fixed}`
     - `count(severity == CRITICAL ∧ verdict == open) == 0`
   - → вывести `OK (cached, hash match)` и завершить
2. Иначе — продолжить

### Шаг 1. Определи scope

- Если имя/тема задачи известна — ищи план в `docs/superpowers/plans/`, спеку в `docs/superpowers/specs/`
- Если передан путь в `$ARGUMENTS` — работай с указанным планом
- Иначе — последний изменённый файл в `docs/superpowers/plans/`
- Спека: совпадение по имени или последний изменённый в `docs/superpowers/specs/`
- Если не найден — сообщи: «Не найден план. Укажи путь: `/check-plan path/to/plan.md`»

### Шаг 2. Подтверди файлы и инициализируй state

1. Сообщи: «Буду проверять план: `<путь>` против спеки: `<путь>`. Верно?»
2. После подтверждения:
   - Прочитать frontmatter плана. Если блока `review:` нет — инициализировать:
     ```yaml
     review:
       plan_hash: <sha256 тела плана>
       spec_hash: <sha256 тела спеки>
       last_run: <today>
       phases:
         structure:     { status: pending }
         coverage:      { status: pending }
         dependencies:  { status: pending }
         verifiability: { status: pending }
         consistency:   { status: pending }
       findings: []
     ```
   - Посчитать хеши секций плана (шагов/тасков)
   - Для existing findings с изменившимся `section_hash` — `verdict: open`
   - Обновить `plan_hash`, `spec_hash`, `last_run`

### Шаг 3. Выполнение фаз

Фазы строго последовательны. Фаза N+1 стартует только если в фазе N нет CRITICAL открытых.

#### Фаза 1: structure

Закрытый чек-лист:
- Плейсхолдеры: `TODO`, `TBD`, `???`, `FIXME`
- Нумерация шагов/тасков (пропуски, дубли)
- Дублирующиеся заголовки шагов

#### Фаза 2: coverage

Закрытый чек-лист:
- Каждое требование спеки покрыто ≥1 шагом плана
- Каждый шаг плана привязан к требованию спеки (нет «лишних»)

#### Фаза 3: dependencies

Закрытый чек-лист:
- Порядок шагов: использование результата шага M в шаге N → M < N
- Циклические зависимости между шагами
- Доступность артефактов (файл/функция, упомянутые в шаге, созданы в предыдущем шаге)

#### Фаза 4: verifiability

Закрытый чек-лист:
- Каждый шаг имеет измеримый критерий готовности (DoD)
- Шаги без явного результата («проработать», «изучить», «улучшить» без выхода)
- Шаги без команды проверки / ожидаемого вывода

#### Фаза 5: consistency

Закрытый чек-лист:
- Сверка хешей секций плана и спеки
- Сводка по изменившимся секциям

### Логика обработки findings

Идентична check-spec:
1. Не дублировать existing findings с тем же `section + text + section_hash`
2. Новые → `id: F-NNN`, `verdict: open`
3. Записать frontmatter
4. Отчёт + запрос verdicts
5. Все CRITICAL закрыты → `passed`, переход; иначе → `in_progress`, остановка

### Шаг 4. Финальный вердикт

Применить exit-критерий. Вывод: `OK` либо `требует доработки: <N> critical, <M> warning`.

## Правила

**Запрещено:**
- Расширять чек-листы фаз
- Придумывать требования, которых нет в спеке
- Редактировать тело плана или спеки (frontmatter плана — исключение)
- Писать «шаг подразумевает» без ссылки на текст

## Формат отчёта

```
## Проверка плана [дата]

### Файлы
- План: <путь> (plan_hash: <short>, prev: <short>)
- Спека: <путь> (spec_hash: <short>, prev: <short>)

### Фаза 1: structure — passed | in_progress | skipped
- Новые findings: N
  - F-001 [CRITICAL] §X.Y — описание

### Фаза 2: coverage — ...
### Фаза 3: dependencies — ...
### Фаза 4: verifiability — ...
### Фаза 5: consistency — ...

### Сводка
- CRITICAL open: N
- WARNING open: M
- Вердикт: OK | требует доработки
```

$ARGUMENTS
````

- [ ] **Step 3: Проверить syntax**

Run: `head -20 .nvm-isolated/.claude-isolated/commands/check-plan.md`
Expected: первые строки нового алгоритма

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-plan.md
git commit -m "feat(commands): rewrite check-plan with phased model + frontmatter state

Mirrors check-spec rewrite. 5 phases (structure, coverage, dependencies,
verifiability, consistency) with closed checklists. Frontmatter review
block tracks plan_hash + spec_hash + findings with verdicts. Quick
exit on dual hash match skips LLM. Same convergence guarantees as
check-spec."
```

---

### Task 3: E2E-верификация на реальной спеке

**Files:**
- Test: использовать `docs/superpowers/specs/2026-05-15-check-spec-convergence-design.md` как мишень

- [ ] **Step 1: Первый прогон check-spec на свежей спеке (без frontmatter.review)**

Действие пользователя: запустить `/check-spec docs/superpowers/specs/2026-05-15-check-spec-convergence-design.md`

Expected:
- Шаг 0 пропускается (нет review-блока)
- Шаг 2 инициализирует review-блок во frontmatter
- Фазы 1-4 выполняются последовательно
- Findings (если есть) получают id `F-001+`
- В конце frontmatter содержит `review:` с заполненными `phases` и `findings`

Verify: `grep -A 20 '^review:' docs/superpowers/specs/2026-05-15-check-spec-convergence-design.md`

- [ ] **Step 2: Поставить verdicts на все open findings**

Действие пользователя: для каждого open finding выставить `accepted | wontfix | fixed` через диалог с командой.

Expected: frontmatter findings обновлены, `verdict_at` заполнен.

- [ ] **Step 3: Повторный прогон check-spec без изменений спеки**

Действие пользователя: запустить `/check-spec` повторно на том же файле.

Expected:
- Шаг 0 видит совпавший `spec_hash` и все verdicts закрыты
- Вывод: `OK (cached, hash match)` — БЕЗ запуска фаз
- Frontmatter не изменился

Verify: вывод команды содержит `cached`, дата `last_run` не обновилась.

- [ ] **Step 4: Изменить одну секцию спеки, повторить прогон**

Действие пользователя:
1. Внести правку в одну секцию спеки (например, добавить предложение в §«Проблема»)
2. Запустить `/check-spec`

Expected:
- `spec_hash` не совпал → Шаг 0 не делает quick exit
- Шаг 2 видит изменившийся `section_hash` для §«Проблема» → vedicts findings этой секции (если были) сбрасываются в `open`
- Vedicts ДРУГИХ секций остаются `accepted/wontfix/fixed`
- Фазы перепроверяют только при необходимости; не дублируют существующие findings

Verify: `grep verdict docs/superpowers/specs/2026-05-15-check-spec-convergence-design.md` — большая часть verdicts не сбросилась.

- [ ] **Step 5: Аналогичный прогон check-plan**

Действие пользователя:
1. Запустить `/check-plan docs/superpowers/plans/2026-05-15-check-spec-convergence.md` (первый прогон)
2. Выставить verdicts на все open findings
3. Запустить `/check-plan` повторно на том же файле

Expected:
- Первый прогон: блок `review:` с `plan_hash` и `spec_hash` инициализируется во frontmatter плана; фазы 1–5 выполняются; findings (если есть) получают id `F-NNN`
- Повторный прогон: вывод содержит `OK (cached, hash match)` БЕЗ запуска фаз; `last_run` не обновился

Verify:
- `grep -A 20 '^review:' docs/superpowers/plans/2026-05-15-check-spec-convergence.md` — блок review присутствует с `plan_hash` + `spec_hash`
- Повторный прогон в выводе содержит строку `cached`

- [ ] **Step 6: Commit результатов верификации**

Если frontmatter спеки/плана был обновлён командой — закоммитить:

```bash
git add docs/superpowers/specs/2026-05-15-check-spec-convergence-design.md \
        docs/superpowers/plans/2026-05-15-check-spec-convergence.md
git commit -m "chore(specs): record check-spec/check-plan review state

E2E verification of phased convergence model. Frontmatter review
blocks populated, all findings have verdicts, hash-based quick exit
confirmed working."
```

---

## Self-Review Checklist

- [x] Все 4 фазы check-spec из спеки реализованы (Task 1)
- [x] Все 5 фаз check-plan из спеки реализованы (Task 2)
- [x] Frontmatter формат идентичен спеке (spec_hash/plan_hash, phases, findings с section_hash + verdict)
- [x] Exit-критерий реализован в Шаге 0 обеих команд
- [x] Запреты из спеки перенесены в правила команд
- [x] Совместимость со старыми спеками: пустой review-блок инициализируется при первом прогоне
- [x] E2E-верификация покрывает: первый прогон, cached OK, точечный сброс vedicts при изменении секции
- [x] Нет плейсхолдеров TBD/TODO в самом плане

## DoD плана

Считается выполненным, когда:
- check-spec.md и check-plan.md содержат фазовую модель
- Е2E прогон на самой этой спеке/плане даёт cached OK на 2-м запуске
- Изменение одной секции сбрасывает только её verdicts
