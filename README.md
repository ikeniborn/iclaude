# iclaude

> Bash-обертка для запуска Claude Code с автоматической настройкой прокси и изолированной установкой

---

## 🚀 Быстрый старт

```bash
# Клонировать репозиторий
git clone https://github.com/ikeniborn/claude.git
cd claude

# Изолированная установка (рекомендуется)
./iclaude.sh --isolated-install

# Запуск
./iclaude.sh

# С прокси
./iclaude.sh --proxy https://user:pass@proxy.example.com:8118
```

---

## ✨ Основные возможности

### 📦 Изолированная установка
- **Портабельность** - весь стек в `.nvm-isolated/` (~278MB)
- **Lockfile** - воспроизводимые версии через `.nvm-isolated-lockfile.json`
- **Нет sudo** - установка без системных прав
- **Git-friendly** - коммит окружения или только lockfile

### 🌐 Прокси
- **HTTP/HTTPS** - автоматическая настройка
- **Credentials** - безопасное хранение (chmod 600)
- **TLS** - поддержка корпоративных сертификатов

### 🔀 Router
- **Альтернативные LLM** - DeepSeek, OpenRouter, Ollama, Gemini
- **Снижение затрат** - используйте более дешевые модели
- **Локальные модели** - полная приватность через Ollama

### 🎨 Status Line
- **Метрики** - dual context (cumulative billing + active NEW tokens), cache, стоимость, модель
- **Адаптивный режим** - три ширины: Full (≥130 cols), Compact (110-129), Minimal (<110) — автоматически
- **Multi-provider** - 🤖 OpenAI/DeepSeek/OpenRouter, 🦙 Ollama (local, $0.00), ✨ Gemini; 30+ моделей в pricing DB
- **Streaming** - 🔄 индикатор во время генерации; токены накапливаются в реальном времени
- **Сессии** - 📄 OSC 8 hyperlink на читаемую историю диалога (TOON формат); append-only (19× быстрее)
- **Память** - 🧠 OSC 8 hyperlink на `MEMORY.md` проекта (авто-память Claude Code)
- **PII** - 🛡 иконка со счётчиком замаскированных элементов; OSC 8 hyperlink на server log сессии
- **Oh My Posh** - кастомные темы

### 🕵️ PII Proxy

HTTP-прокси, который перехватывает **100% трафика к Anthropic API** и маскирует PII/секреты до отправки на серверы Anthropic:

- **Движок** — Presidio NLP (точное NER-распознавание) + детерминированный regex (всегда активен как fallback)
- **Охват** — `system prompt`, `messages[].content`, `tool_results` — все типы контента
- **Streaming** — SSE pass-through без буферизации (ответ в реальном времени)
- **Паттерны** — API keys, JWT, AWS credentials, PEM keys, GitHub tokens, пароли, кредитные карты

```bash
# Установить Python venv + Presidio (~500MB, один раз; повторный запуск — безопасен, идемпотентен)
./iclaude.sh --install-pii-proxy

# Принудительная переустановка всех компонентов с нуля
./iclaude.sh --install-pii-proxy --force

# Проверить статус
./iclaude.sh --check-pii-proxy

# Запустить с PII-маскированием (разово)
./iclaude.sh --pii-proxy

# Включить постоянно
echo 'USE_PII_PROXY=true' >> .claude_config
```

**Архитектура:** `claude → PII proxy (авто-порт 20000–40000) → Anthropic API`

**Уровни маскирования** (`PII_PROXY_MASKING_LEVEL` в `.claude_config`): `standard` (NLP+regex, по умолчанию) / `secrets` (только regex, без latency) / `off` (pass-through).

**Режимы логирования** (`PII_PROXY_LOG_LEVEL`):
- `info` (по умолчанию) — только счётчик: `Masked request: 3 sensitive item(s) found`
- `debug` — поле + тип + исходное значение + замена: `user[0].content: credentials in URL ("https://[CREDENTIALS]@corp.ru:8080" → "https://[CREDENTIALS]@")`. Лог **автоматически удаляется** при завершении сессии.

