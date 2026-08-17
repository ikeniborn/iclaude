---
name: prompt-verifier
description: Верификация и переписывание СУЩЕСТВУЮЩИХ инструкционных файлов (CLAUDE.md, AGENT.md, SKILL.md) против 7 правил форматирования. Использовать когда пользователь просит "проверить/исправить/проаудитить промт", "агент игнорирует правила", "отрефакторить инструкции", перед коммитом изменений в инструкционные файлы. НЕ для создания новых агентов — использовать agent-builder.
user-invocable: true
context: fork
agent: general-purpose
# version: 1.1.0 | updated: 2026-04-10
# tags: prompt, formatting, verification, claude-md, best-practices, agent-instructions
# dependencies: thinking-framework
---

# Prompt Verifier

Верификация и адаптация инструкционных файлов (CLAUDE.md, AGENT.md, SKILL.md) под 7 правил форматирования. Выявляет нарушения и выдаёт улучшенную версию с пояснениями.

## When to Use

- Перед коммитом нового или обновлённого CLAUDE.md / AGENT.md / SKILL.md
- Когда агент игнорирует написанные правила
- При рефакторинге инструкций (уменьшение объёма, повышение чёткости)

## Arguments

```
/prompt-verifier [file_path] [mode] [rules...]
```

| Аргумент | Тип | По умолчанию | Описание |
|----------|-----|-------------|----------|
| `file_path` | строка (путь) | — | Путь к файлу (первый аргумент, если не начинается с `verify`/`adapt`/`R`) |
| `mode` | `verify` \| `adapt` | `adapt` | Режим работы |
| `rules...` | `R1`–`R7` | все 7 | Правила для проверки (пробелом) |

```
/prompt-verifier CLAUDE.md
/prompt-verifier docs/AGENT.md verify
/prompt-verifier .claude/settings.json adapt R1 R5
```

Если `file_path` не передан — запроси у пользователя путь к файлу.

## How It Works

### Step 1: Load Input

1. Прочитай файл через `Read` по переданному `file_path`.
2. Определи режим: `verify` (только отчёт) или `adapt` (отчёт + переписанный документ, по умолчанию).
3. Определи список правил для проверки (`R1`–`R7`; по умолчанию — все).

### Step 2: Analyze Against 7 Rules

Проверь каждое правило:

| # | Правило | Критерий провала |
|---|---------|-----------------|
| R1 | **Обоснование запретов** | Запрет/ограничение без объяснения «почему» |
| R2 | **Плоская иерархия заголовков** | Использование h4/h5 (глубже 3 уровней) |
| R3 | **Описательные имена файлов** | Файлы с неинформативными именами (guide.md, notes.md, setup.sh) |
| R4 | **Заголовки для разделов** | Абзацы прозы без заголовков, конкурирующие инструкции без структуры |
| R5 | **Команды в блоках кода** | Команды/пути/инструменты в прозе, не в `` `backticks` `` или ` ```code``` ` |
| R6 | **Стандартные имена разделов** | Нестандартные названия вместо `## Testing`, `## Commands`, `## Structure` |
| R7 | **Выполнимые инструкции** | Расплывчатые инструкции, не проходящие тест «выполни немедленно» |

### Step 3: Report Violations

Для каждого нарушения укажи: правило (R1–R7), цитату проблемного фрагмента, последствие, конкретное исправление.

Итоговый score: количество выполненных правил из 7.

### Step 4: Adapt (режим `adapt`)

Перепиши документ, применив все исправления:
- Сохрани смысл; сократи объём на -30%
- Добавь обоснование к запретам
- Замени inline-команды блоками кода
- Преобразуй описательные шаги в императивы
- Используй стандартные имена разделов (English)

Выведи JSON по схеме `## Output Format`. Для режима `adapt` поле `adapted_document` — обязательно.

## Output Format

### verify mode

