---
wiki_sources: ["lib/core/init.sh", "lib/core/logging.sh", "lib/core/validation.sh", "lib/core/json.sh", "lib/core/remaining.sh", "lib/README.md"]
wiki_updated: 2026-05-05
wiki_status: mature
tags: ["bash", "module", "iclaude"]
aliases: ["lib/core", "core modules", "Phase 0"]
---

# Core — инфраструктурная категория (lib/core/)

Категория `lib/core/` — фундамент архитектуры v4.0. Загружается первой (Phase 0) и предоставляет примитивы, используемые всеми остальными модулями: инициализацию окружения, цветной вывод, валидацию зависимостей и работу с JSON.

## Основные характеристики

| Модуль | Ключевые функции | Назначение |
|--------|-----------------|------------|
| `init.sh` | `init_environment()`, `resolve_script_directory()` | Инициализация констант и переменных окружения |
| `logging.sh` | `print_info()`, `print_success()`, `print_warning()`, `print_error()` | Цветной вывод в stderr |
| `validation.sh` | `validate_dependency()`, `validate_file_exists()`, `validate_directory_exists()` | Предусловия перед выполнением |
| `json.sh` | `get_lockfile_field()`, `set_lockfile_field()`, `get_lockfile_object()` | Чтение/запись lockfile через jq |
| `remaining.sh` | `install_nodejs()`, `install_claude_code()`, `get_claude_version()`, `check_update()`, `check_dependencies()`, `install_script()`, `uninstall_script()`, `create_symlink_only()`, `uninstall_symlink_only()` | Финальные утилиты (Phase 15) |

## Экспортируемые переменные (init.sh)

`init_environment()` экспортирует следующие переменные, доступные во всех модулях:

| Переменная | Значение по умолчанию | Назначение |
|-----------|----------------------|------------|
| `SCRIPT_DIR` | Директория iclaude.sh | Корень проекта |
| `CREDENTIALS_FILE` | `$SCRIPT_DIR/.claude_config` | Конфигурация прокси + параметры |
| `ISOLATED_NVM_DIR` | `$SCRIPT_DIR/.nvm-isolated` | Изолированное NVM-окружение |
| `ISOLATED_CONFIG_DIR` | `$ISOLATED_NVM_DIR/.claude-isolated` | Конфигурация Claude Code |
| `ISOLATED_LOCKFILE` | `$SCRIPT_DIR/.nvm-isolated-lockfile.json` | Lockfile версий |
| `TOKEN_REFRESH_THRESHOLD` | 604800 (7 дней) | Порог обновления OAuth-токена |
| `ICLAUDE_SESSION_ID` | Случайный hex (6 байт) | ID сессии для per-session изоляции |
| `PII_PROXY_PORT` | 0 (auto) | Порт PII-proxy (0 = выбрать из диапазона) |
| `PII_PROXY_PORT_MIN/MAX` | 20000 / 40000 | Диапазон портов PII-proxy |
| `CCR_HOST` / `CCR_PORT` | 127.0.0.1 / 3456 | CCR (Claude Code Router) по умолчанию |
| `MICRO_VM_*` | см. init.sh | Конфигурация Firecracker microVM |

Ключевое свойство `ICLAUDE_SESSION_ID`: каждая параллельная сессия iclaude получает уникальный ID, исключая коллизии PID-файлов PII-proxy и microVM между сессиями.

## Принцип устранения дублирования (Phase 0)

До рефакторинга:
- 7+ мест проверяли наличие `jq` через `command -v jq` → заменено одним вызовом `validate_dependency()`
- 15+ мест читали поля lockfile через `jq -r ".field"` → заменено одним вызовом `get_lockfile_field()`

## Связанные концепции

- [[категории/обзор-lib]]
- [[категории/proxy-категория]]
- [[категории/nvm-категория]]
