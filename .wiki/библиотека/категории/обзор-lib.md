---
wiki_sources: ["lib/README.md"]
wiki_updated: 2026-05-05
wiki_status: mature
tags: ["bash", "module", "iclaude", "architecture"]
aliases: ["lib", "библиотека модулей", "modular architecture"]
---

# Библиотека модулей lib/

Директория `lib/` содержит модульную реализацию iclaude v4.0. Монолитный скрипт (~8 195 строк) рефакторирован в 57 специализированных bash-модулей с чёткими границами ответственности.

## Основные характеристики

| Параметр | Значение |
|----------|---------|
| Версия архитектуры | 4.0 (100% модульная) |
| Модулей | 57 |
| Функций | 133 |
| Строк кода | ~8 988 |
| Статус legacy | iclaude-legacy.sh удалён |

Точка входа — `iclaude.sh` (~825 строк): загружает модули через 55 source-выражений, затем выполняет инлайн-`main()` (~628 строк).

## Категории модулей

| Категория | Путь | Фаза | Статус | Назначение |
|-----------|------|------|--------|------------|
| core | `lib/core/` | Phase 0 | ✅ | Инфраструктура: инициализация, логирование, валидация, JSON |
| proxy | `lib/proxy/` | Phase 2 | ✅ | Управление прокси: валидация URL, credentials, конфигурация, git |
| nvm | `lib/nvm/` | Phase 3 | ✅ | Управление NVM/Node.js: обнаружение, установка, repair, cleanup |
| lockfile | `lib/lockfile/` | Phase 4 | ✅ | Управление lockfile версий |
| config | `lib/config/` | Phase 5 | ✅ | Конфигурационная изоляция Claude Code |
| oauth | `lib/oauth/` | Phase 5 | ✅ | Проверка и обновление OAuth-токенов |
| router | `lib/router/` | Phase 5 | ✅ | Интеграция Claude Code Router (CCR) |
| lsp | `lib/lsp/` | Phase 5 | ✅ | LSP-серверы (TypeScript, Python) |
| statusline | `lib/statusline/` | Phase 5 | ✅ | Строка статуса (контекст, кэш, ссылки) |
| ohmyposh | `lib/ohmyposh/` | Phase 5 | ✅ | Oh My Posh интеграция |
| sandbox | `lib/sandbox/` | — | ✅ | microVM Firecracker: lifecycle, install, detect |
| update | `lib/update/` | Phase 8 | ✅ | Обновление Claude Code |
| chrome | `lib/chrome/` | — | ✅ | Chrome Integration: обнаружение расширения |
| launcher | `lib/launcher/` | Phase 8 | ✅ | Запуск Claude Code |
| command | `lib/command/` | Phase 14 | ✅ | CLI: usage, parse, dispatch |
| pii-proxy | `lib/pii-proxy/` | — | ✅ | PII Proxy (Presidio NLP): обнаружение, установка, сервер |

## Принципы проектирования

- **Single Responsibility** — каждый модуль отвечает за одну задачу
- **Minimal Coupling** — модули зависят только от `lib/core/`
- **Consistent Error Handling** — `print_error()` + `return 1`
- **Clear API** — все аргументы и возвращаемые значения задокументированы в заголовках функций

## Порядок загрузки

```
Phase 0  → lib/core/       (init, logging, validation, json)
Phase 2  → lib/proxy/      (validate, credentials, configure, git)
Phase 3  → lib/nvm/        (detect, setup, install, claude, repair, cleanup)
Phase 4  → lib/lockfile/   (save, install)
Phase 5  → lib/config/, lib/oauth/, lib/router/, lib/lsp/,
           lib/statusline/, lib/ohmyposh/
Phase 8  → lib/update/, lib/launcher/
Phase 14 → lib/command/    (usage, parse, dispatch)
Phase 15 → lib/core/remaining.sh  (финальные утилиты)
```

## Связанные концепции

- [[категории/core-категория]]
- [[категории/proxy-категория]]
- [[категории/nvm-категория]]
- [[категории/sandbox-категория]]
