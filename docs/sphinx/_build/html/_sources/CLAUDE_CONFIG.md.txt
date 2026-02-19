# Claude Code Configuration Variables

Этот документ описывает переменные окружения для управления поведением Claude Code через файл `.claude_proxy_credentials`.

## Расположение конфигурации

**Файл:** `/home/ikeniborn/Documents/Project/iclaude/.claude_proxy_credentials`

Этот файл содержит как proxy-настройки, так и дополнительные параметры Claude Code.

## Доступные переменные

### 1. Output Token Limits

#### `CLAUDE_CODE_MAX_OUTPUT_TOKENS`

**Описание:** Максимальное количество токенов на вывод (output) в одном ответе Claude.

**Значения:**
- **По умолчанию:** 32000
- **Рекомендуемое:** 64000 (для сложных задач)
- **Максимум:** 128000

**Пример:**
```bash
CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000
```

**Когда использовать:**
- Ошибка: "Claude's response exceeded the 32000 output token maximum"
- Работа с большими файлами или сложными рефакторингами
- Генерация обширной документации

**Внимание:** Более высокие значения увеличивают стоимость API-запросов.

---

### 2. Tasks System

#### `CLAUDE_CODE_ENABLE_TASKS`

**Описание:** Включает/выключает новую систему управления задачами (tasks).

**Значения:**
- `true` - Включено (по умолчанию, рекомендуется)
- `false` - Выключено (старая система)

**Пример:**
```bash
CLAUDE_CODE_ENABLE_TASKS=true
```

**Возможности tasks system:**
- Отслеживание прогресса выполнения работы
- Управление зависимостями между задачами (blocks/blockedBy)
- Отслеживание фоновых процессов (bash shell, subagents)
- Шаринг задач между сессиями

**Когда отключать:**
- Проблемы совместимости с новой системой
- Предпочтение старого интерфейса

---

### 3. Chrome Integration

#### `CLAUDE_CODE_NO_CHROME`

**Описание:** Отключает интеграцию с браузером Chrome (claude-in-chrome extension).

**Значения:**
- `false` - Chrome интеграция включена (по умолчанию)
- `true` - Chrome интеграция выключена

**Пример:**
```bash
CLAUDE_CODE_NO_CHROME=false
```

**Chrome integration возможности:**
- Автоматизация браузера (навигация, клики, ввод данных)
- Чтение консоли и сетевых запросов
- Запись GIF-анимаций взаимодействия
- Автоматическое заполнение форм

**Когда отключать:**
- Chrome не установлен
- Не нужна автоматизация браузера
- Экономия контекста (Chrome integration увеличивает использование токенов)

---

### 4. Model Selection

#### `CLAUDE_CODE_MODEL`

**Описание:** Выбор модели Claude для использования.

**Значения:**
- `claude-3-opus` - Самая мощная модель (дорого, высокое качество)
- `claude-3-sonnet` - Балансированная модель (по умолчанию)
- `claude-3-haiku` - Быстрая модель (дешево, базовое качество)
- `claude-4-6-opus` - Новая Opus 4.6 модель
- `claude-4-5-sonnet` - Новая Sonnet 4.5 модель (по умолчанию в новых версиях)

**Пример:**
```bash
CLAUDE_CODE_MODEL=claude-3-opus
```

**Когда использовать:**
- Opus: сложные задачи, рефакторинг, архитектурные решения
- Sonnet: повседневная разработка, code review
- Haiku: простые задачи, быстрые правки

---

### 5. Session Management

#### `CLAUDE_CODE_SESSION_TIMEOUT`

**Описание:** Таймаут сессии в секундах.

**Значения:**
- **По умолчанию:** 3600 (1 час)
- **Диапазон:** 300-7200 (5 минут - 2 часа)

**Пример:**
```bash
CLAUDE_CODE_SESSION_TIMEOUT=7200
```

**Когда изменять:**
- Длительные сессии разработки (увеличить)
- Быстрые задачи (уменьшить)

---

### 6. Agent Teams (EXPERIMENTAL)

#### `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`

**Описание:** Включает экспериментальную функцию Agent Teams - координацию нескольких экземпляров Claude Code, работающих как команда.

**Статус:** ⚠️ Экспериментальная функция (research preview, февраль 2026)

**Значения:**
- `1` - Включено (agent teams активны)
- Не установлено - Выключено (по умолчанию)

