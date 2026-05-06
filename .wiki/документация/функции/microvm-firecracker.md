---
wiki_sources:
  - "docs/functions/MICROVM.md"
  - "docs/functions/USE_CASES.md"
  - "docs/functions/CONFIGURATION.md"
wiki_updated: 2026-05-06
wiki_status: developing
wiki_outgoing_links:
  - "[[pii-прокси|PII-прокси]]"
  - "[[маршрутизатор-ccr|Claude Code Router]]"
wiki_external_links: []
tags:
  - iclaude
  - documentation
aliases:
  - "microVM"
  - "Firecracker"
  - "sandbox-microvm"
  - "kernel isolation"
  - "KVM"
---

# microVM Sandbox (Firecracker)

Изоляция Claude Code на уровне ядра через Firecracker KVM hypervisor. Claude Code выполняется внутри отдельной виртуальной машины с собственным Linux-ядром — максимальный уровень защиты от prompt injection и атак через репозиторий.

## Основные характеристики

### Архитектура v2 (три virtio-blk устройства)

```
Host OS (Linux + KVM)
└── Firecracker VMM
    ├── /dev/vda (rw) — rootfs-SESSION.ext4 (per-session sparse copy; Ubuntu 22.04)
    ├── /dev/vdb (ro) — nvm.img (~1GB; Node.js + claude binary; shared)
    └── /dev/vdc (rw) — workspace-SESSION.img (per-session, sparse ext4)
```

Процесс Claude Code запускается внутри guest как пользователь `iclaude` (uid=1000) через SSH exec от хоста.

### Требования

- `/dev/kvm` доступен и читаем (нет в WSL1, CI без nested virt, macOS)
- Firecracker v1.11+
- ~1.4GB для установки (vmlinux + rootfs + nvm.img)
- `sudo` для создания TAP-интерфейсов (при каждом запуске)

### Workspace режимы

| Режим | Host→Guest | Guest→Host (sync-back) |
|-------|:----------:|:----------------------:|
| `full` (по умолчанию) | Да | Да |
| `isolated` | Да | Нет |

В режиме `isolated` файлы проекта копируются в VM, но изменения не возвращаются на хост.

### Синхронизация (SSH ControlMaster + rsync)

С rootfs v7: delta-sync через SSH ControlMaster (overhead ~5ms вместо 150–320ms на handshake). Минимальный интервал sync: 2 сек. Без rsync (v6 rootfs): tar-over-SSH, минимум 20–30 сек.

### Снэпшоты (опционально)

При `MICRO_VM_SNAPSHOT_ENABLED=true` при завершении предлагается сохранить снэпшот (память + диски). При следующем запуске можно восстановить из снэпшота вместо холодной загрузки. Размер снэпшота: ~2.5 GB (sparse).

Снэпшоты привязаны к версии Firecracker и несовместимы после `--install-microvm`.

## Применение в контексте iclaude

Совместимые комбинации:

```bash
./iclaude.sh --sandbox-microvm               # базовый запуск
./iclaude.sh --sandbox-microvm --pii-proxy   # + PII маскирование
./iclaude.sh --sandbox-microvm --router      # + CCR маршрутизатор
./iclaude.sh --sandbox-microvm --pii-proxy --router  # комбинация
```

`--sandbox-microvm --system` заблокировано: microVM требует изолированную среду.

## Ключевые конфигурационные переменные

| Переменная | По умолчанию | Описание |
|-----------|-------------|---------|
| `MICRO_VM_ENABLED` | `false` | Автоматически использовать microVM |
| `MICRO_VM_MEM_MB` | `2048` | RAM guest VM |
| `MICRO_VM_VCPU` | `2` | Количество vCPU |
| `MICRO_VM_WORKSPACE_MODE` | `full` | Режим синхронизации |
| `MICRO_VM_NET_ENABLED` | `true` | TAP-сеть (NAT через хост) |
| `MICRO_VM_SNAPSHOT_ENABLED` | `false` | Именованные снэпшоты |

## Безопасность

Граница безопасности — KVM hypervisor. Capabilities внутри guest не выходят за пределы VM. При `MICRO_VM_NET_ENABLED=true` гость получает выход в интернет через NAT (необходим для Anthropic API).
