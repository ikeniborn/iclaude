# Анализ: Изоляция AI агентов на базе микро-ВМ и применимость в iclaude

**Источник:** [A field guide to sandboxes for AI](https://www.luiscardoso.dev/blog/sandboxes-for-ai) — Luis Cardoso, Jan 5, 2026
**Дата анализа:** 2026-03-05
**Статус:** Исследование завершено

---

## Резюме статьи

Статья классифицирует технологии изоляции для AI агентов по трём ортогональным измерениям:

| Измерение | Вопрос |
|-----------|--------|
| **Boundary** | Что общего между кодом и хостом? |
| **Policy** | Что код может трогать (файлы, сеть, устройства)? |
| **Lifecycle** | Что выживает между запусками? |

### Четыре категории изоляции

| Тип | Что изолирует | Когда применять |
|-----|---------------|-----------------|
| **Container** | Process namespaces + seccomp + cgroups | Доверенный код в одном trust domain |
| **gVisor** | Syscall interposition (Sentry, 68 host syscalls) | Semi-trusted, нужна полная Linux совместимость |
| **microVM** (Firecracker) | Guest kernel за KVM/VMM | Multi-tenant SaaS, hostile user-submitted code |
| **Runtime** (Wasm/V8) | Нет syscall ABI — только explicit host imports | Capability-scoped tools |

### Ключевые тезисы

1. **Containers — не security boundary.** Они разделяют host kernel. Kernel exploit — host exploit.
2. **Policy leakage — главная AI-специфичная угроза:** чтение ~/.ssh, ~/.aws, утечка кода в сеть, pivot в internal networks. Не kernel exploit.
3. **Threat model определяет выбор boundary.** Неправильный выбор → слишком слабая или слишком дорогая защита.
4. **microVMs для multi-tenant SaaS.** Hostile code от разных пользователей на одном хосте → Firecracker / cloud-hypervisor.
5. **Local agents — отдельный случай.** Статья явно выделяет Appendix для Claude Code, Codex CLI и аналогов.

### Appendix: Рекомендации для локальных агентов

Автор прямо упоминает `Claude Code` и `Codex CLI` как примеры локальных агентов и описывает специфичные для них механизмы:

| ОС | Механизм | Описание |
|----|----------|----------|
| **macOS** | Seatbelt (SBPL profiles) | Kernel-enforced per-process policy: allow workspace dirs, deny ~/.ssh |
| **Linux** | Landlock + seccomp | Unprivileged LSM для filesystem + TCP; seccomp блокирует опасные syscalls |
| **Windows** | AppContainer | Capability-based process isolation (SID tokens) |

Автор заключает: *"I personally run my code agents only with a sandbox enabled and do advise others to do the same"* — имея в виду OS-level local sandboxes, не microVMs.

---

## Текущее состояние изоляции в iclaude

### Что уже реализовано

| Компонент | Файлы | Статус | Что защищает |
|-----------|-------|--------|--------------|
| **CLAUDE_CONFIG_DIR isolation** | `lib/config/isolated.sh` | ✅ Активно | Config в `.nvm-isolated/.claude-isolated/`, не в `~/.claude` |
| **Bubblewrap sandbox** | `lib/sandbox/*.sh` | ⚠️ Disabled | OS-level isolation для Claude Code process |
| **block-secrets.py** | `hooks/block-secrets.py` | ✅ Активно | Блокирует чтение `.env`, `.pem`, `.ssh/` |
| **redact-secrets.py** | `hooks/redact-secrets.py` | ✅ Активно | Маскирует API ключи, токены в Write/Edit/Bash |
| **PII proxy** | `lib/pii-proxy/` | ✅ Опционально | Маскирует PII в API трафике до Anthropic |

### Bubblewrap: почему отключён

Bubblewrap (`sandbox.enabled: false` в `settings.json`) отключён из-за upstream бага Claude Code: при активированном sandbox создаются 0-байтные файлы-заглушки в `.claude/settings.json` других открытых проектов:

```bash
.claude/settings.json (0 bytes, chmod 444)
.claude/agents (0 bytes, chmod 444)
```

Файлы остаются после выхода из sandbox — автоматической очистки нет. Это делает bubblewrap непригодным в текущем виде, пока upstream не исправит баг.

### Два независимых механизма изоляции

Статья помогает точнее описать архитектуру iclaude:

```
CLAUDE_CONFIG_DIR isolation  →  Config isolation (всегда активно)
                                 Hooks work in any project

Bubblewrap sandbox           →  OS-level boundary (disabled)
                                 Process-level isolation
```

Это корректная двухуровневая модель: config isolation + OS-level boundary. Статья подтверждает правильность подхода.

---

## Критическая оценка: применимость microVM к iclaude

### Вывод: microVM НЕ релевантны для iclaude в текущей форме

#### Несоответствие threat model

| Аспект | SaaS платформа (microVM релевантен) | iclaude (microVM НЕ релевантен) |
|--------|-------------------------------------|----------------------------------|
| Кто запускает код | Пользователи SaaS — strangers | Сам пользователь на своей машине |
| Источник кода | User-submitted — hostile | Claude Code — trusted AI tool |
| Количество изолятов | Тысячи параллельно | 1 экземпляр на пользователя |
| Kernel exploit важен? | Да — multi-tenant | Нет — single-tenant |
| Главная угроза | Kernel exploit, tenant isolation | Prompt injection → policy leakage |

Статья прямо формулирует decision table:

> *"AI coding agent (single-tenant / self-hosted): semi-trusted, full Linux → hardened container or gVisor"*

iclaude попадает в категорию **single-tenant / self-hosted** — не multi-tenant SaaS.

#### Операционные барьеры для microVM в iclaude

1. **KVM зависимость.** KVM недоступен в CI, VMs, WSL1, некоторых cloud instances. iclaude уже обрабатывает WSL1 как unsupported — добавление KVM требования существенно сузит поддерживаемые платформы.

2. **Сложность lifecycle management.** Firecracker требует VMM процесс на VM, boot/snapshot/destroy lifecycle, virtio device management. iclaude — bash wrapper; добавление microVM превратит его в orchestration platform.

3. **PII proxy и CCR router несовместимы с guest isolation без дополнительной работы.** `ANTHROPIC_BASE_URL` и другие env vars нужно явно передавать в guest через cloud-init / vsock / virtio-serial. Это нетривиальная интеграция.

4. **Нарушение принципа минимальности.** Статья: *"MicroVMs recommended only for multi-tenant SaaS with hostile user-submitted code."* iclaude запускает Claude Code — известный, проверенный инструмент, не hostile code.

#### Когда microVM станет релевантным для iclaude

Если iclaude эволюционирует в **оркестратор агентских задач** с возможностью выполнения кода от разных пользователей или с multi-tenant доступом — microVM (Firecracker) становится правильным выбором для execution environment. В текущей форме — нет.

---

## Что реально улучшить: приоритизированные рекомендации

### Приоритет 1: Исправить bubblewrap или заменить Landlock+seccomp (Linux)

Статья точно описывает правильный подход для Linux local agents: **Landlock + seccomp**.

Landlock — непривилегированный LSM (Linux 5.13+), позволяет процессу ограничить собственный filesystem access. Ключевое свойство: ограничение **необратимо и наследуется дочерними процессами**.

```c
// Иллюстративный фрагмент (не production-ready: опущена инициализация
// struct landlock_ruleset_attr и struct landlock_path_beneath_attr)
int ruleset_fd = landlock_create_ruleset(&attr, sizeof(attr), 0);
landlock_add_rule(ruleset_fd, LANDLOCK_RULE_PATH_BENEATH, &rule, 0);
landlock_restrict_self(ruleset_fd, 0);
```

**Для iclaude:** Вместо `bwrap` (bubblewrap) можно использовать `landrun` — CLI обёртку вокруг Landlock (инструмент необходимо найти в актуальных репозиториях; официальные kernel tools: [linux/tools/testing/selftests/landlock](https://github.com/torvalds/linux/tree/master/tools/testing/selftests/landlock)):

```bash
# Концептуально: разрешить только workspace и конфиг dirs, запретить ~/ целиком
landrun \
  --allow-rw "${PWD}" \
  --allow-ro "${ISOLATED_NVM_DIR}" \
  --allow-ro "/tmp" \
  --deny "${HOME}/.ssh" \
  --deny "${HOME}/.aws" \
  -- claude "$@"
```

Преимущества перед bubblewrap:
- Не создаёт 0-байтных файлов в других проектах (нет upstream бага)
- Работает без `CAP_SYS_ADMIN`
- Linux 5.13+ (все современные дистрибутивы); текущее ядро хоста: **6.17** — полная поддержка включая TCP
- Ограничение filesystem + TCP (Linux 6.7+)

**Статус iclaude:** `detect_sandbox_platform()` уже возвращает "linux" как supported. `check_sandbox_dependencies()` проверяет `bwrap` — аналогичную функцию можно добавить для `landrun`.

### Приоритет 2: macOS Seatbelt — реализовать профиль

macOS Seatbelt уже частично поддержан в `lib/sandbox/detect.sh` (возвращает "macos", mark as supported). Нужен SBPL профиль:

```scheme
;; Минимальный профиль для Claude Code
(version 1)
(deny default)
(allow file-read* (subpath (string-append (getenv "HOME") "/Documents")))
(allow file-read-write* (subpath (string-append (getenv "HOME") "/Documents/Project")))
(allow file-read* (subpath "/usr/lib") (subpath "/usr/local/lib"))
(allow network-outbound (remote tcp "api.anthropic.com:443"))
(deny file-read* (subpath (string-append (getenv "HOME") "/.ssh")))
(deny file-read* (subpath (string-append (getenv "HOME") "/.aws")))
```

**Важно:** `sandbox-exec` (CLI обёртка вокруг Seatbelt) deprecated, но сам механизм активен. Современный путь — через entitlements или launchd. Для CLI wrapper `sandbox-exec` всё ещё работает на текущих macOS.

### Приоритет 3: Security hooks уже закрывают главную угрозу

Статья называет **policy leakage** главной AI-специфичной угрозой:

> *"If your sandbox can read the repo and has outbound network access, the agent can leak the repo. If it can read ~/.aws or mount host volumes, it can leak credentials."*

iclaude уже решает это через:

| Hook | Что закрывает | Статус |
|------|---------------|--------|
| `block-secrets.py` | Блокирует Read `.env`, `.pem`, `.ssh/`, `.gnupg/` (exit 2) | ✅ |
| `redact-secrets.py` | Маскирует API keys, JWT, PEM, AWS keys в Write/Edit/Bash | ✅ |
| `PII proxy` | Маскирует PII в API трафике до Anthropic серверов | ✅ (опционально) |

Текущие hooks адресуют exfiltration vector (утечка через файловые операции и API). **Это правильная стратегия для local agent threat model.**

Статья предлагает seccomp как дополнение (restrict syscalls) — для Claude Code это означало бы профиль ограничивающий `ptrace`, `mount`, `kexec_load`, `bpf`, `perf_event_open`. Это можно добавить поверх существующей sandbox.enabled инфраструктуры.

### Приоритет 4: Сетевая политика

Статья: *"Before picking a boundary, write down a minimum viable policy. Default-deny outbound network, then allowlist."*

Для iclaude: Claude Code требует доступ только к `api.anthropic.com:443`. Всё остальное — либо конфигурируемые инструменты (WebFetch, Bash с curl), либо не нужно самому клиенту.

Возможные улучшения:
- Документировать required outbound endpoints для `--proxy` и `--router` режимов
- В sandbox профиле (Seatbelt/Landlock) явно allowlist API endpoints

---

## Сравнение: текущий iclaude vs рекомендации статьи

| Аспект | Рекомендация статьи | Текущий iclaude | Gap |
|--------|---------------------|-----------------|-----|
| **Boundary** | OS sandbox (Landlock/Seatbelt) | Bubblewrap (disabled) | Нужна замена |
| **Policy — filesystem** | Deny-by-default, allowlist workspace | block-secrets.py (path blocklist) | Хорошо, но не exhaustive |
| **Policy — network** | Default-deny + allowlist | Нет ограничений | Gap |
| **Policy — secrets** | No long-lived credentials in sandbox | redact-secrets.py | Частично |
| **Lifecycle** | Fresh per run (local agent) | Fresh (каждый запуск новый процесс) | ✅ Соответствует |
| **Observability** | Log process tree, network egress, failures | log-tools.py, capture-tool-results.py | ✅ Есть |

---

## Итоговая оценка

### Что статья подтверждает (iclaude делает правильно)

1. Двухуровневая изоляция (config + OS-level boundary) — правильная архитектура.
2. Security hooks как policy layer — правильная стратегия для local agent threat model.
3. macOS Seatbelt как sandbox mechanism — правильный выбор для macOS (уже в roadmap).
4. Изолированная NVM среда (`.nvm-isolated/`) — правильный паттерн config isolation.

### Что нужно улучшить

1. **Критично:** Заменить bubblewrap на Landlock+seccomp (Linux) — устранить upstream bug, получить рабочий OS sandbox.
2. **Важно:** Реализовать macOS Seatbelt профиль — завершить уже начатую поддержку.
3. **Полезно:** Задокументировать minimum viable network policy для каждого режима запуска.
4. **Опционально:** Добавить seccomp профиль поверх sandbox для дополнительного сужения syscall attack surface.

### Что НЕ нужно делать

- **microVM (Firecracker, cloud-hypervisor)** — несоответствие threat model, операционная сложность несоразмерна задаче.
- **gVisor** — избыточно для single-tenant local agent; совместимость риска выше, чем security gain.
- **Wasm sandbox для Claude Code** — Claude Code — general-purpose ELF binary, не Wasm-совместимый workload.

---

## Связанные документы

- [docs/SECURITY_RESEARCH.md](SECURITY_RESEARCH.md) — исследование по улучшению `redact-secrets.py`
- [docs/SECURITY_PATTERNS_IMPROVEMENTS.md](SECURITY_PATTERNS_IMPROVEMENTS.md) — конкретные паттерны для hooks
- [CLAUDE.md](../CLAUDE.md) — sandbox limitations (bubblewrap bug documented)
- `lib/sandbox/` — текущая sandbox инфраструктура
- `lib/sandbox/detect.sh` — `detect_sandbox_platform()` — расширить для Landlock detection
- `lib/sandbox/install.sh` — `check_sandbox_dependencies()` — добавить landrun check
