# Plan: Critic Agent для agent-orchestrator pipeline

## Context

Текущий пайплайн `Researcher → [Gate] → Planner → [Gate] → Executor → Report` не имеет
механизма автоматической оценки качества между фазами. Approval gates показывают артефакты,
но не анализируют их. Пользователь должен сам решить: «исследование достаточно полное?»,
«план адекватен рискам?», «исполнение соответствует плану?»

**Цель:** Critic Agent занимает позицию между каждым агентом и approval gate,
оценивает качество артефакта по структурированным рубрикам (0-100 баллов),
выносит вердикт (PASS/WARN/RETRY/ABORT) и при необходимости инициирует повтор агента
с конкретными инструкциями по улучшению.

Новый пайплайн:
```
Researcher → [Critic:research] → [Gate] → Planner → [Critic:plan] → [Gate] → Executor → [Critic:execution] → Report
```

**Complexity:** complex (5 файлов, 1 новый агент, новая концепция retry-loop)

---

## Critical Files

| Файл | Действие | Риск |
|------|---------|------|
| `agents/critic-agent/AGENT.md` | **СОЗДАТЬ** — полная спецификация агента-критика | Сложная рубрика: поверхностные проверки бесполезны |
| `skills/agent-orchestrator/SKILL.md` | Вставить Шаги 3.5, 5.5, 7.5; обновить Gates; retry-loop | Разрыв flow если вставить не в те позиции |
| `agents/_shared/workspace.md` | Добавить 3 новых файла в workspace структуру + правила READ-ONLY | R: агент может перезаписать чужой critique |
| `agents/researcher-agent/AGENT.md` | Добавить секцию RETRY CONTEXT handling | low |
| `agents/planning-agent/AGENT.md` | Добавить секцию RETRY CONTEXT handling | low |

**Опционально (примеры):**
- `agents/critic-agent/examples/example-research-critique.toon`
- `agents/critic-agent/examples/example-plan-critique-retry.toon`
- `agents/critic-agent/examples/example-execution-critique.toon`

---

## Existing Patterns to Reuse

- **TOON блоки**: `<<TOON:name>>` для массивов ≥5 элементов — `toon-protocol.md` (pipe-separated)
- **Completion signal**: `════════` border + структурированный вывод — из `researcher-agent/AGENT.md`
- **Gate display format**: Шаги 4 и 6 в `agent-orchestrator/SKILL.md` (строки 97-143) — точный шаблон
- **Prompt building**: `agent_md_content + WORKSPACE + TASK` паттерн (строки 181-193 SKILL.md)
- **Blocking issue pattern**: `plan-validation/SKILL.md` — структура `blocking_issues[]` vs `warnings[]`
- **Score/verdict вычисление**: `plan-validation` алгоритм (25 pts per dimension, weighted)

---

## Implementation Plan

### Фаза 1: Создать `agents/critic-agent/AGENT.md`

Полная спецификация агента. Файл содержит:

#### 1.1 Frontmatter + Роль

```yaml
---
name: critic-agent
version: 1.0.0
role: critic
subagent_type: general-purpose
capabilities:
  - research_evaluation
  - plan_evaluation
  - execution_evaluation
  - scoring
  - retry_feedback
parameters:
  - EVALUATION_MODE: research|plan|execution
  - RETRY_NUMBER: 0|1|2
  - PREVIOUS_CRITIQUE: null|path
input_files:
  research: [input.toon, research.toon]
  plan: [input.toon, research.toon, plan.toon]
  execution: [input.toon, plan.toon, report.md]
output_file: "{mode}-critique.toon"
---
```

Роль: только оценка (no research, no planning, no code execution). READ-ONLY агент.

#### 1.2 Алгоритм диспетчера

```
Читать EVALUATION_MODE из WORKSPACE/input
IF mode == "research"  → Секция A (Research Rubric)
IF mode == "plan"      → Секция B (Plan Rubric)
IF mode == "execution" → Секция C (Execution Rubric)
Вычислить score → verdict
Записать {mode}-critique.toon
Эмитировать Completion Signal
```

**RETRY context:** Если `RETRY_NUMBER > 0` и `PREVIOUS_CRITIQUE != null`:
- Прочитать предыдущий critique
- Для каждой проблемы из `retry_guidance` предыдущего critique проверить: устранена ли?
- Неустранённые проблемы: -5 к score (double-demerit rule)

#### 1.3 Рубрика A: Research (100 pts = 4 измерения × 25)

