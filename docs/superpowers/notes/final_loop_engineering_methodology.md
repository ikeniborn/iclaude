# Итоговая методология Loop Engineering для разработки на Claude Code и Codex

**Версия:** 1.1, reviewed  
**Дата:** 2026-07-01  
**Статус:** рабочая методология для внедрения в процесс разработки, перепроверена по исходным документам и актуальной документации инструментов  
**Целевая аудитория:** разработчики, тимлиды, platform/AI-инженеры, владельцы CI/eval-процессов  
**Инструменты:** Claude Code, Codex, AGENTS.md, CLAUDE.md, Skills, Subagents, Hooks, Codex Automations, Claude `/goal`/`/loop`/Routines, CI/evals, Langfuse или аналог observability.

---

## 0. Что является результатом

Loop Engineering в этом документе — не формальный отраслевой стандарт, а практическая инженерная дисциплина для работы с coding agents. Ее цель — заменить хаотичный режим «попросил агента — получил дифф — вручную разгребаю» на управляемый процесс:

```text
Goal -> Context -> Plan -> Act -> Check -> Reflect/Fix -> Stop/Handoff
```

Разработчик больше не является оператором бесконечных уточняющих промптов. Он проектирует цикл: цель, границы изменений, проверки, бюджет, state, handoff и rollback. Агент становится исполнителем внутри заданного контура, а не самостоятельным владельцем качества.

Ключевой принцип:

> Worker не должен быть единственным судьей своей работы. Успех подтверждает отдельный verifier: тесты, eval, CI, линтер, reviewer-agent, PR-review или человек.

**Что уточнено в v1.1 после перепроверки:**

- разведены Claude `/goal`, Claude `/loop`/scheduled tasks и Claude Routines: это разные механики с разной долговечностью;
- уточнено, что Claude `/goal` оценивает только то, что уже попало в transcript, и сам не запускает команды;
- уточнены места хранения Codex Skills: репозиторный путь `.agents/skills`, пользовательский `$HOME/.agents/skills`, admin `/etc/codex/skills`;
- добавлены ограничения и риски для Codex Automations: первые прогоны надо ревьюить вручную, background automations используют sandbox/approval settings и могут быть рискованными при full access;
- добавлен раздел с проверенными источниками и ссылками.

---

## 1. Базовая модель loop-процесса

### 1.1. Роли

| Роль | Назначение | Типичный инструмент |
|---|---|---|
| Human owner | Формулирует цель, ограничения, риск-политику, принимает итоговый PR | разработчик / тимлид |
| Planner | Декомпозирует задачу, выявляет риски, предлагает план | Claude Plan/Explore, Codex Plan mode, отдельный subagent |
| Worker / Implementer | Делает минимальные изменения в коде | Claude Code, Codex worker |
| Verifier | Проверяет результат независимо от worker | тесты, eval script, CI, reviewer-subagent, PR-review |
| Reporter | Обновляет state и формирует итоговый отчет | agent skill или сам worker под контролем |
| Governance loop | Отслеживает деградации, стоимость, PII, latency, flaky failures | scheduled automation/routine, Langfuse, CI dashboards |

### 1.2. Минимальный контракт loop

Любой loop должен быть описан как контракт. Без этого агент будет импровизировать, а человек не сможет отличить прогресс от правдоподобного шума.

```yaml
name: passport-registration-ocr-autoresearch
owner: platform-ai
mode: delivery | repair | research | governance | review
objective: "Улучшить распознавание страницы регистрации паспорта РФ"
context_sources:
  - AGENTS.md
  - CLAUDE.md
  - docs/architecture.md
  - docs/evals/ocr_eval.md
  - .agent-loop/STATE.md
mutable_scope:
  - src/ocr_pipeline/**
  - prompts/ocr/**
  - tests/ocr/**
protected_scope:
  - datasets/raw/**
  - datasets/ground_truth/**
  - scripts/eval_ocr.py
  - production_secrets/**
quality_gates:
  - pytest tests/ocr
  - python scripts/eval_ocr.py --dataset datasets/eval_manifest.json --output reports/latest_eval.json
  - bash scripts/guard_no_protected_files_changed.sh
metrics:
  primary:
    - field_level_accuracy.registration_address
    - field_level_accuracy.registration_authority
  secondary:
    - cer_cyrillic
    - invalid_json_rate
    - hallucination_rate
    - latency_p95_ms
    - vram_peak_mb
budget:
  max_iterations: 5
  max_wall_time_minutes: 90
  max_cost_usd: 5
stop_conditions:
  - all quality gates passed
  - primary metric improved without unacceptable secondary regression
  - budget exhausted
handoff_conditions:
  - schema change required
  - eval definition seems wrong
  - model license unclear
  - production PII access required
  - architecture boundary unclear
rollback_policy: "Revert failed experiments; keep only metric-backed changes"
logging:
  state_file: .agent-loop/STATE.md
  experiment_registry: reports/experiments.jsonl
  traces: langfuse
```

---

## 2. Виды loops и где их применять

