---
wiki_sources:
  - "docs/architecture/overview.yaml"
  - "docs/architecture/diagrams/data-flow-microvm-launch.md"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - architecture
  - microvm
  - iclaude
aliases:
  - "microvm launch flow"
  - "--sandbox-microvm"
  - "Firecracker launch"
---

# Поток запуска через microVM

Последовательность операций при запуске Claude Code внутри Firecracker guest VM через SSH с virtio-blk блочными устройствами (архитектура v2).

## Основные характеристики

**Команда:** `./iclaude.sh --sandbox-microvm`
**Диаграмма:** `docs/architecture/diagrams/data-flow-microvm-launch.md`

### Этапы запуска (12 шагов)

1. Получение флага `--sandbox-microvm` (`USE_MICRO_VM_FLAG=true`)
2. `detect_microvm` — проверка KVM и бинарников; при ошибке → fallback на стандартный запуск
3. (Опционально) Запуск CCR сервера на host, если `use_router=true`
4. (Опционально) Запуск PII proxy сервера (`127.0.0.1:PORT`), если `use_pii_proxy=true`
5. `_alloc_microvm_slot` — выбор свободной IP-пары из `MICRO_VM_NET_SUBNET`; запись `slot-N.lock`
6. `_ensure_slot_tap` — создание TAP если нет, обновление IP если мисматч
7. Создание sparse `workspace.img` (ext4, per-session, `MICRO_VM_WORKSPACE_SIZE_MB`)
8. `configure_guest_environment` — запись `guest-env.sh` в `session_dir` (chmod 600)
9. `build_microvm_config` — JSON с drives (vda/vdb/vdc), network (TAP, MAC), kernel + init
10. Запуск Firecracker VMM; guest PID 1 монтирует блочные устройства, стартует sshd
11. Polling SSH-готовности на `guest_ip:22` (max 30s)
12. SCP `guest-env.sh` → `/workspace/.iclaude-guest-env.sh`
13. tar host→guest sync (исключает: `.nvm-isolated`, `.git`, `.claude_config`, `.iclaude-guest-env.sh`)
14. SSH exec `claude` внутри guest; `unset CLAUDECODE`
15. tar guest→host sync-back (исключает: `lost+found`, `.iclaude-guest-env.sh`)
16. `stop_microvm()` по EXIT-трапу: kill FC, `_free_microvm_slot`, удаление `session_dir` + socket

### Обработка ошибок при запуске

- KVM недоступен или бинарники отсутствуют → предупреждение + стандартный запуск
- CCR не стартовал → `print_error + exit 1`
- PII proxy не стартовал → остановить CCR → `exit 1`

## Связанные концепции

- [[../компоненты/microvm-launcher]]
