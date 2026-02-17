---
name: agent-orchestrator
description: Оркестратор пайплайна Researcher → Planner → Executor для выполнения задач через специализированные суб-агенты
version: 1.0.0
tags: [agents, orchestration, pipeline, researcher, planner, executor]
dependencies:
  - agents/researcher-agent/AGENT.md
  - agents/planning-agent/AGENT.md
  - agents/execution-agent/AGENT.md
  - agents/critic-agent/AGENT.md
  - agents/_shared/workspace.md
  - agents/_shared/toon-protocol.md
user-invocable: true
invocation: /agent-orchestrator
---

# Agent Orchestrator

Навык-оркестратор запускает пайплайн специализированных агентов для выполнения задач:

```
Пользователь → Researcher → [Critic] → [Gate] → Planner → [Critic] → [Gate] → Executor → [Critic] → Report
```

## Когда использовать

Используй этот навык для задач требующих:
- Изменения кода в нескольких файлах
- Предварительного исследования кодовой базы
- Структурированного планирования перед изменениями
- Трассируемости: что исследовано → что запланировано → что сделано

**Не нужен для:** простых однострочных правок, вопросов без изменения кода.

## Команда запуска

```
/agent-orchestrator <описание задачи>
```

**Примеры:**
```
/agent-orchestrator Добавить флаг --list-sessions в iclaude.sh
/agent-orchestrator Implement user authentication with JWT
/agent-orchestrator Refactor proxy management to use async/await
```

## Алгоритм оркестратора

### Шаг 1: Инициализация Workspace

```bash
# Агенты находятся в изолированной среде iclaude, не в рабочем проекте.
# SKILL_BASE_DIR — директория этого скилла (из заголовка "Base directory for this skill:")
# Пример: /home/user/.nvm-isolated/.claude-isolated/skills/agent-orchestrator
AGENTS_DIR="${SKILL_BASE_DIR}/../../agents"
# Результат: /home/user/.nvm-isolated/.claude-isolated/agents

# Определить project root
PROJECT_ROOT=$(pwd)
SESSION_ID=$(date +%Y-%m-%dT%H%M)
WORKSPACE="${PROJECT_ROOT}/.claude/workspace/${SESSION_ID}"

# Создать структуру workspace
mkdir -p "${WORKSPACE}"

# Добавить .claude/workspace/ в .gitignore проекта (если нет)
grep -q "^\.claude/workspace/" "${PROJECT_ROOT}/.gitignore" 2>/dev/null || \
  echo -e "\n# Claude Code Agent Workspace\n.claude/workspace/" >> "${PROJECT_ROOT}/.gitignore"

```

### Шаг 2: Записать input.toon

```json
{
  "task_input": {
    "task_description": "<TASK_FROM_USER>",
    "focus_areas": ["codebase", "architecture", "risks", "external_docs"],
    "hints": {
      "language_hint": null,
      "skip_context7": false
    }
  }
}
```

Записать в `{WORKSPACE}/input.toon`.

### Шаг 3: Запустить Researcher Agent

```
Прочитать: ${AGENTS_DIR}/researcher-agent/AGENT.md
Собрать prompt: AGENT.md + "WORKSPACE: {WORKSPACE}\nTASK: {task_description}"
Запустить: Task(subagent_type="general-purpose", prompt=researcher_prompt)
```

Дождаться завершения. Показать пользователю key_insights из вывода агента.

### Шаг 3.5: Запустить Critic Agent (mode=research)