| Тип loop | Когда использовать | Цикл | Verifier | Бюджет по умолчанию |
|---|---|---|---|---|
| Delivery loop | Реализовать фичу, endpoint, тесты, документацию | issue -> plan -> implement -> tests -> review -> PR | unit/integration/e2e tests, lint, typecheck | 3 итерации |
| Repair loop | Починить failing tests, CI, regression, flaky eval | failure -> reproduce -> isolate -> minimal fix -> regression test | failing test becomes green, regression test added | 3 итерации, узкий scope |
| Research / AutoResearch loop | Улучшить качество ML/OCR/RAG/VLM pipeline | hypothesis -> one bounded change -> fixed eval -> compare -> keep/revert | численная метрика + protected data guard | 5 экспериментов |
| Review loop | Проверить PR с разных сторон | diff -> split reviewers -> findings -> fix or reject | reviewer-agent + human PR review | 1-2 прохода |
| Governance / Triage loop | Регулярно отслеживать качество, drift, стоимость, PII | collect traces -> detect anomalies -> classify -> open issues/report | dashboards, policy checks, alerts | scheduled daily/weekly |
| Durable ops loop | Ночная сверка, backlog processing, dependency audit | schedule -> run checks -> fix/report -> archive | deterministic command or query | L3, без auto-merge |

Правило выбора простое: если есть объективный verifier, loop можно автоматизировать глубже. Если verifier субъективный или дорогой, агент должен работать как ассистент с частым human review.

---

## 3. Условие done: главный объект проектирования

Плохое условие: `сделай лучше`, `почини красиво`, `оптимизируй`, `разберись`.

Хорошее условие содержит четыре части:

1. **Одно измеримое конечное состояние.** Например: `pytest exits 0`, `playwright test green`, `context_recall >= 0.85`, `checksum diff = 0`.
2. **Способ проверки.** Команда, SQL, eval script, CI job, report path.
3. **Ограничения.** Какие файлы нельзя менять, какой scope разрешен, какие метрики не должны деградировать.
4. **Failure path.** Что делать после N неудач: остановиться, откатить, доложить лучший результат, попросить человека.

Шаблон условия:

```text
<command> exits 0 and prints <evidence>;
change only <mutable_scope>;
do not modify <protected_scope>;
if still failing after <N> attempts, revert unsafe changes and report blocker.
```

Пример для Claude Code `/goal`:

```text
/goal pytest tests/auth exits 0 and ruff check . exits 0;
change only src/auth/** and tests/auth/**;
do not modify migration files;
if still failing after 3 attempts, stop and report root cause with commands run
```

Пример для Codex prompt:

```text
Use $loop-delivery.
Implement the auth bug fix.
Definition of done:
- pytest tests/auth exits 0
- ruff check . exits 0
- no migration files changed
- final response includes commands run and risk/rollback note
Do not change tests except to add a regression test for this bug.
Stop after 3 failed repair attempts and summarize the blocker.
```

---

## 4. Autonomy slider: как наращивать автономию безопасно

| Уровень | Что автоматизируется | Claude Code | Codex | Когда переходить дальше |
|---|---|---|---|---|
| L0 | Разведка и ручной prompt | обычный prompt, plan/explore | обычный prompt, Plan mode | когда понятен scope и gates |
| L1 | Меньше подтверждений внутри одного хода | auto mode / permission mode | approvals + sandbox | когда команды безопасны |
| L2 | Цикл до done внутри сессии | `/goal` + measurable condition | AGENTS.md + tests/evals + explicit loop prompt | когда verifier надежен |
| L2+ | Убираем per-tool и per-turn ручное управление | `/goal` + auto mode + hooks | workspace-write sandbox + tests + reviewer thread | когда diff остается reviewable |
| L3 | Работа вне активной сессии | `/schedule`, routines, hooks, CI | Automations, thread automations, worktrees | когда prompt уже протестирован вручную |
| L4 | Оркестрация многих loops | Agent SDK, subagents, worktrees, own harness | subagents, automations, custom agents, worktrees | только после зрелых gates и governance |

Нельзя начинать с L4. Сначала проверяется, что condition не обманывает verifier, а агент делает маленькие, reviewable diffs.

Практическое уточнение по Claude Code:

- `/goal` — не cron и не обычный prompt. Это condition-driven loop внутри сессии: после каждого хода отдельный evaluator проверяет условие и либо продолжает работу, либо завершает goal.
- `/loop` и scheduled tasks — interval-driven polling внутри сессии. Они подходят для PR babysitting, long-running build/deploy, CI polling. Session-scoped задачи имеют ограничения по жизненному циклу; для durable scheduling лучше использовать Routines, desktop scheduled tasks или CI/GitHub Actions.
- Hooks — deterministic guardrails и lifecycle automation: блокировать protected files, форматировать после edits, логировать, уведомлять, auto-approve только узко заданные permission prompts.

Практическое уточнение по Codex:

- `AGENTS.md` — основной persistent context. Codex читает глобальные и проектные инструкции, а ближние к рабочей директории инструкции уточняют более общие.
- Skills для Codex лучше хранить в `.agents/skills/<skill>/SKILL.md`, если они должны ехать вместе с репозиторием. `.codex/agents/*.toml` — это другое: custom subagents, а не skills.
- Automations — L3-механика. До расписания prompt должен быть протестирован в обычном thread-е, первые результаты должны пройти human review, а sandbox лучше держать не выше `workspace-write` без отдельного обоснования.

---

## 5. Рекомендуемая структура репозитория