| Измерение | Что проверяет | ABORT trigger |
|-----------|--------------|--------------|
| **File Coverage** (25) | `relevant_files` покрывает ключевые точки задачи; ≥1 файл с relevance:high; `existing_implementations` заполнен | empty `relevant_files` |
| **Risk Depth** (25) | Количество рисков по complexity (min:1, std:2, cmp:3); у каждого risk.id + severity + non-trivial mitigation; `breaking_changes_potential` заполнен | — |
| **Complexity Calibration** (25) | `complexity_hint` соответствует доказательствам: minimal≤2 файла+all-low-risk, standard=3-5 файлов OR medium risk, complex=5+ OR high/critical | Разрыв >1 уровень |
| **Component Identification** (25) | `reusable_components` содержит function-level detail (не только пути); `affected_components` заполнен; `dependency_chain` непустой | — |

#### 1.4 Рубрика B: Plan (100 pts = 4 измерения × 25)

| Измерение | Что проверяет | ABORT trigger |
|-----------|--------------|--------------|
| **Research Alignment** (25) | Все файлы в `plan.files_to_change` присутствуют в `research.relevant_files`; `research_references.reusable_components_used` непустой и ссылается на реальные компоненты | `research_references` пустой |
| **Step Completeness** (25) | Каждая фаза ≥2 шагов; каждый шаг имеет description+action+file+validation; `estimated_steps` == фактическое количество | фаза с 0 шагов |
| **Risk Mitigation** (25) | Каждый риск из research с severity high/critical имеет запись в `risks_mitigated`; ID совпадают | critical риск без mitigation |
| **Validation Accuracy** (25) | Каждая фаза имеет `validation` команду; команды таргетируют правильные файлы; Conventional commit формат | >1 фазы без validation |

#### 1.5 Рубрика C: Execution (100 pts = 4 измерения × 25)

| Измерение | Что проверяет | ABORT trigger |
|-----------|--------------|--------------|
| **File Compliance** (25) | Все файлы из `plan.files_to_change` присутствуют в report с COMPLETED; незапланированные файлы не изменялись | report status == FAILED |
| **Validation Results** (25) | Каждая фаза в report имеет `Validation: cmd → OK`; команды совпадают с планом | validation FAILED без recovery |
| **Pattern Compliance** (25) | commit messages соответствуют плану (conventional commits); `git add` таргетирует файлы (не `.`); хэши коммитов присутствуют | — |
| **Report Completeness** (25) | Summary + все Phase Results + Risks Encountered + Next Steps; статус однозначен (COMPLETED/FAILED/PARTIAL) | >50% planned files absent |

#### 1.6 Verdict computation

```
score = sum(dimension scores)

IF any ABORT trigger → verdict = "ABORT" (override)
ELIF score >= 85    → verdict = "PASS"
ELIF score >= 70    → verdict = "WARN"
ELIF score >= 50    → verdict = "RETRY"
ELSE                → verdict = "ABORT"

NOTE: Execution mode НЕ имеет RETRY (execution failures = human escalation only)
```

#### 1.7 Output: `{mode}-critique.toon`

Формат совпадает с `research.toon` и `plan.toon`: TOON-блоки сначала (если ≥5 items),
затем `---JSON---`, затем JSON-объект.

**Если retry_guidance < 5 items** (чистый JSON):
```
---JSON---
{
  "critique": {
    "metadata": {
      "evaluation_mode": "research|plan|execution",
      "session_id": "2026-02-17T1523",
      "retry_number": 0,
      "timestamp": "ISO8601"
    },
    "verdict": "PASS|WARN|RETRY|ABORT",
    "score": 88,
    "max_score": 100,
    "dimensions": {
      "file_coverage":            { "score": 23, "max": 25, "issues": [] },
      "risk_depth":               { "score": 20, "max": 25, "issues": ["R2 mitigation generic"] },
      "complexity_calibration":   { "score": 25, "max": 25, "issues": [] },
      "component_identification": { "score": 20, "max": 25, "issues": ["missing function names"] }
    },
    "blocking_issues": [],
    "retry_guidance": [
      { "dimension": "risk_depth", "issue": "R2 mitigation generic", "severity": "medium", "fix": "Add code-level steps" }
    ]
  }
}
```

**Если retry_guidance ≥ 5 items** (гибридный TOON):
```
TOON:retry_guidance:v1
dimension|issue|severity|fix
risk_depth|R2 mitigation generic|medium|Add code-level steps
component_identification|missing function names|medium|Add function signatures
...

---JSON---
{
  "critique": {
    ...
    "retry_guidance": "<<TOON:retry_guidance>>"
  }
}
```

