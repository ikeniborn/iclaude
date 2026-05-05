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
  - "Sandbox Layer"
  - "Слой изоляции"
  - "microVM Layer"
---

# Sandbox-слой (Слой изоляции microVM)

Слой архитектуры iclaude, реализующий kernel-level изоляцию через Firecracker VMM. Claude Code запускается внутри гостевой ВМ по SSH; хост управляет жизненным циклом ВМ.

## Основные характеристики

**Архитектура v2 (текущая):**
- Claude Code выполняется **внутри** Firecracker guest
- Хост управляет ВМ через SSH (не через virtiofs)
- Блочные устройства: `vda` (rootfs.ext4), `vdb` (nvm.img, read-only), `vdc` (workspace.img, per-session)
- Синхронизация workspace: tar-over-SSH (host → guest перед запуском, guest → host после)

**Компоненты слоя:**

| Компонент | Файл | Назначение |
|-----------|------|-----------|
| `sandbox-detect` | `lib/sandbox/detect.sh` | Детекция KVM, Firecracker, дистрибутива |
| `sandbox-install` | `lib/sandbox/install.sh` | Установка Firecracker, vmlinux, rootfs, nvm.img |
| `microvm-launcher` | `lib/sandbox/microvm.sh` | Lifecycle ВМ: слоты, TAP, SSH exec, sync, stop |
| `sandbox-status` | `lib/sandbox/status.sh` | Статус: KVM, образы, TAP, активные слоты |

**Сетевая модель:**
- Подсеть: `MICRO_VM_NET_SUBNET` (по умолчанию `172.16.0.0/26`)
- До 31 одновременной сессии; каждая получает уникальную пару IP + TAP-интерфейс
- Lockfile слота: `ISOLATED_CONFIG_DIR/microvm-slots/slot-N.lock` (PID Firecracker)

## Поддерживаемые ОС

| ОС | Версия |
|----|--------|
| Ubuntu | 22.04+ |
| Debian | 10+ |
| ALT Linux | 10+ |
| WSL2 | с включённым nested KVM |

## Требования

- `/dev/kvm` (KVM hardware virtualization)
- Бинарник Firecracker (устанавливается через `--install-microvm`)
- `nvm.img` (~1 ГБ, строится при `--install-microvm`)
- TAP-интерфейс (настраивается один раз через `sudo` при `--install-microvm`)

## Связанные концепции

- [[installation-слой]]
- [[поток-microvm-запуска]]
- [[безопасность-microvm]]
