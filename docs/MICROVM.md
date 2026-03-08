# microVM Sandbox (Firecracker v2)

Операционное руководство по запуску Claude Code с kernel isolation через Firecracker KVM.

---

## Что такое microVM и зачем

Claude Code выполняет **AI-directed tool calls** — bash-команды, чтение файлов, сетевые
запросы — по инструкции модели. Prompt injection через репозиторий или веб-страницу
может привести к выполнению произвольного кода. microVM изолирует этот код в отдельной
виртуальной машине с собственным Linux ядром: даже если injected bash использует kernel
exploit — он атакует **guest kernel**, а не хостовую ОС.

**Уровень защиты:** максимальный — полная kernel isolation через KVM hypervisor.

Полный threat model: [docs/SANDBOX_ANALYSIS.md](SANDBOX_ANALYSIS.md)

---

## Архитектура v2

```
Host OS (Linux + KVM)
├── iclaude.sh              ← управляет lifecycle VM (slot alloc, FC spawn, SSH poll)
├── Firecracker VMM         ← KVM hypervisor; три virtio-blk устройства:
│   ├── /dev/vda  (rw)      ← rootfs-SESSION.ext4 (per-session sparse copy; Ubuntu 22.04; PID 1: iclaude-guest-init)
│   ├── /dev/vdb  (ro)      ← nvm.img (~1GB; Node.js + claude binary; shared across sessions)
│   └── /dev/vdc  (rw)      ← workspace-SESSION.img (per-session, sparse ext4)
└── Guest VM
    ├── iclaude-guest-init  ← PID 1: монтирует vdb→/mnt/nvm, vdc→/workspace, создаёт user iclaude, стартует sshd
    └── claude              ← выполняется ВНУТРИ GUEST как пользователь iclaude (SSH exec от host)
```

**Пользователь внутри guest:** `iclaude` (uid=1000, NOPASSWD sudo). Root SSH отключён (`PermitRootLogin no`).
Запечён в rootfs при `--install-microvm`; создаётся через `useradd` при первом старте guest-init.

Подробная диаграмма запуска: [docs/architecture/diagrams/data-flow-microvm-launch.md](architecture/diagrams/data-flow-microvm-launch.md)

---

## Требования

| Компонент | Проверка | Заметки |
|-----------|---------|---------|
| `/dev/kvm` доступен и читаем | `detect_kvm_support()` | Требуется KVM (нет в CI без nested virt, WSL1) |
| Firecracker binary v1.11+ | `detect_microvm_binary()` | Устанавливается через `--install-microvm` |
| vmlinux kernel image | `$ISOLATED_CONFIG_DIR/bin/vmlinux` | Загружается при установке |
| rootfs.ext4 (Ubuntu 22.04) | `$ISOLATED_CONFIG_DIR/bin/rootfs.ext4` | Загружается при установке |
| nvm.img (NVM snapshot, ~1GB) | `$ISOLATED_CONFIG_DIR/bin/nvm.img` | Строится при `--install-microvm` |
| tap-iclaude TAP-интерфейс | `_ensure_slot_tap()` — авто-создание | Требуется `ip` (iproute2) |
| ed25519 SSH-ключ | `$ISOLATED_CONFIG_DIR/ssh/microvm` | Создаётся при установке, запекается в rootfs |

**OS matrix:**

| ОС | Статус |
|----|--------|
| Ubuntu 22.04+ | ✅ Полная поддержка |
| Debian 10+ | ✅ Полная поддержка |
| ALT Linux 10+ | ✅ Полная поддержка |
| WSL2 (Windows) | ✅ Требует nested virtualization |
| WSL1 | ❌ Нет KVM |
| macOS | ❌ Нет KVM (нужен cloud-hypervisor) |
| CI без nested virt | ❌ Нет KVM |

---

## Установка

```bash
# Установить Firecracker v1.11 + vmlinux + rootfs + nvm.img (~1.4GB, один раз)
./iclaude.sh --install-microvm

# Проверить готовность всех компонентов
./iclaude.sh --check-microvm
```

`--install-microvm` выполняет:
1. Загрузка Firecracker v1.11 и vmlinux (GitHub releases)
2. Загрузка базового rootfs Ubuntu 22.04
3. Инжект SSH-ключа в rootfs через `debugfs` (static authorized_keys)
4. Сборка `nvm.img` (1024MB sparse ext4, монтируется как /dev/vdb в guest)
5. Создание TAP-интерфейса `tap-iclaude`

---

## Запуск

```bash
# Разово с microVM изоляцией
./iclaude.sh --sandbox-microvm

# С PII-маскированием (рекомендуется)
./iclaude.sh --sandbox-microvm --pii-proxy

# Через Claude Code Router
./iclaude.sh --sandbox-microvm --router

# Комбинация: PII + Router
./iclaude.sh --sandbox-microvm --pii-proxy --router

# Постоянный режим через конфиг
echo 'MICRO_VM_ENABLED=true' >> .claude_config
```

---

## Workspace режимы

Управляет тем, какие файлы синхронизируются между host и guest.

| Режим | `MICRO_VM_WORKSPACE_MODE` | Host→Guest sync | Guest→Host sync-back |
|-------|--------------------------|-----------------|----------------------|
| `full` (default) | весь `$PWD` | ✅ | ✅ |
| `path` | только `MICRO_VM_WORKSPACE_PATH` | ✅ | ✅ |
| `isolated` | guest `/workspace` пустой | ❌ | ❌ |

**Исключения при sync (full/path):**
- Host→Guest: `.nvm-isolated/`, `.git/`, `.claude_config`, `.iclaude-guest-env.sh`, `.iclaude-ssh`
- Guest→Host: `lost+found/`, `.iclaude-guest-env.sh`, `.claude-guest/`

