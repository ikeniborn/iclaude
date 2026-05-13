---
wiki_sources:
  - "docs/functions/MICROVM.md"
  - "docs/functions/USE_CASES.md"
  - "docs/functions/CONFIGURATION.md"
  - "docs/superpowers/specs/2026-05-08-pii-microvm-dnat-hardening-design.md"
wiki_updated: 2026-05-08
wiki_status: mature
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
| `MICRO_VM_WORKSPACE_MODE` | `full` | Режим синхронизации (`full`/`isolated`) |
| `MICRO_VM_WORKSPACE_PATH` | — | Источник workspace (по умолчанию `$PWD`) |
| `MICRO_VM_WORKSPACE_SIZE_MB` | `2048` | Размер workspace-диска (vdc, sparse). Для крупных проектов: 8192+ |
| `MICRO_VM_ROOTFS_SIZE_MB` | `2048` | Размер rootfs-образа (vda). Авто-расширение при `--install-microvm`; runtime-рост если < 30% свободно |
| `MICRO_VM_NET_ENABLED` | `true` | TAP-сеть (NAT через хост). `false` — полная изоляция без сети |
| `MICRO_VM_NET_SUBNET` | `172.16.0.0/26` | Подсеть IP-пула слотов (до 31 concurrent сессий) |
| `MICRO_VM_SYNC_INTERVAL` | `0` | Периодический guest→host sync, секунды (только `full`). Минимум 2s (rsync/v7) или 20s (tar/v6) |
| `MICRO_VM_SYNC_EXCLUDE` | — | Дополнительные паттерны исключений (newline-separated) |
| `MICRO_VM_SNAPSHOT_ENABLED` | `false` | Именованные снэпшоты |
| `MICRO_VM_SNAPSHOT_DIR` | `microvm-snapshots/` | Каталог хранения снэпшотов |
| `MICRO_VM_INSECURE_DOWNLOAD` | `false` | Передаёт `-k` в curl при загрузке компонентов (workaround для ALT Linux 10 / OpenSSL < 3.x с TLS-ошибками). SHA-256 в `versions.json` (TOFU) валидируется при повторных установках |

## Безопасность

Граница безопасности — KVM hypervisor. Capabilities внутри guest не выходят за пределы VM. При `MICRO_VM_NET_ENABLED=true` гость получает выход в интернет через NAT (необходим для Anthropic API).

### Linux Capabilities внутри guest

Процесс `claude` запускается как `iclaude` (uid=1000) с bounding capability set `000001ffffffffff` (все 41 capabilities). Это ожидаемо: `guest-init` (PID 1, root) не вызывает `capsh --drop` перед созданием пользователя — capabilities наследуются в bounding set.

Это приемлемо: любой exploit остаётся изолированным в guest kernel и не выходит за пределы KVM. Для defence-in-depth можно добавить `capsh --drop=all --user=iclaude --` перед запуском claude в `launch.sh`.

### Сетевой доступ и IPv6

При `MICRO_VM_NET_ENABLED=true`:
- IPv4: выход в интернет через NAT/MASQUERADE на хостовом интерфейсе
- IPv6: kernel автоматически настраивает SLAAC на `eth0` (если хост имеет IPv6 uplink)

Доступ в интернет необходим для функционирования (Anthropic API, npm). Для полной изоляции: `MICRO_VM_NET_ENABLED=false`.

## Troubleshooting

### `/usr/bin/sudo: Отказано в доступе` (ALT Linux)

На ALT Linux доступ к `sudo` ограничен группой `wheel`. Если пользователь не состоит в ней, бинарь `/usr/bin/sudo` недоступен (SUID не срабатывает) — пароль не запрашивается. Решение: `usermod -aG wheel $USER` через root + перелогин.

### TLS-ошибка при `--install-microvm`

`TLS connect error: unsupported algorithm` (характерно для ALT Linux 10 с OpenSSL < 3.x): использовать `MICRO_VM_INSECURE_DOWNLOAD=true ./iclaude.sh --install-microvm`. Только в доверенной сети — обходит TLS-валидацию, но SHA-256 хеши (TOFU в `versions.json`) проверяются.

### TAP-интерфейс не создаётся

При запуске `--sandbox-microvm` создание TAP требует `sudo` (`ip tuntap add`, `iptables`). Без passwordless sudo скрипт выводит команды для ручного выполнения. Долгосрочное решение — настроить `/etc/sudoers.d/iclaude-tap` с `Cmnd_Alias ICLAUDE_NET` (см. источник).

## Интеграция с PII proxy: DNAT hardening (2026-05-08)

PII proxy биндится только на `127.0.0.1`. Чтобы guest microVM мог достучаться до прокси на хосте, `start_microvm` устанавливает iptables DNAT-правило `<host_ip>:<port> → 127.0.0.1:<port>` + `route_localnet=1` на TAP-интерфейсе.

### Три проблемы устранены

**P1 (silent sudo failure):** раньше при отсутствии passwordless sudo DNAT тихо не создавался — guest получал connection-refused без диагностики. Теперь `_pii_dnat_preflight` явно предупреждает в логе и подсказывает настроить NOPASSWD или запускать без `--pii-proxy`.

**P2 (stale rules):** `kill -9` или crash хоста оставлял orphaned DNAT-правила в iptables. Теперь `_pii_dnat_sweep_stale` идемпотентно вычищает их при каждом старте по comment-маркеру `iclaude-pii-dnat:<tap>`.

**P5 (route_localnet leak):** sysctl флаг сбрасывается в `stop_microvm` через тот же sweep-механизм; зависимость от `MICRO_VM_PII_DNAT_PORT` устранена.

### Новые helper-функции (`lib/sandbox/microvm.sh`)

| Функция | Назначение |
|---------|-----------|
| `_pii_dnat_preflight` | Проверяет PII-активность + passwordless sudo + iptables nat. Возвращает 1 с warning при недоступности. |
| `_pii_dnat_sweep_stale <tap>` | Идемпотентный drain orphaned DNAT/INPUT-правил по marker `iclaude-pii-dnat:<tap>`. Guard cap=20. |

### Comment marker как стабильный идентификатор

iptables-правила теперь несут `-m comment --comment "iclaude-pii-dnat:<tap>"`. Cleanup ищет по маркеру, а не по `(host_ip, port, tap)` — устойчив к port mismatches и partial state.

### Тестовая пирамида

| Уровень | Файл | Зависимости | Поведение |
|--------|------|-------------|-----------|
| L1 | `tests/test_pii_dnat_unit.sh` | bash + awk | PATH-mock unit-тесты, всегда выполняется |
| L2 | `tests/test_pii_dnat_iptables.sh` | passwordless sudo + dummy module | Реальный iptables на dummy iface, self-skip |
| L3 | `tests/test_pii_dnat_e2e.sh` | KVM + sudo + firecracker | Полный lifecycle с E2E-флагами, self-skip |

Runner: `bash tests/test_pii_dnat.sh` — каждый уровень self-gates, без прерываний.

### E2E debug-флаги

Только для L3 (gated `ICLAUDE_E2E_HEADLESS=1`):

- `--e2e-exit-after-boot` — clean exit после boot (sweep отрабатывает)
- `--e2e-kill-after-boot` — `kill -9` self после boot (имитация crash, оставляет stale rules)

### Troubleshooting

См. `docs/functions/MICROVM.md#troubleshooting` — диагностика отсутствующего DNAT-правила, NOPASSWD-конфигурация через `visudo`, ручная очистка stale rules.
