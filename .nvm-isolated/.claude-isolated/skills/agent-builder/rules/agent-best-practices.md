# Agent Best Practices

## 1. Официальная схема frontmatter

Официальная документация: https://code.claude.com/docs/en/sub-agents

### Обязательные поля (ВСЕГДА присутствуют):

- **`name`** — идентификатор в kebab-case, уникальный в директории
- **`description`** — как/когда использовать агента; используется родительской моделью для маршрутизации

### Невалидные поля (НИКОГДА не использовать):

```
version, role, subagent_type, capabilities,
input_file, output_file, input_schema, output_schema,
parameters, input_files
```

Эти поля не входят в официальную схему и молча игнорируются Claude Code.
Их наличие вводит в заблуждение разработчиков и нарушает совместимость.

---

## 2. Принцип минимальных привилегий для tools

Указывай только инструменты, которые агент реально использует.
Колонка `disallowedTools` — явный запрет, он надёжнее чем просто не указать инструмент:

| Тип агента | tools | disallowedTools |
|------------|-------|-----------------|
| Read-only | `Read, Glob, Grep` | `Bash, Write, Edit, Task` |
| Critic/Auditor | `Read, Glob, Grep` | `Bash, Write, Edit, Task` |
| Researcher | `Read, Glob, Grep, Task, WebSearch, WebFetch` | `Bash, Write, Edit` |
| Web researcher | `WebSearch, WebFetch, Read, Write` | `Bash, Edit, Task` |
| Planner | `Read, Glob, Grep, Write` | `Bash, Edit, Task` |
| Executor | `Read, Glob, Grep, Write, Edit, Bash, Task` | — |

> **Важно:** `Bash` даёт полный доступ к системе. Никогда не давай `Bash`
> агентам, которые должны быть read-only — используй `disallowedTools: Bash`.
>
> **Planner** получает `Glob, Grep` для исследования кодовой базы перед планированием,
> но не `Edit` — планировщик пишет новые файлы, а не изменяет существующий код.

---

## 3. Написание description

Description — самое важное поле. Именно по нему Claude Code решает,
когда вызывать агента.

### Формула хорошей description:
```
{Роль-агента} для {область применения}.
{Что принимает на вход}. {Что возвращает/записывает}.
```

### Примеры:

```yaml
# ✅ ХОРОШО — конкретно, ориентировано на действие
description: >
  Агент аудита безопасности bash-скриптов. Анализирует файлы
  на command injection, hardcoded secrets, небезопасные права доступа.
  Возвращает JSON-отчёт с severity и рекомендациями по исправлению.

# ✅ ХОРОШО — читается однозначно
description: >
  Read-only research agent for codebase analysis in Researcher→Planner→Executor
  pipeline. Finds relevant files, analyzes architecture and risks.
  Writes structured research.toon to workspace.

# ❌ ПЛОХО — слишком общая
description: Agent for code analysis

# ❌ ПЛОХО — дублирует name
description: researcher-agent that does research
```

---

## 4. Структура тела AGENT.md

Стандартные секции (порядок важен):

```markdown
# Роль: {DisplayName}       ← обязательно
## Входные данные           ← обязательно
## Алгоритм выполнения      ← обязательно
## ПРАВИЛА (СТРОГИЕ)        ← обязательно
## Сигнал завершения        ← обязательно
## Примеры использования    ← рекомендуется
## Связанные агенты         ← если есть зависимости
```

---

## 5. Graceful Degradation

Агент должен корректно обрабатывать ошибки:

```markdown
## Graceful Degradation

- Если входной файл не найден → вывести ошибку, STOP без записи выходного файла
- Если внешний сервис недоступен → записать `status: "UNAVAILABLE"`, продолжить
- Если часть данных недоступна → записать что найдено, отметить пробелы
```

---

## 6. Сигнал завершения

Каждый агент ДОЛЖЕН иметь чёткий сигнал завершения:
- Позволяет оркестратору определить успешное завершение
- Содержит ключевые метрики выполнения
- Указывает путь к выходному файлу

````markdown
## Сигнал завершения

После записи `{output-file}` вывести:

```
════════════════════════════════════════════
✅ AGENT_NAME COMPLETE
════════════════════════════════════════════
Файл: {WORKSPACE}/output-file.toon

Метрика 1: {значение}
Метрика 2: {значение}
════════════════════════════════════════════
```
````