**Retry rename:** при повторе critique файл предыдущей итерации переименовывается
до записи нового: `research-critique.toon` → `research-critique-r1.toon`.
Финальный critique всегда в `{mode}-critique.toon` (без суффикса).

#### 1.8 Completion Signal

```
════════════════════════════════════════════
🔍 CRITIQUE COMPLETE [{evaluation_mode}]
════════════════════════════════════════════
Score: {score}/100  Verdict: {PASS|WARN|RETRY|ABORT}

Dimensions:
  file_coverage:           {n}/25  {k issues}
  risk_depth:              {n}/25  {k issues}
  complexity_calibration:  {n}/25  {k issues}
  component_identification:{n}/25  {k issues}

{if RETRY: "Retry guidance: {count} items"}
{if ABORT: "ABORT triggers: {list}"}

Critique: {WORKSPACE}/{mode}-critique.toon
════════════════════════════════════════════
```

---

### Фаза 2: Обновить `skills/agent-orchestrator/SKILL.md`

#### 2.1 Обновить pipeline diagram (строка 21)

```
Пользователь → Researcher → [Critic] → [Gate] → Planner → [Critic] → [Gate] → Executor → [Critic] → Report
```

#### 2.2 Добавить в frontmatter `dependencies`

```yaml
  - agents/critic-agent/AGENT.md
```

#### 2.3 Вставить Шаг 3.5 (после строки 93, перед Шагом 4)

```markdown
### Шаг 3.5: Запустить Critic Agent (mode=research)

```
Прочитать: agents/critic-agent/AGENT.md
Собрать prompt:
  critic_prompt = critic_md + f"""
  WORKSPACE: {WORKSPACE}
  EVALUATION_MODE: research
  RETRY_NUMBER: 0
  PREVIOUS_CRITIQUE: null
  """

retry_count = 0
loop:
  Task(subagent_type="general-purpose", prompt=critic_prompt)
  verdict = parse(Read("{WORKSPACE}/research-critique.toon").critique.verdict)

  IF verdict in ["PASS", "WARN"] → break

  IF verdict == "ABORT":
    ❌ RESEARCH ABORTED (score: {score}/100)
    Причина: {blocking_issues}
    Файл: {WORKSPACE}/research-critique.toon
    STOP.

  # verdict == "RETRY"
  retry_count += 1
  IF retry_count > 2 → ABORT ("Превышен лимит повторов после 2 попыток")

  # Перезапустить Researcher с critique как контекстом
  researcher_prompt = researcher_md + f"""
  WORKSPACE: {WORKSPACE}
  TASK: {task_description}
  RETRY_NUMBER: {retry_count}
  PREVIOUS_CRITIQUE: {WORKSPACE}/research-critique.toon
  """
  Task(subagent_type="general-purpose", prompt=researcher_prompt)
  # Update critic prompt for next iteration
  critic_prompt = critic_md + f"""...RETRY_NUMBER: {retry_count}\nPREVIOUS_CRITIQUE: ..."""
```
```

#### 2.4 Обновить Шаг 4 (Gate после Researcher)

Добавить строки оценки критика в gate display:

```
Оценка критика: {score}/100 [{verdict}]
{if WARN: "⚠️  Предупреждения: {warnings_summary}"}
```

#### 2.5 Вставить Шаг 5.5 (после строки 123, перед Шагом 6)

Идентичная структура Шагу 3.5, `EVALUATION_MODE: plan`.
Retry: перезапускает **Planner**, не Researcher.

#### 2.6 Обновить Шаг 6 (Gate после Planner)

Добавить строку критика аналогично Шагу 4.

#### 2.7 Вставить Шаг 7.5 (после строки 156, перед Шагом 8)

```markdown
### Шаг 7.5: Запустить Critic Agent (mode=execution)

Task(subagent_type="general-purpose", prompt=critic_md + EVALUATION_MODE:execution + ...)

verdict = parse(Read("{WORKSPACE}/execution-critique.toon").critique.verdict)

IF verdict == "ABORT":
  report_status = "FAILED (critic verification)"
  # Добавить секцию в итоговый отчёт

IF verdict == "WARN":
  # Продолжить, показать предупреждения в финальном отчёте

# НЕТ retry loop для execution
```

#### 2.8 Обновить Шаг 8 (финальный отчёт)

Добавить строку:
```
Execution Review: {score}/100 [{verdict}]
{if WARN: "⚠️  {warnings}"}
```

---

### Фаза 3: Обновить `agents/_shared/workspace.md`

