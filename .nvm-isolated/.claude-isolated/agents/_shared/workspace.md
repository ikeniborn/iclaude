# Agent Workspace Protocol

**Version:** 1.2.0
**Purpose:** Правила работы с workspace для агентов системы Researcher → [Critic] → Planner → [Critic] → Executor → [Critic]

---

## Структура Workspace

```
{project_root}/
└── .claude/
    ├── workspace/
    │   └── {session-id}/          # ID = дата+время запуска (2026-02-17T1523)
    │       ├── input.toon         # Входная задача (пишет оркестратор)
    │       ├── research.toon      # Researcher → Planner (перезаписывается при retry)
    │       ├── research-critique-r1.toon  # Critique retry 1 (если был retry)
    │       ├── research-critique-r2.toon  # Critique retry 2 (если был retry)
    │       ├── research-critique.toon     # Финальный critique (mode=research)
    │       ├── plan.toon          # Planner → Executor (перезаписывается при retry)
    │       ├── plan-critique-r1.toon      # Critique retry 1 (если был retry)
    │       ├── plan-critique-r2.toon      # Critique retry 2 (если был retry)
    │       ├── plan-critique.toon         # Финальный critique (mode=plan)
    │       ├── report.json        # Итог Executor (машиночитаемый JSON, schema v2.1.0)
    │       └── execution-critique.toon    # Critique (mode=execution)
    └── latest -> workspace/{last-session-id}/  # симлинк на последнюю сессию
```

### Rename Pattern при Retry

Когда Critic перезапускается (RETRY_NUMBER > 0), предыдущий critique переименовывается
**перед записью нового**:

```
Retry 1: {mode}-critique.toon → {mode}-critique-r1.toon
Retry 2: {mode}-critique.toon → {mode}-critique-r2.toon
Финальный: остаётся в {mode}-critique.toon (без суффикса)
```

Это обеспечивает трассируемость: всегда видно историю улучшений.

## Session ID Format

**Format:** `YYYY-MM-DDTHHMM`
**Example:** `2026-02-17T1523`

```bash
# Генерация session-id
SESSION_ID=$(date +%Y-%m-%dT%H%M)
WORKSPACE="${PROJECT_ROOT}/.claude/workspace/${SESSION_ID}"
```

**Почему этот формат:**
- ✅ Человекочитаемый (не UUID)
- ✅ Лексикографически сортируемый (хронологический порядок)
- ✅ Безопасен для файловой системы (без спецсимволов)
- ✅ Однозначный в пределах минуты

## Создание Workspace (оркестратор)

```bash
# 1. Определить project_root (текущий рабочий каталог Claude Code сессии)
PROJECT_ROOT=$(pwd)

# 2. Создать структуру
mkdir -p "${PROJECT_ROOT}/.claude/workspace/${SESSION_ID}"

# 3. Записать input.toon
# (json файл с задачей пользователя)

# 4. Добавить .claude/workspace/ в .gitignore проекта (если ещё нет)
grep -q "^\.claude/workspace/" "${PROJECT_ROOT}/.gitignore" 2>/dev/null || \
  echo ".claude/workspace/" >> "${PROJECT_ROOT}/.gitignore"
```

## Правила для Агентов

### READ-ONLY правило (Researcher)

Researcher Agent **НЕ ДОЛЖЕН** изменять файлы проекта.
Единственный разрешённый write-операции:
- `{workspace}/research.toon` — выходной файл агента

### READ-ONLY правило (Critic Agent)

Critic Agent **НЕ ДОЛЖЕН** изменять файлы проекта.
Разрешённые операции:
- `Read({workspace}/*)` — читает любые файлы workspace
- `Bash(mv ...)` — переименовывает предыдущий critique (rename pattern)
- `Write({workspace}/{mode}-critique.toon)` — пишет только свой critique файл

**Critique файлы READ-ONLY для всех остальных агентов.**

### READ-ONLY правило (Retry Agents)

Когда Researcher или Planner перезапускаются после RETRY verdict:
- Читают `{workspace}/{mode}-critique.toon` как дополнительный контекст (READ-ONLY)
- НЕ изменяют critique файл
- Перезаписывают свой output файл (`research.toon` или `plan.toon`)

### Workspace Path передача

Оркестратор передаёт `workspace_path` в prompt каждого агента:

```
WORKSPACE: /path/to/project/.claude/workspace/2026-02-17T1523
```

Агент использует этот путь для чтения input-файлов и записи output-файлов.

### Файловые зависимости

```
input.toon              → Researcher читает
                        → Critic[research] читает
                        → Planner читает
                        → Critic[plan] читает

research.toon           ← Researcher пишет (перезаписывает при retry)
                        → Planner читает
                        → Critic[plan] читает

research-critique.toon  ← Critic[research] пишет (переименовывается при retry)
                        → Researcher читает при RETRY (READ-ONLY)

plan.toon               ← Planner пишет (перезаписывает при retry)
                        → Executor читает
                        → Critic[execution] читает

plan-critique.toon      ← Critic[plan] пишет (переименовывается при retry)
                        → Planner читает при RETRY (READ-ONLY)

report.json             ← Executor пишет (schema_version: "2.1.0")
                        → Critic[execution] читает

execution-critique.toon ← Critic[execution] пишет
```

## .gitignore Integration

`.claude/workspace/` содержит временные данные сессий и **не должен коммититься** в git.

Оркестратор автоматически добавляет в `.gitignore` проекта:
```
# Claude Code Agent Workspace (временные данные сессий)
.claude/workspace/
```

## Cleanup

После успешного завершения пайплайна оркестратор предлагает очистку:

```
Workspace: /path/to/.claude/workspace/2026-02-17T1523
Файлы: input.toon, research.toon, research-critique*.toon,
       plan.toon, plan-critique*.toon, report.json, execution-critique.toon

Очистить workspace? [yes/keep]
```

**По умолчанию:** `keep` — пользователь может изучить артефакты сессии.

`report.json` рекомендуется сохранить как документацию принятых решений.
`*-critique.toon` содержат историю оценок качества — полезны для анализа.

## Error Handling

Если агент не может прочитать input-файл:
1. Проверить существование `{workspace}/` директории
2. Вывести ошибку с абсолютным путём
3. STOP — не продолжать пайплайн

Если агент не может записать output-файл:
1. Проверить права доступа на директорию
2. Вывести ошибку с абсолютным путём
3. STOP — не продолжать пайплайн

Если Critic не может записать critique файл:
1. Сообщить оркестратору
2. Оркестратор трактует как RETRY-без-guidance (не ABORT)
3. Critic перезапускается для повторной попытки записи
