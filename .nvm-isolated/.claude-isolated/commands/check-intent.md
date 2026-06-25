Проверь intent doc (корень цепи IDD→SDD) на самосогласованность с фазовой моделью и state во frontmatter.

Поддерживаемые аргументы:
- Путь к файлу intent doc — если не передан, файл определяется автоматически
- Контекст разговора используется advisory-фазой alignment

## Алгоритм

### Канонический алгоритм хеширования (ОБЯЗАТЕЛЬНО)

Все хеши — одним пайплайном (frontmatter живой, иначе quick-exit не сойдётся). Запускай bash через инструмент Bash, «в уме» не пересчитывай.

- **Хеш тела документа** (исключает frontmatter):
  ```bash
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
  ```
- **Хеш секции** — тело секции от заголовка `##`/`###` до следующего заголовка того же или более высокого уровня (не включая его), пропущенное через `sha256sum | cut -c1-16`.
- Если frontmatter отсутствует (`fm` < 2) — хеш всего файла: `sha256sum <FILE> | cut -c1-16`.

### Шаг 0. Quick exit по state

Если есть frontmatter с блоком `review:` и `current_body_hash == review.intent_hash` И:
- `∀ phase ∈ {structure, completeness, clarity, consistency}: status == passed`
- `alignment.status == passed` (НЕ пересчитывать — фаза недетерминирована, доверяем прошлому прогону)
- `∀ finding: verdict ∈ {accepted, wontfix, fixed}`
- `count(severity == CRITICAL ∧ verdict == open) == 0`

→ вывести `OK (cached, hash match)` и завершить. Иначе — продолжить.

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
- Использовать diff изменившихся секций из Шага 2 (init-state) — НЕ пересчитывать хеши заново; дать сводку изменений
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
   - Иначе — создать новый: `id: F-NNN` (монотонно следующий), `phase`, `severity`, `section`, `section_hash`, `fragment` (цитата нарушающего текста из секции, ≤140 симв; `null`, если структурная находка без конкретной строки), `text` (в чём проблема), `fix` (предлагаемое исправление), `verdict: open`, `verdict_at: null`
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

### Шаг 5. HTML-отчёт для пользователя

После финального вердикта (включая ветку quick-exit `OK (cached, hash match)`) вызови навык `html-report` через инструмент Skill (`skill: "html-report"`) и собери один self-contained `.html` — человекочитаемый артефакт для пользователя.

Цель отчёта: описать **требования и намерения** intent doc и показать **процесс** их достижения схемами, а не только перечислить findings. Передай навыку три блока (все обязательны):

1. **Резюме требований** — намерения intent doc как требования: Objective, Desired Outcomes, Health Metrics, Constraints (steering / hard), Autonomy Zones, Stop Rules. Каждый Desired Outcome и Constraint — отдельной строкой таблицы.
2. **Схемы намерений и процесса** (обязательны; используй CSS-диаграммы навыка, SVG-граф — для произвольных рёбер):
   - **Карта намерения** — block/flow-диаграмма потока `Objective → Desired Outcomes → Health Metrics`: как намерение превращается в наблюдаемый результат и чем измеряется.
   - **Граф автономии** — block-диаграмма из 4 зон (Full / Guarded / Proposal-first / No autonomy) с пунктами в каждой; пустая зона помечается `N/A`.
   - **Связь ограничений и результатов** — матрица `Constraint × Desired Outcome`: строки — Constraints (steering / hard), столбцы — Desired Outcomes, явная отметка в ячейке там, где constraint ограничивает outcome (пустая ячейка = нет связи).
   - **Stop Rules** — список критериев `Done when:` как условий завершения процесса.
3. **Результаты проверки** — по каждой из 5 фаз (structure / completeness / clarity / consistency / alignment) её `status`; таблица findings (`id`, `severity`, `section`, `fragment`, `text`, `fix`, `verdict`); сводка (CRITICAL open / WARNING open / alignment notes); финальный вердикт; intent — корень цепи, footer смотрит вперёд (`Next step: superpowers:brainstorming`).

**Определи `<topic>` (общий ключ цепи — все 4 команды `check-*` должны прийти к одному файлу).** Возьми basename файла intent doc без `.md`, затем:
1. срежь префикс даты `^[0-9]{4}-[0-9]{2}-[0-9]{2}-`;
2. срежь суффикс стадии — `-intent`, `-design` или `-plan` — **если присутствует** (на плане `-plan` опционален: `…-foo.md` и `…-foo-plan.md` дают один `<topic> = foo`);
3. остаток — `<topic>`.
**Fallback:** если basename не распознан (нет даты/суффикса по шаблону) — `<topic>` = basename без `.md` как есть. Дату в `<topic>` НЕ включать (стадии цепи могут иметь разные даты).

Параметры артефакта (передай навыку явно при вызове):
- **Режим:** `mode: chain`, `tab: intent`. Навык обновит ТОЛЬКО вкладку `intent`; остальные 3 вкладки (Intent / Spec / Plan / Result) сохранит дословно. Если файла нет — создаст все 4 (непройденные — с плейсхолдером «Этап ещё не проверен»).
- **Output path (явный аргумент):** `docs/superpowers/reports/<topic>-results.html` — единый отчёт цепи, без подкаталога и без префикса даты. Это caller-supplied путь (Full-зона): навык создаёт каталог `docs/superpowers/reports/` при отсутствии; первый запуск создаёт файл с 4 вкладками, повторный — сливает только свою вкладку.
- **Данные — inline:** три блока выше переданы в самом вызове. Навык НЕ читает источники сам и НЕ останавливается (halt) из-за «нечитаемого источника» — данные уже предоставлены.
- Язык — русский: весь текст отчёта (заголовки, описания, findings, сводки) на русском языке.

После записи сообщи пользователю путь к `.html`.

## Правила

**Запрещено:**
- Расширять чек-листы фаз (только закрытый список) — открытый список делает проверку недетерминированной и ломает hash-cache/quick-exit, тогда findings не воспроизводятся между прогонами
- Придумывать требования, которых нет ни в intent doc, ни в контексте разговора — валидатор сверяет с источником, а не генерирует; выдуманное требование = ложный finding, который автор не сможет закрыть
- Редактировать тело intent doc, включая строку `**Status:**` (только guard-finding, не запись) — тело это вход проверки и сигнал для остальных команд цепи; правка инвалидирует хеши и смешивает роли проверяющего и автора. Frontmatter `review:` — единственное исключение, обновляется командой
- Писать «вероятно подразумевается» без ссылки на текст — finding без якоря в тексте недоказуем и неустраним автором

## Формат отчёта

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

В конец отчёта добавить (intent — корень цепи, footer смотрит вперёд):
```
---
Next step: superpowers:brainstorming
```

$ARGUMENTS