```text
repo/
  AGENTS.md                         # постоянные инструкции для Codex
  CLAUDE.md                         # постоянный контекст для Claude Code
  README.md
  docs/
    architecture.md
    evals/
      metrics.md
      dataset_policy.md
      ocr_eval.md
    decisions/
      ADR-0001-loop-process.md
  .agent-loop/
    LOOP.md                         # активные loops и их контракт
    STATE.md                        # baseline, попытки, решения, known failures
    RUNBOOK.md                      # как запускать проверки
    QUEUE.md                        # backlog для agents
    DECISIONS.md                    # human decisions и запреты
    FAILURE_TAXONOMY.md             # классификация ошибок
    RISK_REGISTER.md                # риски loop-системы
  .agents/
    skills/
      loop-delivery/SKILL.md        # Codex skills, переносимый Agent Skills формат
      loop-autoresearch/SKILL.md
      pr-review-loop/SKILL.md
  .codex/
    config.toml
    agents/
      pr-explorer.toml
      verifier.toml
      ocr-researcher.toml
  .claude/
    skills/
      loop-delivery/SKILL.md
      loop-autoresearch/SKILL.md
      pr-review-loop/SKILL.md
    agents/
      verifier.md
      security-reviewer.md
      langfuse-analyst.md
    settings.json                  # hooks, permissions, managed local rules
  scripts/
    guard_no_protected_files_changed.sh
    eval_ocr.py
    compare_experiment.py
    collect_langfuse_traces.py
  reports/
    latest_eval.json
    experiments.jsonl
  tests/
```

Принцип: инструкции, state, evals и guardrails живут в репозитории. Chat context исчезает, repo-state остается.

---

## 6. Внедрение в Claude Code

### 6.1. CLAUDE.md: постоянный контекст проекта

```markdown
# CLAUDE.md

## Project context
This repository uses loop engineering for agent-assisted development.
Claude must work through explicit loops: plan, act, check, reflect, stop/handoff.

## Working rules
- Prefer small, reviewable diffs.
- Keep implementation and verification separate where possible.
- Prefer deterministic checks over subjective confidence.
- Before editing, produce a short plan.
- After editing, run the smallest relevant test first, then broader checks.
- Update `.agent-loop/STATE.md` after meaningful experiments or repair attempts.

## Protected areas
Do not edit unless explicitly instructed:
- datasets/raw/**
- datasets/ground_truth/**
- production_secrets/**
- compliance/**
- migration files
- eval scripts, unless task is explicitly about eval design

## Quality gates
Run the relevant checks before declaring done:

```bash
pytest
ruff check .
mypy src
bash scripts/guard_no_protected_files_changed.sh
```

For OCR/VLM work:

```bash
python scripts/eval_ocr.py --dataset datasets/eval_manifest.json --output reports/latest_eval.json
```

## Escalation
Stop and ask for human review when:
- schema or architecture changes are required;
- eval metric improves only by changing eval data or validation;
- PII handling is unclear;
- model license is unclear;
- latency, cost, or VRAM regress materially;
- production credentials or production data are needed.
```

### 6.2. Claude `/goal`: когда использовать

Использовать `/goal`, когда есть проверяемое конечное состояние, а работа требует нескольких turn-ов.

Важная механика: condition в `/goal` запускает ход сразу. После каждого хода evaluator смотрит на conversation/transcript и возвращает yes/no с короткой причиной. Он не запускает команды и не читает файлы самостоятельно. Поэтому worker обязан явно вывести evidence: команду, exit code, summary метрик, путь к report.

Не стоит писать `/goal all tests pass`, если агент не обязан сам запустить тесты и напечатать результат. Лучше писать: `pytest tests/auth exits 0 and Claude prints the command output summary`.

Хорошие задачи для `/goal`:

```text
/goal all tests in tests/billing pass and ruff check . exits 0;
change only src/billing/** and tests/billing/**;
do not modify migrations;
stop after 3 failed attempts and report blocker
```

```text
/goal python scripts/eval_ocr.py --dataset datasets/eval_manifest.json --output reports/latest_eval.json prints field_level_accuracy>=0.93 and invalid_json_rate==0;
change only src/ocr_pipeline/** and prompts/ocr/**;
do not modify datasets/** or scripts/eval_ocr.py;
stop after 5 experiments and report best result
```

Не использовать `/goal` для задач без objective verifier:

```text
/goal make the UI better
/goal refactor the whole codebase
/goal improve architecture
```

Такие задачи сначала нужно превратить в specs, constraints и checks.

### 6.3. Claude subagent: verifier

Файл `.claude/agents/verifier.md`:

```markdown
---
name: verifier
description: Strict verifier for code changes. Use after implementation, repair, eval, or PR preparation.
tools: Read, Grep, Glob, Bash
model: sonnet
---

You are a strict verifier. Review the current diff and evidence like a production owner.

Check:
- acceptance criteria are satisfied;
- tests/evals actually ran and evidence is present;
- protected files were not changed;
- diff is small and reviewable;
- no hidden schema, migration, PII, secret, or license risk;
- rollback path is clear.

Return:
- APPROVE or REJECT;
- evidence;
- missing checks;
- risks;
- required fixes.
```

### 6.4. Claude Skill: Delivery Loop

Файл `.claude/skills/loop-delivery/SKILL.md`:

```markdown
---
name: loop-delivery
description: Use for engineering delivery tasks that require plan, implementation, tests, verification, and PR-ready summary.
---

# Delivery Loop Skill

## Goal
Complete one engineering task with a small, reviewable, test-backed diff.

## Steps
1. Read `CLAUDE.md`, `.agent-loop/LOOP.md`, and `.agent-loop/STATE.md` if present.
2. Restate the task and acceptance criteria.
3. Produce a short plan before editing.
4. Make the smallest viable change.
5. Add or update tests when relevant.
6. Run the smallest relevant check, then broader checks.
7. If checks fail, fix within the loop budget.
8. Ask the verifier subagent to review the diff and evidence.
9. Update `.agent-loop/STATE.md` with commands, results, risks, and next steps.
10. Return a PR-ready summary.

## Stop conditions
- Acceptance criteria pass.
- Quality gate fails for a reason requiring human decision.
- Scope or budget is exceeded.
```

### 6.5. Claude hooks: deterministic guardrails

