---
wiki_sources:
  - "lib/sandbox/microvm.sh"
  - "lib/launcher/launch.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "start_microvm"
  - "stop_microvm"
  - "cleanup_orphaned_microvm_sessions"
---

# start_microvm / stop_microvm

`start_microvm()` — запускает Firecracker VM с rootfs, kernel и virtio дисками. `stop_microvm()` — останавливает и освобождает ресурсы.

## Основные характеристики

Модуль: `lib/sandbox/microvm.sh`

**`start_microvm(skip_isolated)`** — последовательность:

1. Проверка `detect_microvm_binary()` — наличие Firecracker бинарника
2. `_alloc_microvm_slot()` — выделение IP/TAP из CIDR подсети
3. `_ensure_slot_tap()` — создание TAP интерфейса
4. Создание per-session rootfs копии (copy-on-write от базового rootfs)
5. Конфигурация VM через Firecracker API socket (`$MICRO_VM_SOCKET`)
6. Запуск Firecracker процесса + `_claim_microvm_slot()` (записывает реальный PID)
7. `configure_guest_environment()` → SCP `.iclaude-guest-env.sh` в `/workspace`
8. Polling до N×0.5s: ожидание SSH готовности

**`stop_microvm()`**:
- Посылает API-команду `SendCtrlAltDel` для graceful shutdown
- SIGTERM → ожидание → SIGKILL
- `_free_microvm_slot()` — освобождение lock
- Удаление per-session FC socket

**`cleanup_orphaned_microvm_sessions()`**: сканирует `microvm-run/` и `microvm-slots/`, удаляет стейл-записи от завершившихся сессий.

Workspace синхронизация выполняется в `launch_claude()` (не в `start_microvm()`) — после установки SSH ControlMaster.

## Связанные концепции

- [[библиотека/функции/alloc-microvm-slot]]
- [[библиотека/категории/sandbox]]
- [[библиотека/паттерны/orphan-cleanup]]
- [[библиотека/паттерны/detect-start-stop-lifecycle]]
