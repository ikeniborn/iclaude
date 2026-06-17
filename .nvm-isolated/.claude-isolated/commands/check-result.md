Сверь результаты выполнения плана с цепочкой IDD→SDD: intent + spec + plan vs git diff.

Поддерживаемые аргументы:
- Путь к файлу плана — обязателен
- `--since=<ref>` — использовать diff от указанного ref вместо HEAD

## Алгоритм

### Канонический алгоритм хеширования (ОБЯЗАТЕЛЬНО)

Хеш тела плана для `result_check.plan_hash` считается ТЕМ ЖЕ пайплайном, что у
остальных валидаторов и у idd-gate, иначе merge-gate не сойдётся:

```bash
awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <PLAN_FILE> | sha256sum | cut -c1-16
```

Команда ОБЯЗАНА запускать именно эту bash-команду через инструмент Bash. «В уме»
не пересчитывать.

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

### Шаг 7. Запиши state в frontmatter плана

После отчёта впиши машиночитаемый блок в **frontmatter плана** (тело плана НЕ
трогать — это сигнал прохождения merge-gate для idd-gate).

1. Посчитай хеш тела плана по каноническому алгоритму (см. выше).
2. Определи вердикт: `OK`, если CRITICAL findings нет (нет MISSING-шагов);
   иначе `needs_work`.
3. Создай блок `result_check:` (или обнови существующий) во frontmatter плана:
   ```yaml
   result_check:
     verdict: OK | needs_work
     plan_hash: <хеш тела плана>
     last_run: <today>
   ```
   Если frontmatter в плане отсутствует — добавь его в начало файла
   (`---` … `---`), не меняя тело.

### Шаг 8. HTML-отчёт для пользователя

После записи `result_check` вызови навык `html-report` через инструмент Skill (`skill: "html-report"`) и собери один self-contained `.html` — человекочитаемый артефакт для пользователя.

Передай навыку данные (оба блока обязательны):

1. **Резюме сверки** — документы цепи (plan / spec / intent), база diff.
2. **Результаты проверки** — покрытие шагов плана (DONE / PARTIAL / MISSING счётчики); таблица findings (`severity`, шаг, Plan / Diff / Fix options); intent / spec coverage (Desired Outcomes N/M, requirements N/M); excess changes; сводка (CRITICAL / WARNING / INFO); вердикт; chain (`intent → spec → plan`).

Параметры артефакта:
- Выход: `docs/superpowers/reports/<basename плана без .md>-result-check.html` (например `2026-06-17-foo-plan-result-check.html`). Создай каталог `docs/superpowers/reports/`, если его нет.
- Перезаписывать существующий файл **без подтверждения** — это автогенерируемый артефакт команды. Это явный override proposal-first навыка `html-report` для данного пути.
- Язык — русский: весь текст отчёта (заголовки, описания, findings, сводки) на русском языке.

После записи сообщи пользователю путь к `.html`.

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