---

## 7. Токенный бюджет

Явно ограничивай количество tool calls во избежание runaway агентов:

```markdown
### Токенный бюджет

| Операция | Максимум |
|----------|----------|
| WebSearch | 6 вызовов |
| WebFetch | 10 вызовов |
| Read | 20 вызовов |
| Итого turns | 40 |
```

Используй поле `maxTurns` в frontmatter для hard limit.

---

## 8. READ-ONLY агенты

Если агент не должен изменять проект — укажи явно:

```yaml
# В frontmatter:
disallowedTools: Bash, Write, Edit

# В теле AGENT.md:
## ПРАВИЛА (СТРОГИЕ)

### READ-ONLY для кодовой базы
- ❌ НЕ создавать файлы в проекте
- ❌ НЕ изменять файлы проекта
- ❌ НЕ запускать bash команды изменяющие состояние
- ✅ ТОЛЬКО: Read, Glob, Grep, Write({WORKSPACE}/output.toon)
```

---

## 9. Версионирование агентов

Версию агента хранить в комментарии HTML, не в frontmatter:

```markdown
---
name: my-agent
description: ...
---
<!-- version: 1.0.0 | updated: 2026-02-24 -->

# Роль: My Agent
```

---

## 10. Расположение агентов

| Тип | Путь | Auto-discovery | Вызов |
|-----|------|----------------|-------|
| Нативный проект | `.claude/agents/{name}.md` | ✅ Claude Code | `Task(subagent_type="{name}")` |
| Нативный глобальный | `~/.claude/agents/{name}.md` | ✅ Claude Code | `Task(subagent_type="{name}")` |
| iclaude изолированный | `.nvm-isolated/.claude-isolated/agents/{name}/AGENT.md` | ❌ только через оркестратор | `Task(subagent_type="general-purpose", prompt=agent_md+context)` |

Для нативного расположения Claude Code полностью поддерживает все поля схемы.
Для iclaude-изолированного — поля схемы используются для forward compatibility,
но фактически агент запускается как `general-purpose` с prompt из AGENT.md.

---

## 11. Межагентная коммуникация (Workspace Protocol)

Агенты **никогда** не передают данные через return value или stdout напрямую.
Единственный канал — файлы в workspace.

### Структура workspace

```
{project_root}/
└── .claude/
    └── workspace/
        └── {session-id}/        # Формат: YYYY-MM-DDTHHMM
            ├── input.toon        # Оркестратор → все агенты
            ├── research.toon     # Researcher → Planner + Critic
            ├── plan.toon         # Planner → Executor + Critic
            ├── report.md         # Executor → пользователь
            └── *-critique.toon   # Critic → предыдущий агент (при RETRY)
```

### Соглашения именования файлов

| Файл | Производитель | Потребитель | Формат |
|------|---------------|-------------|--------|
| `input.toon` | Оркестратор | Все агенты | JSON/TOON |
| `research.toon` | Researcher | Planner, Critic | JSON + TOON-блоки |
| `plan.toon` | Planner | Executor, Critic | JSON + TOON-блоки |
| `report.md` | Executor | Пользователь | Markdown |
| `{stage}-critique.toon` | Critic | Оркестратор → агент | JSON |
| `deep-research-results.toon` | Deep Research | Researcher | JSON + TOON-блоки |

### Правила передачи данных

```markdown
## ПРАВИЛА (СТРОГИЕ)

### Чтение входных данных
- ✅ Читать ТОЛЬКО из workspace: `Read({WORKSPACE}/input.toon)`
- ❌ НЕ принимать задачу из prompt напрямую (кроме пути к workspace)

### Запись выходных данных
- ✅ Записывать результат ТОЛЬКО в workspace: `Write({WORKSPACE}/output.toon)`
- ❌ НЕ выводить структурированные данные в stdout (только сигнал завершения)

### Атомарность
- Записывать выходной файл ТОЛЬКО после полного завершения работы
- Не оставлять частично заполненные файлы (они будут прочитаны как успех)
```

### Паттерн RETRY через Critic

При получении вердикта `RETRY` от Critic агент перечитывает critique и повторяет работу.
Файлы critique переименовываются для сохранения истории:

