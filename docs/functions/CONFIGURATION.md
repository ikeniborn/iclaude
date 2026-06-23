# Конфигурация iclaude

Полный справочник по всем командам и настройкам.

> **Note:** All `.claude_config` variables must use the `ICLAUDE_` prefix (e.g. `ICLAUDE_USE_PII_PROXY=true`). Legacy files without the prefix are auto-migrated on first launch with a `.claude_config.bak` backup created automatically.

---

## ⚡ Quick Reference

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
| `--clear` | Очистка сохраненных credentials |
| `--no-proxy` | Запуск без прокси |
| `--proxy-ca <file>` | CA сертификат для HTTPS прокси (✅ SECURE) |
| `--proxy-insecure` | Отключить проверку TLS (⚠️ NOT RECOMMENDED) |

**Подробнее:** См. [PROXY.md](./PROXY.md)

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

**Подробнее:** См. [STATUSLINE.md](./STATUSLINE.md)

### 🔧 Repair & Restore

Восстановление и ремонт конфигурации.

| Команда | Описание |
|---------|----------|
| `--restore-git-proxy` | Восстановить git proxy из backup |
| `--refresh-token` | Обновить OAuth токен (~1 year lifetime) |

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

---

## 🎛️ Claude Code Configuration

Управление параметрами Claude Code через файл `.claude_proxy_credentials`.

**Расположение:** `.claude_proxy_credentials` (в корне проекта)

### Доступные переменные

| Переменная | Описание | Значение по умолчанию |
|------------|----------|----------------------|
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | Лимит output токенов | 32000 (макс: 128000) |
| `CLAUDE_CODE_ENABLE_TASKS` | Tasks system (вкл/выкл) | true |
| `CLAUDE_CODE_NO_CHROME` | Отключить Chrome integration | false |
| `CLAUDE_CODE_MODEL` | Выбор модели | claude-4-5-sonnet |
| `CLAUDE_CODE_SESSION_TIMEOUT` | Таймаут сессии (секунды) | 3600 |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Agent Teams ⚠️ EXPERIMENTAL | не установлено (выкл) |

### Пример конфигурации

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

**Подробная документация:** См. [CLAUDE_CONFIG.md](./CLAUDE_CONFIG.md) для полного списка переменных и примеров.

---

## Следующие шаги

- [Использование](./USAGE.md) - команды и примеры
- [Use Cases](./USE_CASES.md) - практические примеры
- [Proxy](./PROXY.md) - настройка прокси