```
Прочитать: ${AGENTS_DIR}/critic-agent/AGENT.md

retry_count = 0
loop:
  critic_prompt = critic_md + """
  WORKSPACE: {WORKSPACE}
  EVALUATION_MODE: research
  RETRY_NUMBER: {retry_count}
  PREVIOUS_CRITIQUE: {null если retry_count==0 иначе WORKSPACE/research-critique.toon}
  """
  Task(subagent_type="general-purpose", prompt=critic_prompt)

  verdict = parse(Read("{WORKSPACE}/research-critique.toon").critique.verdict)

  IF verdict in ["PASS", "WARN"]:
    break  # Продолжить к Gate

  IF verdict == "ABORT":
    ❌ RESEARCH ABORTED (score: {score}/100)
    Причины: {critique.blocking_issues}
    Файл critique: {WORKSPACE}/research-critique.toon
    STOP.

  # verdict == "RETRY"
  retry_count += 1
  IF retry_count > 2:
    ❌ RESEARCH ABORTED: Превышен лимит повторов (2 попытки)
    STOP.

  # Перезапустить Researcher с critique как контекстом
  researcher_prompt = researcher_md + """
  WORKSPACE: {WORKSPACE}
  TASK: {task_description}
  RETRY_NUMBER: {retry_count}
  PREVIOUS_CRITIQUE: {WORKSPACE}/research-critique.toon
  """
  Task(subagent_type="general-purpose", prompt=researcher_prompt)
  # Вернуться в начало loop для нового critique
```

### Шаг 4: [Approval Gate] После Researcher

```
════════════════════════════════════════════
📋 RESEARCH COMPLETE
════════════════════════════════════════════
Исследование завершено.

Ключевые находки:
{вывод из research.toon.recommendations.key_insights}

Сложность: {complexity_hint}
Рисков: {risk_count}

Оценка критика: {score}/100 [{verdict}]
{if WARN: "⚠️  Предупреждения: {critique.dimensions.*issues суммарно}"}

Workspace: {WORKSPACE}

Продолжить к планированию? [yes/no]
════════════════════════════════════════════
```

Если `no` → STOP. Артефакт в `{WORKSPACE}/research.toon`.

### Шаг 5: Запустить Planning Agent

```
Прочитать: ${AGENTS_DIR}/planning-agent/AGENT.md
Собрать prompt: AGENT.md + "WORKSPACE: {WORKSPACE}"
Запустить: Task(subagent_type="general-purpose", prompt=planner_prompt)
```

Дождаться завершения. Показать пользователю summary плана.

### Шаг 5.5: Запустить Critic Agent (mode=plan)

```
Прочитать: ${AGENTS_DIR}/critic-agent/AGENT.md

retry_count = 0
loop:
  critic_prompt = critic_md + """
  WORKSPACE: {WORKSPACE}
  EVALUATION_MODE: plan
  RETRY_NUMBER: {retry_count}
  PREVIOUS_CRITIQUE: {null если retry_count==0 иначе WORKSPACE/plan-critique.toon}
  """
  Task(subagent_type="general-purpose", prompt=critic_prompt)

  verdict = parse(Read("{WORKSPACE}/plan-critique.toon").critique.verdict)

  IF verdict in ["PASS", "WARN"]:
    break  # Продолжить к Gate

  IF verdict == "ABORT":
    ❌ PLAN ABORTED (score: {score}/100)
    Причины: {critique.blocking_issues}
    Файл critique: {WORKSPACE}/plan-critique.toon
    STOP.

  # verdict == "RETRY"
  retry_count += 1
  IF retry_count > 2:
    ❌ PLAN ABORTED: Превышен лимит повторов (2 попытки)
    STOP.

  # Перезапустить Planner с critique как контекстом
  planner_prompt = planner_md + """
  WORKSPACE: {WORKSPACE}
  RETRY_NUMBER: {retry_count}
  PREVIOUS_CRITIQUE: {WORKSPACE}/plan-critique.toon
  """
  Task(subagent_type="general-purpose", prompt=planner_prompt)
  # Вернуться в начало loop для нового critique
```

### Шаг 6: [Approval Gate] После Planner

