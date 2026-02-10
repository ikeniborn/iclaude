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

Скилл **pr-automation** автоматизирует полный цикл создания PR с автоматическим исправлением ошибок:

```bash
# Шаг 1: Установить gh CLI (один раз)
./iclaude.sh --install-gh
gh auth login

# Шаг 2: Проверить статус
./iclaude.sh --check-gh

# Шаг 3: Запустить Claude и создать PR
./iclaude.sh
# Внутри Claude Code:
"Создать PR из feature/my-feature в test"
```

**Что происходит автоматически:**
1. **Auto-detect** стека из `/docs/architecture/index.yaml`
2. **Анализ** CI/CD конфигурации (`.github/workflows/`)
3. **Создание** Draft PR с описанием
4. **Мониторинг** GitHub Actions checks
5. **Исправление** ошибок (TypeScript, ESLint, tests, build)
6. **Commit** фиксов с Conventional Commits
7. **Mark ready** для review после успешных проверок

**Поддерживаемые ошибки:**
- TypeScript: TS2322, TS2304, TS2345, TS2531, TS2532
- ESLint: no-console, no-unused-vars
- Vitest: assertion failures, mock issues
- Build: module not found, syntax errors

**Преимущества:**
- ✅ Экономия времени (автоматические итерации через ralph-loop)
- ✅ Качество (автоматическая валидация CI/CD)
- ✅ Консистентность (Conventional Commits)
- ✅ Адаптивность (работает с любым стеком через auto-detection)

**Документация:** `.nvm-isolated/.claude-isolated/skills/pr-automation/SKILL.md`

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

### Use Case 7: Безопасное выполнение с OS-level Sandboxing

Claude Code v2.0+ включает встроенный sandboxing для изоляции файловой системы и сети:

```bash
# Шаг 1: Проверить доступность sandboxing
./iclaude.sh --sandbox-check

# Шаг 2: Установить зависимости (Linux/WSL2)
./iclaude.sh --sandbox-install
# Устанавливает:
#   - bubblewrap (system package via apt-get/dnf)
#   - socat (system package via apt-get/dnf)
#   - @anthropic-ai/sandbox-runtime (npm package for seccomp filter)

# Шаг 3: Запустить Claude Code
./iclaude.sh

# Шаг 4: Включить sandbox в сессии
# Внутри Claude Code выполнить команду: /sandbox

# macOS пользователям (без установки)
./iclaude.sh --sandbox-check  # Shows "Ready" immediately
```

**Поддержка платформ:**

| Платформа | Поддержка | Требования | Команда |
|-----------|-----------|------------|---------|
| macOS | ✅ Native | Нет (встроенный Seatbelt) | N/A |
| Linux | ✅ Full | `bubblewrap`, `socat`, `@anthropic-ai/sandbox-runtime` | `--sandbox-install` |
| WSL2 | ✅ Full | `bubblewrap`, `socat`, `@anthropic-ai/sandbox-runtime` | `--sandbox-install` |
| WSL1 | ❌ Не поддерживается | Обновление до WSL2 | См. сообщение об ошибке |
| Windows | ❌ Не поддерживается | Использовать WSL2 | См. сообщение об ошибке |

**Возможности изоляции:**

1. **Файловая система:**
   - Ограничение доступа к чтению/записи для конкретных директорий
   - Защита от доступа к sensitive файлам (credentials, SSH keys)

2. **Сеть:**
   - Контроль доступа к доменам через proxy сервер
   - Allow/deny списки для доменов
   - Мониторинг сетевых запросов

**Два режима работы:**
- **Auto-allow**: Sandboxed команды авто-одобряются (быстрая итерация)
- **Regular permissions**: Требуется подтверждение пользователя (безопаснее)

**Интеграция с lockfile:**

Sandbox availability отслеживается в `.nvm-isolated-lockfile.json`:

```json
{
  "sandboxAvailable": true,
  "sandboxPlatform": "linux",
  "sandboxDependencies": {
    "bubblewrap": "0.8.0",
    "socat": "1.7.4.4"
  },
  "sandboxRuntimeVersion": "1.0.5",
  "sandboxInstalledAt": "2026-01-29T12:00:00Z"
}
```

