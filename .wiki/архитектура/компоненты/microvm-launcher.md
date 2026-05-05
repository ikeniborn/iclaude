---
wiki_sources:
  - "docs/architecture/overview.yaml"
  - "docs/architecture/diagrams/README.md"
  - "docs/architecture/diagrams/data-flow-microvm-launch.md"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - architecture
  - microvm
  - iclaude
aliases:
  - "Firecracker"
  - "microVM"
  - "sandbox"
  - "изоляция ядра"
---

# microVM Launcher

Менеджер жизненного цикла Firecracker microVM в iclaude (версия v2). Claude Code выполняется **внутри guest VM** по SSH. Host управляет только lifecycle VM и синхронизацией workspace.

## Основные характеристики

**Расположение:** `lib/sandbox/microvm.sh`

### Архитектура v2

Три блочных устройства (virtio-blk):
| Устройство | Монтирование | Режим | Содержимое |
|-----------|-------------|-------|-----------|
| `/dev/vda` | `/` | RW | rootfs (OS + guest-init) |
| `/dev/vdb` | `/mnt/nvm` | RO | nvm.img с Node.js + claude (~1GB) |
| `/dev/vdc` | `/workspace` | RW | per-session workspace (sparse ext4) |

### Субкомпоненты

- `start_microvm` — полный запуск: аллокация слота → TAP → workspace → config → Firecracker → SSH poll
- `stop_microvm` — остановка по EXIT-трапу: kill FC, освободить слот, удалить session_dir + socket
- `configure_guest_environment` — генерация `guest-env.sh` (HTTPS_PROXY, ANTHROPIC_BASE_URL, CLAUDE_CONFIG_DIR)
- `build_microvm_config` — сборка JSON конфигурации Firecracker (drives + network + init=)
- `_alloc_microvm_slot` — выбор свободной IP-пары из пула `MICRO_VM_NET_SUBNET` (до 31 слота)
- `_ensure_slot_tap` — создание TAP-интерфейса или обновление IP при несовпадении
- `_free_microvm_slot` — освобождение слота, удаление lock-файла

### Последовательность запуска (12 шагов)

1. Аллокация сетевого слота (уникальная IP-пара из пула)
2. Создание/обновление TAP-интерфейса для слота
3. Создание sparse workspace.img (ext4, per-session)
4. Генерация guest env файла (chmod 600)
5. Сборка Firecracker JSON config
6. Запуск Firecracker VMM; guest PID 1 монтирует блочные устройства, стартует sshd
7. Polling SSH-готовности (max 30s)
8. Push env файла в `/workspace` через SCP
9. Sync host→guest (tar-over-SSH)
10. SSH exec claude внутри guest
11. Sync guest→host (sync-back после завершения)
12. Cleanup по EXIT-трапу

### Сетевая конфигурация

- Подсеть: `MICRO_VM_NET_SUBNET` (по умолчанию `172.16.0.0/26`)
- Максимум 31 одновременная сессия
- Lock-файлы: `ISOLATED_CONFIG_DIR/microvm-slots/slot-N.lock` (хранит FC PID)
- NAT через iptables (настраивается один раз при `--install-microvm`)

### Режимы синхронизации workspace

| Режим | Поведение |
|-------|-----------|
| `full` | Двусторонняя синхронизация `$PWD ↔ /workspace` |
| `path` | Синхронизация только `MICRO_VM_WORKSPACE_PATH` |
| `isolated` | Guest `/workspace` пустой, синхронизации нет |

### Требования

- `/dev/kvm` — аппаратная виртуализация (KVM)
- `firecracker` бинарник (устанавливается через `--install-microvm`)
- `nvm.img` блочный образ (~1GB, собирается при `--install-microvm`)
- TAP-интерфейс (настраивается один раз с sudo)

### Поддерживаемые ОС

Ubuntu 22.04+, Debian 10+, AltLinux 10+, WSL2 (с nested KVM)

## Связанные концепции

- [[../потоки/поток-запуска-microvm]]
- [[слои-архитектуры]]