**Метрики в статуслайне:** при активном прокси в статуслайне появляется `🛡 N` — счётчик замаскированных элементов текущей сессии (live, обновляется каждые 30 сек). Иконка кликабельна и открывает server log сессии:
```
.nvm-isolated/.claude-isolated/pii-proxy-logs/fea76675eed6.log
```

**Документация:** [docs/PII_MASKING.md](./docs/PII_MASKING.md)

### 🔒 Security Hooks

Двухуровневая защита от случайной утечки секретов в запросы к LLM:

| Хук | Триггер | Действие |
|-----|---------|----------|
| `block-secrets.py` | Путь к файлу (`.env`, `.pem`, `.ssh/`) | Блокирует операцию (exit 2) |
| `redact-secrets.py` | Содержимое Write/Edit/Bash | Маскирует через `toolInputOverride` |

**Покрытые форматы секретов:**
- API keys: Anthropic, OpenAI, Stripe, OpenRouter (`sk-...`)
- AWS: Access Key ID (`AKIA...`), Secret Access Key
- GitHub: классические PAT (`ghp_`) и fine-grained PAT (`github_pat_`)
- JWT, PEM private keys (RSA/EC/DSA/OPENSSH/ENCRYPTED)
- URL credentials (`scheme://user:pass@host`) — любые схемы
- Пароли в конфигах (с кавычками и без), `.env`-переменные

**Важно:** `Edit.old_string` **не маскируется** намеренно — это поисковый паттерн, маскирование сломало бы операцию Edit.

**Документация:** [docs/PII_MASKING.md](./docs/PII_MASKING.md)

### 🔥 microVM Sandbox (Firecracker)

Kernel isolation через KVM: каждый инструментальный вызов Claude Code работает в гостевой ВМ с **отдельным Linux ядром**, изолированным от хостовой ОС.

- **Kernel isolation** — prompt injection → kernel exploit затрагивает guest kernel, не host
- **virtio-blk block devices** — `/dev/vdb` = NVM snapshot (RO, Node.js + claude), `/dev/vdc` = per-session workspace (RW, sparse ext4)
- **SSH exec** — claude выполняется **внутри guest** по SSH; host управляет только lifecycle
- **tar-over-SSH sync** — двунаправленная синхронизация workspace (full/path/isolated режимы)
- **IP-пул слотов** — `MICRO_VM_NET_SUBNET=172.16.0.0/26`, до 31 concurrent сессий без конфликтов адресов
- **OS matrix** — Ubuntu 22+, Debian 10+, ALT Linux 10+, WSL2 (с nested virt)

```bash
# Установить Firecracker + vmlinux + rootfs + nvm.img (~1.4GB, один раз)
./iclaude.sh --install-microvm

# Проверить готовность (KVM, образы, TAP, SSH ключ)
./iclaude.sh --check-microvm

# Запустить с microVM изоляцией
./iclaude.sh --sandbox-microvm

# Постоянный режим
echo 'MICRO_VM_ENABLED=true' >> .claude_config
```

**Архитектура v2:** `Firecracker VMM → guest-init (PID 1) → vdb:/mnt/nvm + vdc:/workspace → sshd → claude (inside guest)`

Полная документация: [docs/MICROVM.md](docs/MICROVM.md)

---