Hooks не должны заменять reasoning. Их задача — жестко и детерминированно запрещать опасное или запускать автоматические проверки.

Пример `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash scripts/prevent_protected_edits.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash scripts/agent_post_edit_check.sh"
          }
        ]
      }
    ]
  }
}
```

---

## 7. Внедрение в Codex

### 7.1. AGENTS.md: постоянные инструкции и Definition of Done

`AGENTS.md` должен быть коротким и операционным: команды проверки, protected files, Definition of Done, правила handoff. Большие runbooks лучше вынести в `.agent-loop/RUNBOOK.md`, docs или skills. В Codex можно использовать глобальный уровень (`~/.codex/AGENTS.md` или `AGENTS.override.md`) и repo-level/dir-level инструкции; более близкие к рабочей директории правила должны уточнять общие.

```markdown
# AGENTS.md

## Mission
You are working in this repository as an engineering agent.
Your job is to make small, reviewable, test-backed changes.

## Working rules
- Always read `.agent-loop/LOOP.md` and `.agent-loop/STATE.md` before loop work.
- Before editing, produce a short plan.
- Prefer small diffs over large rewrites.
- Run the smallest relevant test first, then broader checks.
- Do not loop forever; respect the loop budget.
- If architecture, schema, license, PII, or production credentials are involved, stop for human review.

## Protected files
Do not modify unless explicitly requested:
- datasets/raw/**
- datasets/ground_truth/**
- production_secrets/**
- compliance/**
- migration files
- scripts/eval_*.py unless task is eval design

## Definition of done
- Requested behavior is implemented.
- Tests/evals were added or updated when relevant.
- Relevant checks pass.
- Protected files were not changed.
- Final response includes commands run, evidence, risks, and rollback note.
- `.agent-loop/STATE.md` is updated for loop/research work.

## Commands
- Unit tests: `pytest`
- Lint: `ruff check .`
- Type check: `mypy src`
- Protected file guard: `bash scripts/guard_no_protected_files_changed.sh`
- OCR eval: `python scripts/eval_ocr.py --dataset datasets/eval_manifest.json --output reports/latest_eval.json`

## Loop budget
- Max repair iterations per task: 3
- Max research experiments per run: 5
- Stop early if gates pass.
```

### 7.2. Codex Skill: Delivery Loop

Файл `.agents/skills/loop-delivery/SKILL.md` — репозиторный путь для Codex Skills:

```markdown
---
name: loop-delivery
description: Use for one engineering delivery task that needs plan, implementation, tests, verification, and PR-ready summary.
---

# Delivery Loop

Follow this process:
1. Read `AGENTS.md`, `.agent-loop/LOOP.md`, and `.agent-loop/STATE.md` if present.
2. Restate task and acceptance criteria.
3. Produce a short plan.
4. Make the smallest viable change.
5. Add/update tests when relevant.
6. Run relevant checks.
7. Fix failures within the stated budget.
8. Review the diff for protected files and risk.
9. Update `.agent-loop/STATE.md` if this was loop/research work.
10. Return a final PR-ready summary with commands run and rollback notes.

Stop if the task requires human decisions about architecture, schema, production data, secrets, or model licensing.
```

Вызов:

```text
Use $loop-delivery to implement this issue with tests and a PR-ready summary.
```

### 7.3. Codex Skill: AutoResearch Loop

Файл `.agents/skills/loop-autoresearch/SKILL.md`:

```markdown
---
name: loop-autoresearch
description: Use for metric-driven experiments where the agent proposes one hypothesis, changes one bounded area, runs a fixed eval, compares metrics, and keeps or reverts.
---

# AutoResearch Loop

## Rules
- Change one main variable per experiment.
- Never modify eval data, ground truth, or eval script unless the task is explicitly eval design.
- Never improve metrics by weakening validation.
- Keep seed, model version, eval command, and dataset fixed when possible.
- Log every failed attempt; failed experiments are useful data.
- Keep only changes that improve the primary metric without unacceptable secondary regression.

## Cycle
1. Load baseline metrics from `.agent-loop/STATE.md` or `reports/latest_eval.json`.
2. Propose one hypothesis.
3. Predict expected metric movement and risk.
4. Make one bounded change.
5. Run the fixed eval command.
6. Compare before/after metrics.
7. Keep or revert.
8. Update `.agent-loop/STATE.md` and `reports/experiments.jsonl`.

## Required output
- Hypothesis
- Files changed
- Eval command
- Before/after metrics
- Keep/revert decision
- Risks
- Next hypothesis
```

### 7.4. Codex custom agents: maker/checker split

Файл `.codex/config.toml`:

```toml
[agents]
max_threads = 6
max_depth = 1
```

Файл `.codex/agents/pr-explorer.toml`:

```toml
name = "pr_explorer"
description = "Read-only codebase explorer for gathering evidence before review or implementation."
model_reasoning_effort = "medium"
sandbox_mode = "read-only"
developer_instructions = """
Stay in exploration mode.
Trace real execution paths, cite files and symbols, and avoid edits.
Prefer targeted reads and searches over broad scans.
"""
```

Файл `.codex/agents/verifier.toml`:

```toml
name = "verifier"
description = "Strict verifier focused on correctness, tests, protected files, metrics, PII, and rollback."
model_reasoning_effort = "high"
sandbox_mode = "read-only"
developer_instructions = """
Review code like a production owner.
Check acceptance criteria, test evidence, protected files, secrets, PII, latency/cost regressions, and rollback.
Do not approve subjective improvements without evidence.
Return APPROVE or REJECT with concrete findings.
"""
```