**Пример:**
```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

**Что это дает:**
- **Team Lead:** Основная сессия координирует работу, назначает задачи, синтезирует результаты
- **Teammates:** Отдельные экземпляры Claude Code работают независимо, каждый в своем контексте
- **Shared Task List:** Общий список задач для координации работы
- **Direct Communication:** Агенты могут напрямую общаться друг с другом

**Сравнение с Subagents:**

| Характеристика | Subagents | Agent Teams |
|----------------|-----------|-------------|
| Контекст | Свой контекст, результаты возвращаются вызывающему | Полностью независимый контекст |
| Коммуникация | Только с главным агентом | Прямое общение между агентами |
| Координация | Главный агент управляет всей работой | Shared task list с самокоординацией |
| Подходит для | Фокусные задачи, где важен только результат | Сложная работа, требующая обсуждения и коллаборации |
| Token cost | Ниже (результаты суммаризируются) | Выше (каждый teammate = отдельный Claude instance) |

**Лучшие use cases:**
- ✅ **Research и review:** Параллельное исследование разных аспектов проблемы
- ✅ **Новые модули/фичи:** Каждый teammate владеет отдельной частью
- ✅ **Debugging с конкурирующими гипотезами:** Тестирование разных теорий параллельно
- ✅ **Cross-layer координация:** Frontend, backend, tests - каждый owned by teammate

**Требования:**
- Claude Code CLI v2.0+
- Paid Claude plan (Pro/Team/Enterprise)
- Опционально: `tmux` или iTerm2 для split-pane режима

**Display modes:**
- **In-process:** Все teammates в главном терминале (Shift+Up/Down для переключения)
- **Split panes:** Каждый teammate в отдельной панели (требует tmux/iTerm2)

**⚠️ Важно:**
- **Высокое использование токенов:** Каждый teammate = отдельный Claude instance
- **Экспериментальная функция:** Известные ограничения (см. документацию)
- **Нет session resumption:** `/resume` и `/rewind` не восстанавливают teammates
- **Один team за сессию:** Lead может управлять только одной командой

**Когда использовать:**
- Задачи, где параллельное исследование добавляет реальную ценность
- Teammates могут работать независимо без частых синхронизаций
- Готовность платить за увеличенное использование токенов

**Когда НЕ использовать:**
- Последовательные задачи
- Редактирование одного файла несколькими агентами
- Работа с множеством зависимостей между задачами
- Простые задачи (координация overhead > benefit)

**Пример использования:**

```bash
# После включения в .claude_proxy_credentials
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Запустите Claude Code
./iclaude.sh

# В Claude Code запросите team
> Create an agent team to review PR #142. Spawn three reviewers:
> - One focused on security implications
> - One checking performance impact
> - One validating test coverage
> Have them each review and report findings.
```

**Документация:**
- [Orchestrate teams of Claude Code sessions](https://code.claude.com/docs/en/agent-teams)
- [Agent Teams Setup Guide](https://www.marc0.dev/en/blog/claude-code-agent-teams-multiple-ai-agents-working-in-parallel-setup-guide-1770317684454)
- [Agent Teams Best Practices](https://scottspence.com/posts/enable-team-mode-in-claude-code)

---

## Proxy Configuration Variables

### `PROXY_URL`

**Описание:** URL HTTP/HTTPS прокси-сервера.

**Формат:**
```
protocol://username:password@host:port
```

**Примеры:**
```bash
PROXY_URL=https://user:pass@proxy.example.com:8118
PROXY_URL=http://192.168.1.100:8118
```

**Поддерживаемые протоколы:**
- `https://` - Рекомендуется (сохраняет домен для OAuth/TLS)
- `http://` - Не рекомендуется

---

### `PROXY_INSECURE`

**Описание:** Отключает проверку TLS-сертификата прокси.

**Значения:**
- `true` - Отключить проверку (небезопасно, но работает с самоподписанными сертификатами)
- `false` - Включить проверку (рекомендуется, используйте с `PROXY_CA`)

**Пример:**
```bash
PROXY_INSECURE=false
```

---

### `PROXY_CA`

**Описание:** Путь к файлу CA-сертификата прокси-сервера (для самоподписанных сертификатов).

**Пример:**
```bash
PROXY_CA=/path/to/proxy-cert.pem
```

**Использование:**
1. Получите сертификат прокси-сервера
2. Сохраните в файл (например, `proxy-cert.pem`)
3. Укажите путь в `PROXY_CA`
4. Установите `PROXY_INSECURE=false`

---

### `NO_PROXY`

**Описание:** Список хостов, для которых НЕ использовать прокси (через запятую).

**По умолчанию:**
```bash
NO_PROXY=localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org
```

**Когда изменять:**
- Добавьте внутренние хосты компании
- Добавьте API-эндпоинты, доступные напрямую

---

## Дополнительные переменные окружения

