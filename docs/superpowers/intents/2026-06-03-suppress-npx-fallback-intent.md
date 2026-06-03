# Intent: Suppress npx fallback on launch

**Date:** 2026-06-03
**Status:** draft

## Objective

При запуске `./iclaude.sh` без параметров появляется интерактивный промпт npm:
```
Need to install the following packages:
@anthropic-ai/claude-code@2.1.161
Ok to proceed? (y)
```

Источник — `lib/launcher/launch.sh:630`: когда детектирование бинарника не находит Claude Code в `.nvm-isolated/`, срабатывает fallback `exec npx @anthropic-ai/claude-code "$@"`. npx обращается к npm registry и запрашивает подтверждение установки.

Это нарушает архитектуру изолированной среды: бинарник должен быть только в `.nvm-isolated/`, обновляться через CI/CD (git pull → `--install-from-lockfile`), а не через локальный npm на машине пользователя.

## Desired Outcomes

- `./iclaude.sh` запускается без любых интерактивных промптов
- При отсутствии бинарника в изолированной среде — понятная ошибка с инструкцией запустить `--repair-isolated`, не тихая установка
- Никаких обращений к npm registry при обычном запуске (без `--update` / `--install-from-lockfile`)
- CI/CD — единственный путь доставки обновлений бинарника

## Health Metrics

- `./iclaude.sh --update` работает без регрессий
- `./iclaude.sh --repair-isolated` работает без регрессий
- `./iclaude.sh --install-from-lockfile` работает без регрессий
- Нормальный запуск при наличии бинарника — без изменений в поведении

## Strategic Context

- Interacts with: `lib/launcher/launch.sh`, `lib/nvm/detect.sh`, `lib/nvm/repair.sh`, `lib/update/isolated.sh`, `lib/update/update.sh`, CI/CD pipeline (lockfile-based delivery)
- Priority trade-off: доверие > скорость (изоляция важнее удобства тихой установки)

## Constraints

### Steering (behavioral guidance)

- Ошибка при отсутствии бинарника должна направлять пользователя к `--repair-isolated`
- Сообщение об ошибке должно объяснять, почему авто-установка не происходит

### Hard (architectural enforcement)

- Запрещено любое обращение к npm registry при обычном запуске `./iclaude.sh`
- npx fallback в `launch.sh:612–637` — удалить, не заменять `--yes`-вариантом
- Обновление бинарника — только через явные флаги (`--update`, `--repair-isolated`, `--install-from-lockfile`)

## Autonomy Zones

- Full autonomy (reversible, low risk): удаление npx fallback из `launch.sh`, аудит других мест с `npx @anthropic-ai/claude-code`, обновление `lat.md/`
- Guarded (log + confidence threshold): изменение текста ошибок (убедиться что инструкция точная)
- Proposal-first (needs approval): изменения в CI/CD pipeline, lockfile workflow
- No autonomy (human only): изменения в `.github/workflows/`

## Stop Rules

- Halt if: npx fallback нужен для какого-то существующего флага/режима — предложить альтернативу перед удалением
- Escalate if: обнаружены другие места где `npx @anthropic-ai/claude-code` вызывается в критичном пути
- Done when: `./iclaude.sh` без параметров при отсутствии бинарника выводит понятную ошибку без npm промптов; при наличии — запускается без изменений
