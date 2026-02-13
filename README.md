# iclaude - Запуск Claude Code через прокси

> Автоматическая настройка прокси и запуск Claude Code. Введите настройки один раз - используйте многократно.

---

## 📋 Содержание

- [Что это?](#что-это)
- [⚡ Quick Reference](#-quick-reference)
  - [🔧 Системные команды](#-системные-команды)
  - [📦 Изолированные команды](#-изолированные-команды)
  - [⚙️ Конфигурация](#️-конфигурация)
  - [🌐 Proxy](#-proxy)
- [💡 Use Cases](#-use-cases)
- [📚 Шаблоны и Skills для разработки](#-шаблоны-и-skills-для-разработки)
- [🔄 Ralph-Wiggum Plugin: Итеративное выполнение](#-ralph-wiggum-plugin-итеративное-выполнение)
- [Варианты установки](#варианты-установки)
  - [📦 Изолированная установка (Рекомендуется)](#-изолированная-установка-рекомендуется)
  - [🖥️ Системная установка](#️-системная-установка)
- [Использование](#использование)
  - [🔍 Выбор протокола прокси](#-выбор-протокола-прокси-https-vs-http-vs-socks5)
- [Обновление](#обновление)
- [Troubleshooting](#troubleshooting)

---

## Что это?

Утилита для быстрого запуска Claude Code через HTTP/HTTPS прокси с автоматическим сохранением настроек.

### Возможности

✅ Настройка прокси один раз
✅ Автоматическое сохранение credentials
✅ Безопасное хранение паролей
✅ Поддержка HTTP и HTTPS прокси (SOCKS5 НЕ поддерживается)
✅ Проверка подключения перед запуском
✅ **Изолированная установка** - портабельность через git
✅ **Воспроизводимые версии** через lockfile
✅ **Claude Code Router** - использование альтернативных LLM провайдеров (OpenRouter, DeepSeek, Ollama, Gemini)

---

## ⚡ Quick Reference

Быстрый справочник по всем командам для ускоренного знакомства с утилитой.

### 🔧 Системные команды

Работают с системным npm/node (требуют предварительную установку зависимостей).

| Команда | Описание | Sudo | Зависимости |
|---------|----------|------|-------------|
| `--install` | Полная системная установка | ✅ | apt, npm (~200MB) |
| `--uninstall` | Удаление системной установки | ✅ | - |
| `--update` | Обновление системного Claude Code | ✅* | npm |
| `--check-update` | Проверка доступных обновлений | ❌ | - |
| `--system` | Принудительно использовать системную установку | ❌ | - |

<sub>*Требуется sudo только для системной установки</sub>

### 📦 Изолированные команды

Работают с `.nvm-isolated/` (НЕ требуют системный npm).

| Команда | Описание | Sudo | Зависимости |
|---------|----------|------|-------------|
| `--isolated-install` | Установка изолированной среды | ❌ | curl, bash |
| `--isolated-update` | Обновление изолированного Claude Code | ❌ | - |
| `--install-from-lockfile` | Установка из lockfile (воспроизводимость) | ❌ | curl, bash |
| `--create-symlink` | Создание глобального симлинка | ✅ | isolated env |
| `--uninstall-symlink` | Удаление симлинка | ✅ | - |
| `--repair-isolated` | Починка симлинков после git clone | ❌ | - |
| `--repair-plugins` | Починка путей плагинов после переноса проекта | ❌ | - |
| `--check-isolated` | Статус изолированной среды | ❌ | - |
| `--cleanup-isolated` | Удаление изолированной среды (сохраняет lockfile) | ❌ | - |

<sub>✨ **Преимущество:** НЕ загружает 200MB+ системных пакетов</sub>

### ⚙️ Конфигурация

Управление конфигурацией Claude Code.

| Команда | Описание |
|---------|----------|
| `--check-config` | Статус текущей конфигурации |
| `--isolated-config` | Использовать изолированную конфигурацию |
| `--shared-config` | Использовать общую конфигурацию (`~/.claude/`) |
| `--export-config <path>` | Экспорт конфигурации в backup |
| `--import-config <path>` | Импорт конфигурации из backup |

### 🌐 Proxy

Настройка и тестирование прокси.

| Команда | Описание |
|---------|----------|
| `--proxy <url>` | Установка прокси (http/https/socks5) |
| `--test` | Тестирование прокси подключения |

### 🎛️ Claude Code Configuration

Управление параметрами Claude Code через файл `.claude_proxy_credentials`.

**Расположение:** `.claude_proxy_credentials` (в корне проекта)

**Доступные переменные:**

| Переменная | Описание | Значение по умолчанию |
|------------|----------|----------------------|
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | Лимит output токенов | 32000 (макс: 128000) |
| `CLAUDE_CODE_ENABLE_TASKS` | Tasks system (вкл/выкл) | true |
| `CLAUDE_CODE_NO_CHROME` | Отключить Chrome integration | false |
| `CLAUDE_CODE_MODEL` | Выбор модели | claude-4-5-sonnet |
| `CLAUDE_CODE_SESSION_TIMEOUT` | Таймаут сессии (секунды) | 3600 |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Agent Teams ⚠️ EXPERIMENTAL | не установлено (выкл) |

**Пример конфигурации:**

```bash
# .claude_proxy_credentials

# Proxy settings
PROXY_URL=https://user:pass@proxy.example.com:8118
PROXY_INSECURE=false
NO_PROXY=localhost,127.0.0.1

# Claude Code configuration
CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000    # Увеличенный лимит (для сложных задач)
# CLAUDE_CODE_MODEL=claude-3-opus       # Закомментировано = не используется
# CLAUDE_CODE_NO_CHROME=true            # Закомментировано = не используется
```

**⚠️ Важно:** Только **раскомментированные** переменные будут экспортированы при запуске. Закомментированные (`#`) переменные игнорируются.

**Подробная документация:** См. [CLAUDE_CONFIG.md](./docs/CLAUDE_CONFIG.md) для полного списка переменных и примеров.
| `--clear` | Очистка сохраненных credentials |
| `--no-proxy` | Запуск без прокси |
| `--proxy-ca <file>` | CA сертификат для HTTPS прокси (✅ SECURE) |
| `--proxy-insecure` | Отключить проверку TLS (⚠️ NOT RECOMMENDED) |

### 🔀 Router

Интеграция с Claude Code Router для альтернативных LLM провайдеров.

| Команда | Описание |
|---------|----------|
| `--install-router` | Установка Claude Code Router |
| `--check-router` | Статус router и конфигурации |
| `--router` | Запуск через router (по умолчанию native) |

<sub>✨ **Поддерживаемые провайдеры:** OpenRouter, DeepSeek, Ollama, Gemini, OpenAI, Volcengine, SiliconFlow</sub>

### 🎨 Oh My Posh

Интеграция с oh-my-posh для кастомных prompts.

| Команда | Описание |
|---------|----------|
| `--install-posh` | Установка oh-my-posh + кастомных тем |
| `--install-ohmyposh` | Алиас для `--install-posh` |
| `--check-posh` | Статус oh-my-posh установки |

### 📊 Status Line & Display

Метрики и визуализация для Claude Code.

| Команда | Описание |
|---------|----------|
| `--install-statusline` | Установка скрипта метрик для Claude Code |
| `--check-statusline` | Проверка статуса statusline |

### 🔧 Repair & Restore

Восстановление и ремонт конфигурации.

| Команда | Описание |
|---------|----------|
| `--restore-git-proxy` | Восстановить git proxy из backup |
| `--refresh-token` | Обновить OAuth токен (~1 year lifetime) |

### 🧠 Auto Memory

Управление памятью Claude Code (MEMORY.md).

| Команда | Описание |
|---------|----------|
| `--context-memory-organize [PATH]` | Разбить MEMORY.md на топик-файлы |
| `--context-memory-init` | Создать MEMORY.md |
| `--context-memory-validate` | Проверить 200 строк лимит |
| `--context-memory-add "text"` | Добавить запись |
| `--context-memory-status` | Статус Auto Memory |

### 🔒 Sandbox Integration

OS-level изоляция файловой системы и сети для безопасного выполнения.

| Команда | Описание |
|---------|----------|
| `--sandbox-check` | Проверка доступности и требований |
| `--sandbox-install` | Установка системных зависимостей (Linux/WSL2) |

<sub>✅ **Поддержка платформ:** macOS (native Seatbelt), Linux (bubblewrap+socat+sandbox-runtime), WSL2 (bubblewrap+socat+sandbox-runtime)</sub>

### 🌐 Chrome Integration

Интеграция с Google Chrome для автоматизации браузерных задач.

**Chrome интеграция ВКЛЮЧЕНА ПО УМОЛЧАНИЮ.** Для отключения:

```bash
./iclaude.sh --no-chrome
```

**Требования:**
- Google Chrome browser
- Claude in Chrome extension v1.0.36+
- Claude Code CLI v2.0.73+
- Paid Claude plan (Pro/Team/Enterprise)

**Возможности:**
- Навигация по страницам и открытие вкладок
- Клики по элементам и ввод текста
- Заполнение форм
- Чтение логов консоли и сетевых запросов
- Запись GIF взаимодействий

**Когда отключать:**
- Нет установленного Chrome browser
- Не нужна браузерная автоматизация для текущей задачи
- Хотите снизить потребление контекста

<sub>⚠️ **Важно:** Chrome интеграция увеличивает потребление контекста даже если не используется</sub>

### 🐙 GitHub CLI

Интеграция с GitHub CLI для автоматизации PR workflow.

| Команда | Описание |
|---------|----------|
| `--install-gh` | Установка gh CLI в изолированное окружение |
| `--check-gh` | Статус gh CLI и авторизации |

<sub>✨ **Используется скиллом:** pr-automation для создания PR и мониторинга CI/CD</sub>

---

## 💡 Use Cases

Типичные сценарии использования с пошаговыми инструкциями.

### Use Case 1: Deploy на новый сервер (БЕЗ системного npm)

Самый быстрый способ развертывания без установки системных зависимостей:

```bash
# Шаг 1: Клонировать репозиторий (включает .nvm-isolated/)
git clone https://github.com/ikeniborn/claude.git
cd claude

# Шаг 2: Починить симлинки после git clone
./iclaude.sh --repair-isolated

# Шаг 3: Создать глобальный симлинк (БЕЗ системного npm!)
sudo ./iclaude.sh --create-symlink

# Шаг 4: Использовать глобально
iclaude  # ✓ Работает из любой директории
```

**Преимущества:**
- ✅ Не требует `apt install npm` (экономия 200MB+)
- ✅ Готово за 3 команды
- ✅ Полная портабельность

### Use Case 2: Обновление изолированного Claude Code

```bash
# Проверить текущую версию
./iclaude.sh --check-isolated

# Обновить до последней версии (БЕЗ sudo!)
./iclaude.sh --isolated-update

# Проверить новую версию
./iclaude.sh --check-isolated
```

**Вывод будет:**
```
Current version: 2.0.28
Running: npm update -g @anthropic-ai/claude-code
...
✓ Claude Code updated successfully
  Previous version: 2.0.28
  New version:      2.0.29
```

### Use Case 3: Временное переключение на системную установку

Если у вас есть и изолированная, и системная установка:

```bash
# Запустить из системной установки (игнорируя изолированную)
iclaude --system

# Обновить системную установку
sudo iclaude --system --update
```

### Use Case 4: Управление симлинками

```bash
# Создать глобальный симлинк
sudo ./iclaude.sh --create-symlink

# Проверить куда указывает симлинк
ls -la /usr/local/bin/iclaude

# Удалить симлинк (сохранить изолированную среду)
sudo iclaude --uninstall-symlink

# Повторно создать симлинк
sudo ./iclaude.sh --create-symlink
```

### Use Case 5: Автоматизация создания Pull Request

Автоматизация PR workflow с мониторингом CI/CD и автоисправлением ошибок:

```bash
# Установить gh CLI (один раз)
./iclaude.sh --install-gh
gh auth login

# Создать PR через Claude
./iclaude.sh
"Создать PR из feature/my-feature в test"
```

**Возможности:**
- ✅ Auto-detect стека и CI/CD конфигурации
- ✅ Создание Draft PR с описанием
- ✅ Мониторинг GitHub Actions checks
- ✅ Автоматическое исправление ошибок (TypeScript, ESLint, tests)

**Подробнее:** См. `.nvm-isolated/.claude-isolated/skills/pr-automation/SKILL.md`

---

### Use Case 6: Использование альтернативных LLM провайдеров через Router

Claude Code Router позволяет использовать DeepSeek, OpenRouter, OpenAI, Ollama и другие провайдеры вместо Anthropic API:

```bash
# Шаг 1: Установить Claude Code Router
./iclaude.sh --install-router

# Шаг 2: Настроить провайдер в router.json
# Редактировать .nvm-isolated/.claude-isolated/router.json
# (используйте ${VAR_NAME} для API ключей)

# Шаг 3: Экспортировать API ключ
export DEEPSEEK_API_KEY="your-key-here"

# Шаг 4: Запустить через router (требуется флаг --router)
./iclaude.sh --router

# Проверить статус router
./iclaude.sh --check-router

# Запуск по умолчанию (native Claude, без router)
./iclaude.sh
```

**Преимущества:**
- ✅ Снижение затрат (DeepSeek дешевле Anthropic API)
- ✅ Локальные модели через Ollama (полная приватность)
- ✅ Доступ к нескольким провайдерам (OpenRouter → Claude/GPT/Gemini)
- ✅ Полная совместимость с Claude Code API

**Пример конфигурации** (`.nvm-isolated/.claude-isolated/router.json`):
```json
{
  "providers": {
    "deepseek": {
      "type": "deepseek",
      "apiKey": "${DEEPSEEK_API_KEY}",
      "baseURL": "https://api.deepseek.com"
    }
  },
  "models": {
    "claude-sonnet-4-5": {
      "provider": "deepseek",
      "model": "deepseek-chat",
      "maxTokens": 8000
    }
  },
  "routing": {
    "default": "claude-sonnet-4-5"
  }
}
```

---

### Use Case 7: Кастомная Status Line

Показывает метрики Claude Code в терминале:

```bash
# Установка
./iclaude.sh --install-posh
./iclaude.sh --install-statusline

# Запуск
./iclaude.sh
# Отображается: 50,000 tokens | Sonnet 4.5 | $1.06
```

**Метрики:**
- Token usage (cumulative + active)
- Cache visibility
- Model name
- Cost tracking
- Session links (OSC 8 hyperlinks)

**Подробнее:** См. [docs/STATUSLINE.md](./docs/STATUSLINE.md)

---

### Use Case 8: Безопасное выполнение с OS-level Sandboxing

OS-level изоляция файловой системы и сети:

```bash
# Проверить доступность
./iclaude.sh --sandbox-check

# Установить зависимости (Linux/WSL2)
./iclaude.sh --sandbox-install

# Запустить Claude Code
./iclaude.sh

# Включить sandbox в сессии: /sandbox
```

**Поддержка платформ:**

| Платформа | Поддержка | Требования |
|-----------|-----------|------------|
| macOS | ✅ Native | Нет (встроенный Seatbelt) |
| Linux | ✅ Full | `bubblewrap`, `socat`, `@anthropic-ai/sandbox-runtime` |
| WSL2 | ✅ Full | `bubblewrap`, `socat`, `@anthropic-ai/sandbox-runtime` |
| WSL1/Windows | ❌ Не поддерживается | Использовать WSL2 |

**Возможности:**
- Ограничение доступа к файловой системе
- Контроль сетевых запросов
- Allow/deny списки для доменов

**Документация:** https://code.claude.com/docs/en/sandboxing

---

## 📚 Шаблоны и Skills для разработки

Проект включает систему **Claude Code Skills** - модульные шаблоны для автоматизации разработки с использованием AI.

### Что это?

**Skills** - специализированные модули с готовыми шаблонами, чеклистами и примерами для типовых задач:
- ✅ Context Awareness (автоопределение языка, framework, PRD)
- ✅ LSP Integration (автоустановка Language Server Protocol плагинов)
- ✅ Context7 Integration (автозагрузка документации библиотек через Context7 MCP)
- ✅ Structured Planning (планирование с JSON валидацией)
- ✅ Validation Framework (проверка acceptance criteria, синтаксиса)
- ✅ Git Workflow (Conventional Commits, changelog generation)
- ✅ Thinking Framework (структурированный reasoning)
- ✅ Phase Execution (выполнение сложных задач по фазам)
- ✅ Task Decomposition (разбиение задач на 2-5 фаз)
- ✅ **PR Automation** (создание PR, мониторинг CI/CD, автоисправление ошибок)

### Два режима работы

**1. Simple Tasks (task-lite-template)**
Для простых задач (<10 steps, один компонент):
```
"Добавь метод calculate_total в BudgetService"
"Исправь bug с null pointer в validator"
"Создай функцию для ротации credentials"
```

**2. Phase-Based Workflow ([task-planning-template-v3.md](task-planning-template-v3.md) + [task-execution-template-v3.md](task-execution-template-v3.md))**
Для сложных задач (>10 steps, multiple компоненты):
```
# Шаг 1: Разбить на фазы (task-planning-template-v3.md)
"Разбей задачу 'Добавить JWT auth' на фазы"
→ Создает master plan + phase-1.md, phase-2.md, phase-3.md

# Шаг 2: Выполнить поэтапно (task-execution-template-v3.md)
"Выполни Phase 1 из plans/phase-1-database-models.md"
→ Checkpoint → Execute → Validation → Commit

"Выполни Phase 2 из plans/phase-2-backend-api.md"
→ Checkpoint → Execute → Validation → Commit
```

### Quick Start

**Для простой задачи:**
```bash
# 1. Описать задачу Claude
"Добавь флаг --timeout для ограничения времени ожидания"

# Claude автоматически:
# - Создаст план (structured-planning)
# - Запросит подтверждение (approval-gates)
# - Реализует функцию (bash-development)
# - Провалидирует результат (validation-framework)
# - Создаст commit (git-workflow)
```

**Для сложной задачи:**
```bash
# 1. Декомпозиция
"Разбей задачу 'Добавить систему аутентификации' на фазы"
→ Создает master-plan.md + 3 phase files

# 2. Выполнение по фазам
"Выполни Phase 1"  # Database models → commit
"Выполни Phase 2"  # Backend API → commit
"Выполни Phase 3"  # Frontend → commit

# Результат: 3 atomic commits, каждый можно rollback отдельно
```

### Преимущества

- ✅ **Экономия контекста:** 60-70% токенов для phase-based tasks
- ✅ **Модульность:** Каждый skill = отдельная responsibility
- ✅ **Atomic commits:** Phase-based workflow создает отдельный commit на фазу
- ✅ **Checkpoint validation:** Гарантирует корректность между фазами
- ✅ **Переиспользуемость:** Skills работают в любых проектах

### Детальная документация

**Skills:**
- **[SKILLS.md](SKILLS.md)** - Полная документация всех 11 skills с примерами
- **[.claude/skills/](/.claude/skills/)** - Исходники всех skills

**Templates:**
- **[task-lite-template-v6.0.md](.nvm-isolated/.claude-isolated/task-lite-template-v6.0.md)** - Adaptive workflow + ralph-loop integration - **РЕКОМЕНДУЕТСЯ (LATEST)**
- **[task-lite-template-v3.1.md](task-lite-template-v3.1.md)** - Simple tasks (одна фаза, <10 steps)
- **[task-planning-template-v3.1.md](task-planning-template-v3.1.md)** - Планирование (разбиение на 2-5 фаз)
- **[task-execution-template-v3.1.md](task-execution-template-v3.1.md)** - Выполнение одной фазы

**Project Documentation:**
- **[CLAUDE.md](CLAUDE.md)** - Архитектура проекта и Phase-Based Workflow

**Дополнительные руководства:**
- **[docs/STATUSLINE.md](./docs/STATUSLINE.md)** - Метрики в терминале
- **[lib/loop/README.md](./lib/loop/README.md)** - Параллельное выполнение задач
- **[lib/context/README.md](./lib/context/README.md)** - Управление памятью

---

## 🔄 Ralph-Wiggum Plugin: Итеративное выполнение

Официальный плагин Claude Code для автоматических итеративных циклов с самокоррекцией.

### Что это?

Ralph-wiggum автоматически повторяет задачу до достижения успешного результата. Claude видит предыдущие попытки и корректирует код на основе ошибок валидации.

**Пример использования:**
```bash
# Автоматическое исправление TypeScript ошибок
/ralph-loop "Fix all TypeScript errors" \
  --completion-promise "COMPILED SUCCESSFULLY" \
  --max-iterations 20

# Итерации: fix → build → fix → build → SUCCESS
```

### Когда использовать?

**✅ Подходит для:**
- Исправление compilation errors (TypeScript, Rust, Go)
- Рефакторинг для linting rules (ESLint, Pylint)
- Прохождение тестов (pytest, jest)
- Задачи с автоматической валидацией

**❌ НЕ подходит для:**
- Single-pass задачи
- Ручная валидация (UI review, документация)
- Исследовательские задачи

### Преимущества

- ✅ Экономия времени (1 команда вместо 5-10 ручных итераций)
- ✅ Автономная коррекция ошибок
- ✅ Прозрачность через iteration count
- ✅ Atomic commits с полным результатом

**Подробнее:** См. [lib/loop/README.md](./lib/loop/README.md) и [task-lite-template-v6.0.md](.nvm-isolated/.claude-isolated/task-lite-template-v6.0.md)

---

## Prerequisites (Внешние зависимости)

Некоторые Skills используют внешние зависимости. Все они **опциональны** - Skills работают в fallback режиме без них.

### Обязательные зависимости

Только для Skills, связанных с Git:
- **Git** - version control (обязательно для git-workflow, pr-automation)
- **GitHub CLI (gh)** - создание PR, управление issues (обязательно для pr-automation)

Установка:
```bash
# Ubuntu/Debian
sudo apt install git gh

# macOS
brew install git gh

# Аутентификация gh
gh auth login
```

### Опциональные зависимости

Расширяют возможности Skills (не обязательны):

| Зависимость | Skills | Назначение | Установка |
|-------------|--------|-----------|-----------|
| **LSP Servers** | lsp-integration, code-review | Enhanced type checking | `/plugin install pyright-lsp` + `npm install -g pyright` |
| **Context7 MCP** | context7-integration, structured-planning | Library docs, code examples | `npx @modelcontextprotocol/create-server context7` |
| **Ralph-Loop Plugin** | pr-automation | Авто-фикс CI/CD errors | `/plugin install ralph-loop` |

**Детальная документация:** См. [External Dependencies Guide](.nvm-isolated/.claude-isolated/skills/_shared/external-dependencies.md)

**Проверка установленных зависимостей:**
```bash
# CLI tools
git --version
gh --version

# Внутри Claude Code сессии
/plugin list    # Claude plugins
/mcp list       # MCP servers
```

---

## Варианты установки

Выберите подходящий вариант установки в зависимости от ваших потребностей.

### 📦 Изолированная установка (Рекомендуется)

Изолированная установка размещает NVM, Node.js и Claude Code в директории проекта (`.nvm-isolated/`). Это обеспечивает полную портабельность и избегает конфликтов с системными установками.

#### Когда использовать:

✅ Нужна портабельность между машинами
✅ Избежание конфликтов с системным Node.js/NVM
✅ Работа без sudo на других машинах
✅ Воспроизводимые версии через lockfile
✅ Возможность коммитить окружение в git

#### Первая установка

```bash
# Клонировать репозиторий
git clone https://github.com/ikeniborn/claude.git
cd claude

# Установить в изолированное окружение
./iclaude.sh --isolated-install

# Это создаст:
# - .nvm-isolated/                  (~278MB, в git)
# - .nvm-isolated-lockfile.json     (lockfile с версиями, в git)
```

#### Установка на другой машине (git clone)

**Вариант 1: Использование полного окружения из git**

```bash
# 1. Клонировать репозиторий (включает .nvm-isolated/)
git clone https://github.com/ikeniborn/claude.git
cd claude

# 2. Восстановить симлинки после git clone
./iclaude.sh --repair-isolated

# 3. Готово! Запуск
./iclaude.sh
```

**Вариант 2: Установка из lockfile (легче для git)**

```bash
# 1. Клонировать репозиторий (включает только lockfile)
git clone https://github.com/ikeniborn/claude.git
cd claude

# 2. Установить из lockfile (точные версии)
./iclaude.sh --install-from-lockfile

# 3. Готово! Запуск
./iclaude.sh
```

#### Проверка статуса

```bash
# Проверить статус изолированного окружения
./iclaude.sh --check-isolated

# Вывод:
# - Версии Node.js, npm, Claude Code
# - Статус симлинков (✓/✗)
# - Содержимое lockfile
```

#### Обновление Claude Code

```bash
# Обновить Claude Code в изолированном окружении
./iclaude.sh --update

# После обновления автоматически:
# ✅ Обновляется Claude Code к последней версии
# ✅ Обновляется lockfile с новой версией
# ✅ Восстанавливаются симлинки и права доступа

# Проверить что lockfile обновился корректно
./iclaude.sh --check-isolated
# Должны совпадать:
# - Claude Code: X.X.X
# - claudeCodeVersion: "X.X.X" (в lockfile)
```

**Примечание:** Начиная с версии от 24.10.2025, проблема с обновлением lockfile исправлена. Lockfile теперь всегда обновляется автоматически вместе с Claude Code.

#### Очистка

```bash
# Удалить изолированное окружение (сохраняет lockfile)
./iclaude.sh --cleanup-isolated

# Для переустановки:
./iclaude.sh --install-from-lockfile
```

#### 🔐 Изолированная конфигурация

По умолчанию Claude Code хранит все данные (историю, сессии, credentials) в общей директории `~/.claude/`, которая используется всеми установками (изолированной и системной). Это может привести к потере данных при переключении между установками.

**Изолированная конфигурация** решает эту проблему, создавая отдельное хранилище для каждой установки:

```bash
# Изолированная установка → .nvm-isolated/.claude-isolated/
# Системная установка → ~/.claude/
```

**Автоматическое поведение:**

- При использовании изолированной установки конфигурация автоматически изолируется
- При использовании системной установки (`--system`) используется общая конфигурация `~/.claude/`
- Можно явно управлять поведением через флаги

**Управление конфигурацией:**

```bash
# Проверить текущую конфигурацию
./iclaude.sh --check-config

# Явно использовать изолированную конфигурацию
./iclaude.sh --isolated-config

# Явно использовать общую конфигурацию (по умолчанию)
./iclaude.sh --shared-config

# Экспортировать конфигурацию в backup
./iclaude.sh --export-config /path/to/backup

# Импортировать конфигурацию из backup
./iclaude.sh --import-config /path/to/backup
```

**Что изолируется:**

- ✅ История команд (`history.jsonl`)
- ✅ Активные сессии (`session-env/`)
- ✅ Credentials (`.credentials.json`)
- ✅ Настройки (`settings.json`)
- ✅ Проектные настройки (`projects/`)
- ✅ TODO-списки (`todos/`)
- ✅ История файлов (`file-history/`)

**Примечание:** Изолированная конфигурация добавляется в `.gitignore` и не коммитится в git. Используйте `--export-config` для создания backup.

---

### 🖥️ Системная установка

Системная установка размещает команду `iclaude` в `/usr/local/bin/` и использует системный или существующий NVM для Claude Code.

#### Когда использовать:

✅ Нужна глобальная установка для всех пользователей
✅ Уже есть системный Node.js
✅ Не требуется портабельность

#### Установка

```bash
# Установить глобально (требует sudo)
cd /path/to/claude
sudo ./iclaude.sh --install

# После установки команда доступна из любой директории
iclaude --help
```

**Автоматическая установка зависимостей:**

При первой установке скрипт автоматически проверит и предложит установить:
- ✅ Node.js и npm (если отсутствуют) - через официальный репозиторий NodeSource
- ✅ Claude Code (если отсутствует) - через `npm install -g @anthropic-ai/claude-code`

#### Обновление Claude Code

```bash
# Проверить доступные обновления
iclaude --check-update

# Обновить к последней версии
sudo iclaude --update  # Для системной установки
# или
iclaude --update       # Для NVM установки (без sudo)
```

#### Удаление

```bash
# Удалить команду (сохраняет настройки прокси)
sudo iclaude --uninstall

# Очистить сохраненные настройки прокси
iclaude --clear
```

---

## Использование

После установки (изолированной или системной) использование одинаковое.

### Первый запуск

```bash
# Изолированная установка
./iclaude.sh

# Системная установка
iclaude
```

Программа попросит ввести proxy URL в формате:
```
http://username:password@host:port
https://username:password@host:port
```

**⚠️ Важно:** SOCKS5 прокси НЕ поддерживаются Claude Code из-за ограничений библиотеки undici.

**Примеры:**
```bash
http://alice:secret123@127.0.0.1:8118
https://user:pass@proxy.example.com:8118
```

### Последующие запуски

```bash
# Использует сохраненные настройки автоматически
./iclaude.sh  # изолированная
iclaude       # системная
```

### ⚙️ Конфигурация Claude Code через переменные окружения

iclaude.sh поддерживает настройку параметров Claude Code через файл `.claude_proxy_credentials` в корне проекта.

#### Решение проблемы "output token maximum exceeded"

Если вы столкнулись с ошибкой:
```
API Error: Claude's response exceeded the 32000 output token maximum.
To configure this behavior, set the CLAUDE_CODE_MAX_OUTPUT_TOKENS environment variable.
```

**Решение:** Добавьте в `.claude_proxy_credentials`:

```bash
# Увеличить лимит до 64000 токенов
CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000
```

Или до максимума (128000):
```bash
CLAUDE_CODE_MAX_OUTPUT_TOKENS=128000
```

#### Доступные переменные конфигурации

Отредактируйте файл `.claude_proxy_credentials`:

```bash
# Proxy settings (настраиваются автоматически)
PROXY_URL=https://user:pass@proxy.example.com:8118
PROXY_INSECURE=false
NO_PROXY=localhost,127.0.0.1

# ===== Claude Code Configuration =====

# 1. Лимит output токенов (default: 32000, max: 128000)
CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000

# 2. Tasks system (default: true)
# CLAUDE_CODE_ENABLE_TASKS=true

# 3. Chrome integration (default: включена)
# CLAUDE_CODE_NO_CHROME=false

# 4. Выбор модели (default: claude-4-5-sonnet)
# CLAUDE_CODE_MODEL=claude-3-opus

# 5. Session timeout в секундах (default: 3600)
# CLAUDE_CODE_SESSION_TIMEOUT=7200
```

**⚠️ Важно:**
- Только **раскомментированные** переменные (без `#`) будут применены
- Закомментированные переменные игнорируются при запуске
- Изменения применяются при следующем запуске `./iclaude.sh`

#### Практические примеры конфигурации

**Пример 1: Работа со сложными задачами (рефакторинг, большие файлы)**

```bash
# Максимальный лимит + модель Opus
CLAUDE_CODE_MAX_OUTPUT_TOKENS=128000
CLAUDE_CODE_MODEL=claude-3-opus
CLAUDE_CODE_SESSION_TIMEOUT=7200
```

**Пример 2: Экономия контекста (отключить Chrome)**

```bash
# Базовая конфигурация без браузера
CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000
CLAUDE_CODE_NO_CHROME=true
```

**Пример 3: Быстрые правки (модель Haiku)**

```bash
# Быстрая и дешевая модель
CLAUDE_CODE_MODEL=claude-3-haiku
CLAUDE_CODE_MAX_OUTPUT_TOKENS=32000
```

#### Проверка применения конфигурации

Проверить, что переменные загружаются правильно:

```bash
bash -c "source ./iclaude.sh && load_claude_config && env | grep CLAUDE_CODE"
```

Ожидаемый вывод:
```
CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000
CLAUDE_CODE_ENABLE_TASKS=true
...
```

#### Подробная документация

См. [CLAUDE_CONFIG.md](./docs/CLAUDE_CONFIG.md) для:
- Полного списка переменных
- Описания каждого параметра
- Дополнительных примеров
- Troubleshooting

### Безопасная работа с HTTPS прокси

**Рекомендуется** использовать `--proxy-ca` для HTTPS прокси с самоподписанными сертификатами:

```bash
# SECURE (рекомендуется)
./iclaude.sh --proxy https://proxy:8118 --proxy-ca /path/to/proxy-cert.pem
```

**Не рекомендуется** использовать `--proxy-insecure` (отключает TLS для всех подключений):

```bash
# ⚠️ INSECURE (не рекомендуется)
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

Как получить сертификат прокси:
```bash
# Экспортировать сертификат
openssl s_client -showcerts -connect proxy.example.com:8118 < /dev/null 2>/dev/null | \
  openssl x509 -outform PEM > proxy-cert.pem

# Или получить справку
./iclaude.sh --help-export-cert
```

### 🔍 Выбор протокола прокси

| Протокол | Статус | Рекомендация |
|----------|--------|--------------|
| **HTTPS** | ✅ Полная поддержка | **✅ Рекомендуется** |
| **HTTP** | ✅ Полная поддержка | ⚠️ Только для localhost |
| **SOCKS5** | ❌ **НЕ поддерживается** | ❌ Вызывает краш приложения |

**HTTPS прокси (рекомендуется):**
```bash
# С сертификатом (безопасно)
./iclaude.sh --proxy https://proxy:8118 --proxy-ca /path/to/cert.pem

# Без проверки сертификата (не рекомендуется)
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

**HTTP прокси (только для localhost):**
```bash
# Для локальной разработки
./iclaude.sh --proxy http://localhost:8118
```

**SOCKS5 - обходные пути:**
```bash
# Используйте Privoxy как переходник
sudo apt install privoxy
# Настроить: forward-socks5 / 127.0.0.1:1080 .
./iclaude.sh --proxy http://127.0.0.1:8118
```

⚠️ **Важно:** Используйте только доверенные прокси-серверы. Библиотека undici не проверяет сертификаты целевых серверов ([HackerOne #1583680](https://hackerone.com/reports/1583680)).

**Источники:**
- [Claude Code: Corporate Proxy](https://docs.claude.com/en/docs/claude-code/corporate-proxy)
- [GitHub Issue #3387](https://github.com/anthropics/claude-code/issues/3387)

---

### Другие команды

```bash
# Изменить прокси
./iclaude.sh --proxy http://new:proxy@host:port

# Запустить без прокси
./iclaude.sh --no-proxy

# Тестировать прокси без запуска Claude
./iclaude.sh --test

# Очистить сохраненные настройки
./iclaude.sh --clear

# Использовать системную установку (игнорируя изолированную)
./iclaude.sh --system

# Передать аргументы в Claude Code
./iclaude.sh -- --model claude-3-opus
```

---

## Обновление

### Изолированная установка

```bash
# Обновить Claude Code
./iclaude.sh --update

# Автоматически:
# ✅ Обновляет Claude Code к последней версии
# ✅ Обновляет lockfile с новой версией
# ✅ Восстанавливает симлинки и права доступа

# Проверить статус после обновления
./iclaude.sh --check-isolated

# Проверьте, что версии совпадают:
# Claude Code: 2.0.26
# claudeCodeVersion: "2.0.26" (в lockfile)
```

**✨ Исправление (24.10.2025):** Проблема с обновлением lockfile в изолированной среде была исправлена. Теперь lockfile всегда обновляется автоматически при запуске `--update`.

### Системная установка

```bash
# Проверить доступные обновления
iclaude --check-update

# Обновить (требует sudo для системной установки)
sudo iclaude --update

# Для NVM установки (без sudo)
iclaude --update
```

---

## Troubleshooting

### После git clone симлинки не работают

**Решение:**
```bash
./iclaude.sh --repair-isolated
./iclaude.sh --check-isolated
```

### LSP плагины не устанавливаются

**Причина:** Claude Code хранит абсолютные пути. После переноса проекта пути становятся невалидными.

**Решение:**
```bash
./iclaude.sh --repair-plugins
./iclaude.sh --install-lsp
```

### SOCKS5 прокси не работает

**Причина:** Claude Code НЕ поддерживает SOCKS5 (ограничение undici).

**Решение:**
```bash
# Вариант 1: Использовать HTTP/HTTPS
./iclaude.sh --proxy https://proxy:8118

# Вариант 2: Privoxy как переходник
sudo apt install privoxy
# Настроить: forward-socks5 / 127.0.0.1:1080 .
./iclaude.sh --proxy http://127.0.0.1:8118
```

### HTTPS прокси с самоподписанным сертификатом

**Решение (безопасно):**
```bash
openssl s_client -showcerts -connect proxy:8118 < /dev/null 2>/dev/null | \
  openssl x509 -outform PEM > proxy-cert.pem
./iclaude.sh --proxy https://proxy:8118 --proxy-ca ./proxy-cert.pem
```

**Решение (небезопасно):**
```bash
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

### Прокси не работает

```bash
./iclaude.sh --test
./iclaude.sh --clear
```

### Конфликт изолированной и системной установки

**Решение:**
```bash
# Принудительно использовать системную
./iclaude.sh --system

# По умолчанию использует изолированную (если есть)
./iclaude.sh
```

---

## Дополнительная информация

### Файлы

**Изолированная установка:**
- `.nvm-isolated/` - изолированная установка NVM (~278MB, в git)
- `.nvm-isolated-lockfile.json` - lockfile с версиями (в git)
- `.claude_proxy_credentials` - прокси credentials (chmod 600, НЕ в git)

**Системная установка:**
- `/usr/local/bin/iclaude` - глобальная команда
- `~/.claude_proxy_credentials` - прокси credentials (chmod 600)

### Справка

```bash
# Полная справка
./iclaude.sh --help
iclaude --help

# Справка по экспорту сертификатов
./iclaude.sh --help-export-cert
```

### Поддержка

- Репозиторий: https://github.com/ikeniborn/claude
- Issues: https://github.com/ikeniborn/claude/issues

---

## Context Management System

Управление контекстом Claude Code и Auto Memory с best practices от Anthropic.

**Подробнее:** См. [lib/context/README.md](./lib/context/README.md)

### ⚡ Быстрый старт

**CLI (вне сессии):**
```bash
./iclaude.sh --context-status              # Статус контекста
./iclaude.sh --context-export              # Экспорт в архив
./iclaude.sh --context-sync pull           # Синхронизация worktree
./iclaude.sh --context-clean 30            # Очистка старых данных
./iclaude.sh --context-backup manual       # Создание backup
```

**Skill (внутри сессии):**
```bash
/context-management status                 # Статус контекста
/context-management export                 # Экспорт в архив
/context-management sync pull              # Синхронизация worktree
```

### 🧠 Auto Memory (Best Practices)

MEMORY.md хранится в `.claude/memory/` проекта, версионируется в git.

**CLI:**
```bash
./iclaude.sh --context-memory-init         # Создать MEMORY.md
./iclaude.sh --context-memory-validate     # Проверить 200 строк лимит
./iclaude.sh --context-memory-add "text"   # Добавить запись
./iclaude.sh --context-memory-status       # Статус Auto Memory
```

**Skill:**
```bash
/context-management memory-init            # Создать MEMORY.md
/context-management memory-validate        # Проверить best practices
/context-management memory-add "text"      # Добавить запись
/context-management memory-status          # Статус Auto Memory
```

**Best Practices:**
- ✅ Первые 200 строк → system prompt каждой сессии
- ✅ Специфичные записи: "Use 2-space YAML indent" (не "proper indent")
- ✅ Организация с заголовками
- ✅ Топик-файлы для деталей >200 строк

### 🎯 Решенные проблемы

| Проблема | Решение |
|----------|---------|
| Потеря контекста при `/compact` | beforeCompact hook + snapshots |
| Память в `~/.claude/` | MEMORY.md в `.claude/memory/` проекта |
| Нет версионирования памяти | MEMORY.md в git |
| Изоляция git worktrees | Shared memory sync |
| Рост истории (10 MB+) | Автоочистка + trimming |

### 📚 Документация

- **Best Practices**: https://code.claude.com/docs/en/memory
- **Skill**: `.nvm-isolated/.claude-isolated/skills/context-management/SKILL.md`

**Версия**: 1.0.0 | **Статус**: ✅ Готово к использованию