Вызов:

```text
Review this branch against main. Spawn pr_explorer to map affected code paths and verifier to check the diff, tests, protected files, and risks. Wait for both and return a consolidated keep/fix/reject recommendation.
```

### 7.5. Codex Automations

Использовать, когда workflow уже стабилен в ручном thread-е. Automations могут быть standalone/project runs, где каждый запуск независим и попадает в Triage, или thread automations, которые возвращаются в тот же thread и сохраняют его контекст.

Перед расписанием обязательно: протестировать prompt вручную, проверить reviewability diff, ограничить sandbox, зафиксировать stop/handoff условия и просмотреть первые N запусков человеком.

Примеры:

```text
Standalone automation: Every weekday at 09:00, check CI failures for this repository.
Use $loop-repair-triage.
If there are actionable failures, create a concise triage report and propose one minimal fix branch.
If there are no findings, archive the run.
```

```text
Thread automation: Every 15 minutes, check the PR status through the GitHub plugin.
If new review feedback appears, address only non-controversial comments with tests.
If feedback requires product or architecture decision, report and stop.
Stop when PR is merged or closed.
```

Правило: сначала протестировать prompt вручную, затем включать schedule. Для unattended work использовать worktree и sandbox не выше `workspace-write`, если нет явной причины.

---

## 8. Ежедневный процесс разработчика

### 8.1. Issue -> loop-ready task

Перед запуском агента issue должен содержать:

```markdown
## Objective
Что должно измениться для пользователя или системы.

## Acceptance criteria
- Конкретные проверяемые критерии.
- Команды, которые должны пройти.

## Scope
Can edit:
- ...

Do not edit:
- ...

## Verification
Commands:
- pytest ...
- ruff check .
- playwright test ...

## Budget
- max iterations: 3
- stop after: blocker / schema decision / architecture uncertainty

## Rollback
Как откатить или отключить изменение.
```

### 8.2. Стандартный flow

```text
1. Human пишет issue/spec с acceptance criteria.
2. Agent читает AGENTS.md/CLAUDE.md + .agent-loop/LOOP.md.
3. Agent делает план. Для сложных задач план подтверждает человек.
4. Worker делает минимальный diff.
5. Worker запускает checks и печатает evidence.
6. Verifier/reviewer проверяет diff и evidence.
7. Worker исправляет только подтвержденные проблемы.
8. Agent формирует PR summary: что изменено, команды, риски, rollback.
9. Human review как чужой PR.
10. После merge governance loop следит за regressions, cost, latency, PII.
```

### 8.3. PR summary template

```markdown
## What changed
- ...

## Why
- ...

## Verification
- `pytest tests/...` -> pass
- `ruff check .` -> pass
- `python scripts/eval_...` -> metrics before/after

## Risk
- ...

## Rollback
- Revert commit / disable feature flag / restore config

## Agent loop notes
- Iterations: N
- Files changed: ...
- Handoff needed: yes/no
```

---

## 9. Примеры внедрения

### 9.1. Delivery loop: fullstack endpoint

**Задача:** реализовать `/api/passport/registration/recognize`.

**Loop card:**

```yaml
mode: delivery
objective: "Endpoint accepts image and returns JSON matching passport_registration_v1"
mutable_scope:
  - src/api/**
  - src/ocr_pipeline/**
  - tests/api/**
protected_scope:
  - datasets/raw/**
  - datasets/ground_truth/**
quality_gates:
  - pytest tests/api/test_passport_registration.py
  - python scripts/eval_ocr.py --dataset datasets/eval_manifest.json --output reports/latest_eval.json
budget:
  max_iterations: 3
handoff:
  - schema change required
  - production PII needed
```

Claude Code:

```text
/loop-delivery Implement `/api/passport/registration/recognize`.
Acceptance: accepts image input, returns JSON matching passport_registration_v1,
handles Cyrillic stamp text, adds unit and integration tests, does not modify raw datasets or ground truth.
Run pytest and OCR eval. Stop after 3 failed iterations or if schema change is required.
```

Claude `/goal` variant:

```text
/goal pytest tests/api/test_passport_registration.py exits 0 and python scripts/eval_ocr.py --dataset datasets/eval_manifest.json --output reports/latest_eval.json prints invalid_json_rate==0;
change only src/api/** src/ocr_pipeline/** tests/api/**;
do not modify datasets/** or scripts/eval_ocr.py;
stop after 3 failed attempts and report blocker
```

Codex:

```text
Use $loop-delivery.
Task: implement `/api/passport/registration/recognize`.
Acceptance:
- accepts image input
- returns JSON matching passport_registration_v1
- handles Cyrillic stamp text
- adds unit and integration tests
- does not modify raw datasets or ground truth
Commands:
- pytest tests/api/test_passport_registration.py
- python scripts/eval_ocr.py --dataset datasets/eval_manifest.json --output reports/latest_eval.json
Stop after 3 failed iterations or if schema change is required.
```

### 9.2. Repair loop: failing CI

**Задача:** CI падает на `tests/billing/test_invoice_total.py`.

Claude:

```text
/goal pytest tests/billing/test_invoice_total.py exits 0 and ruff check . exits 0;
first reproduce the failure, then make the smallest fix;
add regression coverage only if missing;
do not touch unrelated billing files;
stop after 3 failed attempts and report root cause
```

Codex:

```text
Use $loop-delivery as a repair loop.
Failure: `pytest tests/billing/test_invoice_total.py` fails in CI.
Steps:
1. Reproduce locally.
2. Identify minimal root cause.
3. Make smallest fix.
4. Add/adjust regression test only if needed.
5. Run failing test, then relevant billing suite, then ruff.
Budget: 3 attempts. Stop if fix requires product decision.
```