#### 3.1 Новая workspace структура

```
{project_root}/
└── .iclaude/
    └── workspace/{session-id}/
        ├── input.toon                  # Orc → Researcher
        ├── research.toon               # Researcher output (overwritten on retry)
        ├── research-critique-r1.toon   # Critique от retry 1 (если был retry)
        ├── research-critique.toon      # Финальный critique (mode=research)  ← NEW
        ├── plan.toon                   # Planner output
        ├── plan-critique-r1.toon       # Critique от retry 1 (если был retry)
        ├── plan-critique.toon          # Финальный critique (mode=plan)       ← NEW
        ├── report.md                   # Executor output
        └── execution-critique.toon     # Critique (mode=execution)            ← NEW
```

**Rename pattern при retry:** перед записью нового critique — переименовать предыдущий:
- Retry 1: `{mode}-critique.toon` → `{mode}-critique-r1.toon`
- Retry 2: `{mode}-critique.toon` → `{mode}-critique-r2.toon`
- Финальный: остаётся в `{mode}-critique.toon`

#### 3.2 Новые правила для агентов

```
Critique files: READ-ONLY для всех агентов кроме Critic Agent.
Critic Agent: только читает workspace файлы, НИКОГДА не изменяет project файлы.
Retry agents: читают critique file как дополнительный контекст (READ-ONLY).
Ошибка записи critique: оркестратор трактует как RETRY-без-guidance, не ABORT.
```

#### 3.3 Обновить Cleanup секцию workspace.md

Добавить в список файлов cleanup предложения:
```
Файлы: input.toon, research.toon, research-critique*.toon,
       plan.toon, plan-critique*.toon, report.md, execution-critique.toon
```

---

### Фаза 4: Обновить Researcher и Planner AGENT.md (retry handling)

В оба файла добавить секцию в конец:

```markdown
## Retry Context (если RETRY_NUMBER > 0)

Если в prompt передан `RETRY_NUMBER > 0` и `PREVIOUS_CRITIQUE: {path}`:

1. Прочитать `{PREVIOUS_CRITIQUE}`
2. Найти секцию `retry_guidance`
3. **Для каждого пункта:** явно обратиться к issue и показать как исправлено
4. В completion signal добавить: "Адресовано {N} проблем из предыдущего critique"

КРИТИЧНО: Агент должен обратить внимание на dimension с issues и улучшить
соответствующие части вывода. Невыполнение → двойной штраф в следующем critique.
```

---

## Validation

```bash
# Smoke test: запустить пайплайн на простой задаче
/agent-orchestrator Добавить комментарий в lib/core/logging.sh

# Проверить что critique файлы созданы
ls .iclaude/latest/
# Ожидаем: input.toon research.toon research-critique.toon
#          plan.toon plan-critique.toon report.md execution-critique.toon

# Проверить verdict в critique (grep безопаснее чем json.load — файл может быть гибридным TOON)
grep '"verdict"' .iclaude/latest/research-critique.toon
grep '"score"'   .iclaude/latest/research-critique.toon

# Парсинг JSON из гибридного файла (awk пропускает TOON-блоки до ---JSON---)
awk '/^---JSON---$/{found=1; next} found' .iclaude/latest/research-critique.toon \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['critique']['verdict'], d['critique']['score'])"

# Проверить retry rename при RETRY verdict (если был повтор)
ls .iclaude/latest/*-critique-r*.toon 2>/dev/null && echo "Retries occurred"
```

---

## Commits (3)

1. `feat(agents): add critic-agent/AGENT.md with 3-mode evaluation rubrics`
2. `feat(orchestrator): integrate critic into pipeline with retry-loop (steps 3.5, 5.5, 7.5)`
3. `feat(agents): update researcher/planner for retry context; workspace spec for critique files`

---

## Key Design Decisions

| Решение | Обоснование |
|---------|-------------|
| Один агент с `EVALUATION_MODE` вместо 3 отдельных | Единый формат вывода, 1 файл для поддержки, проще routing в orchestrator |
| Критик READ-ONLY (не перезапускает команды) | Изоляция ответственности: критик оценивает artifacts, не среду |
| Execution mode без retry loop | Ошибки выполнения (сломанный commit, неправильный файл) требуют human judgment |
| WARN не блокирует pipeline | Сохранение human agency: пользователь сам решает при approval gate |
| max 2 retries per phase | Предотвращение бесконечных петель; после 2 — проблема в задаче, не в агенте |
| double-demerit при повторе | Давление на агент действительно устранить issue, а не замаскировать |
