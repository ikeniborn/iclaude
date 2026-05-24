---
wiki_sources:
  - "[[.nvm-isolated/.claude-isolated/skills/idd/SKILL.md]]"
  - "[[docs/superpowers/specs/2026-05-24-idd-sdd-integration-design.md]]"
  - "[[docs/superpowers/plans/2026-05-24-idd-skill.md]]"
  - "[[CLAUDE.md]]"
wiki_updated: 2026-05-24
wiki_status: developing
wiki_outgoing_links:
  - "[[документация/скиллы/llm-wiki]]"
tags:
  - iclaude
  - documentation
  - skill
  - idd
  - superpowers
aliases:
  - "IDD"
  - "Intent-Driven Design"
  - "idd"
---

# idd (Intent-Driven Design)

Claude Code skill, реализующий паттерн IDD: захват *почему* перед *как* — upstream слой для superpowers SDD workflow. Запускается вручную перед `/brainstorm` на нетривиальных фичах.

## Проблема и обоснование

Superpowers workflow начинается с brainstorming — spec-driven (SDD). Нет слоя для захвата *почему* мы что-то строим до написания спецификации. Intent теряется; спецификации могут быть точно неправильными (правильное КАК, неправильное ЧТО/ЗАЧЕМ).

## Стек слоёв

```
/idd           → intent doc (objective, outcomes, metrics, constraints, stop rules)
/brainstorm    → spec (читает intent doc как контекст в Step 1)
writing-plans  → план реализации
execute        → код
```

## Когда использовать

| Триггер | Действие |
|---------|----------|
| Новый модуль / новый CLI-флаг / API change / архитектурное решение | Запустить IDD |
| Hotfix / опечатка / форматирование | Пропустить |
| Intent doc уже есть в `docs/superpowers/intents/` | Пропустить → сразу /brainstorm |
| "Это маленькое изменение" / "Я уже знаю что строить" | Всё равно запустить IDD |

## Процесс: 5-вопросный интервью

Задаёт пять вопросов **по одному**, ждёт ответа перед следующим:

1. **Objective** — Какую проблему решает, и почему сейчас?
2. **Desired outcomes** — Какие наблюдаемые состояния подтверждают успех (с точки зрения пользователя)?
3. **Health metrics** — Что не должно деградировать? (защита от закона Гудхарта: назвать метрики, которые не приносятся в жертву главной цели)
4. **Constraints** — Архитектурные или технические ограничения?
5. **Stop rules + autonomy** — Когда остановиться и эскалировать? Какие решения можно принимать автономно?

## Артефакт: intent doc

**Путь:** `docs/superpowers/intents/YYYY-MM-DD-<topic>-intent.md`

Разделы (1:1 отображение на Intent Engineering Framework, Huryn 2026):
- `## Objective` — ответ на Q1
- `## Desired Outcomes` — список наблюдаемых состояний
- `## Health Metrics` — что не должно деградировать
- `## Constraints` — архитектурные/технические ограничения
- `## Autonomy Level` — решения без подтверждения пользователя
- `## Stop Rules` — условия эскалации

После создания — автоматический git commit:
```bash
git add docs/superpowers/intents/ && git commit -m "docs(idd): add intent doc for <topic>"
```

## Интеграция с brainstorming

Brainstorming Step 1 сканирует файлы проекта и подхватывает intent doc автоматически — изменений в superpowers не нужно.

## Расположение skill

```
.nvm-isolated/.claude-isolated/skills/idd/
└── SKILL.md          ← единственный файл (≤500 слов, нет sub-rules)
```

Проектный scope: работает в iclaude-сессиях (через `CLAUDE_CONFIG_DIR`).

## Частые ошибки

- **"Это маленький change"** — новый CLI-флаг — это CLI API change. Всё равно запустить IDD.
- **"Я уже знаю что строить"** — intent doc для *пользователя*, не для агента. Делает неявные предположения явными и проверяемыми.
- **"Дайте я задам один уточняющий вопрос"** — уточнение scope ≠ захват intent. Scope отвечает ЧТО; intent захватывает ЗАЧЕМ, outcomes и stop conditions.
- **"Мы уже обсуждали это"** — проверить наличие intent doc. Если нет — создать.

## Конфигурация CLAUDE.md

В `iclaude/CLAUDE.md` добавлен раздел `## IDD → SDD workflow` (до `## Commands`):

```markdown
For non-trivial features (new module, new CLI flag, API change, architectural decision):
1. `/idd <topic>` — creates intent doc in `docs/superpowers/intents/`
2. `/brainstorm` — reads intent doc as context (Step 1 picks it up automatically)
```

## TDD-цикл реализации (из плана)

- **RED** — протестировать без skill: агент перепрыгивает к планированию, не захватывает intent
- **GREEN** — написать минимальный SKILL.md, адресующий конкретные провалы RED
- **REFACTOR** — найти новые рационализации → добавить counters → ретестировать

## Связанные страницы

- [[документация/скиллы/llm-wiki]] — паттерн wiki-базы знаний (llm-wiki)
