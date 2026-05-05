---
wiki_sources: ["lib/core/init.sh"]
wiki_updated: 2026-05-05
wiki_status: mature
tags: ["bash", "module", "iclaude"]
aliases: ["lib/core/init.sh", "init_environment", "resolve_script_directory"]
---

# lib/core/init.sh — модуль инициализации окружения

Первый загружаемый модуль iclaude. Определяет все константы и экспортирует переменные окружения, используемые остальными модулями.

## Основные характеристики

Содержит две функции и набор цветовых констант. Не имеет зависимостей — подключается в Phase 0 до всех остальных модулей.

## Функции

### resolve_script_directory()

Определяет абсолютный путь к директории скрипта с учётом симлинков. Следует цепочке `readlink` до получения физического пути. Использует `BASH_SOURCE[1]` (путь вызывающего, не текущего файла).

### init_environment()

Инициализирует все переменные окружения iclaude. Вызывается один раз при старте `iclaude.sh`.

Включает автоматическую миграцию: если существует старый файл `.claude_proxy_credentials` и новый `.claude_config` отсутствует — переименовывает автоматически.

Группы экспортируемых переменных:
- Пути (SCRIPT_DIR, CREDENTIALS_FILE, ISOLATED_NVM_DIR, ISOLATED_CONFIG_DIR, ISOLATED_LOCKFILE)
- OAuth (TOKEN_REFRESH_THRESHOLD = 604800 с = 7 дней)
- Per-session ID (ICLAUDE_SESSION_ID — случайный 12-символьный hex)
- PII-proxy (PII_PROXY_PORT, PII_PROXY_PORT_MIN/MAX, PII_PROXY_VENV, PII_PROXY_PID_DIR, PII_PROXY_PID_FILE, PII_PROXY_SERVER_SCRIPT)
- CCR (CCR_PID, CCR_SESSION_OWNED, CCR_HOST=127.0.0.1, CCR_PORT=3456)
- microVM (MICRO_VM_ENABLED, MICRO_VM_BACKEND, MICRO_VM_VCPU, MICRO_VM_MEM_MB, MICRO_VM_NET_*, MICRO_VM_SNAPSHOT_*, и др.)

## Применение в контексте iclaude

`PII_PROXY_PID_FILE` строится как `$PII_PROXY_PID_DIR/$ICLAUDE_SESSION_ID.pid` — обеспечивает изоляцию PID-файлов между параллельными сессиями iclaude.

`PII_PROXY_PORT=0` означает автовыбор порта из диапазона `PII_PROXY_PORT_MIN`..`PII_PROXY_PORT_MAX` при старте сервера. Можно зафиксировать конкретный порт через `.claude_config`.

## Связанные концепции

- [[категории/core-категория]]
- [[модули/core-logging]]
- [[категории/обзор-lib]]