```
════════════════════════════════════════════
📝 PLAN READY
════════════════════════════════════════════
Фаз: {total_phases}, Шагов: {estimated_steps}
Файлы к изменению: {files_list}

{для каждой фазы: "  Фаза N: {phase_name} [{risk}]"}

{если есть фаза с risk==high: "⚠️ Фаза X требует подтверждения перед выполнением"}

Оценка критика: {score}/100 [{verdict}]
{if WARN: "⚠️  Предупреждения: {critique.dimensions.*issues суммарно}"}

Workspace: {WORKSPACE}

Выполнить план? [yes/no/show-plan]
════════════════════════════════════════════
```

При `show-plan` → показать полное содержимое `{WORKSPACE}/plan.toon`, затем снова спросить.

Если `no` → STOP. Артефакт в `{WORKSPACE}/plan.toon`.

### Шаг 7: Запустить Execution Agent

```
Прочитать: ${AGENTS_DIR}/execution-agent/AGENT.md
Собрать prompt: AGENT.md + "WORKSPACE: {WORKSPACE}"
Запустить: Task(subagent_type="general-purpose", prompt=executor_prompt)
```

Дождаться завершения (Execution Agent сам запрашивает подтверждения для high-risk фаз).

### Шаг 7.5: Запустить Critic Agent (mode=execution)

```
Прочитать: ${AGENTS_DIR}/critic-agent/AGENT.md

critic_prompt = critic_md + """
WORKSPACE: {WORKSPACE}
EVALUATION_MODE: execution
RETRY_NUMBER: 0
PREVIOUS_CRITIQUE: null
"""
Task(subagent_type="general-purpose", prompt=critic_prompt)

verdict = parse(Read("{WORKSPACE}/execution-critique.toon").critique.verdict)

IF verdict == "PASS":
  # Всё в порядке — продолжить к шагу 8

IF verdict == "WARN":
  # Продолжить к шагу 8, показать предупреждения в финальном отчёте

IF verdict == "ABORT":
  # НЕ останавливать пайплайн — добавить секцию критика в итоговый отчёт
  report_status = "FAILED (critic verification)"
  # В шаге 8: вывести blocking_issues из execution-critique.toon

# НЕТ retry loop для execution — ошибки выполнения требуют human judgment
```

### Шаг 8: Итоговый отчёт

Показать содержимое `{WORKSPACE}/report.md`.

```
════════════════════════════════════════════
🎉 PIPELINE COMPLETE
════════════════════════════════════════════
Session: {SESSION_ID}
Report: {WORKSPACE}/report.md

{содержимое report.md}

Execution Review: {score}/100 [{verdict}]
{if WARN: "⚠️  {critique.dimensions.* issues суммарно}"}
{if ABORT: "❌ Critic выявил критические проблемы: {execution-critique.blocking_issues}"}

Workspace сохранён: {WORKSPACE}
════════════════════════════════════════════
```

## Как читать AGENT.md файл

При сборке prompt для субагента:

```python
# Псевдокод - оркестратор выполняет это напрямую
# AGENTS_DIR = "${SKILL_BASE_DIR}/../../agents"  (из Шага 1)
agent_md_path = f"{AGENTS_DIR}/{agent_name}/AGENT.md"
agent_md_content = Read(agent_md_path)

prompt = f"""{agent_md_content}

---

WORKSPACE: {workspace_path}
TASK: {task_description}
"""

result = Task(subagent_type="general-purpose", prompt=prompt)
```

**Важно:** AGENT.md содержит полные инструкции для агента. Он читается и передаётся
в prompt как есть — агент получает роль, алгоритм и правила.

**Разделение путей:**
- `AGENTS_DIR` — изолированная среда iclaude (не меняется при смене проекта)
- `PROJECT_ROOT` — рабочий проект пользователя (pwd при запуске оркестратора)

## Параллельность

Researcher, Planner, Executor работают **последовательно** (каждый зависит от предыдущего).
Critic запускается **после** каждого агента, перед Gate.
**Внутри** Researcher есть параллельность (два Explore суб-агента).