### 📄 Sphinx Documentation
- **Per-project** - работает в любом проекте, не только iclaude
- **docs/sphinx/** - изолированная поддиректория, не засоряет `docs/`
- **API Reference** - автогенерация из `lib/**/*.sh` комментариев
- **llms.txt** - AI-first индекс документации для LLM-агентов

### 📚 Skills System
- **Context Awareness** - автоопределение стека
- **LSP Integration** - автоустановка Language Servers
- **PR Automation** - создание PR + CI/CD мониторинг
- **Agent Orchestrator** - пайплайн Researcher → Critic → Planner → Executor

### 🤖 Agent System

Четырёхуровневый пайплайн специализированных суб-агентов:

```
Пользователь → Researcher → [Critic] → [Gate] → Planner → [Critic] → [Gate] → Executor → [Critic] → Report
```

| Агент | Что делает | Файлы |
|-------|-----------|-------|
| **Researcher** | Исследует кодовую базу (2 параллельных Explore) | → `research.toon` |
| **Critic** | Оценивает артефакт (PASS/WARN/RETRY/ABORT) | → `*-critique.toon` |
| **Planner** | Создаёт пошаговый план на основе research | → `plan.toon` |
| **Executor** | Вносит изменения в код, валидирует, коммитит | → `report.md` |

**Запуск:**
```
/agent-orchestrator <описание задачи>
```

**Артефакты** хранятся в `.claude/workspace/{session-id}/` (в `.gitignore`).
Approval gates после каждого агента — можно остановиться на любом этапе.

**Пример 1 — простая задача:**
```
/agent-orchestrator Добавить поддержку нового LSP языка
```
→ Researcher: находит `lib/command/args.sh`, complexity=minimal
→ Planner: 2 фазы, 4 шага
→ Executor: 2 коммита, report.md со статусом COMPLETED

**Пример 2 — сложная задача:**
```
/agent-orchestrator Refactor proxy management to use async/await
```
→ Researcher: 8 файлов, complexity=complex, риски high
→ Planner: 4 фазы, approval gate для фаз с риском high
→ Executor: запрашивает подтверждение перед breaking changes

**Агенты:** `.nvm-isolated/.claude-isolated/agents/`
**Оркестратор:** `.nvm-isolated/.claude-isolated/skills/agent-orchestrator/SKILL.md`

---

## 📖 Документация

### Основное
- **[Установка](./docs/INSTALLATION.md)** - изолированная и системная установка
- **[Конфигурация](./docs/CONFIGURATION.md)** - все команды и настройки (Quick Reference)
- **[Use Cases](./docs/USE_CASES.md)** - 8 практических примеров

### Специфичное
- **[Прокси](./docs/PROXY.md)** - настройка HTTP/HTTPS/SOCKS5
- **[Status Line](./docs/STATUSLINE.md)** - метрики в терминале
- **[Claude Config](./docs/CLAUDE_CONFIG.md)** - переменные окружения
- **[Migration](./docs/MIGRATION.md)** - npm deprecation roadmap
- **[PII Masking](./docs/PII_MASKING.md)** - маскирование секретов (security hooks)
- **[microVM Sandbox](./docs/MICROVM.md)** - Firecracker kernel isolation: установка, запуск, troubleshooting
- **[Sandbox Analysis](./docs/SANDBOX_ANALYSIS.md)** - threat model, выбор уровня изоляции

### Техническое
- **[CLAUDE.md](./CLAUDE.md)** - архитектура проекта

---

## 💡 Популярные команды

```bash
# Установка
./iclaude.sh --isolated-install        # Изолированная установка
./iclaude.sh --install-from-lockfile   # Установка из lockfile

# Запуск
./iclaude.sh                           # Стандартный запуск
./iclaude.sh --proxy https://proxy:8118 # С прокси
./iclaude.sh --router                  # Через Claude Code Router
./iclaude.sh --no-chrome               # Без Chrome integration

# Обновление
./iclaude.sh --update                  # Обновить Claude Code
./iclaude.sh --check-isolated          # Проверить статус

# Ремонт
./iclaude.sh --repair-isolated         # Починить симлинки после git clone
./iclaude.sh --repair-plugins          # Починить пути плагинов

# PII Proxy (маскирование персональных данных)
./iclaude.sh --install-pii-proxy       # Установить Presidio NLP (идемпотентно — пропускает актуальные)
./iclaude.sh --install-pii-proxy --force  # Переустановить всё с нуля
./iclaude.sh --check-pii-proxy         # Статус venv, моделей, PID
./iclaude.sh --pii-proxy               # Запуск с PII-маскированием

# microVM (Firecracker kernel isolation)
./iclaude.sh --install-microvm        # Установить Firecracker + образы (~350MB)
./iclaude.sh --check-microvm          # Проверить KVM, nvm.img, TAP, SSH ключ
./iclaude.sh --sandbox-microvm        # Запустить с kernel isolation

