---
wiki_sources:
  - "lib/sandbox/detect.sh"
  - "lib/sandbox/microvm.sh"
  - "lib/sandbox/install.sh"
  - "lib/sandbox/status.sh"
  - "lib/sandbox/guest-init.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/sandbox"
  - "sandbox module"
  - "microVM module"
---

# sandbox

Подсистема `lib/sandbox/` — управление жизненным циклом Firecracker microVM. Обеспечивает kernel-level изоляцию: claude работает внутри KVM-виртуальной машины, а workspace синхронизируется через SSH/rsync.

## Основные характеристики

Файловый состав (5 модулей):

| Файл | Содержимое |
|------|-----------|
| `detect.sh` | `detect_microvm()`, `detect_kvm_support()`, `detect_linux_distro()`, `check_distro_microvm_support()`, `detect_microvm_binary()` |
| `microvm.sh` | `start_microvm()`, `stop_microvm()`, `cleanup_orphaned_microvm_sessions()`, `configure_guest_environment()`, `_alloc_microvm_slot()`, `_free_microvm_slot()`, `_ensure_slot_tap()`, `_claim_microvm_slot()` |
| `install.sh` | `install_microvm()` — загрузка Firecracker (~1.4GB), rootfs, kernel |
| `status.sh` | `check_microvm_status()` |
| `guest-init.sh` | Инициализация guest окружения |

Поддерживаемые ОС: Ubuntu 22.04+, Debian 10+, ALT Linux 10+, WSL2 (при включённой nested virt). macOS не поддерживается (KVM — Linux only).

Slot-based архитектура для параллельных сессий: из CIDR-подсети `MICRO_VM_NET_SUBNET` (дефолт `172.16.0.0/26`) выделяются пары IP-адресов. Slot N → host=base+2N+1, guest=base+2N+2, TAP=`tap-iclaude-{N+1}`. Захват слота — атомарный через `noclobber`.

Синхронизация workspace: `rsync` (v7+ rootfs) или `tar-over-SSH` (fallback). Режимы: `full` (bidirectional) или `isolated` (one-way host→guest). Периодическая фоновая синхронизация через `MICRO_VM_SYNC_INTERVAL`.

SSH ControlMaster: снижает overhead с 200ms до 5ms на операцию. `ControlPersist=60` закрывает осиротевшие соединения через 60 секунд.

## Связанные концепции

- [[библиотека/паттерны/slot-based-resource-pools]]
- [[библиотека/паттерны/orphan-cleanup]]
- [[библиотека/паттерны/detect-start-stop-lifecycle]]
- [[библиотека/функции/start-microvm]]
- [[библиотека/функции/alloc-microvm-slot]]
- [[библиотека/категории/launcher]]
