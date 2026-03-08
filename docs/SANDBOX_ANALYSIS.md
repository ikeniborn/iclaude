# Анализ: Изоляция процессов Claude Code — от OS sandbox до микро-ВМ

**Источник:** [A field guide to sandboxes for AI](https://www.luiscardoso.dev/blog/sandboxes-for-ai) — Luis Cardoso, Jan 5, 2026
**Дата анализа:** 2026-03-06
**Статус:** Актуализирован — microVM v2 реализован: virtio-blk + SSH exec (2026-03-07)

---

## Threat Model: что именно защищаем

### Цепочка атаки

```
Внешний контент (репо, веб, файл)
    ↓ prompt injection
Claude Code (AI-directed tool calls)
    ↓ выполняет вредоносный bash / read / write
Host OS kernel
    ↓ kernel exploit
Полный контроль над машиной пользователя
```

**Ключевое:** Claude Code — доверенный инструмент, но он выполняет **AI-directed tool calls** — bash-команды, чтение файлов, сетевые запросы — направляемые моделью. Модель может быть введена в заблуждение через:

- Вредоносный код в читаемом репозитории
- Malicious content на веб-странице (WebFetch)
- Специально сформированный файл с инструкциями для модели
- MitM-инъекция в API-ответы (при использовании proxy)

**Цель изоляции:** даже если prompt injection привёл к выполнению произвольного кода, этот код не должен иметь возможности повлиять на ядро хостовой ОС, выйти за пределы рабочей директории или похитить credentials пользователя.

### Две независимые угрозы

| Угроза | Вектор | Что защищает |
|--------|--------|--------------|
| **Policy leakage** | Чтение ~/.ssh, ~/.aws, утечка кода в сеть | Hooks (block-secrets, redact-secrets) |
| **Kernel compromise** | Exploit ядра через tool call (bash, Wasm, native) | OS sandbox / gVisor / microVM |

Текущий iclaude закрывает **policy leakage** через hooks. **Kernel boundary** обеспечивается через microVM (Firecracker).

---

## Резюме статьи

Статья классифицирует технологии изоляции по трём измерениям:

| Измерение | Вопрос |
|-----------|--------|
| **Boundary** | Что общего между кодом и хостом? |
| **Policy** | Что код может трогать (файлы, сеть, устройства)? |
| **Lifecycle** | Что выживает между запусками? |

### Четыре категории изоляции (переоценённые)

| Тип | Что изолирует | Kernel isolation | Применимость к iclaude |
|-----|---------------|-----------------|------------------------|
| **Container** | Process namespaces + seccomp + cgroups | ❌ Общий host kernel | Базово, но недостаточно |
| **gVisor** | Syscall interposition (Sentry) | ✅ Частичная (userspace kernel) | Хороший баланс |
| **microVM** (Firecracker) | Guest kernel за KVM/VMM | ✅ Полная (отдельный kernel) | Максимальная защита |
| **Landlock+seccomp** | Filesystem + syscall policy | ❌ Общий host kernel | Практичный первый шаг |

**Переоценка:** Статья описывает microVM как "для multi-tenant SaaS", но это упрощение. Правильный критерий — **необходимость kernel isolation**, которая определяется не количеством пользователей, а threat model: если AI-процесс может выполнять произвольный код, kernel isolation защищает хост вне зависимости от количества арендаторов.

---

## Текущее состояние изоляции в iclaude

| Компонент | Файлы | Статус | Что защищает |
|-----------|-------|--------|--------------|
| **CLAUDE_CONFIG_DIR isolation** | `lib/config/isolated.sh` | ✅ Активно | Config в `.nvm-isolated/.claude-isolated/`, не в `~/.claude` |
| **Bubblewrap sandbox** | `lib/sandbox/*.sh` | ⚠️ Disabled (upstream bug) | Process-level isolation |
| **block-secrets.py** | `hooks/block-secrets.py` | ✅ Активно | Policy: блокирует чтение `.env`, `.pem`, `.ssh/` |
| **redact-secrets.py** | `hooks/redact-secrets.py` | ✅ Активно | Policy: маскирует API ключи, токены |
| **PII proxy** | `lib/pii-proxy/` | ✅ Опционально | API traffic masking |

### Bubblewrap: почему отключён

`sandbox.enabled: false` в `settings.json` — upstream баг Claude Code: при активированном sandbox создаются 0-байтные файлы-заглушки в `.claude/settings.json` других открытых проектов (chmod 444, не очищаются после выхода).

### Текущий gap

```
Policy layer      ✅  block-secrets + redact-secrets → закрыт
Kernel isolation  ✅  microVM (Firecracker) → закрыт при --sandbox-microvm
```

---

## Переоценённые варианты решения: от практичного к максимальному

### Уровень 1 — OS Policy (Landlock + seccomp)

**Что даёт:** ограничивает доступ к filesystem и набор разрешённых syscalls для процесса Claude Code. Если injected bash пытается читать `~/.ssh` — ядро блокирует на уровне LSM. Если пытается вызвать `ptrace`, `kexec_load`, `bpf` — seccomp блокирует.

**Что НЕ даёт:** если exploit использует разрешённый syscall с уязвимостью в ядре — kernel compromise возможен. Ядро одно на хост и Claude Code процесс.

**Реализация для iclaude:**

Landlock (Linux 5.13+, текущий хост: 6.17 — полная поддержка):

```c
// Иллюстративный фрагмент (не production-ready: опущена инициализация
// struct landlock_ruleset_attr и struct landlock_path_beneath_attr)
int ruleset_fd = landlock_create_ruleset(&attr, sizeof(attr), 0);
landlock_add_rule(ruleset_fd, LANDLOCK_RULE_PATH_BENEATH, &rule, 0);
landlock_restrict_self(ruleset_fd, 0);
```

Для iclaude — CLI-обёртка вокруг Landlock syscalls (`landlock_restrict_self`) + отдельный seccomp BPF фильтр (`prctl(PR_SET_SECCOMP, ...)`). `landrun` как концептуальная обёртка (инструмент необходимо найти в актуальных репозиториях; официальные kernel tools: [linux/tools/testing/selftests/landlock](https://github.com/torvalds/linux/tree/master/tools/testing/selftests/landlock)):

```bash
# Концептуально: разрешить только workspace и конфиг dirs
landrun \
  --allow-rw "${PWD}" \
  --allow-ro "${ISOLATED_NVM_DIR}" \
  --allow-ro "/tmp" \
  --deny "${HOME}/.ssh" \
  --deny "${HOME}/.aws" \
  -- claude "$@"
```

**Статус iclaude:** Landlock не реализован. При необходимости добавить `detect_landlock_support()` в `lib/sandbox/detect.sh`.

**Защита:** Policy leakage ✅ | Kernel isolation ❌ (shared kernel)

---

### Уровень 2 — gVisor (syscall interposition)

**Что даёт:** Claude Code видит Linux ABI, но syscalls перехватываются userspace Sentry процессом. Host kernel получает только ~68 системных вызовов от Sentry. Даже если injected code использует kernel exploit через uname, read, mmap — exploit бьёт в Sentry userspace, не в host kernel.

**Что НЕ даёт:** если exploit в одном из 68 syscalls которые Sentry пропускает в host kernel — возможен escape. Не полная изоляция, но значительно сужает attack surface.

**Операционная сложность:** средняя. `runsc` (gVisor runtime для Docker/containerd) устанавливается как deb-пакет. Для iclaude:

```bash
# Запуск Claude Code под gVisor через Docker (рекомендованный путь)
# Предварительно: настроить runsc как Docker runtime (runsc install)
docker run --runtime=runsc \
  -v "${PWD}:/workspace" \
  -v "${ISOLATED_NVM_DIR}:${ISOLATED_NVM_DIR}:ro" \
  -e CLAUDE_CONFIG_DIR -e ANTHROPIC_BASE_URL \
  --workdir /workspace \
  claude-code-image claude "$@"
# Прямой запуск (runsc do — минимальный OCI sandbox без Docker):
# runsc do -- claude "$@"  # упрощён; требует OCI bundle для production use
```

**Ограничения:** gVisor не поддерживает все Linux syscalls — некоторые инструменты (особенно с BPF, io_uring) могут не работать. Claude Code использует Node.js — совместимость нужно проверять.

**Защита:** Policy leakage ✅ | Kernel isolation ✅ (частичная, userspace kernel)

---

### Уровень 3 — microVM (Firecracker / cloud-hypervisor)

**Что даёт:** Claude Code процесс и все его subprocess выполняются внутри отдельной виртуальной машины с собственным Linux ядром. Если injected bash запускает kernel exploit — он эксплуатирует **guest kernel**, изолированный от host kernel через KVM/VMM. Host kernel не получает ни одного syscall от guest кода напрямую.

**Это максимальная доступная защита** от prompt injection → kernel compromise цепочки.

**Что НЕ даёт:** не защищает от уязвимостей в самом KVM гипервизоре (крайне редкий вектор). Требует KVM-совместимого хоста.

#### Архитектура microVM для iclaude

```
Host OS (Linux + KVM)
├── iclaude.sh               ← управляет microVM lifecycle
├── VMM (Firecracker)        ← запускает guest, управляет virtio devices
│   ├── virtio-net           ← гостевой сетевой интерфейс (только allowlist)
│   └── virtio-fs / virtiofs ← монтирует workspace в гость
└── Guest VM
    ├── Minimal Linux kernel (5.x) ← изолированный guest kernel
    ├── claude process             ← Claude Code запущен здесь
    │   ├── bash tool calls        ← всё внутри гостя
    │   └── file operations        ← ограничены virtio-fs mount
    └── vsock / virtio-serial      ← канал для env vars, PII proxy, CCR router
```

#### Интеграция с iclaude компонентами

| Компонент iclaude | Проблема в guest | Решение |
|-------------------|-----------------|---------|
| `ANTHROPIC_BASE_URL` (PII proxy) | Env var недоступен в guest | Передать через `cloud-init` или vsock |
| `CLAUDE_CONFIG_DIR` hooks | Path к hooks в guest другой | Монтировать hooks dir через virtio-fs |
| CCR router `router.json` | API keys в env vars | Передать в guest environment при boot |
| `--proxy` HTTPS | Guest network через VMM bridge | Настроить NAT + proxy env в guest |

#### Практические барьеры

1. **KVM зависимость.** Недоступен: CI без nested virt, WSL1, некоторые cloud VMs. iclaude уже обрабатывает WSL1 как unsupported — нужно добавить KVM detection.

2. **Boot latency.** Firecracker с снэпшотом запускается ~125ms, без снэпшота — ~1-2s. Для интерактивного использования приемлемо, но требует snapshot management.

3. **Операционная сложность.** Firecracker требует VMM процесс, virtio device management, network bridge setup. Это значительно усложняет iclaude как bash wrapper. Минимальная реализация: ~500-800 строк дополнительного кода + конфиги.

4. **Сопровождение guest image.** Нужен минимальный rootfs с Node.js + claude binary. Либо использовать virtiofs для монтирования host Node.js.

#### Оценка: когда microVM оправдан

| Критерий | Оценка |
|----------|--------|
| Claude Code выполняет bash tool calls от имени AI | ✅ Да — риск есть |
| Prompt injection через репозитории/веб — реальный вектор | ✅ Да |
| Пользователь работает с чувствительными данными/системами | ✅ Зависит |
| KVM доступен на целевом хосте | ✅ На текущем хосте (Linux 6.17) |
| Готовность к увеличению сложности iclaude | ⚠️ Решение за пользователем |

**Вывод:** microVM **технически оправдан** для максимальной защиты ядра хоста. Это не избыточно, если пользователь принимает операционные издержки. Для большинства случаев Landlock+seccomp или gVisor достаточны.

---

## Сравнительная таблица: выбор уровня изоляции

| Уровень | Технология | Kernel isolation | Сложность | Рекомендован когда |
|---------|-----------|-----------------|-----------|-------------------|
| **0 (base)** | hooks only | ❌ | Минимальная | Базовая policy, без OS boundary |
| **1** | Landlock + seccomp | ❌ (shared) | Низкая | Практичный первый шаг, быстро |
| **2** | gVisor (runsc) | ✅ частичная | Средняя | Хороший баланс защиты и совместимости |
| **3 ✅ реализован** | microVM (Firecracker) | ✅ полная | Высокая | Максимальная защита, KVM доступен |

---

## Сравнение: уровни изоляции iclaude

| Аспект | Base (hooks) | microVM v2 ✅ CURRENT |
|--------|-------------|----------------------|
| **Policy — filesystem** | block-secrets.py (blocklist) | virtio-blk: vdb=nvm (RO), vdc=workspace (RW) |
| **Policy — network** | Нет ограничений | TAP + iptables NAT + IP-пул слотов |
| **Kernel boundary** | ❌ | ✅ guest kernel (KVM) |
| **Kernel exploit blast radius** | Весь хост | Только guest VM |
| **Где выполняется claude** | host | guest (full in-guest, SSH exec) |
| **PII proxy** | ✅ опционально | ✅ host-side, `ANTHROPIC_BASE_URL=host_ip:PORT` в guest env |
| **Hooks** | ✅ активно | ✅ без изменений |
| **Статус** | всегда активен | `--sandbox-microvm` |
| **Совместимость** | Широкая | KVM required (Linux/WSL2) |

---

## Приоритизированные рекомендации

### Приоритет 1 (практичный, немедленный): Landlock + seccomp

Закрывает policy leakage полностью, существенно сужает syscall attack surface. Ядро остаётся общим — kernel exploit теоретически возможен, но attack surface сокращается на 80%+.

**Изменения в iclaude:**
- `lib/sandbox/detect.sh` → добавить `detect_landlock_support()` (проверить `/proc/sys/kernel/landlock_abi`)
- `lib/sandbox/install.sh` → добавить проверку и инструкцию для Landlock CLI wrapper
- Launcher: добавить Landlock-based запуск вместо прямого вызова claude

### Приоритет 2 (сильная защита, приемлемая сложность): gVisor

gVisor даёт userspace kernel — injected code не получает прямого доступа к host kernel syscalls. Совместимость с Node.js / Claude Code нужно проверить (`runsc` + Node.js совместим, но BPF/io_uring могут не работать).

**Изменения в iclaude:**
- Добавить `detect_gvisor_support()` (наличие `runsc` binary)
- Launcher: `runsc do -- claude "$@"` вместо прямого вызова
- Новый флаг: `--sandbox-gvisor`

### Приоритет 3 (максимальная защита): microVM ✅ РЕАЛИЗОВАН (v2)

Реализован как `lib/sandbox/microvm.sh` + `lib/sandbox/install.sh` + `lib/sandbox/guest-init.sh`.

**Текущая архитектура (v2 — virtio-blk + SSH exec):**
```
Host OS (Linux + KVM)
├── iclaude.sh              ← управляет lifecycle VM
├── Firecracker VMM         ← virtio-blk devices (vda/vdb/vdc)
└── Guest VM
    ├── iclaude-guest-init  ← PID 1: монтирует vdb→/mnt/nvm, vdc→/workspace, стартует sshd
    └── claude              ← выполняется ВНУТРИ GUEST (full in-guest)
```

Claude Code и все tool calls выполняются внутри guest с отдельным Linux ядром. Host управляет только lifecycle VM.

**Команды:**
```bash
./iclaude.sh --install-microvm    # Firecracker v1.11 + vmlinux + rootfs + nvm.img (~1.4GB)
./iclaude.sh --check-microvm      # KVM, nvm.img, TAP, SSH ключ
./iclaude.sh --sandbox-microvm    # Запуск с изоляцией
```

**OS matrix:** Ubuntu 22+, Debian 10+, ALT Linux 10+, WSL2 (nested virt).

**Документация:** [docs/MICROVM.md](MICROVM.md) · [Architecture diagram](architecture/diagrams/data-flow-microvm-launch.md)

### Текущий security hooks layer — оставить без изменений

`block-secrets.py` + `redact-secrets.py` закрывают policy leakage независимо от уровня sandbox. Они работают поверх любого варианта изоляции как дополнительный слой.

---

## Что НЕ нужно делать

- **Wasm sandbox для Claude Code** — Claude Code — ELF binary, не Wasm workload
- **Docker container** — не даёт kernel isolation (shared kernel), при этом требует daemon и привилегий
- **Отказаться от microVM только потому что "это для SaaS"** — неправильный критерий; правильный критерий — необходимость kernel boundary при выполнении AI-directed arbitrary code

---

## Итоговая оценка

**microVM технически обоснован** для iclaude при правильном threat model: Claude Code выполняет AI-directed tool calls, prompt injection — реальный вектор, kernel exploit через bash tool call — теоретически возможен. Firecracker изолирует guest kernel от host kernel — это не избыточно, это правильный ответ на конкретную угрозу.

**Статус реализации:**
- ✅ **microVM (Firecracker v2)** — реализован, `--sandbox-microvm`
- ⬜ **gVisor (`runsc`)** — не реализован; userspace kernel, средняя сложность
- ⬜ **Landlock + seccomp** — не реализован; низкая сложность

**Текущие security hooks остаются актуальными** на всех уровнях — они закрывают policy leakage независимо от наличия kernel boundary.

---

## Связанные документы

- [docs/MICROVM.md](MICROVM.md) — операционное руководство по microVM (установка, запуск, troubleshooting)
- [docs/architecture/diagrams/data-flow-microvm-launch.md](architecture/diagrams/data-flow-microvm-launch.md) — архитектурная диаграмма v2
- [CLAUDE.md](../CLAUDE.md) — архитектурные примечания
- `lib/sandbox/detect.sh` — расширить для Landlock + gVisor detection
- `lib/sandbox/install.sh` — добавить Landlock / runsc check
- `lib/sandbox/status.sh` — `check_microvm_status()` → расширить для tier reporting
