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

### 📚 Skills System
- **Context Awareness** - автоопределение стека
- **LSP Integration** - автоустановка Language Servers
- **PR Automation** - создание PR + CI/CD мониторинг
- **Ralph-Loop** - итеративное выполнение с автокоррекцией

---

## 📖 Документация

### Основное
- **[Установка](./docs/INSTALLATION.md)** - изолированная и системная установка
- **[Конфигурация](./docs/CONFIGURATION.md)** - все команды и настройки (Quick Reference)
- **[Use Cases](./docs/USE_CASES.md)** - 8 практических примеров

### Специфичное
- **[Прокси](./docs/PROXY.md)** - настройка HTTP/HTTPS/SOCKS5
- **[Troubleshooting](./docs/TROUBLESHOOTING.md)** - решение проблем
- **[Status Line](./docs/STATUSLINE.md)** - метрики в терминале
- **[Claude Config](./docs/CLAUDE_CONFIG.md)** - переменные окружения
- **[Migration](./docs/MIGRATION.md)** - npm deprecation roadmap

### Техническое
- **[CLAUDE.md](./CLAUDE.md)** - архитектура проекта
- **[lib/loop/README.md](./lib/loop/README.md)** - Ralph-Loop документация
- **[lib/context/README.md](./lib/context/README.md)** - Context Management

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
./iclaude.sh --install-gh              # Установить GitHub CLI
./iclaude.sh --sandbox-install         # Установить sandboxing (Linux/WSL2)

# Управление
./iclaude.sh --check-config            # Статус конфигурации
./iclaude.sh --export-config /path     # Backup конфигурации
```

**Полный список:** См. [docs/CONFIGURATION.md](./docs/CONFIGURATION.md)

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
│       ├── scripts/                    # Status Line и др.
│       └── memory/                     # Auto Memory (MEMORY.md)
├── .nvm-isolated-lockfile.json         # Version lockfile
└── docs/                               # Документация
```

---

## 🛠️ Требования

**Минимальные (для изолированной установки):**
- Linux/macOS/WSL2
- `bash`, `curl`

**Опциональные:**
- `git` - для git-workflow skill
- `gh` - для pr-automation skill (`./iclaude.sh --install-gh`)
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
- `.nvm-isolated/.claude-isolated/scripts/` - scripts
- `.nvm-isolated/.claude-isolated/memory/` - MEMORY.md

---

## 🤝 Вклад и поддержка

- **Issues:** https://github.com/ikeniborn/claude/issues
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
**Последнее обновление:** 2026-02-13
