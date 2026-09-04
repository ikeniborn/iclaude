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
| `--create-symlink` | Создание пользовательского симлинка | ❌ | isolated env |
| `--uninstall-symlink` | Удаление пользовательского симлинка | ❌ | - |
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
| `--proxy <url>` | Установка прокси (https рекомендуется; http — только localhost; socks5 НЕ поддерживается) |
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

**Chrome интеграция ВЫКЛЮЧЕНА по умолчанию.** Для включения:

```bash
./iclaude.sh --chrome
```

Постоянное включение — `ICLAUDE_USE_CHROME=true` в `.claude_config`; разовое отключение при включённом флаге — `--no-chrome`.

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

## 🛡️ Дополнительные подсистемы

Команды подсистем, у каждой из которых есть отдельный подробный документ.

| Команда | Описание | Документ |
|---------|----------|----------|
| `--install-pii-proxy` / `--pii-proxy` / `--check-pii-proxy` | PII-маскирующий прокси перед api.anthropic.com | [PII_MASKING.md](./PII_MASKING.md) |
| `--install-microvm` / `--sandbox-microvm` / `--check-microvm` | Ядровая изоляция в Firecracker microVM | [MICROVM.md](./MICROVM.md) |
| `--install-caveman` / `--check-caveman` / `--uninstall-caveman` | Режим сжатых ответов (caveman) | [CAVEMAN.md](./CAVEMAN.md) |
| `--no-telemetry` | Отключить OTEL-телеметрию (включается `ICLAUDE_USE_OTEL=true`) | [TELEMETRY.md](./TELEMETRY.md) |
| `--model <name>` | Передать модель в Claude Code | — |
| `--refresh-token` | Обновить OAuth токен | — |
| `-- <args>` | Всё после `--` передаётся в Claude Code как есть | — |

Плагин loen управляется скиллами `/loen:*` внутри сессии, не флагами — см. [LOEN.md](./LOEN.md).

---

## 🎛️ Claude Code Configuration

Управление параметрами Claude Code через файл `.claude_config` в корне проекта (chmod 600, исключён из git). Все переменные — с префиксом `ICLAUDE_`; при запуске `source_iclaude_config` экспортирует их без префикса.

### Доступные переменные

| Переменная | Описание | Значение по умолчанию |
|------------|----------|----------------------|
| `ICLAUDE_CLAUDE_CODE_MAX_OUTPUT_TOKENS` | Лимит output токенов | не задано |
| `ICLAUDE_CLAUDE_CODE_ENABLE_TASKS` | Tasks system (вкл/выкл) | true |
| `ICLAUDE_CLAUDE_CODE_NO_CHROME` | Отключить Chrome integration | не задано |
| `ICLAUDE_CLAUDE_CODE_MODEL` | Выбор модели (флаг `--model` имеет приоритет) | не задано |
| `ICLAUDE_CLAUDE_CODE_SESSION_TIMEOUT` | Таймаут сессии (секунды) | не задано |
| `ICLAUDE_CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Agent Teams ⚠️ EXPERIMENTAL | не задано (выкл) |

### Пример конфигурации

```bash
# .claude_config

# Proxy settings
ICLAUDE_PROXY_URL=https://user:pass@proxy.example.com:8118
ICLAUDE_PROXY_INSECURE=false

# Claude Code configuration
ICLAUDE_CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000    # Увеличенный лимит (для сложных задач)
# ICLAUDE_CLAUDE_CODE_MODEL=claude-sonnet-5     # Закомментировано = не используется
# ICLAUDE_CLAUDE_CODE_NO_CHROME=true            # Закомментировано = не используется
```

**⚠️ Важно:** Только **раскомментированные** переменные будут экспортированы при запуске. Закомментированные (`#`) переменные игнорируются. Legacy-файлы без префикса `ICLAUDE_` автоматически мигрируются при первом запуске (backup `.claude_config.bak`).

**Полный список переменных:** см. `.claude_config.example` в корне репозитория (~130 ключей: proxy, PII, microVM, iwiki, Langfuse, OTEL, caveman, провайдеры).

---

## Следующие шаги

- [Use Cases](./USE_CASES.md) - практические примеры
- [Proxy](./PROXY.md) - настройка прокси
