---
wiki_sources: ["docs/functions/MICROVM.md"]
wiki_updated: 2026-05-05
wiki_status: developing
tags: [iclaude, features, microvm, sandbox, security]
aliases: ["Firecracker", "sandbox", "KVM isolation", "kernel isolation"]
---

# microVM Sandbox (Firecracker)

microVM Sandbox обеспечивает kernel-level изоляцию Claude Code через Firecracker KVM. Claude Code выполняется внутри гостевой виртуальной машины с собственным Linux-ядром, что защищает хостовую ОС даже при prompt injection с kernel exploit.

## Основные характеристики

### Запуск с microVM

```bash
./iclaude.sh --sandbox-microvm
```

### Архитектура v2

```
Host OS (Linux + KVM)
├── iclaude.sh              ← управляет lifecycle VM (slot alloc, FC spawn, SSH poll)
├── Firecracker VMM         ← KVM hypervisor; три virtio-blk устройства:
│   ├── /dev/vda  (rw)      ← rootfs-SESSION.ext4 (per-session sparse copy)
│   ├── /dev/vdb  (ro)      ← nvm.img (~1GB; Node.js + claude binary; shared)
│   └── /dev/vdc  (rw)      ← workspace-SESSION.img (per-session)
└── Guest VM
    ├── iclaude-guest-init  ← PID 1: монтирует vdb→/mnt/nvm, vdc→/workspace
    └── claude              ← выполняется ВНУТРИ GUEST как пользователь iclaude
```

Пользователь внутри guest: `iclaude` (uid=1000, NOPASSWD sudo). Root SSH отключён.

### Установка

```bash
./iclaude.sh --install-microvm   # ~1.4GB: Firecracker binary + vmlinux + rootfs + nvm.img
```

Требует `sudo` для создания TAP-интерфейсов и сборки nvm.img.

### Требования

| Компонент | Условие |
|-----------|---------|
| `/dev/kvm` | Доступен и читаем |
| Firecracker v1.11+ | Установлен через `--install-microvm` |
| vmlinux kernel image | В `$ISOLATED_CONFIG_DIR/bin/vmlinux` |
| rootfs.ext4 (Ubuntu 22.04) | В `$ISOLATED_CONFIG_DIR/bin/rootfs.ext4` |
| nvm.img (~1GB) | В `$ISOLATED_CONFIG_DIR/bin/nvm.img` |
| TAP-интерфейс (per-slot) | Создаётся автоматически при запуске |
| ed25519 SSH-ключ | В `$ISOLATED_CONFIG_DIR/ssh/microvm` |

### OS matrix

| ОС | Поддержка |
|----|-----------|
| Ubuntu 22.04+ | Полная |
| Debian 10+ | Полная |
| ALT Linux 10+ | Полная |
| WSL2 (Windows) | Требует nested virtualization |
| WSL1 | Нет KVM |
| macOS | Нет KVM |
| CI без nested virt | Нет KVM |

## Угрозы, от которых защищает microVM

Claude Code выполняет AI-directed tool calls — bash-команды, чтение файлов, сетевые запросы по инструкции модели. Prompt injection через репозиторий или веб-страницу может привести к выполнению произвольного кода. microVM изолирует этот код: kernel exploit атакует guest kernel, а не хостовую ОС.

**Уровень защиты:** максимальный — полная kernel isolation через KVM hypervisor.

## Ограничения

- Требует Linux с KVM (не работает в macOS, WSL1, CI без nested virt)
- При `--install-microvm` загружается ~1.4GB
- TAP-интерфейсы создаются с sudo при каждом запуске

## Связанные концепции

- [[функции/возможности/установка]] — команда `--install-microvm`
- [[библиотеки/функции/start-microvm]] — bash-функция управления lifecycle VM
- [[библиотеки/паттерны/slot-based-resource-pools]] — атомарное выделение слотов
