---
wiki_sources: ["docs/functions/INTEGRATIONS.md"]
wiki_updated: 2026-05-06
wiki_status: developing
tags: [iclaude, integration, oh-my-posh, prompt, terminal, statusline]
aliases: ["oh-my-posh", "ohmyposh", "кастомный промпт"]
---

# Oh-My-Posh

Oh-My-Posh — интеграция для кастомизации терминального промпта. Показывает git-ветку, окружение и контекст прямо в строке приглашения — отдельно от Claude Code Statusline.

## Основные характеристики

| Параметр | Значение |
|----------|----------|
| Модуль | `lib/ohmyposh/` (detect.sh, install.sh + файл темы) |
| Флаг установки | `--install-ohmyposh` |
| Зависимости | `curl`, `jq`, `tar`, доступ к GitHub Releases API |
| AI-ценность (scoring) | 🟢 Низкая (2.8/5) |

## Платформы

Linux (amd64, arm64) и macOS (amd64, arm64) — через бинарник из GitHub Releases.

## Установка

```bash
# Установить oh-my-posh в изолированное окружение
./iclaude.sh --install-ohmyposh
```

Бинарник устанавливается в `.nvm-isolated/`. Тема загружается автоматически.

## Разграничение с Statusline

**Oh-My-Posh** и **Statusline** — две отдельные системы:

| | Oh-My-Posh | Statusline |
|-|------------|-----------|
| Где показывается | Строка приглашения терминала (prompt) | Claude Code UI (внутри сессии) |
| Что показывает | Git-ветка, окружение, PWD | Токены, кэш, стоимость, провайдер |
| Назначение | Контекст окружения разработчика | Мониторинг AI-сессии |

Рекомендация: определить чёткую границу — oh-my-posh для терминала, statusline для Claude Code UI.

## Связанные концепции

- [[функции/возможности/statusline]] — Statusline: метрики токенов, кэша и стоимости в реальном времени
- [[функции/интеграции/обзор-интеграций]] — scoring и сравнение всех интеграций