# Дополнительно
./iclaude.sh --install-statusline      # Установить Status Line
# Oh My Posh (опционально, для красивого status line)
./iclaude.sh --install-posh            # Скачать и установить (автоматически)
./iclaude.sh --insecure --install-posh # То же, но с корпоративным прокси (TLS)
./iclaude.sh --check-posh              # Проверить статус

# Управление
./iclaude.sh --check-config            # Статус конфигурации
./iclaude.sh --export-config /path     # Backup конфигурации
```

**Полный список:** См. [docs/CONFIGURATION.md](./docs/CONFIGURATION.md)

---

## 📄 Sphinx документация

```bash
# Первый раз: инициализировать Sphinx в проекте
./iclaude.sh --init-docs               # текущий проект
./iclaude.sh --init-docs /path/to/proj # другой проект

# Установить Python-зависимости (один раз, в .nvm-isolated/.python-docs/)
./iclaude.sh --install-docs

# Собрать документацию
./iclaude.sh --build-docs              # HTML + llms.txt
./iclaude.sh --build-docs --clean      # с очисткой кэша

# Просмотр в браузере
./iclaude.sh --serve-docs              # localhost:8000
./iclaude.sh --serve-docs $(pwd) 9000  # другой порт

# Статус
./iclaude.sh --check-docs
```

**Результат:**
```
docs/sphinx/
├── conf.py          ← конфигурация Sphinx
├── index.md         ← toctree (ссылается на docs/*.md)
├── api-reference/   ← автогенерация из lib/*.sh
└── _build/html/
    ├── index.html   ← HTML сайт
    └── llms.txt     ← индекс для AI-агентов
```

---

## 🎯 Quick Start Examples

### Deploy на новый сервер (без npm)

```bash
git clone https://github.com/ikeniborn/claude.git
cd claude
./iclaude.sh --repair-isolated
sudo ./iclaude.sh --create-symlink
iclaude  # Работает глобально
```

### Настроить прокси

```bash
# HTTPS с сертификатом (безопасно)
./iclaude.sh --proxy https://proxy:8118 --proxy-ca /path/to/cert.pem

# HTTP для localhost
./iclaude.sh --proxy http://localhost:8118

# Тестировать
./iclaude.sh --test
```

### Маскировать PII/секреты в API-трафике

```bash
# Установить Presidio NLP (идемпотентно: пропускает уже установленные компоненты)
./iclaude.sh --install-pii-proxy

# Повторный запуск безопасен — покажет что пропущено, что установлено:
# ✓ venv: already exists, skipping creation
# ✓ Presidio: already installed, skipping pip install
# ✓ spaCy en_core_web_lg: already installed, skipping download (587MB saved)
# ✓ Server script: up to date
# Принудительная переустановка с нуля:
./iclaude.sh --install-pii-proxy --force

# Постоянный режим — добавить в конфиг
echo 'USE_PII_PROXY=true' >> .claude_config
./iclaude.sh

# Разовый запуск без изменения конфига
./iclaude.sh --pii-proxy

# Проверить что всё работает
./iclaude.sh --check-pii-proxy
```

**Примечание:** `--pii-proxy` и `--router` работают вместе в режиме цепочки:
`claude → PII proxy (авто-порт) → CCR (:3456) → провайдеры`

**Параллельные сессии:** каждый запуск `./iclaude.sh --pii-proxy` получает изолированный прокси-процесс на отдельном порту из диапазона 20000–40000. Сессии не конфликтуют и не зависят друг от друга.

**Важно:** PII proxy venv **не хранится в git** (~500MB). После `git clone` или `git pull` на новой машине нужно переустановить:
```bash
./iclaude.sh --repair-isolated   # напомнит если venv отсутствует
./iclaude.sh --install-pii-proxy
```

### Использовать DeepSeek вместо Anthropic

```bash
./iclaude.sh --install-router
# Редактировать .nvm-isolated/.claude-isolated/router.json
export DEEPSEEK_API_KEY="your-key"
./iclaude.sh --router
```

**Ограничение CCR + Anthropic:** Claude Code Router **не может** использовать OAuth токен подписки для роутинга к Anthropic API. `api.anthropic.com` возвращает `401 "OAuth authentication is currently not supported"` при попытке использовать `sk-ant-oat01-...` токен. Для роутинга через CCR к Anthropic нужен отдельный API ключ (`sk-ant-api03-...`) с [console.anthropic.com](https://console.anthropic.com/settings/keys). Без него — используйте Ollama/DeepSeek/OpenRouter.

**Больше примеров:** См. [docs/USE_CASES.md](./docs/USE_CASES.md)

---

## 🔧 Структура проекта

```
.
├── iclaude.sh                          # Модульный entry point
├── lib/                                # Bash библиотеки (v4.0)
│   ├── core/                           # Validation, logging
│   ├── proxy/                          # Proxy управление
│   ├── nvm/                            # NVM/Node.js/Claude detection
│   ├── oauth/                          # OAuth token management
│   ├── router/                         # Claude Code Router
│   ├── lsp/                            # LSP server management
│   ├── lockfile/                       # Version locking
│   ├── sandbox/                        # microVM (Firecracker)
│   └── ...                             # 16 модулей
├── .nvm-isolated/                      # Изолированная среда (~278MB)
│   ├── versions/node/                  # Node.js + npm
│   └── .claude-isolated/               # Конфигурация + skills
│       ├── skills/                     # Claude Code Skills
│       ├── agents/                     # Agent pipeline (Researcher, Planner, Executor, Critic)
│       ├── scripts/                    # Status Line и др.
│       ├── themes/                     # Oh My Posh темы
│       └── hooks/                      # PreToolUse/PostToolUse хуки
│           ├── block-secrets.py        # Блокировка по пути файла
│           └── redact-secrets.py       # Маскирование содержимого
├── .claude/                            # Конфигурация Claude Code
│   └── skills/                         # Навыки проекта
├── .nvm-isolated-lockfile.json         # Version lockfile
└── docs/                               # Документация
    └── sphinx/                         # Sphinx (HTML + llms.txt)
```

---

## 🛠️ Требования

**Минимальные (для изолированной установки):**
- Linux/macOS/WSL2
- `bash`, `curl`

**Опциональные:**
- `git` - для git-workflow skill
- `gh` - для pr-automation skill (установить через `gh` пакетный менеджер)
- `kvm` (`/dev/kvm`) - для microVM sandbox (`./iclaude.sh --install-microvm`)

---

## 📝 Файлы и безопасность

**Не в git:**
- `.claude_proxy_credentials` - прокси credentials (chmod 600)
- `.nvm-isolated/.claude-isolated/*` - сессии, история, credentials

**В git:**
- `.nvm-isolated/` - изолированное окружение (опционально)
- `.nvm-isolated-lockfile.json` - version lockfile
- `.nvm-isolated/.claude-isolated/skills/` - skills
- `.nvm-isolated/.claude-isolated/agents/` - agent pipeline
- `.nvm-isolated/.claude-isolated/scripts/` - scripts
- `.nvm-isolated/.claude-isolated/themes/` - Oh My Posh темы
- `.nvm-isolated/.claude-isolated/hooks/` - Claude Code хуки

---

## 🤝 Вклад и поддержка

- **Issues:** https://github.com/ikeniborn/iclaude/issues
- **Pull Requests:** приветствуются
- **Документация:** [CLAUDE.md](./CLAUDE.md) - архитектура для контрибьюторов

---

## 📜 Лицензия

[Apache License 2.0](./LICENSE)

---

## 🔗 Полезные ссылки

- [Claude Code Docs](https://code.claude.com/docs)
- [Claude API Docs](https://docs.anthropic.com)
- [Claude Code Router](https://github.com/zckly/claude-code-router)

---

**Версия:** 4.0 (Modular Architecture)
**Последнее обновление:** 2026-03-12
