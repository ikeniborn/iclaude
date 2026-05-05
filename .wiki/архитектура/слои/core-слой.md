---
wiki_sources:
  - "docs/architecture/overview.yaml"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - architecture
  - iclaude
aliases:
  - "Core Layer"
  - "Core Services"
---

# Core-слой (Core Services)

Слой бизнес-логики iclaude, содержащий основные функциональные модули: управление прокси, окружением, версиями, конфигурацией, OAuth-токенами и Router.

## Основные характеристики

**Ответственности слоя:**
- Валидация и конфигурация proxy (HTTP/HTTPS)
- Управление изолированным окружением (`.nvm-isolated/`)
- Версионирование через lockfile
- OAuth-токены: проверка срока действия и автообновление
- Интеграция с Claude Code Router (CCR)

**Модули Core-слоя:**

| Модуль | Строки в iclaude.sh | Назначение |
|--------|---------------------|-----------|
| `proxy-management` | 60–2015 | Прокси: валидация, парсинг, тестирование |
| `isolated-environment` | 422–1121 | NVM + Node.js + Claude в `.nvm-isolated/` |
| `version-management` | 732–910 | Lockfile: сохранение и восстановление версий |
| `config-management` | 1242–1586 | Изоляция конфигурационной директории |
| `oauth-token-management` | 3021–3183 | Автообновление OAuth-токена |
| `router-management` | 333–1430 | Интеграция с Claude Code Router |

## Связанные концепции

- [[cli-слой]]
- [[installation-слой]]
- [[proxy-management]]
- [[oauth-token-management]]
- [[поток-oauth-обновления]]