При выполнении `./iclaude.sh --install-from-lockfile` зависимости sandboxing автоматически восстанавливаются, если `sandboxAvailable: true`.

**Troubleshooting:**

**WSL1 обнаружен:**
```bash
# Обновление до WSL2
wsl --set-version Ubuntu 2
wsl --shutdown
# Проверка
wsl --list --verbose
```

**Permission Denied:**
```bash
# Убедитесь в доступе sudo для системных пакетов
sudo apt-get install bubblewrap socat

# NPM пакет устанавливается в изолированную среду (sudo не требуется)
npm install -g @anthropic-ai/sandbox-runtime
```

**Примечания по безопасности:**
- Sandboxing не является идеальным (см. escape hatch механизм)
- Риск domain fronting (CDN могут обходить фильтры доменов)
- Возможна privilege escalation через unix socket
- Используйте доверенный proxy для сетевой изоляции
- Проверяйте настройки sandbox перед включением auto-allow режима

Полная документация: https://code.claude.com/docs/en/sandboxing

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

---

## 🔄 Ralph-Wiggum Plugin: Итеративное выполнение

Ralph-wiggum - официальный плагин Claude Code для **самореферентных итеративных циклов**. Интегрирован в Task Execution Template v6.0 как опциональный режим выполнения Phase 3.

### Что это такое?

**Ralph-wiggum** использует Stop hook для блокировки выхода из сессии и повторной инъекции того же prompt'а. Claude видит результаты предыдущих итераций (файлы, git history) и самостоятельно корректирует работу до достижения completion promise.

**Принцип работы:**
```
User: /ralph-loop "Fix all TypeScript errors" --completion-promise "BUILD SUCCESS"
  ↓
Iteration 1: Claude fixes 5 errors → npm run build → 12 errors remain → Loop continues
  ↓
Iteration 2: Claude fixes 7 errors → npm run build → 5 errors remain → Loop continues
  ↓
Iteration 3: Claude fixes 5 errors → npm run build → Success! → Outputs "BUILD SUCCESS" → EXIT
```

### Интеграция с Template v6.0

Template v6.0 добавляет **двухрежимное выполнение** в Phase 3:

| Mode | Описание | Когда использовать |
|------|----------|-------------------|
| **Mode A: Standard** | Традиционное выполнение | Single-pass задачи, ручная валидация |
| **Mode B: Ralph-Loop** | Итеративное выполнение | Автоматическая валидация, refinement tasks |

**Decision Criteria (автоматическая рекомендация):**
```
✓ Has automatic validation? (tests, linting, build)
✓ Multiple iterations expected? (>2 refinements)
✓ Completion detectable via validation output?
✓ Complexity = complex OR execution_steps > 5?
→ Claude recommends ralph-loop mode
```

### Когда использовать ralph-loop?

**✅ Используйте ralph-loop для:**
- Исправление compilation errors (TypeScript, Rust, Go)
- Рефакторинг для соответствия linting rules (ESLint, Pylint)
- Прохождение acceptance tests (pytest, jest)
- Задачи с чётким критерием завершения
- Greenfield проекты с автоматической валидацией

**❌ НЕ используйте ralph-loop для:**
- Single-pass задачи (добавление API endpoint)
- Ручная валидация (UI review, документация)
- Задачи без автоматической проверки
- Исследовательские задачи (exploration)

### Примеры использования

#### Пример 1: TypeScript Compilation Errors

```bash
# Standard workflow (v5.0)
"Fix all TypeScript compilation errors"
→ Manual iterations: fix → test → fix → test → fix → test (5+ prompts)

# Ralph-loop workflow (v6.0)
/ralph-loop "Fix all TypeScript compilation errors" \
  --completion-promise "COMPILED SUCCESSFULLY" \
  --max-iterations 20

→ Autonomous iterations: 3 iterations, automatic exit on success (1 prompt)
```

