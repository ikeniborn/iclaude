---
name: agent-builder
description: Интерактивное создание НОВОГО Claude Code sub-agent (AGENT.md с валидным frontmatter, документацией роли, IO-примерами, валидацией по схеме). Использовать когда пользователь просит "создать/собрать/построить агента", "новый sub-agent". НЕ для редактирования существующих AGENT.md/SKILL.md/CLAUDE.md — использовать prompt-verifier.
user-invocable: true
context: fork
# version: 1.1.0 | updated: 2026-02-24
# tags: agents, generator, scaffolding, claude-code, subagents, frontmatter
# invocation: /agent-builder
# dependencies: skill-generator, validation-framework
# files: templates: ./templates/*.json, examples: ./examples/*.md, rules: ./rules/*.md
---

# Agent Builder

Интерактивный скилл для создания Claude Code sub-agents в соответствии с официальной схемой.
Генерирует корректный `AGENT.md` с валидным frontmatter, описанием роли, IO-протоколом и примерами.

## Quick Reference

| Аспект | Детали |
|--------|--------|
| **Запуск** | `/agent-builder` |
| **Входные данные** | 8 интерактивных вопросов |
| **Выходные файлы** | `AGENT.md` + опционально `examples/`, `schemas/` |
| **Целевая директория** | `.nvm-isolated/.claude-isolated/agents/` (global) или `.claude/agents/` (project) |
| **Официальная схема** | `name` + `description` (обязательные), остальные опциональные |
| **Валидация** | 4 проверки (frontmatter, tools, description, body) |

## Официальная схема Claude Code Sub-Agents

### Обязательные поля

| Поле | Тип | Описание |
|------|-----|----------|
| `name` | string | Уникальный идентификатор агента в kebab-case |
| `description` | string | Описание назначения агента — используется моделью для маршрутизации |

### Опциональные поля

| Поле | Тип | Значения / Формат |
|------|-----|-------------------|
| `tools` | string | Через запятую: `Read, Write, Bash, Glob, Grep, Task, WebSearch, WebFetch, Edit` |
| `disallowedTools` | string | Через запятую: инструменты явно запрещённые агенту |
| `model` | string | `claude-opus-4-6`, `claude-sonnet-4-6`, `claude-haiku-4-6` |
| `permissionMode` | string | `default` \| `acceptEdits` \| `bypassPermissions` \| `plan` |
| `maxTurns` | integer | Максимальное число agentic turns (≥1) |
| `skills` | list | Список скиллов доступных агенту |
| `mcpServers` | list | Список MCP серверов для включения |
| `hooks` | object | Хуки на события (PreToolUse, PostToolUse и др.) |
| `memory` | object | Конфигурация памяти агента |
| `background` | boolean | Запуск в фоне |
| `isolation` | string | `worktree` — изолированная копия репозитория |

### Невалидные поля (НЕ использовать)

Следующие поля **не входят в официальную схему** и игнорируются Claude Code:

```
version, role, subagent_type, capabilities,
input_file, output_file, input_schema, output_schema,
parameters, input_files
```

### Хранение метаданных версии и тегов

Версия, теги и зависимости — нестандартные поля. Правила хранения:

| Метод | Правило |
|-------|---------|
| ✅ `# comment` внутри `---...---` | YAML-парсер стрипает `#`-комментарии — **не попадают в контекст модели** |
| ❌ `<!-- comment -->` после `---` | Тело файла передаётся в контекст as-is — **HTML-комментарии ВИДНЫ модели** |

**Правильно:**
```yaml
---
name: my-agent
description: ...
# version: 1.0.0 | updated: 2026-02-24
# tags: search, analysis
---
```

**Неправильно (загрязняет контекст):**
```yaml
---
name: my-agent
description: ...
---
<!-- version: 1.0.0 | tags: search, analysis -->
```

> **Источник:** Claude Code CLI исходный код — тело AGENT.md передаётся без обработки через `content:A` / `w=A.slice(Y[0].length)`. YAML-парсер (`Tz8(z)`) стрипает `#`-комментарии из frontmatter.

