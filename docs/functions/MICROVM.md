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

Границы изоляции и security notes — см. раздел [Security Notes](#security-notes) ниже.

**Use case — loen verifier:** плагин `loen` (см. [docs/functions/LOEN.md](LOEN.md),
раздел "Hardening") умеет запускать своего loop-верификатора headless внутри этой
microVM над одноразовым снапшотом дерева (`verifier_isolation: microvm` в `loop.yaml`) —
судья не имеет канала записи на хост.

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

Подробная диаграмма запуска: [docs/architecture/diagrams/data-flow-microvm-launch.md](../architecture/diagrams/data-flow-microvm-launch.md)

---

## Требования

| Компонент | Проверка | Заметки |
|-----------|---------|---------|
| `/dev/kvm` доступен и читаем | `detect_kvm_support()` | Требуется KVM (нет в CI без nested virt, WSL1) |
| Firecracker binary v1.11+ | `detect_microvm_binary()` | Устанавливается через `--install-microvm` |
| vmlinux kernel image | `$ISOLATED_CONFIG_DIR/bin/vmlinux` | Загружается при установке |
| rootfs.ext4 (Ubuntu 22.04) | `$ISOLATED_CONFIG_DIR/bin/rootfs.ext4` | Загружается при установке |
| nvm.img (NVM snapshot, ~1GB) | `$ISOLATED_CONFIG_DIR/bin/nvm.img` | Строится при `--install-microvm` (требует `sudo`) |
| TAP-интерфейс (per-slot) | `_ensure_slot_tap()` — авто-создание | Создаётся при каждом `--sandbox-microvm` (требует `sudo`); удаляется при завершении VM |
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

> **Требуется sudo** в двух ситуациях:
> - **При установке** (`--install-microvm`): `sudo mount -o loop` для сборки `nvm.img`.
> - **При каждом запуске** (`--sandbox-microvm`): создание и удаление TAP-интерфейса
>   (`ip tuntap add/del`, `iptables`, `ip route`). TAP удаляется автоматически при завершении VM.
>
> Запускайте от обычного пользователя — пароль будет запрошен при необходимости.

```bash
# Установить Firecracker v1.11 + vmlinux + rootfs + nvm.img (~1.4GB, один раз)
./iclaude.sh --install-microvm

# Проверить готовность всех компонентов
./iclaude.sh --check-microvm
```

> **TLS-ошибка при загрузке (ALT Linux / старый OpenSSL)?**
> Если `--install-microvm` завершается с ошибкой `TLS connect error: unsupported algorithm`
> (характерно для ALT Linux 10 с OpenSSL < 3.x), используйте обходной путь:
>
> ```bash
> MICRO_VM_INSECURE_DOWNLOAD=true ./iclaude.sh --install-microvm
> ```
>
> Скрипт передаёт `-k` (`--insecure`) в curl только для загрузки компонентов microVM.
> SHA-256 хеши сохраняются в `versions.json` (TOFU) и проверяются при повторных установках.
> Используйте только в доверенной сети.

`--install-microvm` выполняет:
1. Загрузка Firecracker v1.11 и vmlinux (GitHub releases)
2. Загрузка базового rootfs Ubuntu 22.04
3. Инжект SSH-ключа в rootfs через `debugfs` (static authorized_keys)
4. Сборка `nvm.img` (1024MB sparse ext4, монтируется как /dev/vdb в guest)
5. Настройка сети (sudo): TAP-интерфейс slot-1 (`tap-iclaude-1`), NAT/MASQUERADE, `ip_forward=1`

> **Lifecycle TAP-интерфейса:** `--install-microvm` создаёт TAP (slot 1, `tap-iclaude-1`).
> При каждом `--sandbox-microvm` TAP пересоздаётся если отсутствует (`_ensure_slot_tap`).
> **При завершении VM TAP удаляется** (`stop_microvm`). Имя: `{MICRO_VM_NET_TAP_IFACE}-{slot+1}`.

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
echo 'ICLAUDE_MICRO_VM_ENABLED=true' >> .claude_config
```

### Workspace: конкретный путь

```bash
# Работать с проектом из конкретной директории (независимо от cwd)
MICRO_VM_WORKSPACE_PATH=/home/user/projects/my-project ./iclaude.sh --sandbox-microvm

# Или через .claude_config:
# ICLAUDE_MICRO_VM_ENABLED=true
# ICLAUDE_MICRO_VM_WORKSPACE_PATH=/home/user/projects/my-project
```

### Workspace: isolated режим

```bash
# Файлы проекта доступны в VM, но изменения НЕ возвращаются на хост
MICRO_VM_WORKSPACE_MODE=isolated ./iclaude.sh --sandbox-microvm

# С указанием источника:
MICRO_VM_WORKSPACE_MODE=isolated \
MICRO_VM_WORKSPACE_PATH=/home/user/projects/my-project \
./iclaude.sh --sandbox-microvm
```

---

## Workspace режимы

Управляет тем, какие файлы синхронизируются между host и guest.

| `MICRO_VM_WORKSPACE_MODE` | Источник | Host→Guest sync | Guest→Host sync-back |
|--------------------------|----------|-----------------|----------------------|
| `full` (default) | `MICRO_VM_WORKSPACE_PATH` или `$PWD` | ✅ | ✅ |
| `isolated` | `MICRO_VM_WORKSPACE_PATH` или `$PWD` | ✅ | ❌ |

**`full`** — двунаправленная синхронизация: данные копируются в guest при запуске, изменения возвращаются на хост после завершения.

**`isolated`** — одностороннее копирование: данные копируются в guest при запуске, но изменения **не возвращаются** на хост. Файлы на хосте остаются неизменными. Используется когда нужно дать claude доступ к файлам, но запретить изменение оригиналов.

**`MICRO_VM_WORKSPACE_PATH`** — переопределяет `$PWD` как источник workspace (работает для обоих режимов).
Если не задан — используется `$PWD` (поведение по умолчанию).

Пример: `MICRO_VM_WORKSPACE_PATH=/home/user/projects/my-project` позволяет работать
с конкретным проектом независимо от текущего каталога.

**Исключения при sync (full и isolated):**
- Host→Guest: `.nvm-isolated/`, `.git/`, `.claude_config`, `.iclaude-guest-env.sh`, `.iclaude-ssh`
- Guest→Host: `lost+found/`, `.iclaude-guest-env.sh`, `.claude-guest/`

Дополнительные исключения через `ICLAUDE_MICRO_VM_SYNC_EXCLUDE` (newline-separated patterns).

### Механизм синхронизации (SSH ControlMaster + rsync)

Начиная с rootfs v7, используется delta-sync через SSH ControlMaster:

| Компонент | Описание |
|-----------|---------|
| **SSH ControlMaster** | Одно постоянное TCP-соединение. Все sync-операции проходят через него, overhead ~5ms вместо 150-320ms на handshake |
| **rsync** | Delta-sync: передаются только изменённые файлы. При малых изменениях объём передачи снижается на 90%+ |
| **Fallback** | Если rsync недоступен в guest (rootfs v6 или ниже) — автоматический откат на tar-over-SSH |
| **ControlPersist=60** | Мастер-соединение закрывается автоматически через 60s после последнего использования (защита от orphan при SIGKILL) |

> **tar-fallback и удаления.** `tar -x` сам по себе только добавляет/перезаписывает и **не удаляет**. Чтобы `full`-режим переносил удаления и на tar-пути, после каждой guest→host tar-синхронизации launcher запрашивает список файлов guest (`find` по `/workspace` с тем же исключением protected-путей) и удаляет на хосте файлы, отсутствующие в guest (`_microvm_mirror_deletions`) — те же семантики, что у `rsync --delete`. Безопасно: при ошибке/пустом списке сканирования удаление **не выполняется** (нет массового удаления). rsync bundle по-прежнему предпочтителен ради скорости (delta вместо full-copy) — `--install-microvm`.

**Минимальный интервал sync:**
- С rsync+ControlMaster (v7 rootfs): **2 секунды** (рекомендуется 5s)
- Без rsync (v6 rootfs, tar-over-SSH): **20-30 секунд**

**Обновление до v7:**
```bash
./iclaude.sh --install-microvm   # inject rsync, без re-download
./iclaude.sh --check-microvm     # проверить: [v7: + rsync]
```

---

## Снэпшоты

### Принцип работы

Именованные снэпшоты позволяют сохранить полное состояние VM (память, диски, сеть)
и восстановить его при следующем запуске — без холодной загрузки ядра.

**Включение:**

```bash
# .claude_config
ICLAUDE_MICRO_VM_SNAPSHOT_ENABLED=true
```

### UX-сценарий

**При запуске** — если снэпшоты есть, показывается список:

```
  Available snapshots:
  1. 2026-03-09_14-30 — "django auth in progress"
  2. 2026-03-08_11-22 — "npm build debugging"
  0. Cold boot (new session)

  Choice [0-2]: _
```

Если снэпшотов нет — холодный старт без вопросов.

**При завершении** — предлагается сохранить:

```
  Save snapshot? [y/N]: y
  Description (optional): django auth done, tests passing
```

При отказе (`n` или Enter) — обычное завершение без снэпшота.

### Хранение снэпшотов

Каждый снэпшот — отдельная директория:

```
${MICRO_VM_SNAPSHOT_DIR}/        # по умолчанию: .claude-isolated/microvm-snapshots/
  2026-03-09_14-30_django-auth/
    vm.snap          # состояние Firecracker (CPU, RAM registers)
    vm.mem           # дамп оперативной памяти
    meta.env         # TIMESTAMP, DESCRIPTION, сетевые параметры (SLOT, IP, TAP)
    rootfs.ext4      # образ гостевого диска
    workspace.img    # образ рабочего пространства
  2026-03-08_11-22_npm-build-debugging/
    ...
```

**Размер:** rootfs (~500MB sparse) + workspace (~2GB sparse) + vm.mem (`ICLAUDE_MICRO_VM_MEM_MB` MB).
При дефолтных 2048 MB RAM ≈ **~2.5 GB на снэпшот** (sparse-файлы занимают меньше реального места).

### Параллельный запуск из одного снэпшота

Несколько сессий могут стартовать из **одного и того же** снэпшота одновременно — каждая
получает независимую рабочую копию дисков:

```
snap/rootfs.ext4    ──(cp)──→  session-A/rootfs.ext4   ← FC process A (RW)
snap/workspace.img  ──(cp)──→  session-A/workspace.img ← FC process A (RW)
                    ──(cp)──→  session-B/rootfs.ext4   ← FC process B (RW)
                    ──(cp)──→  session-B/workspace.img ← FC process B (RW)
```

Снэпшот-файлы остаются неизменными после восстановления.

### Как работает restore (технически)

1. Копирование `rootfs.ext4` и `workspace.img` из снэпшота в `session_dir/`
2. Запуск Firecracker без `--config-file`
3. `PUT /snapshot/load` — FC загружает состояние (кратко открывает оригинальные файлы)
4. `PATCH /drives/rootfs` + `PATCH /drives/workspace` → перенаправление FC на session-копии
5. `PATCH /vm {"state": "Resumed"}` — гость продолжает выполнение
6. SSH-опрос готовности гостя
7. Обновление `guest-env.sh` (прокси, API URL могли измениться)

### Как работает сохранение (технически)

1. `PATCH /vm {"state": "Paused"}` — гость заморожен
2. Копирование текущих session-дисков в новую директорию снэпшота
3. `PATCH /drives/rootfs` + `PATCH /drives/workspace` → перенаправление FC в директорию снэпшота
4. `PUT /snapshot/create` — FC сохраняет vm.snap + vm.mem (пути дисков встроены в снэпшот)
5. Запись `meta.env` с описанием, временем и сетевыми параметрами

### Ограничения

| Ограничение | Описание |
|-------------|---------|
| Привязка к версии FC | Снэпшоты несовместимы между версиями Firecracker. После `--install-microvm` (обновление FC) существующие снэпшоты не загрузятся — автоматический fallback на cold boot |
| Размер | ~2.5 GB на снэпшот (sparse; реальный размер зависит от заполненности дисков) |
| Сетевой конфиг | При restore сетевые параметры (IP, TAP) берутся из `meta.env`. Если нужный слот занят другой сессией — может потребоваться cold boot |

### Управление снэпшотами

```bash
# Проверить количество снэпшотов
./iclaude.sh --check-microvm

# Посмотреть список директорий
ls -lh ~/.../microvm-snapshots/

# Удалить конкретный снэпшот вручную
rm -rf ~/.../microvm-snapshots/2026-03-08_11-22_npm-build-debugging/
```

---

## Переменные конфигурации

Добавляются в `.claude_config` (chmod 600, не в git):

| Переменная | По умолчанию | Описание |
|-----------|-------------|---------|
| `ICLAUDE_MICRO_VM_ENABLED` | `false` | Автоматически использовать microVM при каждом запуске |
| `ICLAUDE_MICRO_VM_NET_ENABLED` | `true` | TAP-сеть (NAT через хост). `false` — полная изоляция без сети. При `true` гость получает доступ к интернету через хостовый NAT (iptables MASQUERADE). |
| `ICLAUDE_MICRO_VM_NET_SUBNET` | `172.16.0.0/26` | Подсеть для IP-пула слотов (до 31 concurrent сессий) |
| `ICLAUDE_MICRO_VM_WORKSPACE_MODE` | `full` | Режим синхронизации: `full`, `isolated` |
| `ICLAUDE_MICRO_VM_WORKSPACE_PATH` | — | Источник workspace для `full` и `isolated` (по умолчанию: `$PWD`) |
| `ICLAUDE_MICRO_VM_SYNC_EXCLUDE` | — | Дополнительные паттерны исключений (colon-separated) |
| `ICLAUDE_MICRO_VM_SYNC_INTERVAL` | `0` | Периодическая синхронизация guest→host (секунды, только `full` режим). `0` — только при выходе. Минимум 2s (rsync/v7) или 20s (tar/v6). |
| `ICLAUDE_MICRO_VM_MEM_MB` | `2048` | Объём RAM гостевой ВМ в МБ. **Рекомендуется: 2048** (Claude Code использует ~600 MB RSS в базовом состоянии, без swap) |
| `ICLAUDE_MICRO_VM_VCPU` | `2` | Количество vCPU гостевой ВМ. Значение читается напрямую из `.claude_config` и применяется к конфигурации Firecracker без переопределений. |
| `ICLAUDE_MICRO_VM_ROOTFS_SIZE_MB` | `2048` | Размер rootfs образа (vda: OS-диск гостя, `/home`, `/etc`, логи). `--install-microvm` авто-расширяет до этого значения; при запуске VM дополнительно авто-растёт если < 30% свободно. Workspace (файлы проекта) — отдельный диск (vdc), задаётся `ICLAUDE_MICRO_VM_WORKSPACE_SIZE_MB`. |
| `ICLAUDE_MICRO_VM_WORKSPACE_SIZE_MB` | `2048` | Размер workspace образа (vdc: `/workspace` в госте). Sparse-файл — на хосте занимает только фактически использованное место. Пересоздаётся при каждом запуске VM. Для крупных проектов: 8192+. |
| `ICLAUDE_MICRO_VM_SNAPSHOT_ENABLED` | `false` | Включить именованные снэпшоты. При запуске показывает список снэпшотов для выбора; при завершении предлагает сохранить |
| `ICLAUDE_MICRO_VM_SNAPSHOT_DIR` | `...microvm-snapshots/` | Директория хранения снэпшотов |

---

## Совместимость режимов

| Комбинация | Статус | Поведение |
|-----------|--------|-----------|
| `--sandbox-microvm` | ✅ | virtio-blk + SSH ControlMaster + rsync sync (tar fallback при v6 rootfs) |
| `--sandbox-microvm --router` | ✅ | CCR стартует на host до VM; порт в guest env |
| `--sandbox-microvm --pii-proxy` | ✅ | PII proxy на host; `ANTHROPIC_BASE_URL=host_ip:PORT` в guest |
| `--sandbox-microvm --pii-proxy --router` | ✅ | PII → CCR цепочка на host; оба порта в guest env |
| `--sandbox-microvm --system` | ❌ | Заблокировано: microVM требует isolated environment |

---

## Как работает запуск (кратко)

### Cold boot (без снэпшота или `MICRO_VM_SNAPSHOT_ENABLED=false`)

1. **Slot alloc** — уникальная пара IP из пула `MICRO_VM_NET_SUBNET` (host_ip/guest_ip/TAP)
2. **TAP setup** — `_ensure_slot_tap`: создать TAP-интерфейс если отсутствует
3. **rootfs copy** — sparse copy базового rootfs в `session_dir/rootfs.ext4`
4. **workspace.img** — sparse ext4 per-session в `session_dir/workspace.img`
5. **guest-env.sh** — файл с `HTTPS_PROXY`, `ANTHROPIC_BASE_URL`, `CLAUDE_CONFIG_DIR` для guest
6. **FC config** — JSON: kernel + `init=` + drives (vda/vdb/vdc) + TAP network
7. **FC spawn** — `firecracker --api-sock ... --config-file vmconfig.json`
8. **SSH poll** — ожидание готовности sshd в guest (max 30s)
9. **SCP env** — `guest-env.sh` → `/workspace/.iclaude-guest-env.sh` в guest (via `iclaude@`)
10. **ControlMaster** — `ssh -M -N -f -o ControlPersist=60` — постоянное SSH-соединение для всех sync-операций (overhead 5ms вместо 150-320ms)
11. **rsync detect** — проверка наличия rsync в guest (`command -v rsync`); если отсутствует — fallback на tar
12. **initial sync** — host→guest: rsync или tar (режимы `full` и `isolated`); исключает `.nvm-isolated/`, `.git/`, secrets
13. **SSH exec** — `ssh iclaude@guest_ip "source /workspace/.iclaude-guest-env.sh && exec claude"`
14. **sync-back** — guest→host после завершения claude (только режим `full`): rsync с ControlMaster fallback, или tar; `isolated` — без sync-back
13. **Snapshot prompt** — если `MICRO_VM_SNAPSHOT_ENABLED=true`: `Save snapshot? [y/N]`
14. **Cleanup** — EXIT-трап: `stop_microvm()`, `_free_microvm_slot()`, `rm session_dir`

### Restore из снэпшота (`MICRO_VM_SNAPSHOT_ENABLED=true`)

1. **Slot alloc** — как при cold boot
2. **TAP setup** — как при cold boot; затем сетевые параметры переопределяются из `meta.env`
3. **Snapshot select** — интерактивный выбор из списка; выбор `0` → cold boot
4. **Drive copy** — `rootfs.ext4` и `workspace.img` из снэпшота копируются в `session_dir/`
5. **FC spawn** — `firecracker --api-sock ...` (без `--config-file`)
6. **PUT /snapshot/load** — загрузка состояния VM (mem + CPU state)
7. **PATCH /drives** — перенаправление FC на session-копии дисков (VM остаётся Paused)
8. **PATCH /vm Resumed** — гость продолжает выполнение с сохранённого момента
9. **SSH poll** — ожидание готовности sshd (max 30s)
10. **SCP env** — обновлённый `guest-env.sh` → guest (прокси/API могли измениться)
11. **SSH exec** — запуск claude внутри guest
12. **Snapshot prompt** — при завершении: `Save snapshot? [y/N]`
13. **Cleanup** — как при cold boot

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

### Снэпшот не загружается (HTTP != 204)

```
microVM: snapshot load failed (HTTP 400) — try cold boot
```

Наиболее частая причина — несовместимость версии снэпшота с текущим Firecracker (после `--install-microvm`). Снэпшот привязан к конкретной версии FC.

**Решение:** выбрать `0. Cold boot`. Старые снэпшоты можно удалить вручную:

```bash
rm -rf .claude-isolated/microvm-snapshots/2026-03-*/
```

### Список снэпшотов пустой после переустановки

Снэпшоты хранятся в `MICRO_VM_SNAPSHOT_DIR` (по умолчанию `.claude-isolated/microvm-snapshots/`),
которая исключена из git. После `git clone` + `--repair-isolated` снэпшоты не восстанавливаются — это ожидаемо.

### `/usr/bin/sudo: Отказано в доступе` (ALT Linux)

```
/usr/bin/sudo: Отказано в доступе
```

На ALT Linux доступ к `sudo` ограничен группой `wheel`. Если пользователь не состоит в ней,
бинарный файл `/usr/bin/sudo` недоступен (SUID не срабатывает) — пароль при этом не запрашивается вовсе.

**Решение:** добавить пользователя в группу `wheel` (требует root или существующего sudo-пользователя):

```bash
su -
usermod -aG wheel YOUR_USERNAME
exit
# Выйти из сессии и войти снова, чтобы группа применилась
```

Или, если есть доступ к sudo через другого пользователя:

```bash
sudo usermod -aG wheel $USER
# Выйти и войти снова (logout/login), затем повторить установку
./iclaude.sh --install-microvm
```

После перелогина проверьте доступность sudo:

```bash
sudo -v   # должен запросить пароль, не вернуть "Отказано в доступе"
```

### TAP-интерфейс не создаётся

```
microVM: TAP tap-iclaude-1 not found (sudo unavailable to create it)
```

TAP создаётся при каждом запуске `--sandbox-microvm` и требует `sudo`. Если `sudo`
недоступен без пароля, скрипт выведет команды для ручного выполнения:

```bash
sudo ip tuntap add dev tap-iclaude-1 mode tap
sudo ip addr add 172.16.0.1/26 dev tap-iclaude-1
sudo ip link set tap-iclaude-1 up
```

Для работы без интерактивного пароля — разрешить конкретные команды через `sudoers`:

```
# /etc/sudoers.d/iclaude-tap  (редактировать через visudo)
Cmnd_Alias ICLAUDE_NET = \
    /usr/sbin/ip tuntap *, \
    /usr/sbin/ip link *, \
    /usr/sbin/ip addr *, \
    /usr/sbin/ip route *, \
    /usr/sbin/iptables *, \
    /usr/sbin/sysctl *
username ALL=(ALL) NOPASSWD: ICLAUDE_NET
```

### Guest cannot reach PII proxy

If the guest's Claude Code calls hang or fail with connection errors after launching with `--pii-proxy --sandbox-microvm`, verify the host installed the DNAT rule:

```bash
sudo iptables -t nat -L PREROUTING -n | grep iclaude-pii-dnat
```

Expected: one rule per active microVM session, e.g.

```
DNAT  tcp  --  0.0.0.0/0  172.16.0.1  tcp dpt:<port> /* iclaude-pii-dnat:tap-iclaude-1 */ to:127.0.0.1:<port>
```

If the rule is missing, the most common cause is missing passwordless sudo. iclaude prints a warning at launch time:

```
WARN: microVM: PII proxy active but passwordless sudo unavailable
WARN: microVM: guest cannot reach PII proxy at 172.16.0.1:<port>
INFO: microVM: configure NOPASSWD for iptables/sysctl OR launch without --pii-proxy
```

Configure NOPASSWD via `visudo`, e.g.:

```
%iclaude ALL=(root) NOPASSWD: /usr/sbin/iptables, /usr/sbin/sysctl, /usr/sbin/ip
```

Adjust paths via `command -v iptables sysctl ip` — locations vary across distros (e.g. `/sbin/iptables` vs `/usr/sbin/iptables`). Required commands: `iptables`, `sysctl`, `ip`.

### Stale iptables rules after crash

If iclaude was killed via `kill -9` or the host crashed, DNAT rules may persist. They are removed automatically the next time iclaude launches with `--pii-proxy --sandbox-microvm` (sweep on start).

To remove them manually:

```bash
while sudo iptables -t nat -L PREROUTING --line-numbers -n | grep -q iclaude-pii-dnat; do
    L=$(sudo iptables -t nat -L PREROUTING --line-numbers -n | awk '/iclaude-pii-dnat/ {print $1; exit}')
    sudo iptables -t nat -D PREROUTING "$L"
done
```

---

## Security Notes

### Linux Capabilities внутри guest

Процесс `claude` запускается как `iclaude` (uid=1000) с bounding capability set `000001ffffffffff` (все 41 capabilities). Это ожидаемо: `guest-init` запускается как PID 1 root и не вызывает `capsh --drop` перед созданием пользователя. Capabilities наследуются в bounding set.

**Это приемлемо:** границей безопасности является KVM hypervisor. Capabilities внутри guest не могут распространяться за пределы VM — любой exploit остаётся изолированным в guest kernel. Повышение привилегий внутри VM через SUID-бинари возможно, но не выходит за пределы KVM-изоляции.

Если требуется минимальный capability set (defence in depth), добавьте `capsh --drop=all --user=iclaude --` перед запуском claude в `launch.sh`.

### Сетевой доступ и IPv6

При `MICRO_VM_NET_ENABLED=true` (по умолчанию) гостевая VM получает:
- IPv4: выход в интернет через NAT/MASQUERADE на хостовом интерфейсе
- IPv6: kernel автоматически настраивает SLAAC на `eth0` (если хост имеет IPv6 uplink)

**Это ожидаемо и корректно** — claude внутри VM должен обращаться к Anthropic API, npm и прочим сервисам. Доступ в интернет не является уязвимостью: он необходим для функционирования.

Для полной изоляции без сети: `ICLAUDE_MICRO_VM_NET_ENABLED=false` (тогда API недоступен).

## Обновление образов

```bash
# Переустановить все компоненты (безопасно, идемпотентно)
./iclaude.sh --install-microvm
```

---

## Связанные документы

- [docs/architecture/diagrams/data-flow-microvm-launch.md](../architecture/diagrams/data-flow-microvm-launch.md) — детальная диаграмма запуска
- `lib/sandbox/microvm.sh` — реализация `start_microvm()`
- `lib/sandbox/install.sh` — реализация `install_microvm()`
- `lib/sandbox/guest-init.sh` — guest PID 1 (монтирование, sshd)

