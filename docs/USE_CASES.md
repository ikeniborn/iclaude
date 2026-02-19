# Use Cases

Типичные сценарии использования с пошаговыми инструкциями.

---

## Use Case 1: Deploy на новый сервер (БЕЗ системного npm)

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

---

## Use Case 2: Обновление изолированного Claude Code

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

---

## Use Case 3: Временное переключение на системную установку

Если у вас есть и изолированная, и системная установка:

```bash
# Запустить из системной установки (игнорируя изолированную)
iclaude --system

# Обновить системную установку
sudo iclaude --system --update
```

---

## Use Case 4: Управление симлинками

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

---

## Use Case 5: Автоматизация создания Pull Request

Автоматизация PR workflow с мониторингом CI/CD и автоисправлением ошибок:

```bash
# Установить gh CLI (один раз, через пакетный менеджер)
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

## Use Case 6: Использование альтернативных LLM провайдеров через Router

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

## Use Case 7: Кастомная Status Line

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

**Подробнее:** См. [STATUSLINE.md](./STATUSLINE.md)

---

## Use Case 8: Безопасное выполнение с OS-level Sandboxing

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

## Дополнительная информация

- [Установка](./INSTALLATION.md) - варианты установки
- [Конфигурация](./CONFIGURATION.md) - все команды и настройки
- [Troubleshooting](./TROUBLESHOOTING.md) - решение проблем