**Mode Selection (automatic):**
- ✓ Automatic validation: `npm run build`
- ✓ Iterations expected: Unknown (potentially many)
- ✓ Completion detectable: "Compiled successfully" in output
- ✓ Complexity: standard
- → **Claude recommends ralph-loop mode**

#### Пример 2: ESLint Refactoring

```bash
/ralph-loop "Refactor codebase to pass ESLint rules" \
  --completion-promise "LINT CLEAN" \
  --max-iterations 50
```

**Loop behavior:**
```
Iteration 1: Fix 15 violations → npm run lint → 47 violations remain
Iteration 2: Fix 22 violations → npm run lint → 25 violations remain
Iteration 3: Fix 18 violations → npm run lint → 7 violations remain
Iteration 4: Fix 7 violations → npm run lint → Success! → Output "LINT CLEAN" → EXIT
```

#### Пример 3: API Endpoint (Standard Mode)

```bash
# Ralph-loop НЕ рекомендуется (ручная валидация)
"Add GET /api/users endpoint"

Mode Selection:
- ✗ Single-pass task (create file, write code, test manually)
- ✗ Manual verification needed
- → Use standard execution
```

### Явная постановка задачи с ralph-loop

Если вы хотите **принудительно** использовать ralph-loop (минуя автоматический выбор режима), укажите параметры явно в описании задачи в template v6.0:

#### Способ 1: Структурированная инструкция (рекомендуется)

```markdown
## Задачи

Исправить все ошибки компиляции TypeScript в проекте.

**Режим выполнения:** ralph-loop
**Completion promise:** "COMPILED SUCCESSFULLY"
**Max iterations:** 20
**Validation command:** npm run build
```

#### Способ 2: Компактный формат

```markdown
## Задачи

Исправить все TypeScript ошибки используя ralph-loop
(promise: "COMPILED SUCCESSFULLY", max: 20, validation: npm run build)
```

#### Способ 3: Дополнительная секция

```markdown
## Задачи

Исправить все ошибки компиляции TypeScript.

## Execution Mode

**Force ralph-loop mode:**
- Task: "Fix all TypeScript compilation errors"
- Completion promise: "COMPILED SUCCESSFULLY"
- Max iterations: 20
- Validation: npm run build

---

## Execution Flow
...
```

**Важно указать:**
- ✅ **Completion promise** - точный текст из вывода валидации при успехе
- ✅ **Max iterations** - разумное число (20-50 в зависимости от сложности)
- ✅ **Validation command** - команда для проверки (если не очевидна из контекста)

**Поведение Claude:**
- Когда Claude видит явные параметры ralph-loop в Phase 1, он пропустит автоматический выбор режима
- В Phase 3 Claude сразу запустит ralph-loop с указанными параметрами
- Не требуется подтверждение пользователя (параметры уже заданы явно)

### Интеграция с Skills

Ralph-loop **дополняет** существующие skills, а не заменяет их:

| Phase | Skills (v5.0) | Ralph-loop (v6.0) |
|-------|--------------|------------------|
| 0 | context-awareness, adaptive-workflow | ← Same |
| 1 | thinking-framework, structured-planning | **+ execution_mode_recommendation** |
| 2 | approval-gates | ← Same |
| 3 | code-review | **+ ralph-loop [conditional]** |
| 4 | validation-framework, error-handling | ← Same |
| 5 | git-workflow | ← Same |

**Workflow в Phase 1:**
```json
{
  "task_plan": {
    "execution_mode_recommendation": {
      "mode": "ralph-loop",
      "confidence": "high",
      "reasoning": "Task has automatic validation (npm test) and requires iterative refinement",
      "ralph_config": {
        "completion_promise": "ALL TESTS PASSING",
        "max_iterations": 30,
        "validation_command": "npm test"
      }
    }
  }
}
```

**Workflow в Phase 3:**
```
Claude: "I recommend using ralph-loop for this task.
  - Validation: npm run build
  - Completion promise: 'COMPILED SUCCESSFULLY'
  - Max iterations: 20

Proceed with ralph-loop? (yes/no)"

User: "yes"

Claude: [Launches /ralph-loop command]
```

### Template v6.0 File Location