Verifier expectations:

```text
- original failure reproduced;
- test now passes;
- no broad rewrite;
- no unrelated snapshots changed;
- final summary includes root cause and rollback.
```

### 9.3. Research / AutoResearch loop: OCR/VLM passport registration

**Задача:** улучшить распознавание кириллических штампов на странице регистрации.

```yaml
mode: research
objective: "Improve field-level accuracy for registration address and authority"
mutable_scope:
  - src/ocr_pipeline/preprocess.py
  - src/ocr_pipeline/router.py
  - prompts/ocr/registration_page.md
protected_scope:
  - datasets/raw/**
  - datasets/ground_truth/**
  - scripts/eval_ocr.py
primary_metric:
  - field_level_accuracy.registration_address
  - field_level_accuracy.registration_authority
secondary_metrics:
  - cer_cyrillic
  - invalid_json_rate
  - hallucination_rate
  - latency_p95_ms
  - vram_peak_mb
eval_command: python scripts/eval_ocr.py --dataset datasets/eval_manifest.json --output reports/latest_eval.json
acceptance:
  - primary metric improves
  - invalid_json_rate does not increase
  - hallucination_rate does not increase
  - latency_p95 regression <= 20%
  - no protected files changed
budget:
  max_experiments: 5
```

Codex:

```text
Use $loop-autoresearch.
Objective: improve Cyrillic stamp recognition on passport registration pages.
Editable scope:
- src/ocr_pipeline/preprocess.py
- src/ocr_pipeline/router.py
- prompts/ocr/registration_page.md
Do not edit:
- datasets/raw/**
- datasets/ground_truth/**
- scripts/eval_ocr.py
Primary metric: field_level_accuracy for registration_address and registration_authority.
Secondary metrics: cer_cyrillic, invalid_json_rate, hallucination_rate, latency_p95_ms, vram_peak_mb.
Eval command:
python scripts/eval_ocr.py --dataset datasets/eval_manifest.json --output reports/latest_eval.json
Run up to 5 experiments. Change one main thing per experiment. Keep only changes that improve the primary metric without unacceptable secondary regression. Log every attempt in `.agent-loop/STATE.md` and `reports/experiments.jsonl`.
```

Claude:

```text
/loop-autoresearch Improve Cyrillic stamp recognition for passport registration pages using the fixed OCR eval.
Keep changes only if field-level accuracy improves without invalid JSON or hallucination regression and latency p95 regression is <=20%.
Never modify datasets/** or scripts/eval_ocr.py.
Run up to 5 experiments and update `.agent-loop/STATE.md`.
```

### 9.4. RAG eval-driven loop

**Задача:** настроить hybrid retrieval: embeddings + BM25 + reranker + RRF.

```yaml
mode: research
objective: "Improve retrieval quality on golden Russian question set"
mutable_scope:
  - config/retrieval.yaml
  - src/retrieval/**
protected_scope:
  - eval/golden_ru.jsonl
quality_gates:
  - ragas eval eval/golden_ru.jsonl
metrics:
  primary:
    - context_recall >= 0.85
    - faithfulness >= 0.90
budget:
  max_experiments: 5
```

Claude `/goal`:

```text
/goal ragas eval eval/golden_ru.jsonl prints context_recall>=0.85 and faithfulness>=0.90;
change only config/retrieval.yaml and src/retrieval/**;
do not modify eval/golden_ru.jsonl;
after 5 failed attempts, report best configuration and metrics
```

Codex:

```text
Use $loop-autoresearch.
Tune retrieval parameters only in config/retrieval.yaml and src/retrieval/**.
Do not modify eval/golden_ru.jsonl.
Eval command: ragas eval eval/golden_ru.jsonl
Target: context_recall >= 0.85 and faithfulness >= 0.90.
Run up to 5 bounded experiments, changing one main parameter family per run.
Log before/after metrics and keep only successful changes.
```

### 9.5. Durable reconciliation loop: Greenplum -> Trino/Iceberg

**Задача:** ночная сверка source и Iceberg по watermark, включая обработку удалений.

```yaml
mode: governance | repair
autonomy: L3
objective: "Source and Iceberg table converge for the watermark window"
quality_gate: "Trino reconciliation SQL returns 0 mismatches and exit 0"
actuator:
  - run reconciliation runbook
  - open issue or PR on drift
protected_scope:
  - production credentials
  - destructive DDL without human approval
```

Claude `/loop` для session-scoped polling или Routine для durable scheduled work:

```text
Every night, run the reconciliation check for Greenplum -> Iceberg.
If mismatch_count == 0, record success and stop.
If mismatches exist, classify: insert/update drift, missing deletes, checksum mismatch, or infra failure.
Run only safe reconciliation steps from `.agent-loop/RUNBOOK.md`.
Do not run destructive DDL.
Open a report with SQL evidence and recommended fix.
```

Codex standalone automation:

```text
Use $reconciliation-triage.
On schedule, run the Trino reconciliation command from `.agent-loop/RUNBOOK.md`.
If the command returns 0 mismatches, archive the run.
If mismatches exist, create a triage report with source table, Iceberg table, watermark, mismatch type, sample keys, and proposed safe fix.
Do not modify production config or credentials.
```

### 9.6. PR babysitting review-loop

**Задача:** агент следит за PR, отвечает на новые review comments, но не принимает продуктовые решения.

Codex thread automation:

```text
Every 15 minutes, check the current PR status through the GitHub plugin.
If new review comments are actionable and local to this PR, implement the smallest fix, run relevant tests, and reply with evidence.
If feedback requires product, architecture, schema, or security decision, stop and ask human.
Stop when PR is merged, closed, or no new comments after 3 checks.
```

Claude `/loop` / scheduled task / Routine:

```text
Monitor this PR for new review feedback.
For non-controversial fixes, update the branch and run relevant checks.
For architecture/product/security questions, summarize the decision needed and stop.
Never auto-merge.
```

---

## 10. Governance, безопасность и наблюдаемость

### 10.1. Quality gates

Engineering gates:

```text
- unit/integration/e2e tests pass
- lint/typecheck pass
- no protected files changed
- diff is small and reviewable
- PR summary includes evidence
- rollback path is clear
```

Research gates:

```text
- fixed eval dataset
- fixed metric definition
- before/after comparison
- no modification of ground truth
- no metric shortcut
- held-out validation for durable improvement
- experiment reproducible from logged config
```

Production gates:

```text
- latency within SLO
- VRAM/cost within budget
- throughput within target
- no PII leak in logs/traces
- model license checked
- fallback path exists
- safe structured error on failure
- confidence threshold calibrated
```

### 10.2. Anti-cheating controls

Минимальный guard script:

```bash
#!/usr/bin/env bash
set -euo pipefail

protected_patterns=(
  "datasets/raw/"
  "datasets/ground_truth/"
  "production_secrets/"
  "compliance/"
  "scripts/eval_ocr.py"
)

changed=$(git diff --name-only)
for pattern in "${protected_patterns[@]}"; do
  if echo "$changed" | grep -q "^${pattern}"; then
    echo "ERROR: protected path changed: ${pattern}" >&2
    exit 1
  fi
done

echo "Protected file guard passed"
```

### 10.3. Langfuse / observability schema

```json
{
  "loop_name": "ocr-registration-autoresearch",
  "run_id": "2026-07-01-001",
  "agent": "codex|claude|local-llm",
  "task": "Improve Cyrillic stamp recognition",
  "hypothesis": "Deskew before OCR reduces CER",
  "editable_scope": ["src/ocr_pipeline/preprocess.py"],
  "commands": ["python scripts/eval_ocr.py --dataset datasets/eval_manifest.json"],
  "metrics_before": {
    "field_level_accuracy": 0.88,
    "cer_cyrillic": 0.19,
    "latency_p95_ms": 3200
  },
  "metrics_after": {
    "field_level_accuracy": 0.90,
    "cer_cyrillic": 0.16,
    "latency_p95_ms": 3500
  },
  "decision": "keep",
  "risk": "latency increased by 9%",
  "human_review_required": false
}
```

Минимальные dashboards:

| Dashboard | Что показывает |
|---|---|
| Loop success rate | Доля loop-runs, закончившихся passing gates |
| Metric delta | Изменение качества по экспериментам |
| Cost/tokens | Стоимость по loop type, skill, agent |
| Latency/VRAM | Производительность inference и regressions |
| Handoff reasons | Почему агент остановился |
| Failure taxonomy | Топ классов ошибок |
| Protected file alerts | Попытки изменить eval/ground truth/secrets |

---

## 11. Zero-cloud и sensitive data policy

Для чувствительных данных нельзя смешивать удобство агента и требования к контуру безопасности.

Рекомендуемое разделение:

| Сценарий | Инструмент |
|---|---|
| Нечувствительный код, OSS, PR-review, docs, triage | Codex или Claude Code cloud/web/app |
| Внутренний код без production data | Claude Code/Codex с sandbox, review и protected files |
| Паспорта, PII, DWH production extracts, закрытые датасеты | self-hosted/local loop harness, Claude Code через approved LLM gateway, локальные evals |
| Полностью offline/zero-cloud | собственный loop script + локальный inference + deterministic tests/evals |

Для zero-cloud основной паттерн:

```text
local dataset -> local inference -> structured output -> local eval -> state/report -> human review
```

Codex и cloud-сессии не должны получать production PII, raw passport scans или закрытые DWH extracts. Для таких задач использовать синтетические fixtures, redacted samples или локальный контур.

Отдельно: даже когда агентный инструмент поддерживает sandbox, sandbox не является заменой data governance. Он ограничивает действия процесса, но не решает вопрос передачи чувствительного контекста в облачную модель.

---

## 12. План внедрения

### Этап 1. Рельсы без автономии

Цель: подготовить репозиторий к безопасной agent-assisted разработке.

1. Добавить `AGENTS.md`.
2. Добавить `CLAUDE.md`, если используется Claude Code.
3. Создать `.agent-loop/LOOP.md`, `.agent-loop/STATE.md`, `.agent-loop/RUNBOOK.md`.
4. Зафиксировать protected paths.
5. Зафиксировать команды tests/evals/lint/typecheck.
6. Добавить `guard_no_protected_files_changed.sh`.
7. Зафиксировать PR summary template.

Exit criteria:

```text
- агент знает команды проверки;
- protected paths описаны;
- один developer может запустить delivery loop вручную;
- результат ревьюится как обычный PR.
```

### Этап 2. Controlled delivery/repair loops

1. Выбрать 3-5 безопасных задач.
2. Запускать только L1/L2 loops с max 3 iterations.
3. Требовать план до edits.
4. Требовать evidence после checks.
5. Добавить verifier-agent.
6. После каждой повторяющейся ошибки обновлять `AGENTS.md` или `CLAUDE.md`.

Exit criteria:

```text
- агент регулярно делает маленькие diffs;
- tests/evidence присутствуют в финальном отчете;
- verifier ловит реальные ошибки;
- human review не становится bottleneck из-за гигантских диффов.
```