Эти переменные не хранятся в `.claude_proxy_credentials`, но могут быть экспортированы в shell перед запуском.

### `CLAUDE_CODE_TASK_LIST_ID`

**Описание:** ID списка задач для шаринга между сессиями.

**Пример:**
```bash
export CLAUDE_CODE_TASK_LIST_ID=shared-task-list-123
./iclaude.sh
```

---

### `NODE_EXTRA_CA_CERTS`

**Описание:** Дополнительные CA-сертификаты для Node.js (автоматически устанавливается из `PROXY_CA`).

**Пример:**
```bash
export NODE_EXTRA_CA_CERTS=/path/to/cert.pem
```

---

### `NODE_TLS_REJECT_UNAUTHORIZED`

**Описание:** Отключает проверку TLS-сертификатов в Node.js (автоматически устанавливается из `PROXY_INSECURE`).

**Значения:**
- `0` - Отключить проверку (небезопасно)
- `1` - Включить проверку (по умолчанию)

**Пример:**
```bash
export NODE_TLS_REJECT_UNAUTHORIZED=0
```

---

## Примеры конфигурации

### Базовая конфигурация (с proxy)

```bash
PROXY_URL=https://user:pass@proxy.example.com:8118
PROXY_INSECURE=false
NO_PROXY=localhost,127.0.0.1,github.com

# Увеличенный лимит токенов
CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000
```

### Конфигурация для сложных задач

```bash
PROXY_URL=https://user:pass@proxy.example.com:8118
PROXY_INSECURE=false
NO_PROXY=localhost,127.0.0.1

# Максимальный лимит токенов
CLAUDE_CODE_MAX_OUTPUT_TOKENS=128000

# Модель Opus для сложных задач
CLAUDE_CODE_MODEL=claude-3-opus

# Длительный таймаут сессии (2 часа)
CLAUDE_CODE_SESSION_TIMEOUT=7200
```

### Конфигурация без Chrome integration

```bash
PROXY_URL=https://user:pass@proxy.example.com:8118
PROXY_INSECURE=false

# Отключить Chrome (экономия контекста)
CLAUDE_CODE_NO_CHROME=true

# Стандартный лимит токенов
CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000
```

---

## Применение изменений

После изменения `.claude_proxy_credentials`:

1. **Перезапустите iclaude.sh:**
   ```bash
   ./iclaude.sh
   ```

2. **Или экспортируйте переменные вручную:**
   ```bash
   source .claude_proxy_credentials
   export CLAUDE_CODE_MAX_OUTPUT_TOKENS
   ./iclaude.sh
   ```

3. **Проверьте применение:**
   ```bash
   bash -c "source ./iclaude.sh && load_claude_config && env | grep CLAUDE_CODE"
   ```

---

## Troubleshooting

### Ошибка "output token maximum exceeded"

**Решение:**
```bash
CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000
```
или
```bash
CLAUDE_CODE_MAX_OUTPUT_TOKENS=128000
```

### Chrome integration не работает

**Проверьте:**
1. Chrome установлен и запущен
2. Claude in Chrome extension v1.0.36+
3. Paid Claude plan (Pro/Team/Enterprise)

**Или отключите:**
```bash
CLAUDE_CODE_NO_CHROME=true
```

### Медленная работа модели

**Попробуйте Haiku:**
```bash
CLAUDE_CODE_MODEL=claude-3-haiku
```

### Tasks system не работает

**Включите явно:**
```bash
CLAUDE_CODE_ENABLE_TASKS=true
```

---

## Полезные команды

```bash
# Просмотреть текущую конфигурацию
cat .claude_proxy_credentials

# Редактировать конфигурацию
nano .claude_proxy_credentials

# Проверить экспортированные переменные
bash -c "source ./iclaude.sh && load_claude_config && env | grep CLAUDE_CODE"

# Запуск с проверкой конфигурации
./iclaude.sh --test
```

---

## Безопасность

⚠️ **ВНИМАНИЕ:** Файл `.claude_proxy_credentials` содержит чувствительные данные (пароли прокси, API-ключи).

**Защита:**
- Файл имеет права `600` (только владелец может читать/писать)
- Файл исключен из git (`.gitignore`)
- НЕ передавайте этот файл другим людям
- НЕ коммитьте этот файл в публичные репозитории

---

## Дополнительная информация

- **Claude Code Documentation:** https://code.claude.com/docs
- **iclaude.sh README:** [README.md](./README.md)
- **iclaude.sh CLAUDE.md:** [.nvm-isolated/.claude-isolated/CLAUDE.md](./.nvm-isolated/.claude-isolated/CLAUDE.md)

---

Обновлено: 2026-02-10
