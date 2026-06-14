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

$ARGUMENTS