**Расположение:**
- **Repository:** `.nvm-isolated/.claude-isolated/task-lite-template-v6.0.md`
- **External:** `/home/ikeniborn/Documents/Notes/Work/ИИ/Prompt/Системные промты/template/task-lite-template-v6.0.md`

**Использование:**
```bash
# Передать template Claude при запуске
./iclaude.sh
# Внутри Claude:
"Use task-lite-template-v6.0.md for this task"
```

### Error Handling

Template v6.0 добавляет специальные error types для ralph-loop:

| Error Type | Action | Max Retries | Description |
|------------|--------|-------------|-------------|
| RALPH_MAX_ITERATIONS | STOP, report progress | 0 | Max iterations exhausted without completion |
| RALPH_STUCK_LOOP | Cancel ralph, ASK user | 0 | Same error repeated 3+ iterations |

**Recovery:**
```bash
# If ralph-loop gets stuck
/cancel-ralph  # Manual cancellation

# Check iteration count
grep '^iteration:' .claude/ralph-loop.local.md
```

### Monitoring Ralph-Loop

**Current iteration:**
```bash
# Ralph stores state in .claude/ralph-loop.local.md
cat .claude/ralph-loop.local.md
```

**Expected output:**
```yaml
---
iteration: 3
maxIterations: 20
completionPromise: "BUILD SUCCESS"
prompt: |
  Fix all TypeScript compilation errors
---
```

### Преимущества

**Для разработчика:**
- ✅ Снижение числа ручных итераций (1 prompt вместо 5-10)
- ✅ Автономная коррекция ошибок
- ✅ Гарантированное достижение completion promise
- ✅ Прозрачность через iteration count

**Для AI:**
- ✅ Видимость предыдущих попыток (files + git history)
- ✅ Самокоррекция на основе validation feedback
- ✅ Детерминированный exit condition

**Для проекта:**
- ✅ Atomic commits с полным результатом (не промежуточные состояния)
- ✅ Reproducible builds через completion promise
- ✅ Меньше мусора в git history

### Ограничения

**Ralph-loop НЕ подходит для:**
- ❌ Задач без автоматической валидации
- ❌ Исследовательских задач (exploration)
- ❌ UI/UX review (субъективная оценка)
- ❌ Задач с изменяющимися requirements
- ❌ Debugging без чёткого completion criteria

### Документация