> **Источник:** [Claude Code Sub-Agents Documentation](https://code.claude.com/docs/en/sub-agents)

## Расположение Агентов

### Глобальные агенты iclaude (через оркестратор)
```
.nvm-isolated/.claude-isolated/agents/{agent-name}/
└── AGENT.md
```
- Читаются оркестратором и передаются как prompt в `Task(subagent_type="general-purpose")`
- НЕ обнаруживаются Claude Code автоматически
- Используй официальную схему для forward compatibility

### Нативные агенты проекта (auto-discovery)
```
.claude/agents/{agent-name}.md      ← одиночный файл
.claude/agents/{agent-name}/
└── AGENT.md                        ← директория
```
- Автоматически обнаруживаются Claude Code
- Доступны через Task tool как `subagent_type="{agent-name}"`
- Полная поддержка всех полей официальной схемы

### Глобальные нативные агенты
```
~/.claude/agents/{agent-name}.md
```
- Доступны во всех проектах глобально

## Алгоритм работы скилла

### Шаг 1: Определить целевую директорию

Проверить в каком контексте запущен скилл:

```bash
# Проверить наличие директорий
ls .nvm-isolated/.claude-isolated/agents/ 2>/dev/null && echo "GLOBAL_ISOLATED"
ls .claude/agents/ 2>/dev/null && echo "PROJECT_NATIVE"
```

Предложить пользователю выбор:
- **iclaude global** → `.nvm-isolated/.claude-isolated/agents/{name}/`
- **Проект (нативный)** → `.claude/agents/{name}.md` или `.claude/agents/{name}/AGENT.md`

### Шаг 2: Интерактивные вопросы (8 вопросов)

```
════════════════════════════════════════════════════
🤖 AGENT BUILDER — Создание нового агента
════════════════════════════════════════════════════

Q1. Имя агента (kebab-case, например: data-validator):
→ {agent-name}

Q2. Краткое описание назначения (1-2 предложения, для поля description):
    Будет использоваться моделью для маршрутизации вызовов.
→ {description}

Q3. Какие инструменты нужны агенту? (через запятую)
    Доступные: Read, Write, Edit, Bash, Glob, Grep, Task, WebSearch, WebFetch
    Оставь пустым для всех инструментов.
→ {tools}

Q4. Есть ли запрещённые инструменты? (через запятую, Enter — нет)
→ {disallowedTools}

Q5. Модель агента? (Enter — наследует от родителя)
    Варианты: claude-opus-4-6 | claude-sonnet-4-6 | claude-haiku-4-6
→ {model}

Q6. Режим разрешений? (Enter — default)
    default | acceptEdits | bypassPermissions | plan
→ {permissionMode}

Q7. Создать примеры и правила? (y/n, Enter — y)
→ {create_examples}

Q8. Лимит turns агента? (число ≥1, Enter — без лимита)
    Read-only: 20-30 | Researcher: 40-60 | Executor: 80-100
→ {maxTurns}
```

### Шаг 3: Сформировать frontmatter

На основе ответов сформировать минимальный валидный frontmatter:

**Минимальный (только обязательные поля):**
```yaml
---
name: {agent-name}
description: {description}
---
```

**С инструментами:**
```yaml
---
name: {agent-name}
description: {description}
tools: {tools}
---
```

**Полный (с опциональными полями):**
```yaml
---
name: {agent-name}
description: {description}
tools: {tools}
disallowedTools: {disallowedTools}
model: {model}
permissionMode: {permissionMode}
maxTurns: {maxTurns}
---
```

**Правило:** включать только те поля, которые пользователь явно указал.
НЕ добавлять пустые поля (`tools: ""`) и НИКОГДА не добавлять невалидные поля.

### Шаг 4: Сформировать тело AGENT.md

Тело файла содержит описание роли в формате Markdown.
Смотри шаблон: `@template:./templates/agent-body.json`

Обязательные секции:
1. `# Роль: {Agent Name}` — краткое описание
2. `## Входные данные` — что агент принимает
3. `## Алгоритм выполнения` — шаги работы агента
4. `## ПРАВИЛА (СТРОГИЕ)` — ограничения и разрешённые операции
5. `## Сигнал завершения` — output агента

### Шаг 5: Создать файлы

```bash
# Для iclaude global
mkdir -p .nvm-isolated/.claude-isolated/agents/{agent-name}
# Записать AGENT.md

# Для нативного проекта (одиночный файл)
# Записать .claude/agents/{agent-name}.md

# Опционально: создать examples/ и schemas/
```

### Шаг 6: Валидация (4 проверки)

```
✅ Frontmatter: name + description присутствуют
✅ Невалидных полей нет (version, role, subagent_type, capabilities, etc.)
✅ description: длина 20-300 символов
✅ Тело: содержит хотя бы секцию "# Роль:"
```

### Шаг 7: Сигнал завершения

```
════════════════════════════════════════════════════
✅ AGENT CREATED
════════════════════════════════════════════════════
Агент: {agent-name}
Файл: {path}/AGENT.md

Frontmatter:
  name: {agent-name}
  description: {description_preview}
  tools: {tools}
  {other fields if present}

Валидация:
  ✅ Frontmatter корректный
  ✅ Невалидных полей нет
  ✅ Description присутствует
  ✅ Тело агента сформировано

{если iclaude:
  "Для использования: оркестратор прочитает AGENT.md через agents/{agent-name}/AGENT.md"
}
{если нативный:
  "Для использования: Task(subagent_type='{agent-name}', prompt='...')"
}
════════════════════════════════════════════════════
```

## Примеры

### Пример 1: Минимальный агент

````yaml
---
name: file-summarizer
description: Агент для создания кратких summary файлов проекта. Читает указанные файлы и возвращает структурированный summary с ключевыми компонентами.
tools: Read, Glob
---

# Роль: File Summarizer

Ты агент для суммаризации файлов проекта.
Твоя задача — прочитать указанные файлы и вернуть краткое структурированное описание.

## Входные данные

Ты получишь в prompt:
- `FILES: [path1, path2, ...]` — список файлов для суммаризации
- `DEPTH: brief|detailed` — уровень детализации

## Алгоритм выполнения

1. Прочитать каждый файл из `FILES`
2. Извлечь: назначение, ключевые функции, зависимости
3. Вернуть структурированный список

## ПРАВИЛА (СТРОГИЕ)

```
✅ Read({path}) — читать файлы
✅ Glob({pattern}) — искать файлы
❌ НЕ изменять файлы проекта
❌ НЕ запускать bash команды
```

## Сигнал завершения

Вернуть markdown с секциями по каждому файлу.
````

### Пример 2: Агент с ограничениями по инструментам

```yaml
---
name: security-auditor
description: READ-ONLY агент аудита безопасности. Анализирует код на OWASP уязвимости (XSS, SQL injection, hardcoded secrets). Никогда не изменяет файлы.
tools: Read, Glob, Grep
disallowedTools: Bash, Write, Edit, Task
permissionMode: default
---
```

### Пример 3: Агент с моделью и maxTurns

```yaml
---
name: quick-linter
description: Быстрый агент проверки синтаксиса bash-скриптов. Использует облегчённую модель для скорости. Максимум 5 turns.
tools: Read, Bash
model: claude-haiku-4-6
maxTurns: 5
---
```

### Пример 4: Фоновый агент с worktree изоляцией

```yaml
---
name: test-runner
description: Агент запуска тестов в изолированном worktree. Запускается в фоне, не блокирует основную сессию.
tools: Bash, Read
background: true
isolation: worktree
permissionMode: acceptEdits
---
```

### Пример 5: Агент оркестратора (из iclaude, через Task)

```yaml
---
name: deep-research-agent
description: Агент глубокого веб-исследования с рекурсивным поиском, фетчингом источников и синтезом результатов. Читает deep-research-request.toon, записывает deep-research-results.toon.
tools: WebSearch, WebFetch, Read, Write
---
```

## Правила формирования Description

Поле `description` критично — оно определяет когда Claude Code вызовет агента.

### Хорошая description (конкретная, ориентированная на действие):
```
✅ "Агент аудита безопасности кода. Анализирует Python файлы на SQL injection, XSS, hardcoded secrets. Возвращает структурированный отчёт с severity и fix suggestions."

✅ "Read-only research agent for codebase analysis. Finds relevant files, analyzes architecture, assesses risks. Writes research.toon to workspace."

✅ "Агент генерации CHANGELOG из git log. Принимает диапазон коммитов, группирует по типу (feat/fix/refactor), форматирует в Keep a Changelog формат."
```

### Плохая description (слишком общая):
```
❌ "Агент для работы с кодом"
❌ "Helper agent"
❌ "Does research and planning"
```

### Правила:
1. **Длина:** 20–300 символов
2. **Формат:** 1-3 предложения
3. **Содержание:** ЧТО делает + НА ЧЁМ работает + ЧТО возвращает
4. **Язык:** любой, согласованный с остальным проектом
5. **НЕ дублировать** name агента в description

## Правила формирования Tools

Принцип минимальных привилегий — указывай только необходимые.
`disallowedTools` надёжнее чем просто не указать инструмент:

| Тип агента | tools | disallowedTools |
|------------|-------|-----------------|
| Read-only | `Read, Glob, Grep` | `Bash, Write, Edit, Task` |
| Critic/Auditor | `Read, Glob, Grep` | `Bash, Write, Edit, Task` |
| Researcher | `Read, Glob, Grep, Task, WebSearch, WebFetch` | `Bash, Write, Edit` |
| Web researcher | `WebSearch, WebFetch, Read, Write` | `Bash, Edit, Task` |
| Planner | `Read, Glob, Grep, Write` | `Bash, Edit, Task` |
| Executor | `Read, Glob, Grep, Write, Edit, Bash, Task` | — |

> `Bash` даёт полный доступ к системе. Никогда не давай `Bash` агентам,
> которые должны быть read-only. `Planner` получает `Glob, Grep` для исследования
> кодовой базы, но не `Edit` — он пишет новые файлы, не изменяет существующие.

Подробно: `./rules/agent-best-practices.md` §2

## Структура директории агента

### Минимальная (обязательная):
```
agents/{agent-name}/
└── AGENT.md                  ← обязательный файл
```

### Расширенная (рекомендуется для сложных агентов):
```
agents/{agent-name}/
├── AGENT.md                  ← роль, алгоритм, правила
├── schemas/
│   ├── input.schema.json     ← JSON Schema входного формата
│   └── output.schema.json    ← JSON Schema выходного формата
└── examples/
    ├── example-input.toon    ← пример входных данных
    └── example-output.toon   ← пример выходных данных
```

## Распространённые ошибки

### Ошибка 1: Невалидные поля в frontmatter

```yaml
# ❌ НЕПРАВИЛЬНО — все поля кроме name невалидны
---
name: my-agent
version: 1.0.0          # ❌ не в схеме
role: researcher         # ❌ не в схеме
subagent_type: general-purpose  # ❌ не в схеме
capabilities:            # ❌ не в схеме
  - web_search
---

# ✅ ПРАВИЛЬНО
---
name: my-agent
description: Агент-исследователь для анализа кодовой базы...
tools: Glob, Grep, Read, Write, Task
---
```

### Ошибка 2: Пустая или слишком общая description

```yaml
# ❌ НЕПРАВИЛЬНО
---
name: researcher
description: Research agent
---

# ✅ ПРАВИЛЬНО
---
name: researcher-agent
description: Агент-исследователь кодовой базы в пайплайне Researcher→Planner→Executor. Анализирует файлы, архитектуру, риски и внешние docs, записывает research.toon.
---
```

### Ошибка 3: Слишком широкие права инструментов

```yaml
# ❌ НЕПРАВИЛЬНО для read-only агента
---
name: auditor
description: Security audit agent.
tools: Read, Write, Edit, Bash, Task, WebSearch, WebFetch
---

# ✅ ПРАВИЛЬНО
---
name: auditor
description: Security audit agent. Reads code files and reports vulnerabilities.
tools: Read, Glob, Grep
disallowedTools: Bash, Write, Edit
---
```

### Ошибка 4: name не в kebab-case

```yaml
# ❌ НЕПРАВИЛЬНО
name: ResearcherAgent
name: researcher_agent
name: Researcher Agent

# ✅ ПРАВИЛЬНО
name: researcher-agent
name: deep-research-agent
name: security-auditor
```

## Интеграция с Оркестратором

Агенты в `.nvm-isolated/.claude-isolated/agents/` используются через оркестратор:

```python
# Оркестратор читает AGENT.md и передаёт как prompt
agents_dir = f"{skill_base_dir}/../../agents"
agent_md = Read(f"{agents_dir}/{agent_name}/AGENT.md")

Task(
  subagent_type="general-purpose",
  prompt=agent_md + f"""

WORKSPACE: {workspace}
TASK: {task}
"""
)
```

Нативные агенты (в `.claude/agents/`) используются напрямую:

```python
Task(
  subagent_type="researcher-agent",  # имя из name поля
  prompt="Investigate this codebase for authentication issues"
)
```

## Межагентная коммуникация и форматы вывода

### Workspace Protocol

Агенты передают данные ТОЛЬКО через файлы в workspace — никакого return value:

```
.claude/workspace/{YYYY-MM-DDTHHMM}/
├── input.toon          # Оркестратор → агенты
├── research.toon       # Researcher → Planner, Critic
├── plan.toon           # Planner → Executor, Critic
├── report.json         # Executor → пользователь (schema v2.1.0)
└── {stage}-critique.toon  # Critic → предыдущий агент
```

**Правила агента:**
- Читать входные данные: `Read({WORKSPACE}/input.toon)`
- Писать результат: `Write({WORKSPACE}/output.toon)` — только после полного завершения
- Не выводить структурированные данные в stdout (только сигнал завершения)

### Выбор формата вывода

| Формат | Когда использовать |
|--------|--------------------|
| **JSON** | Метаданные, конфиг, массивы < 5 элементов |
| **TOON** | Массивы ≥ 5 элементов, табличные данные (30-60% экономии токенов) |
| **Hybrid JSON+TOON** | Смешанный вывод: JSON-оболочка + TOON для больших массивов |
| **JSON** (typed) | Машиночитаемые отчёты агентов (report.json, schema v2.1.0) |

**Hybrid пример:**
```
{"metadata": {"status": "COMPLETE"}, "relevant_files": "<<TOON:relevant_files>>"}

TOON:relevant_files:v1
path|relevance|reason
lib/command/args.sh|high|CLI argument parsing
lib/context/sessions.sh|high|Session management
...
```

Подробно: `./rules/agent-best-practices.md` §11-13

## lat.md Integration

Этот скилл не вызывает `context-awareness`, поэтому проверяет lat.md напрямую.

### Query (перед началом Questionnaire)

```
IF exists("{CWD}/lat.md/"):
  Skill(skill="lat-search", args='search "паттерны и спецификации Claude Code агентов"')
  # без LAT_LLM_KEY lat-search сам откатывается на `lat locate`

  Использовать результат для обогащения Questionnaire:
  - Если найдены похожие агенты → предложить их description/tools как starting point
  - Если найдены рекомендованные model/permissionMode для данного типа → предзаполнить
  - Если в lat.md нет данных → продолжить стандартный Questionnaire без изменений
```

### Record (после успешной валидации — Сигнал завершения)

lat.md — авторский граф, без авто-ингеста: спецификация добавляется ручной секцией.

```
IF exists("{CWD}/lat.md/") AND validation_passed:
  (опционально) Skill(skill="lat-md") → создать/обновить секцию агента в lat.md/
    (name, description, tools, permissionMode — что и почему)
  Затем Skill(skill="lat-check") → валидировать [[refs]] и code refs

  Результат: спецификации агентов попадают в граф lat.md —
  переиспользуются как паттерны при создании следующих агентов.
```

---

## Связанные ресурсы

- **@skill:agent-orchestrator** — запуск агентов через оркестратор
- **@skill:skill-generator** — создание скиллов (аналогичный генератор для скиллов)
- **Официальная документация:** https://code.claude.com/docs/en/sub-agents
- **Примеры:** `./examples/`
- **Правила:** `./rules/agent-best-practices.md`