Дополнительные исключения через `MICRO_VM_SYNC_EXCLUDE` (newline-separated patterns).

---

## Переменные конфигурации

Добавляются в `.claude_config` (chmod 600, не в git):

| Переменная | По умолчанию | Описание |
|-----------|-------------|---------|
| `MICRO_VM_ENABLED` | `false` | Автоматически использовать microVM при каждом запуске |
| `MICRO_VM_NET_SUBNET` | `172.16.0.0/26` | Подсеть для IP-пула слотов (до 31 concurrent сессий) |
| `MICRO_VM_WORKSPACE_MODE` | `full` | Режим синхронизации: `full`, `path`, `isolated` |
| `MICRO_VM_WORKSPACE_PATH` | — | Путь для режима `path` (относительно `$PWD`) |
| `MICRO_VM_SYNC_EXCLUDE` | — | Дополнительные паттерны исключений (newline-separated) |
| `MICRO_VM_MEM_MB` | `1024` | Объём RAM гостевой ВМ в МБ |
| `MICRO_VM_VCPU` | `2` | Количество vCPU гостевой ВМ |

---

## Совместимость режимов

| Комбинация | Статус | Поведение |
|-----------|--------|-----------|
| `--sandbox-microvm` | ✅ | virtio-blk + SSH exec + tar sync |
| `--sandbox-microvm --router` | ✅ | CCR стартует на host до VM; порт в guest env |
| `--sandbox-microvm --pii-proxy` | ✅ | PII proxy на host; `ANTHROPIC_BASE_URL=host_ip:PORT` в guest |
| `--sandbox-microvm --pii-proxy --router` | ✅ | PII → CCR цепочка на host; оба порта в guest env |
| `--sandbox-microvm --system` | ❌ | Заблокировано: microVM требует isolated environment |

---

## Как работает запуск (кратко)

1. **Slot alloc** — уникальная пара IP из пула `MICRO_VM_NET_SUBNET` (host_ip/guest_ip/TAP)
2. **TAP setup** — `_ensure_slot_tap`: создать TAP-интерфейс если отсутствует
3. **workspace.img** — sparse ext4 per-session в `session_dir/`
4. **guest-env.sh** — файл с `HTTPS_PROXY`, `ANTHROPIC_BASE_URL`, `CLAUDE_CONFIG_DIR` для guest
5. **FC config** — JSON: kernel + `init=` + drives (vda/vdb/vdc) + TAP network
6. **FC spawn** — `firecracker --api-sock ... --config-file vmconfig.json`
7. **SSH poll** — ожидание готовности sshd в guest (max 30s)
8. **SCP env** — `guest-env.sh` → `/workspace/.iclaude-guest-env.sh` в guest (via `iclaude@`)
9. **tar sync** — host→guest (режимы full/path); исключает `.nvm-isolated/`, `.git/`, secrets
10. **SSH exec** — `ssh iclaude@guest_ip "source /workspace/.iclaude-guest-env.sh && exec claude"`
11. **sync-back** — guest→host после завершения claude (режимы full/path)
12. **Cleanup** — EXIT-трап: `stop_microvm()`, `_free_microvm_slot()`, `rm session_dir`

---

## Troubleshooting

### KVM недоступен

```
microVM not available: /dev/kvm missing or not readable
```

- Проверить: `ls -la /dev/kvm`
- Добавить пользователя в группу kvm: `sudo usermod -aG kvm $USER` (logout/login)
- Для WSL2: включить nested virtualization в настройках Windows

### SSH timeout при запуске

```
Timeout waiting for SSH (30s). Guest may have failed to boot.
```

- Проверить лог Firecracker: `cat $ISOLATED_CONFIG_DIR/microvm-run/*/firecracker.log`
- Убедиться, что rootfs и nvm.img не повреждены: `./iclaude.sh --check-microvm`
- Переустановить образы: `./iclaude.sh --install-microvm`

### nvm.img отсутствует

```
nvm.img not found: run --install-microvm first
```

`nvm.img` не хранится в git (в `.gitignore`). Необходимо пересобрать:

```bash
./iclaude.sh --install-microvm
```

### Stale socket / занятый порт

При аварийном завершении может остаться stale FC socket. Скрипт автоматически делает
`rm -f "$MICRO_VM_SOCKET"` перед запуском Firecracker. Если проблема повторяется:

```bash
rm -f /tmp/iclaude-*-fc.sock
```

### TAP-интерфейс не создаётся

```
Failed to create TAP interface tap-iclaude
```

Требуются права на создание TAP. Добавить пользователя в группу `netdev`:

```bash
sudo usermod -aG netdev $USER
# или
sudo ip tuntap add dev tap-iclaude mode tap user $USER
```

---

## Обновление образов

```bash
# Переустановить все компоненты (безопасно, идемпотентно)
./iclaude.sh --install-microvm
```

---

## Связанные документы

- [docs/SANDBOX_ANALYSIS.md](SANDBOX_ANALYSIS.md) — threat model, выбор уровня изоляции
- [docs/MIGRATION.md](MIGRATION.md) — история архитектуры (v1 virtiofs → v2 virtio-blk)
- [docs/architecture/diagrams/data-flow-microvm-launch.md](architecture/diagrams/data-flow-microvm-launch.md) — детальная диаграмма запуска
- `lib/sandbox/microvm.sh` — реализация `start_microvm()`
- `lib/sandbox/install.sh` — реализация `install_microvm()`
- `lib/sandbox/guest-init.sh` — guest PID 1 (монтирование, sshd)
