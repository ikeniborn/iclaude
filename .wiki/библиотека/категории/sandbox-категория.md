---
wiki_sources: ["lib/sandbox/microvm.sh", "lib/README.md"]
wiki_updated: 2026-05-05
wiki_status: developing
tags: ["bash", "module", "iclaude"]
aliases: ["lib/sandbox", "sandbox modules", "microVM", "Firecracker"]
---

# Sandbox — категория изоляции microVM (lib/sandbox/)

Категория `lib/sandbox/` реализует изоляцию на уровне ядра через Firecracker microVM. Управляет полным жизненным циклом виртуальной машины: установка, обнаружение зависимостей, запуск, остановка, монтирование рабочего пространства.

## Основные характеристики

| Модуль | Ключевые функции | Назначение |
|--------|-----------------|------------|
| `detect.sh` | `detect_kvm_support()`, `detect_microvm_binary()`, `detect_virtiofsd()`, `detect_linux_distro()` | Проверка KVM, бинарных файлов Firecracker/virtiofsd |
| `install.sh` | `install_microvm()`, `check_microvm_dependencies()` | Установка Firecracker (~1.4 GB) и зависимостей |
| `status.sh` | `check_microvm_status()` | Вывод текущего состояния sandbox |
| `microvm.sh` | `start_microvm()`, `stop_microvm()`, и вспомогательные функции | Жизненный цикл VM: запуск, остановка, SSH-exec |
| `guest-init.sh` | PID 1 init | Init-скрипт, запекаемый в rootfs гостевой ОС |
| `versions.json` | — | Зафиксированные версии Firecracker и virtiofsd |

## Архитектура microVM

```
Host: iclaude.sh → firecracker VMM (KVM) → Guest VM (virtio-blk)

Диски гостя:
  vda = rootfs.ext4   (per-session копия, rw)
  vdb = nvm.img       (NVM-окружение, ro)
  vdc = workspace.img (рабочая директория, rw)

Сетевое подключение:
  TAP-интерфейс tap-iclaude + iptables MASQUERADE NAT
  Host IP:  172.16.0.1 (MICRO_VM_NET_HOST_IP)
  Guest IP: 172.16.0.2 (MICRO_VM_NET_GUEST_IP)

Выполнение команд:
  SSH exec через TAP/NAT; sync рабочего пространства через tar-over-SSH
  Переменные окружения: SCP guest-env.sh → /workspace/.iclaude-guest-env.sh
```

## Переменные конфигурации (из lib/core/init.sh)

| Переменная | Значение по умолчанию | Назначение |
|-----------|----------------------|------------|
| `MICRO_VM_ENABLED` | false | Включить microVM |
| `MICRO_VM_BACKEND` | firecracker | Бэкенд VMM |
| `MICRO_VM_VCPU` | 2 | Количество vCPU |
| `MICRO_VM_MEM_MB` | 1024 | RAM гостя в МБ |
| `MICRO_VM_NET_ENABLED` | true | Включить сеть |
| `MICRO_VM_NET_TAP_IFACE` | tap-iclaude | Имя TAP-интерфейса |
| `MICRO_VM_SNAPSHOT_ENABLED` | false | Включить снапшоты |
| `MICRO_VM_PROXY_PASS` | true | Передавать настройки прокси в гостя |
| `MICRO_VM_MOUNT_WORKSPACE` | true | Монтировать рабочую директорию |

Бинарные файлы хранятся в `$ISOLATED_CONFIG_DIR/bin/` — исключены из git (.gitignore).

## Per-session изоляция

`ICLAUDE_SESSION_ID` (из `lib/core/init.sh`) обеспечивает изоляцию между параллельными сессиями: каждая сессия получает собственные PID-файлы и socket-файлы microVM, исключая коллизии при одновременной работе нескольких iclaude.

## Связанные концепции

- [[категории/обзор-lib]]
- [[категории/core-категория]]
