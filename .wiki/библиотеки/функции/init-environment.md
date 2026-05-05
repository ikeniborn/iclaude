---
wiki_sources:
  - "lib/core/init.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "init_environment"
---

# init_environment

`init_environment()` — центральная функция инициализации глобального окружения iclaude. Определяет все пути, константы и конфигурационные переменные, экспортирует их для subshells. Вызывается один раз при запуске `iclaude.sh`.

## Основные характеристики

Модуль: `lib/core/init.sh`

Группы переменных, инициализируемых функцией:

**Пути:**
- `SCRIPT_DIR` — директория `iclaude.sh` (через `resolve_script_directory()`)
- `CREDENTIALS_FILE` — `.claude_config` (с миграцией с `.claude_proxy_credentials`)
- `ISOLATED_NVM_DIR` — `.nvm-isolated/`
- `ISOLATED_CONFIG_DIR` — `.nvm-isolated/.claude-isolated/`
- `ISOLATED_LOCKFILE`, `LOCKFILE_HASH_FILE`

**Per-session:**
- `ICLAUDE_SESSION_ID` — 6 байт hex, генерируется из `/dev/urandom`; наследуется если уже установлен (subshells)

**PII Proxy:**
- `PII_PROXY_PORT` (0=авто), `PII_PROXY_PORT_MIN/MAX` (20000–40000)
- `PII_PROXY_VENV`, `PII_PROXY_LOG_DIR`, `PII_PROXY_PID_DIR`
- `PII_PROXY_PID_FILE` — `$PII_PROXY_PID_DIR/$ICLAUDE_SESSION_ID.pid`

**CCR Router:**
- `CCR_PID`, `CCR_SESSION_OWNED`, `CCR_HOST` (127.0.0.1), `CCR_PORT` (3456)

**microVM (Firecracker):**
- `MICRO_VM_VCPU` (2), `MICRO_VM_MEM_MB` (1024)
- `MICRO_VM_NET_*` — сетевые параметры TAP+IP
- `MICRO_VM_SNAPSHOT_*`, `MICRO_VM_ROOTFS_PATH`, `MICRO_VM_KERNEL_PATH`
- `MICRO_VM_SESSION_OWNED`, `VIRTIOFSD_PID_NVM`, `VIRTIOFSD_PID_WORKSPACE`

Все переменные экспортируются для доступности в дочерних процессах.

## Связанные концепции

- [[библиотека/категории/core]]
- [[библиотека/паттерны/per-session-isolation]]