### Этап 3. Controlled AutoResearch

1. Зафиксировать baseline metrics.
2. Защитить eval dataset и ground truth.
3. Создать `$loop-autoresearch` / `/loop-autoresearch` skill.
4. Разрешить менять только bounded area.
5. Запустить 5-10 экспериментов.
6. Сравнить с ручной baseline-работой.
7. Прогнать held-out validation.

Exit criteria:

```text
- каждая гипотеза логируется;
- failed experiments сохраняются как знание;
- improvements воспроизводимы;
- нет metric cheating;
- latency/cost/VRAM не игнорируются.
```

### Этап 4. Governance and scheduled routines

1. Подключить Langfuse или аналог traces.
2. Добавить dashboards.
3. Ввести failure taxonomy.
4. Настроить daily/weekly report.
5. Настроить scheduled CI/eval triage.
6. Ввести PII redaction policy.
7. Запретить auto-merge для production изменений.

Exit criteria:

```text
- scheduled loops не меняют опасные файлы;
- first N scheduled outputs были проверены человеком;
- есть stop/handoff reasons;
- стоимость, latency, regressions видны на dashboards.
```

---

## 13. Definition of Done для внедрения Loop Engineering

Методология считается внедренной в репозиторий, когда:

```text
[ ] Есть AGENTS.md и/или CLAUDE.md.
[ ] Есть .agent-loop/LOOP.md с активными loops.
[ ] Есть .agent-loop/STATE.md с baseline и историей попыток.
[ ] Есть хотя бы один reusable skill: loop-delivery или loop-autoresearch.
[ ] Quality gates запускаются одной командой или documented command set.
[ ] Eval dataset и protected paths защищены guard script/hook/policy.
[ ] Worker/checker split применяется для production-sensitive задач.
[ ] Agent final summary всегда содержит commands run, evidence, risks, rollback.
[ ] Есть human handoff policy.
[ ] Есть лимиты итераций, времени и стоимости.
[ ] Есть rollback policy.
[ ] Хотя бы один реальный loop прошел полный цикл от issue до PR/report.
[ ] Governance loop отслеживает regressions, cost, latency, PII или failure taxonomy.
```

---

## 14. Антипаттерны и исправления

| Антипаттерн | Почему плохо | Как исправить |
|---|---|---|
| `Сделай лучше` | Нет verifier, нет границ | Задать metric, command, scope, stop condition |
| Бесконечный loop | Тратит токены и время | max iterations, max cost, handoff |
| Worker сам себя принимает | Reviewer bias | deterministic tests или separate verifier |
| Огромная составная цель | Human review становится bottleneck | дробить на последовательные goals |
| Менять eval под результат | Metric cheating | protected eval, guard script, verifier |
| Хранить state только в chat | Контекст теряется | `.agent-loop/STATE.md`, reports, traces |
| Автоматический merge в main | Риск незамеченной деградации | PR + human review |
| Использовать debate/model ensemble всегда | Cost/latency растут без пользы | включать только при uncertainty |
| Оптимизировать только accuracy | Производительность деградирует | secondary metrics: latency, VRAM, cost |
| Запускать L4 сразу | Непредсказуемое поведение | идти L0 -> L1 -> L2 -> L3 -> L4 |

---

## 15. Короткая памятка для разработчика

Перед запуском агента:

```text
1. Могу ли я проверить done командой или метрикой?
2. Написан ли mutable/protected scope?
3. Есть ли max iterations и failure path?
4. Понятно ли, что агент должен доложить в конце?
5. Будет ли diff reviewable?
6. Кто verifier: тест, eval, subagent, PR-review или человек?
```

Команда для Claude Code:

```text
/goal <measurable condition>;
change only <scope>;
do not modify <protected>;
stop after <N> failed attempts and report blocker with commands run
```

Команда для Codex:

```text
Use $loop-delivery or $loop-autoresearch.
Objective: ...
Acceptance: ...
Editable scope: ...
Do not edit: ...
Commands: ...
Budget: ...
Final output must include commands run, evidence, risks, rollback.
```

## 16. Проверенные источники и опоры

При перепроверке документ был сверен с двумя исходными рабочими документами и актуальной документацией инструментов. Практическая рамка остается прежней: loop engineering — emerging-паттерн, а не формальный стандарт; AutoResearch — частный research-loop с фиксированным экспериментом и численной метрикой; Codex и Claude Code — execution surfaces, а не замена eval/governance.

Проверенные внешние опоры:

- OpenAI Codex AGENTS.md: `https://developers.openai.com/codex/guides/agents-md`
- OpenAI Codex Skills: `https://developers.openai.com/codex/skills`
- OpenAI Codex Subagents: `https://developers.openai.com/codex/subagents`
- OpenAI Codex Automations: `https://developers.openai.com/codex/app/automations`
- Claude Code `/goal`: `https://code.claude.com/docs/en/goal`
- Claude Code scheduled tasks / `/loop`: `https://code.claude.com/docs/en/scheduled-tasks`
- Claude Code Hooks: `https://code.claude.com/docs/en/hooks-guide`
- Claude Code Subagents: `https://code.claude.com/docs/en/sub-agents`
- Claude Code Skills: `https://code.claude.com/docs/en/skills`

Редакционная позиция: все примеры в документе являются шаблонами. Перед применением к конкретному репозиторию нужно заменить команды, пути, thresholds, sandbox mode и protected paths на реальные значения проекта.

Финальное правило:

> Чем выше автономия агента, тем более механическим, дешевым и независимым должен быть verifier.