## Парсинг critique verdict

Critique файлы могут быть гибридными (TOON + JSON). Для парсинга verdict:

```bash
# Безопасный парсинг (пропускает TOON блоки до ---JSON---)
awk '/^---JSON---$/{found=1; next} found' {WORKSPACE}/{mode}-critique.toon \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['critique']['verdict'], d['critique']['score'])"
```

Если файл содержит только JSON (нет TOON блоков), можно читать напрямую через Read и парсить JSON.

## Workspace Cleanup

После успешного завершения предложить очистку:

```
Очистить workspace? [yes/keep]
(Рекомендуется: keep — report.md полезен как документация)
```

При `yes`:
```bash
rm -rf "${WORKSPACE}"
# Удалить симлинк latest если указывает на удалённый workspace
```

## Troubleshooting

### Researcher не находит файлы

Убедиться что:
- `pwd` указывает на корень проекта
- Проект содержит файлы (не пустой)
- Researcher Agent запущен с правильным WORKSPACE path

### Плохой план (не ссылается на research)

Признак: `research_references.reusable_components_used` пустой.
Действие: Critic выдаст RETRY, Planner перезапустится с guidance.

### Execution Agent не находит файл

Признак: `Read({file})` возвращает ошибку "file not found".
Действие: Проверить что `file` путь в плане корректен (относительно project root).

### Context7 недоступен

Это нормально. Researcher Agent gracefully skip и продолжит.
`external_docs.context7_status` будет `"PLUGIN_NOT_AVAILABLE"`.

### Critique файл не создан (ошибка записи)

Оркестратор трактует это как RETRY-без-guidance, не ABORT.
Перезапустить Critic, затем целевой агент.

## Связанные файлы

Агенты находятся в изолированной среде iclaude (`${AGENTS_DIR}`):

```
${AGENTS_DIR}/                   # = ${SKILL_BASE_DIR}/../../agents
├── _shared/
│   ├── workspace.md             # Правила workspace
│   └── toon-protocol.md         # TOON-спецификация для агентов
├── researcher-agent/
│   └── AGENT.md                 # Роль + инструкции Researcher
├── planning-agent/
│   └── AGENT.md                 # Роль + инструкции Planner
├── execution-agent/
│   └── AGENT.md                 # Роль + инструкции Executor
└── critic-agent/
    ├── AGENT.md                 # Роль + инструкции Critic
    └── examples/                # Примеры critique файлов
```

Рабочий проект (`${PROJECT_ROOT}`):
```
${PROJECT_ROOT}/
└── .claude/workspace/{SESSION_ID}/   # Все артефакты сессии (gitignored)
    ├── input.toon
    ├── research.toon
    ├── research-critique.toon
    ├── plan.toon
    ├── plan-critique.toon
    ├── report.md
    └── execution-critique.toon
```

## Пример end-to-end

**Вход:**
```
/agent-orchestrator Добавить флаг --list-sessions в iclaude.sh
```

**Пайплайн:**
1. Workspace создан: `.claude/workspace/2026-02-17T1523/`
2. input.toon записан
3. Researcher → research.toon
4. Critic[research]: score=88/100, verdict=PASS
5. [Gate] Пользователь: "yes"
6. Planner → plan.toon
7. Critic[plan]: score=92/100, verdict=PASS
8. [Gate] Пользователь: "yes"
9. Executor → изменяет 4 файла, 2 коммита
10. Critic[execution]: score=95/100, verdict=PASS
11. report.md записан: status=COMPLETED

**Выход:**
```
✅ COMPLETED: feat(cli): add --list-sessions flag + feat(context): implement --list-sessions functionality
Files changed: lib/command/args.sh, lib/command/help.sh, lib/context/sessions.sh, iclaude.sh
Commits: abc1234, def5678
Execution Review: 95/100 [PASS]
```
