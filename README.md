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
- **Метрики** - token usage, cache, стоимость
- **Сессии** - OSC 8 hyperlinks для навигации
- **Oh My Posh** - кастомные темы

### 🔒 Sandboxing
- **OS-level изоляция** - файловая система и сеть
- **Платформы** - macOS (Seatbelt), Linux/WSL2 (bubblewrap)

### 🐙 GitHub Integration
- **PR automation** - создание PR с автоматическим исправлением ошибок
- **CI/CD мониторинг** - GitHub Actions checks
- **gh CLI** - интеграция в изолированное окружение

### 🧠 Auto Memory
- **MEMORY.md** - persistent context в `.claude/memory/`
- **Best practices** - первые 200 строк → system prompt
- **Git versioning** - история изменений памяти

### 📄 Sphinx Documentation
- **Per-project** - работает в любом проекте, не только iclaude
- **docs/sphinx/** - изолированная поддиректория, не засоряет `docs/`
- **API Reference** - автогенерация из `lib/**/*.sh` комментариев
- **llms.txt** - AI-first индекс документации для LLM-агентов

### 📚 Skills System
- **Context Awareness** - автоопределение стека
- **LSP Integration** - автоустановка Language Servers
- **PR Automation** - создание PR + CI/CD мониторинг
- **Ralph-Loop** - итеративное выполнение с автокоррекцией

### 🤖 Agent System

Трёхуровневый пайплайн специализированных суб-агентов:

```
Пользователь → Researcher → [Gate] → Planner → [Gate] → Executor → report.md
```

| Агент | Что делает | Файлы |
|-------|-----------|-------|
| **Researcher** | Исследует кодовую базу (2 параллельных Explore) | → `research.toon` |
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

# Дополнительно
./iclaude.sh --install-statusline      # Установить Status Line
./iclaude.sh --sandbox-install         # Установить sandboxing (Linux/WSL2)

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

### Использовать DeepSeek вместо Anthropic

```bash
./iclaude.sh --install-router
# Редактировать .nvm-isolated/.claude-isolated/router.json
export DEEPSEEK_API_KEY="your-key"
./iclaude.sh --router
```

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
│   └── ...                             # 20+ модулей
├── .nvm-isolated/                      # Изолированная среда (~278MB)
│   ├── versions/node/                  # Node.js + npm
│   └── .claude-isolated/               # Конфигурация + skills
│       ├── skills/                     # Claude Code Skills
│       ├── agents/                     # Agent pipeline (Researcher, Planner, Executor, Critic)
│       ├── scripts/                    # Status Line и др.
│       ├── themes/                     # Oh My Posh темы
│       └── hooks/                      # Claude Code хуки (beforeCompact)
├── .claude/                            # Конфигурация Claude Code
│   ├── memory/                         # Auto Memory (MEMORY.md)
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
- `bubblewrap`, `socat` - для sandboxing на Linux/WSL2 (`./iclaude.sh --sandbox-install`)

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
- `.claude/memory/` - MEMORY.md (Auto Memory)

---

## 🤝 Вклад и поддержка

- **Issues:** https://github.com/ikeniborn/iclaude/issues
- **Pull Requests:** приветствуются
- **Документация:** [CLAUDE.md](./CLAUDE.md) - архитектура для контрибьюторов

---

## 📜 Лицензия

MIT License

---

## 🔗 Полезные ссылки

- [Claude Code Docs](https://code.claude.com/docs)
- [Claude API Docs](https://docs.anthropic.com)
- [Claude Code Router](https://github.com/zckly/claude-code-router)
- [Ralph Technique](https://ghuntley.com/ralph/)

---

**Версия:** 4.0 (Modular Architecture)
**Последнее обновление:** 2026-02-19
