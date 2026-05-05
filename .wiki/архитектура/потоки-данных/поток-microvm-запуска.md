---
wiki_sources:
  - "docs/architecture/overview.yaml"
  - "docs/architecture/diagrams/data-flow-microvm-launch.md"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - architecture
  - iclaude
aliases:
  - "microVM Launch Flow"
  - "Поток запуска microVM"
  - "Firecracker launch flow"
---

# Поток запуска microVM (Firecracker)

Последовательность операций при запуске Claude Code внутри Firecracker guest (режим `--sandbox-microvm`). Архитектура v2: Claude выполняется в guest по SSH; хост управляет жизненным циклом ВМ.

## Основные характеристики

**ID потока:** `microvm-launch-flow`

**Шаги:**

| Шаг | Компонент | Действие |
|-----|-----------|---------|
| 1 | `cli-main` | Приём флага `--sandbox-microvm` |
| 2 | `sandbox-detect` | `detect_kvm_support()` — проверка `/dev/kvm` |
| 3 | `sandbox-detect` | `detect_microvm()` — проверка Firecracker, vmlinux, rootfs, nvm.img |
| 4 | `microvm-launcher` | `_alloc_microvm_slot()` — поиск свободной IP-пары в пуле; запись `slot-N.lock` |
| 5 | `microvm-launcher` | `_ensure_slot_tap()` — создание/обновление TAP-интерфейса (sudo) |
| 6 | `microvm-launcher` | Создание sparse `workspace.img` (ext4, `MICRO_VM_WORKSPACE_SIZE_MB`) |
| 7 | `microvm-launcher` | `configure_guest_environment()` — запись `guest-env.sh` (credentials, CLAUDE_CONFIG_DIR) |
| 8 | `microvm-launcher` | `build_microvm_config()` — JSON: drives vda/vdb/vdc, TAP, MAC, kernel + init |
| 9 | `firecracker-binary` | Запуск Firecracker VMM; guest PID 1 монтирует устройства, стартует sshd |
| 10 | `microvm-launcher` | Polling SSH на `guest_ip:22` (макс. 30 сек) |
| 11 | `microvm-launcher` | SCP `guest-env.sh` → `/workspace/.iclaude-guest-env.sh` |
| 12 | `cli-main` | tar host→guest sync (исключения: `.nvm-isolated`, `.git`, `.claude_config`) |
| 13 | `cli-main` | SSH exec `claude` внутри guest; `unset CLAUDECODE` |
| 14 | `cli-main` | tar guest→host sync-back (исключения: `lost+found`, `.iclaude-guest-env.sh`) |
| 15 | `microvm-launcher` | `stop_microvm()` на EXIT-trap: kill Firecracker, `_free_microvm_slot`, rm session_dir + socket |

## Сетевая модель

- Подсеть: `MICRO_VM_NET_SUBNET` (по умолчанию `172.16.0.0/26`)
- Слоты: до 31 одновременно; каждый — уникальная IP-пара + TAP-интерфейс
- Lockfile слота: `ISOLATED_CONFIG_DIR/microvm-slots/slot-N.lock` (содержит PID Firecracker)

## Связанные концепции

- [[microvm-launcher]]
- [[sandbox-слой]]
- [[безопасность-microvm]]
