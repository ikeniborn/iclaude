---
review:
  plan_hash: ""
  spec_hash: ""
  last_run: 2026-05-26
  phases:
    structure:     { status: pending }
    coverage:      { status: pending }
    dependencies:  { status: pending }
    verifiability: { status: pending }
    consistency:   { status: pending }
  findings: []
chain:
  intent: docs/superpowers/intents/2026-05-26-check-result-intent.md
  spec:   docs/superpowers/specs/2026-05-26-check-result-design.md
---
# check-result + IDD→SDD Chain Navigation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `chain:` frontmatter navigation to `check-spec` and `check-plan`, and replace `verify.md` with `check-result.md` — a command that verifies git diff against intent + spec + plan.

**Architecture:** Three markdown command files modified/replaced. No code — these are Claude slash-command prompt files in `.nvm-isolated/.claude-isolated/commands/`. Changes are purely textual insertions and one full rewrite.

**Tech Stack:** Markdown, YAML frontmatter, bash (`git diff HEAD`, `find`)

---

## Files

- Modify: `.nvm-isolated/.claude-isolated/commands/check-spec.md`
- Modify: `.nvm-isolated/.claude-isolated/commands/check-plan.md`
- Replace: `.nvm-isolated/.claude-isolated/commands/verify.md` → `check-result.md`

---

### Task 1: Update check-spec.md — intent resolution + chain: block + footer

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-spec.md`

- [ ] **Step 1: Add intent resolution to Шаг 1**

In `check-spec.md`, find the block starting with `### Шаг 1. Определи scope` and append this paragraph directly after the last bullet of that section (before the next `###`):

```
Дополнительно — определи путь к intent doc:
- Если `$ARGUMENTS` содержит второй путь (к файлу `*intent.md`) — используй его
- Если intent doc упоминается в контексте разговора — используй его
- Иначе — извлеки `<topic>` из имени файла спеки (`YYYY-MM-DD-<topic>-design.md`) и выполни:
  ```bash
  find docs/superpowers/intents/ -name "*<topic>*intent.md" 2>/dev/null | head -1
  ```
- Если не найден — запомни `intent_path = null`, продолжай без блокировки
```

- [ ] **Step 2: Add chain: initialization to Шаг 2**

In `check-spec.md`, find the line:
```
   - Обновить `spec_hash` и `last_run`
```

Insert directly after it:
```
   - Если блока `chain:` нет во frontmatter — добавить:
     ```yaml
     chain:
       intent: <intent_path или null>
     ```
   - Если `chain:` уже есть — обновить `chain.intent` до resolved значения
```

- [ ] **Step 3: Add footer to report format**

In `check-spec.md`, find `## Формат отчёта` section. The format block ends with:
```
### Сводка
- CRITICAL open: N
- WARNING open: M
- Вердикт: OK | требует доработки
```

After the closing ` ``` ` of the format block, add:

```
Если `intent_path` известен — добавить в конец отчёта:
```
---
Previous step: <intent_path>
```
```

- [ ] **Step 4: Verify the file looks correct**

```bash
grep -n 'intent_path\|chain:\|Previous step' .nvm-isolated/.claude-isolated/commands/check-spec.md
```

Expected output: 3+ lines referencing the new additions.

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-spec.md
git commit -m "feat(commands): add chain: block and intent navigation to check-spec"
```

---

### Task 2: Update check-plan.md — intent resolution + chain: block + footer

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-plan.md`

- [ ] **Step 1: Add intent resolution to Шаг 1**

In `check-plan.md`, find `### Шаг 1. Определи scope` and append after its last bullet (before the next `###`):

```
Дополнительно — определи `intent_path`:
- Прочитай frontmatter спеки: если поле `chain.intent` присутствует — используй его
- Иначе — извлеки `<topic>` из имени файла плана (`YYYY-MM-DD-<topic>-plan.md`) и выполни:
  ```bash
  find docs/superpowers/intents/ -name "*<topic>*intent.md" 2>/dev/null | head -1
  ```
- Если не найден — `intent_path = null`
```

- [ ] **Step 2: Add chain: initialization to Шаг 2**

In `check-plan.md`, find:
```
   - Обновить `plan_hash`, `spec_hash`, `last_run`
```

Insert directly after it:
```
   - Если блока `chain:` нет во frontmatter плана — добавить:
     ```yaml
     chain:
       intent: <intent_path или null>
       spec:   <путь к спеке>
     ```
   - Если `chain:` уже есть — обновить оба поля до resolved значений
```

- [ ] **Step 3: Add footer to report format**

In `check-plan.md`, find the `## Формат отчёта` section. After the closing ` ``` ` of the format block, add:

```
В конец отчёта добавить:
```
---
Previous step: <spec_path>
```
Если `intent_path` известен — также добавить строку:
```
Chain: <intent_path> → <spec_path> → <plan_path>
```
```

- [ ] **Step 4: Verify the file looks correct**

```bash
grep -n 'intent_path\|chain:\|Previous step\|Chain:' .nvm-isolated/.claude-isolated/commands/check-plan.md
```

Expected output: 4+ lines referencing the new additions.

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-plan.md
git commit -m "feat(commands): add chain: block and intent+spec navigation to check-plan"
```

---

### Task 3: Replace verify.md with check-result.md

**Files:**
- Replace: `.nvm-isolated/.claude-isolated/commands/verify.md` → `check-result.md`

- [ ] **Step 1: Rename verify.md to check-result.md**

```bash
git mv .nvm-isolated/.claude-isolated/commands/verify.md \
       .nvm-isolated/.claude-isolated/commands/check-result.md
```

