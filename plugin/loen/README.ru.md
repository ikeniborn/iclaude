# loen — Loop Engineering

Выполняет одну ограниченную инженерную задачу как **стадийную durable-topic петлю**.
Состояние живёт в семи нумерованных артефактах под `docs/loen/<topic>/` — не в чате. После
одного человеческого гейта (одобрение плана) оркестратор `loop-run` автономно гоняет
`Act → Check → Reflect` до записанного результата, который судит независимый верификатор, а
контракт держат шесть детерминированных хуков.

Версия 1.0.0 · [English version](README.md) · Полное руководство: `docs/functions/LOEN.md` ·
Архитектура: `docs/architecture.md`

## Зачем loen

Неконтролируемый прогон агента дрейфует: правит файлы, которые трогать нельзя, проверяет сам
себя, объявляет успех без доказательств и забывает прогресс при компакте контекста. loen
закрывает каждый разрыв по построению:

- **Durable-состояние, не чат.** Каждая единица работы — *топик* под `docs/loen/<topic>/`,
  проведённый через семь нумерованных стадийных файлов (`1_goal … 7_result`). *Нет файла =
  нет состояния* — резюм читает диск, а не разговор.
- **Контракт вместо чата.** Задача привязана к `loop.yaml`, который человек одобряет до любой
  правки: цель, редактируемая/защищённая область, quality gates, бюджет, условия остановки и
  передачи, привязки ролей, политика инструментов и разрешений.
- **Автономность после одного гейта.** `loop-start` держит единственный гейт одобрения; затем
  `loop-run` сам гоняет `Act → Check → Reflect` до `7_result.md` (Done) или `handoff.md`.
- **Worker ≠ судья.** Основная сессия (worker) — единственный писатель; независимый субагент
  `verifier` — другая модель, изолированный контекст, ограниченная capsule — одобряет или
  отклоняет каждую итерацию. Опционально он работает внутри Firecracker microVM.
- **Детерминированные ограничители, градуированные.** Шесть хуков читают контракт и держат
  область, инструменты, роли, shell/сеть, порядок стадий и финальные доказательства —
  градация через `LOEN_MODE` (`off`/`advisory`/`enforce`/`strict`). Петля всегда завершается
  человеческим PR-review — никакого авто-merge.

Без `loop.yaml` плагин инертен.

## Что решает

| Нужно… | Вызов | Получаете |
|---|---|---|
| Безопасно доставить одно ограниченное изменение | `/loen:loop-delivery <task>` | Минимальный проверенный diff, доказательный `7_result.md` |
| Починить падающий тест / CI / регресс | `/loen:loop-repair <failure>` | Воспроизведение → минимальный фикс + регресс-тест |
| Улучшить одну числовую метрику | `/loen:loop-autoresearch <metric>` | Метрико-подтверждённые изменения + лог экспериментов |
| Отревьюить diff / ветку / PR | `/loen:loop-review <diff/PR>` | Находки + вердикт как durable-артефакты |
| Прогнать одобренную петлю автономно | `/loen:loop-run` | `Act → Check → Reflect` до `7_result.md` / `handoff.md` |
| Узнать состояние топика | `/loen:loop-status` | Стадия, последние доказательства, следующее действие (read-only) |
| Вручную проверить одну стадию | `loen:audit plan\|act\|check\|result` | Вердикт `OK` / `needs_work` + регенерация `audit.html` |
| Обозреть все топики сразу | `/loen:governance [--triage]` | Дашборд `docs/loen/governance.html`; `--triage` предлагает действия |

## Как это работает

1. **Start.** Конфигуратор (`loop-delivery`/`repair`/`autoresearch`/`review`) задаёт `mode` и
   вызывает `loop-start`, который валидирует slug топика, скаффолдит `docs/loen/<topic>/`,
   пишет `1_goal.md` + `2_context.md`, делегирует `3_plan.md` в `loop-plan` и **держит
   единственный гейт одобрения**. После одобрения взводит контракт (`run.plan_approved: true`,
   `run.plan_hash`).
