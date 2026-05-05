---
wiki_sources:
  - "lib/chrome/detection.sh"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/chrome"
  - "chrome module"
---

# chrome

Подсистема `lib/chrome/` — обнаружение Chrome для интеграции с расширением Claude-in-Chrome. По умолчанию отключена.

## Основные характеристики

Файловый состав (1 файл):

| Файл | Содержимое |
|------|-----------|
| `detection.sh` | `detect_chrome()` — обнаружение Chrome и расширения |

Требования для активации: платный план Anthropic + Chrome расширение v1.0.36+ + Claude Code CLI v2.0.73+.

Проблема без расширения: `CHROME_DESKTOP` из VS Code (`code.desktop`) перехватывается Claude Code и открывает неправильный браузер. `launch_claude()` явно делает `unset CHROME_DESKTOP` перед запуском.

Флаги: `--chrome` (включить), `--no-chrome` (отключить явно).

Ограничение в microVM: `--chrome` не пробрасывается в guest VM — расширение работает только на хосте.

## Связанные концепции

- [[библиотека/категории/launcher]]