- [ ] **Step 2: Overwrite check-result.md with new content**

Write the following content to `.nvm-isolated/.claude-isolated/commands/check-result.md`:

```markdown
Сверь результаты выполнения плана с цепочкой IDD→SDD: intent + spec + plan vs git diff.

Поддерживаемые аргументы:
- Путь к файлу плана — обязателен
- `--since=<ref>` — использовать diff от указанного ref вместо HEAD

## Алгоритм

### Шаг 1. Загрузи план

- Прочитай файл плана из `$ARGUMENTS`
- Извлеки `chain.intent` и `chain.spec` из frontmatter
- Если отсутствуют — извлеки `<topic>` из имени файла плана (`YYYY-MM-DD-<topic>-plan.md`) и выполни:
  ```bash
  find docs/superpowers/intents/ -name "*<topic>*intent.md" 2>/dev/null | head -1
  find docs/superpowers/specs/   -name "*<topic>*design.md" 2>/dev/null | head -1
  ```
- Если план не найден — сообщи: «Не найден план. Укажи путь: `/check-result path/to/plan.md`» и остановись
- Если intent или spec не найдены — предупреди пользователя, продолжай с доступными документами

### Шаг 2. Загрузи документы

- **Intent doc:** прочитай секции Objective, Desired Outcomes, Constraints
- **Spec:** прочитай секции требований и Success Criteria
- **План:** прочитай все шаги (и `[ ]`, и `[x]`)

### Шаг 3. Получи git diff

```bash
git diff HEAD
```

Если передан `--since=<ref>`: `git diff <ref>`.

Если diff пустой — сообщи: «Нет незакоммиченных изменений. Запусти после внесения изменений или передай `--since=<ref>`.»

### Шаг 4. Сопоставь шаги плана с diff

Для каждого шага плана:

1. Извлеки явные пути к файлам из текста шага
2. Проверь наличие этих файлов в `git diff HEAD`
3. Для шагов без явных путей — семантическое сопоставление:
   - `DONE` — изменения в diff чётко и полностью соответствуют описанию шага
   - `PARTIAL` — diff содержит связанные изменения, но упускает часть описанного действия (например, шаг говорит «переименовать и переписать X», а в diff только переименование)
   - `MISSING` — никаких свидетельств шага в diff нет

Дополнительно — найди `EXCESS`: изменённые файлы в diff без соответствующего шага плана.

### Шаг 5. Проверь покрытие intent + spec

- Для каждого Desired Outcome из intent doc: отражён ли в diff?
- Для каждого требования / Success Criterion из spec: отражён ли в diff?
- Непокрытое → finding со ссылкой на конкретный outcome/требование

### Шаг 6. Сформируй отчёт

## Severity

| Severity | Условие |
|----------|---------|
| `[CRITICAL]` | Шаг плана полностью отсутствует в diff |
| `[WARNING]` | Шаг выполнен частично; или избыточные изменения без привязки к плану |
| `[INFO]` | Семантическое расхождение; outcome из intent частично отражён |

## Формат finding

Каждый finding содержит:
- **Plan:** что говорит шаг плана
- **Diff:** что показывает git diff (или «изменений не найдено»)
- **Fix options:** варианты исправления

## Формат отчёта

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

## Правила

**Запрещено:**
- Выдавать finding без ссылки на конкретный шаг плана или outcome
- Запускать code review (синтаксис, безопасность) — это не назначение команды
- Писать «вероятно выполнено» без свидетельства в diff

$ARGUMENTS
```

- [ ] **Step 3: Verify file content**

```bash
wc -l .nvm-isolated/.claude-isolated/commands/check-result.md
grep -n 'chain\.\|DONE\|PARTIAL\|MISSING\|EXCESS\|Шаг 1\|Шаг 2\|Шаг 3\|Шаг 4\|Шаг 5\|Шаг 6' \
  .nvm-isolated/.claude-isolated/commands/check-result.md | head -20
```

Expected: file has 80+ lines, grep shows all 6 algorithm steps and classification terms.

- [ ] **Step 4: Verify verify.md no longer exists**

```bash
ls .nvm-isolated/.claude-isolated/commands/
```

Expected: `check-result.md` present, `verify.md` absent.

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-result.md
git commit -m "feat(commands): replace verify.md with check-result — IDD→SDD result verification"
```

---

### Task 4: Smoke test the chain end-to-end

**Files:** none (read-only verification)

- [ ] **Step 1: Verify check-spec has chain: additions**

```bash
grep -c 'intent_path\|chain:\|Previous step' \
  .nvm-isolated/.claude-isolated/commands/check-spec.md
```

Expected: count ≥ 3

- [ ] **Step 2: Verify check-plan has chain: additions**

```bash
grep -c 'intent_path\|chain:\|Previous step\|Chain:' \
  .nvm-isolated/.claude-isolated/commands/check-plan.md
```

Expected: count ≥ 4

- [ ] **Step 3: Verify check-result has all required sections**

```bash
for section in "Шаг 1" "Шаг 2" "Шаг 3" "Шаг 4" "Шаг 5" "Шаг 6" \
               "CRITICAL" "WARNING" "EXCESS" "chain\." "Fix options" "Previous step"; do
  grep -q "$section" .nvm-isolated/.claude-isolated/commands/check-result.md \
    && echo "OK: $section" || echo "MISSING: $section"
done
```

Expected: all lines print `OK:`.

- [ ] **Step 4: Commit final check**

```bash
git log --oneline -5
```

Expected: 3 commits from this plan visible in history.
```