- **Template v6.0:** `.nvm-isolated/.claude-isolated/task-lite-template-v6.0.md`
- **Plugin Source:** `.nvm-isolated/.claude-isolated/plugins/marketplaces/claude-plugins-official/plugins/ralph-loop/`
- **Official Docs:** [Ralph Technique](https://ghuntley.com/ralph/)

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

### 🔍 Выбор протокола прокси: HTTPS vs HTTP vs SOCKS5

#### Поддержка протоколов (официальная документация)

| Протокол | Статус | Рекомендация |
|----------|--------|--------------|
| **HTTPS** | ✅ Полная поддержка | **✅ Рекомендуется** |
| **HTTP** | ✅ Полная поддержка | ⚠️ Fallback вариант |
| **SOCKS5** | ❌ **НЕ поддерживается** | ❌ Вызывает краш приложения |

**Источник:** [Claude Code: Corporate Proxy Configuration](https://docs.claude.com/en/docs/claude-code/corporate-proxy)

---

#### ✅ HTTPS прокси (рекомендуется)

**Преимущества:**
- ✅ Официально рекомендован Anthropic
- ✅ Шифрование соединения клиент↔прокси
- ✅ Защита credentials от перехвата
- ✅ Поддержка самоподписанных сертификатов через `NODE_EXTRA_CA_CERTS`

**Недостатки:**
- ⚠️ **Критическая уязвимость:** undici не проверяет сертификаты целевых серверов ([HackerOne #1583680](https://hackerone.com/reports/1583680))
- ⚠️ Прокси-сервер может перехватывать весь HTTPS трафик (MitM)
- ⚠️ Требует доверия к прокси-серверу

**Когда использовать:**
- ✅ Корпоративные сети с доверенным прокси
- ✅ Приватные прокси в вашем контроле
- ✅ Когда важна защита credentials

**Конфигурация:**
```bash
# С сертификатом (SECURE)
./iclaude.sh --proxy https://proxy:8118 --proxy-ca /path/to/cert.pem

# Небезопасно (не рекомендуется)
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

---

#### ⚠️ HTTP прокси (fallback)

**Преимущества:**
- ✅ Официально поддерживается
- ✅ Простая настройка (не требует сертификаты)
- ✅ Работает как fallback если HTTPS недоступен

**Недостатки:**
- ❌ **Весь трафик передается открытым текстом** между клиентом и прокси
- ❌ Прокси видит все запросы, включая API ключи Claude
- ❌ Уязвим к перехвату на сетевом уровне
- ❌ Та же уязвимость undici с непроверкой сертификатов

**Когда использовать:**
- ⚠️ Только для локальных прокси (localhost)
- ⚠️ Разработка и тестирование
- ❌ НЕ использовать через интернет
- ❌ НЕ использовать в production

**Конфигурация:**
```bash
# Только для localhost!
./iclaude.sh --proxy http://localhost:8118
```

---

#### ❌ SOCKS5 прокси (НЕ РАБОТАЕТ)

**Статус:** **Полностью не поддерживается**

**Проблема:**
- Claude Code использует библиотеку `undici` для HTTP запросов
- undici [не поддерживает SOCKS протокол](https://github.com/nodejs/undici/issues/2224)
- При попытке использования **приложение крашится** с ошибкой:
  ```
  InvalidArgumentError: Invalid URL protocol:
  the URL must start with `http:` or `https:`
  ```

**Официальный комментарий Anthropic:**
> "This is a limitation of the undici proxy library that we use."
> — [GitHub Issue #3387](https://github.com/anthropics/claude-code/issues/3387)

**Обходные пути:**
1. **HTTP/HTTPS прокси** - используйте вместо SOCKS5
2. **Privoxy/squid** - локальный переходник SOCKS5 → HTTP:
   ```bash
   # Установить privoxy
   sudo apt install privoxy

   # Настроить forward-socks5 в /etc/privoxy/config
   forward-socks5 / 127.0.0.1:1080 .

   # Использовать privoxy как HTTP прокси
   ./iclaude.sh --proxy http://127.0.0.1:8118
   ```
3. **LLM Gateway** (LiteLLM) с поддержкой SOCKS5

---

#### 🎯 Рекомендации по выбору

**Для корпоративных сетей:**
```bash
# ЛУЧШИЙ ВАРИАНТ: HTTPS с корпоративным сертификатом
export HTTPS_PROXY=https://proxy.company.com:8118
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/company-proxy-ca.pem
./iclaude.sh
```

**Для разработки (localhost):**
```bash
# ПРИЕМЛЕМО: HTTP для локального прокси
export HTTP_PROXY=http://localhost:8118
export NO_PROXY="localhost,127.0.0.1"
./iclaude.sh
```

**Для production:**
```bash
# Рассмотрите LiteLLM Gateway вместо прямого прокси:
# - Продвинутая аутентификация (NTLM, Kerberos)
# - Централизованное управление безопасностью
# - Обход ограничений undici
```

---

#### ⚠️ Важные предупреждения безопасности

**Критическая уязвимость undici ProxyAgent:**

Независимо от использования HTTPS или HTTP прокси, библиотека undici имеет фундаментальную проблему:

- ❌ **Не проверяет сертификаты** целевых HTTPS серверов при работе через прокси
- ❌ Весь HTTPS трафик **потенциально уязвим к MitM атакам** со стороны прокси
- ❌ При HTTP прокси **весь трафик передается открытым текстом** клиент↔прокси

**Это означает:**
- Прокси-сервер может видеть и модифицировать все запросы к Anthropic API
- Прокси видит ваши API ключи, код проекта, персональные данные
- **Используйте только доверенные прокси-серверы**

**Источник:** [HackerOne Report #1583680](https://hackerone.com/reports/1583680)

---

#### 📊 Сравнительная таблица

| Критерий | HTTPS | HTTP | SOCKS5 |
|----------|-------|------|--------|
| **Официальная поддержка** | ✅ Рекомендуется | ✅ Поддерживается | ❌ Не работает |
| **Безопасность клиент↔прокси** | ✅ Шифрование | ❌ Открытый текст | N/A |
| **Безопасность прокси↔API** | ⚠️ Без проверки сертификатов | ⚠️ Без проверки сертификатов | N/A |
| **Простота настройки** | ⚠️ Требует сертификаты | ✅ Простая | N/A |
| **Корпоративные сети** | ✅✅ Лучший выбор | ⚠️ Не рекомендуется | ❌ Невозможно |
| **Локальная разработка** | ✅ Хороший выбор | ✅ Приемлемо | ❌ Невозможно |
| **Production** | ✅ С доверенным прокси | ❌ Не рекомендуется | ❌ Невозможно |

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

### SOCKS5 прокси - краш приложения

**Проблема:** `InvalidArgumentError: Invalid URL protocol: the URL must start with 'http:' or 'https:'`

**Причина:** Claude Code НЕ поддерживает SOCKS5 из-за ограничений библиотеки undici.

**Решение:** См. раздел [SOCKS5 прокси не работает](#socks5-прокси-не-работает) ниже или используйте HTTP/HTTPS прокси.

---

### После git clone симлинки не работают

**Симптомы:**
- `./iclaude.sh` выдает ошибки
- Claude Code не найден
- Команды npm/node не работают

**Решение:**
```bash
# Восстановить симлинки и права
./iclaude.sh --repair-isolated

# Проверить статус
./iclaude.sh --check-isolated
```

### LSP плагины не устанавливаются ("Plugin not found")

**Симптомы:**
- `./iclaude.sh --install-lsp` выдает ошибку:
  ```
  Plugin "typescript-lsp" not found in marketplace "claude-plugins-official"
  Plugin "pyright-lsp" not found in marketplace "claude-plugins-official"
  ```
- Плагины не находятся после переноса/переименования директории проекта

**Причина:**
- Claude Code хранит абсолютные пути в `known_marketplaces.json` и `installed_plugins.json`
- После переноса проекта пути становятся невалидными (например `/Project/claude/` → `/Project/iclaude/`)

**Решение:**
```bash
# Вариант 1: Автоматическое исправление через --repair-isolated
./iclaude.sh --repair-isolated

# Вариант 2: Только исправление путей плагинов
./iclaude.sh --repair-plugins

# После исправления повторить установку LSP
./iclaude.sh --install-lsp
./iclaude.sh --check-lsp
```

**Примечание:** Начиная с версии от 19.01.2026, пути плагинов автоматически проверяются и исправляются при каждом запуске (тихий режим).

### Проверка симлинков

```bash
./iclaude.sh --check-isolated

# Вывод покажет статус всех симлинков:
# Symlinks Status:
#   ✓ npm
#   ✓ npx
#   ✓ corepack
#   ✓ claude
#
# Если есть ✗ - запустить --repair-isolated
```

### Прокси не работает

```bash
# Тестировать подключение
./iclaude.sh --test

# Очистить настройки и ввести заново
./iclaude.sh --clear
./iclaude.sh
```

### HTTPS прокси с самоподписанным сертификатом

**Проблема:** `SSL certificate problem: self signed certificate`

**Решение 1 (безопасно):**
```bash
# Экспортировать сертификат прокси
openssl s_client -showcerts -connect proxy:8118 < /dev/null 2>/dev/null | \
  openssl x509 -outform PEM > proxy-cert.pem

# Использовать с --proxy-ca
./iclaude.sh --proxy https://proxy:8118 --proxy-ca ./proxy-cert.pem
```

**Решение 2 (небезопасно):**
```bash
# Отключить проверку TLS (не рекомендуется)
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

### Lockfile не обновляется после обновления

**Симптомы:**
- Claude Code обновился, но версия в lockfile осталась старой
- `./iclaude.sh --check-isolated` показывает разные версии:
  ```
  Claude Code: 2.0.26
  claudeCodeVersion: "2.0.25"  ← НЕ СОВПАДАЕТ
  ```

**Решение:**

✅ **Исправлено в версии от 24.10.2025** - обновите скрипт:
```bash
git pull
./iclaude.sh --update
```

Для старых версий скрипта:
```bash
# Вручную обновить lockfile
bash -c 'source ./iclaude.sh && save_isolated_lockfile'

# Проверить результат
./iclaude.sh --check-isolated
```

### Обновление не работает (NVM)

**Симптомы:** `ENOTEMPTY` ошибки при обновлении

**Решение для изолированной установки:**
```bash
# Очистить и переустановить
./iclaude.sh --cleanup-isolated
./iclaude.sh --install-from-lockfile
```

**Решение для системного NVM:**
```bash
# Запустить обновление повторно (автоматическая очистка)
iclaude --update

# Или вручную:
rm -rf ~/.nvm/versions/node/*/lib/node_modules/@anthropic-ai/.claude-code-*
npm install -g @anthropic-ai/claude-code@latest
```

### Git на Windows - симлинки не работают

**Проблема:** На Windows симлинки могут быть сохранены как текстовые файлы.

**Решение:**
```bash
# Включить поддержку симлинков в git
git config --global core.symlinks true

# Пересоздать репозиторий
cd ..
rm -rf claude
git clone https://github.com/ikeniborn/claude.git
cd claude

# Восстановить симлинки
./iclaude.sh --repair-isolated
```

### Конфликт изолированной и системной установки

**Симптомы:** Скрипт использует неправильную установку

**Решение:**

**Вариант 1: Флаг `--system` (Рекомендуется)**
```bash
# Проверить какая установка активна
./iclaude.sh --check-isolated

# Принудительно использовать системную установку (игнорируя изолированную)
./iclaude.sh --system
./iclaude.sh --system --update
./iclaude.sh --system --check-update

# Без флага --system (по умолчанию)
./iclaude.sh          # Использует изолированную (если есть)
./iclaude.sh --update # Обновит изолированную (если есть)
```

**Вариант 2: Использовать разные команды**
```bash
# Изолированная установка: ./iclaude.sh (с ./)
./iclaude.sh

# Системная установка: iclaude (без ./)
iclaude
```

**Приоритет окружения (без `--system`):**
1. Изолированное окружение (`.nvm-isolated/`) - если существует
2. Системный NVM - если установлен
3. Системный Node.js - если установлен

**С флагом `--system`:**
1. Системный NVM - если установлен
2. Системный Node.js - если установлен
3. Изолированное окружение пропускается

### SOCKS5 прокси не работает

**Симптомы:**
- Приложение крашится с ошибкой: `InvalidArgumentError: Invalid URL protocol`
- Ошибка: `the URL must start with 'http:' or 'https:'`

**Причина:**
- Claude Code использует библиотеку undici, которая **НЕ поддерживает SOCKS5**
- Это ограничение на уровне зависимости, не специфичное для Claude Code

**Решение:**

**Вариант 1: Использовать HTTP/HTTPS прокси**
```bash
# Вместо SOCKS5 используйте HTTP/HTTPS
./iclaude.sh --proxy https://proxy:8118
```

**Вариант 2: Прокси-переходник (Privoxy)**
```bash
# Установить privoxy
sudo apt install privoxy

# Настроить /etc/privoxy/config
echo "forward-socks5 / 127.0.0.1:1080 ." | sudo tee -a /etc/privoxy/config

# Перезапустить
sudo systemctl restart privoxy

# Использовать privoxy как HTTP прокси
./iclaude.sh --proxy http://127.0.0.1:8118
```

**Вариант 3: LLM Gateway**
```bash
# Использовать LiteLLM Gateway с поддержкой SOCKS5
# См. https://docs.litellm.ai/
```

**Официальный источник:**
- [GitHub Issue #3387](https://github.com/anthropics/claude-code/issues/3387)
- [Claude Docs: Corporate Proxy](https://docs.claude.com/en/docs/claude-code/corporate-proxy)

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
