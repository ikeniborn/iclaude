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

$ARGUMENTS