```json
{
  "verification": {
    "score": "{{score: integer, min 0, max 7}}",
    "rules_passed": ["{{rule_id: enum R1|R2|R3|R4|R5|R6|R7}}"],
    "violations": [
      {
        "rule": "{{rule_id: enum R1|R2|R3|R4|R5|R6|R7}}",
        "rule_name": "{{rule_name: string}}",
        "severity": "{{severity: enum critical|warning|info}}",
        "fragment": "{{fragment: string}}",
        "consequence": "{{consequence: string}}",
        "fix": "{{fix: string}}"
      }
    ],
    "summary": "{{summary: string}}"
  }
}
```

### adapt mode (дополнительно)

```json
{
  "verification": { "...": "...same as verify..." },
  "adaptation": {
    "adapted_document": "{{adapted_document: string}}",
    "changes_made": ["{{change: string}}"],
    "word_count_before": "{{word_count_before: integer}}",
    "word_count_after": "{{word_count_after: integer}}",
    "reduction_percent": "{{reduction_percent: integer}}"
  }
}
```

## Rules

- **@rules:best-practices.md** - Проектирование инструкций, типичные ловушки, советы по производительности

## Examples

- **@example:basic-claude-md.md** - Верификация простого CLAUDE.md (3 нарушения, режим adapt)
- **@example:agent-instructions.md** - Верификация инструкций агента (режим verify)
- **@example:skill-md-check.md** - Проверка SKILL.md с нестандартными именами разделов

## Templates

- **@template:input.json** - Входные данные для вызова скилла
- **@template:output-verify.json** - Структура выходных данных (verify mode)
- **@template:output-adapt.json** - Структура выходных данных (adapt mode)

## Schemas

- **@schema:input** - Валидация входных данных
- **@schema:output-verify** - Валидация выходных данных (verify mode)
- **@schema:output-adapt** - Валидация выходных данных (adapt mode)

## iwiki Integration

Этот скилл не вызывает `context-awareness` — читает состояние iwiki (`wiki_status`) напрямую.

**Read-only.** Скилл выполняется в отдельном контексте (`context: fork`) и потому является
субагентом: разрешены только `wiki_status`, `wiki_search`, `wiki_read_page`, `wiki_related`.
`wiki_bind` и любая запись в вики запрещены — привязка и запись принадлежат parent agent
(см. iwiki Project Binding и Task Log в `CLAUDE.md`).

### Query (в начале Step 2 — Analyze Against Rules)

```
IF iwiki MCP подключён AND wiki_status сообщает непустой primary:
  wiki_search(query='паттерны нарушений и best practices форматирования инструкций')

  Использовать результат для обогащения Step 2:
  - Если домен iwiki содержит задокументированные нарушения → добавить в анализ
  - Если домен iwiki содержит принятые стандарты форматирования → учесть при adapt
  - Если в домене iwiki нет данных → продолжить стандартный анализ по R1-R7
```

### Report (после Step 4 — только в режиме adapt)

Скилл ничего не пишет в вики. Если в режиме `adapt` найдены нарушения, он возвращает
parent agent'у предложение к записи — тот решает, публиковать ли его:

```
IF mode == "adapt" AND violations_found > 0:
  вернуть в выводе блок proposed_wiki_page:
    { slug, markdown, source: <verified_file_path>, rationale }
    — пример нарушения и его исправление (что и почему)

  Parent agent (единственный писатель) решает, вызывать ли wiki_write_page /
  wiki_update_page. Результат: эталоны нарушений и исправлений попадают в вики
  и переиспользуются при следующих проверках.
```

---

## Workflow Integration

### Input Dependencies

- Путь к файлу (обязательно) или inline-текст
- Режим: `verify` | `adapt` (default: `adapt`)

### Output Consumers

- Пользователь → применяет адаптированный документ
- `git-workflow` → коммит улучшенного файла
- CI/CD → автоматическая проверка CLAUDE.md перед мержем