```
Попытка 1: research-critique.toon → research-critique-r1.toon
Попытка 2: research-critique.toon → research-critique-r2.toon
Финальный: research-critique.toon (без суффикса)
```

---

## 12. Structured Output: JSON, TOON, Markdown

### Когда что использовать

| Формат | Когда использовать | Потребитель |
|--------|--------------------|-------------|
| **JSON** | Метаданные, конфиг, массивы < 5 элементов | Агент-потребитель |
| **TOON** | Массивы ≥ 5 элементов, табличные данные | Агент-потребитель |
| **Markdown** | Финальные отчёты для человека | Пользователь |
| **Hybrid JSON+TOON** | Большие структурированные результаты | Агент-потребитель |

### Типовая структура JSON-вывода агента

```json
{
  "metadata": {
    "agent": "researcher-agent",
    "session_id": "2026-02-24T1430",
    "status": "COMPLETE"
  },
  "results": {
    "scalar_field": "value",
    "small_array": ["a", "b", "c"],
    "large_array": "<<TOON:array_name>>"
  }
}
```

Для `large_array` (≥ 5 элементов) вместо JSON-массива пишется маркер `<<TOON:name>>`,
а данные размещаются отдельным TOON-блоком в том же файле после JSON.

### Hybrid JSON+TOON файл

```
{
  "metadata": { "agent": "researcher-agent", "status": "COMPLETE" },
  "relevant_files": "<<TOON:relevant_files>>",
  "risks": [
    { "id": "R1", "severity": "low", "description": "..." }
  ]
}

TOON:relevant_files:v1
path|relevance|reason
lib/command/args.sh|high|CLI argument parsing
lib/command/help.sh|medium|Help text update needed
lib/context/sessions.sh|high|Session management
lib/proxy/validate.sh|medium|Proxy URL validation
iclaude.sh|low|Entry point sources all modules
```

**Правила hybrid формата:**
- JSON-часть идёт первой (потребитель читает статус без парсинга TOON)
- TOON-блоки идут после JSON, разделены пустой строкой
- Маркер `<<TOON:name>>` в JSON указывает на соответствующий `TOON:name:v1` блок
- Массив из < 5 элементов остаётся в JSON (нет смысла в TOON)

---

## 13. TOON формат

TOON (Token-Oriented Object Notation) — компактный формат для табличных данных.
Даёт 30-60% экономии токенов по сравнению с JSON для массивов ≥ 5 элементов.

### Синтаксис

```
arrayName[N]{field1,field2,field3}:
  value1_1,value1_2,value1_3
  value2_1,value2_2,value2_3
```

- `[N]` — точное количество элементов (для валидации)
- `{fields}` — схема (имена полей)
- `:` — начало данных
- Запятая — разделитель полей
- Значения с запятой — в кавычках: `"value, with comma"`

### В workspace файлах (pipe-разделитель)

В `.toon` файлах используется `|` (не запятая) во избежание конфликтов с CSV:

```
TOON:relevant_files:v1
path|relevance|reason
lib/command/args.sh|high|CLI argument parsing module
lib/command/help.sh|medium|Help text needs updating
lib/context/sessions.sh|high|Session management source
iclaude.sh|medium|Entry point sources all lib/ modules
lib/proxy/validate.sh|low|May need URL format check
```

### Пример: шаги плана

```
TOON:phase_1_steps:v1
step|description|file|validation
1|Добавить case --list-sessions в parse_args()|lib/command/args.sh|bash -n lib/command/args.sh
2|Реализовать чтение session-env/ директории|lib/context/sessions.sh|bash -n lib/context/sessions.sh
3|Обновить help text|lib/command/help.sh|bash -n lib/command/help.sh
4|Добавить интеграцию в main()|iclaude.sh|bash -n iclaude.sh
5|Обновить lockfile|lib/lockfile/save.sh|bash -n lib/lockfile/save.sh
```

### Когда НЕ использовать TOON

- ❌ Массивы < 5 элементов (экономия токенов незначительна: 5-15%)
- ❌ Глубоко вложенные структуры (> 3 уровня)
- ❌ Конфигурационные файлы (нужна IDE-валидация)
- ❌ Файлы в git для людей (используй YAML/JSON)
