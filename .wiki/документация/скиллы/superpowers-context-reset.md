---
wiki_sources:
  - "https://github.com/obra/superpowers/issues/1503"
  - "https://github.com/obra/superpowers/issues/1490"
  - "https://github.com/obra/superpowers/issues/931"
  - "https://github.com/obra/superpowers/issues/478"
wiki_updated: 2026-05-08
wiki_status: stub
wiki_outgoing_links:
  - "[[документация/скиллы/llm-wiki]]"
tags:
  - iclaude
  - documentation
  - skill
  - superpowers
  - workflow
aliases:
  - "Auto context-reset between workflow phases"
  - "superpowers #1503"
  - "phase-transition handoff"
---

# Auto context-reset между фазами workflow superpowers (#1503)

Feature-предложение в [obra/superpowers#1503](https://github.com/obra/superpowers/issues/1503) (создано 2026-05-08, статус: open) — автоматический сброс контекста Claude Code на границах фаз workflow superpowers (`design → spec → plan → execute`). Цель — устранить накопление stale-обсуждений (брейнсторм, отвергнутые альтернативы, итерации спеки) к моменту фазы исполнения, где модель должна работать только с финальным артефактом.

## Основные характеристики

- **Проблема:** к моменту execute контекст содержит брейнсторм-диалог, ревизии спеки, итерации плана, логи диспатча сабагентов — модель отвлекается на устаревшие промежуточные состояния, качество падает, расход токенов растёт
- **Текущий обходной путь (manual):** выйти из сессии → запустить новую → вручную вызвать следующий скилл с указанием на сохранённый артефакт. Хрупко, легко пропустить, теряется автозагрузка скилла
- **Предлагаемый механизм handoff на каждой границе фазы:**
  1. **Persist** артефакта (design doc / spec / plan) в канонический путь `docs/superpowers/`
  2. **Reset** контекста (`/clear` или эквивалент compact)
  3. **Reload** только: финального артефакта предыдущей фазы + тела скилла следующей фазы + минимального preserved state (активная ветка, worktree, путь к plan-файлу)
  4. **Resume** в чистом контексте с авто-вызовом скилла следующей фазы

## Три перехода

| Переход | Загружаемый артефакт | Загружаемый скилл |
|---------|----------------------|-------------------|
| design → spec | design doc | `writing-plans` (или отдельный spec-writing skill) |
| spec → plan | spec | `writing-plans` |
| plan → execute | plan | `executing-plans` или `subagent-driven-development` |

## Связь с другими issues

- **#1490** (open) — полная автоматизация `brainstorm → plan → implement` с переключением моделей и compact между шагами. Пересекается, но шире: end-to-end оркестрация. #1503 — узкая примитива (context hygiene), применимая даже когда пользователь хочет оставаться в driver's seat
- **#931** (open) — `/create_handoff` + `/resume_plan` для cross-session continuation при переполнении контекста. Другой триггер (mid-execution overflow vs. phase boundary), комплементарен
- **#478** (closed) — clear context after plan, before execute. Та же идея, но только один из трёх переходов; #1503 обобщает на все границы фаз и отвязывает от full-automation framing #1490

## Открытые вопросы дизайна

- **Механизм:** хук на завершение скилла? Новый lifecycle event (cf. #1442)? Slash-команда `/handoff`? Скилл `phase-transition`, оборачивающий `/clear` + reload?
- **Opt-in vs default:** per-skill flag, plugin-level setting или per-invocation override?
- **State preservation:** memory/preferences уже персистят между сессиями. Что ещё требует явного carry-over (active worktree, plan file path, model selection)?
- **Compact vs clear:** полный `/clear` теряет memory-инжекции; compact сохраняет, но может оставить stale phase content. Вероятно `/clear` + повторный `SessionStart` — самый чистый вариант
- **Failure mode:** если next-phase skill нельзя авто-вызвать после сброса (ограничение harness'а), fallback — печать exact resume-команды для пользователя

## Out of scope (#1503)

- Переключение моделей между фазами (покрыто #1490)
- Mid-phase context overflow handoff (покрыто #931)
- Worktree management (покрыто `using-git-worktrees`)

## Релевантность для iclaude

В iclaude установлены скиллы пакета superpowers (`superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:executing-plans`, `superpowers:subagent-driven-development` и др.). Реализация #1503 в апстриме напрямую повлияет на workflow, используемый в `.nvm-isolated/.claude-isolated/skills/superpowers/`.

## Связанные концепции

- [[документация/скиллы/llm-wiki]]