2. **Run (автономно).** `loop-run` делает preflight одобренного контракта
   (`validate_run_contract`), затем крутит машину состояний:
   - **act** (`loop-act`) — worker делает минимальный diff в пределах `mutable_scope` →
     `4_act.md`;
   - **check** (`loop-check`) — прогон `quality_gates` → `5_check.md`; субагент `verifier`
     судит с ограниченной capsule → `evidence/verifier-verdict.md`;
   - **reflect** (`loop-reflect`) — гейты `PASS` + вердикт `APPROVE` → `7_result.md` (Done);
     `REJECT` в пределах бюджета → назад в act; бюджет/handoff → `handoff.md`.
   Каждый переход обновляет `loop.yaml` `run.state`/`run.current_pass`, поэтому петля
   резюмируется после компакта.
3. **Terminate.** `7_result.md` (Done) или `handoff.md` (решение человека). Stop-хук блокирует
   заявление «готово» без `5_check` + `7_result` + вердикта верификатора + доказательств.

## Установка

Плагин поставляется внутри репозитория iclaude (`plugin/loen/`), зарегистрирован в
marketplace `iclaude` (источник `directory`). Включите на уровне пользователя:

```bash
claude plugin marketplace add /path/to/iclaude
claude plugin install loen@iclaude
```

Требования: Claude Code с поддержкой плагинов, `python3` (все скрипты/хуки только на stdlib),
`git`, `bash`. Опциональная microVM-изоляция дополнительно требует установки iclaude
Firecracker (см. `docs/functions/MICROVM.md`).

## Конфигурация

`LOEN_MODE` градуирует enforcement хуков: `off` (инертно) · `advisory` (только печать) ·
`enforce` (блок, по умолчанию) · `strict` (+ требование различия worker/verifier).
`LOEN_ARTIFACT_ROOT` переопределяет корень артефактов (по умолчанию `docs/loen`).

## Артефакты

Всё состояние живёт под `docs/loen/<topic>/`:

| Путь | Содержимое |
|---|---|
| `1_goal.md … 7_result.md` | семь нумерованных стадийных артефактов |
| `loop.yaml` | машиночитаемый контракт |
| `handoff.md` | нетерминальный выход — нужно решение человека |
| `audit.html` | регенерируемый отчёт |
| `attempts.jsonl` | append-only лог итераций |
| `evidence/` | вердикт верификатора, логи гейтов, метрики |
| `../current` | указатель на слаг активного топика |
| `../governance.html` | кросс-топик дашборд |

Шаблоны поставляются как ассеты плагина (`assets/templates/`) — ничего не скаффолдится в
проект, пока петля не запущена.

## Компоненты

**Skills (13):** pipeline — `loop-start`, `loop-run`, `loop-plan`, `loop-act`, `loop-check`,
`loop-reflect`, `loop-status`; конфигураторы — `loop-delivery`, `loop-repair`,
`loop-autoresearch`, `loop-review`; cross-cutting — `governance`, `audit`.

**Хуки + общая библиотека:** `loen_common` / `loen_artifacts` / `loen_capsules` стоят за
шестью хуками — `loop-gate`, `scope-guard`, `tool-guard`, `permission-guard` (PreToolUse),
`evidence-gate` (Stop), `audit-writer` (PostToolUse). Детерминированные shell-нетто
`check_layout.sh` и `guard_protected.sh` перепроверяют раскладку и защищённую область для
артефактов, записанных через Bash.

**Агенты (5, read-only; worker — основная сессия):**

| Агент | Модель | Роль |
|---|---|---|
| `planner` | fable | декомпозирует задачу, заполняет `loop.yaml` + план шагов |
| `explorer` | haiku | дешёвый read-only сбор доказательств |
| `verifier` | opus | строгий независимый судья; может гонять гейты; по умолчанию REJECT без доказательств |
| `reviewer` | opus | ревьюит diff/PR на reflect; фиксирует находки + вердикт |
| `researcher` | fable | research-режим: гоняет фиксированный eval, пишет метрики |

Каждый субагент получает ограниченную **capsule** (текст из durable-артефактов, не чат).

**Скрипты:** `loen_stats.py` (агрегатор governance), `log_experiment.py` (лог экспериментов),
`verify_microvm.sh` (опциональный изолированный верификатор), `check_layout.sh`,
`guard_protected.sh`.

## Подробнее

- `docs/architecture.md` — операционная модель, лестница изоляции, карта хуков.
- `docs/functions/LOEN.md` — полное руководство пользователя.
- `docs/functions/MICROVM.md` — установка Firecracker для microVM-изоляции.
