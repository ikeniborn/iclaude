# Use Cases

Типичные сценарии использования с пошаговыми инструкциями.

---

## Use Case 1: Deploy на новый сервер (БЕЗ системного npm)

Самый быстрый способ развертывания без установки системных зависимостей:

```bash
# Шаг 1: Клонировать репозиторий (включает .nvm-isolated/)
git clone https://github.com/ikeniborn/iclaude.git
cd iclaude

# Шаг 2: Починить симлинки после git clone
./iclaude.sh --repair-isolated

# Шаг 3: Создать пользовательский симлинк (БЕЗ системного npm!)
./iclaude.sh --create-symlink

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
# Создать пользовательский симлинк
./iclaude.sh --create-symlink

# Проверить куда указывает симлинк
ls -la ~/.local/bin/iclaude

# Удалить симлинк (сохранить изолированную среду)
iclaude --uninstall-symlink

# Повторно создать симлинк
./iclaude.sh --create-symlink
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

**Подробнее:** См. `.claude-isolated/skills/git-workflow/SKILL.md` (скилл `git-workflow`: ветки `dev-<topic>`, Conventional Commits, PR через `gh pr create`).

---

## Use Case 6: Использование альтернативных LLM провайдеров через Router

Claude Code Router позволяет использовать DeepSeek, OpenRouter, OpenAI, Ollama и другие провайдеры вместо Anthropic API:

```bash
# Шаг 1: Установить Claude Code Router
./iclaude.sh --install-router

# Шаг 2: Настроить провайдер в router.json
# Редактировать .claude-isolated/router.json
# (используйте ${VAR_NAME} для API ключей)

# Шаг 3: Добавить API ключ в .claude_config
echo 'ICLAUDE_DEEPSEEK_API_KEY=your-key-here' >> .claude_config

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

**Пример конфигурации** (`.claude-isolated/router.json`, схема CCR v2: массив `Providers` + объект `Router`):
```json
{
  "PORT": 3456,
  "Providers": [
    {
      "name": "deepseek",
      "api_base_url": "https://api.deepseek.com/v1/chat/completions",
      "api_key": "${DEEPSEEK_API_KEY}",
      "models": ["deepseek-chat"],
      "transformer": { "use": ["deepseek"] }
    }
  ],
  "Router": {
    "default": "deepseek,deepseek-chat",
    "background": "deepseek,deepseek-chat"
  }
}
```

Устаревшая pre-v2 схема (lowercase `providers`/`models`/`routing`) больше не поддерживается — полный справочник схемы см. [ROUTER.md](./ROUTER.md).

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

## Use Case 8: Kernel-level Isolation с microVM (Firecracker)

Claude Code внутри изолированной виртуальной машины — максимальная защита от prompt injection:

```bash
# Установить (один раз, ~1.4GB)
./iclaude.sh --install-microvm

# Проверить готовность
./iclaude.sh --check-microvm

# Запустить с kernel isolation
./iclaude.sh --sandbox-microvm

# С PII-маскированием (рекомендуется)
./iclaude.sh --sandbox-microvm --pii-proxy
```

**Уровни изоляции:**

| Уровень | Механизм | Статус |
|---------|----------|--------|
| Security hooks | block-secrets.py + redact-secrets.py | Всегда активны |
| CLAUDE_CONFIG_DIR | Изолированный конфиг в `.nvm-isolated/` | Всегда активен |
| microVM | Firecracker KVM (отдельный Linux kernel) | `--sandbox-microvm` |

**Подробнее:** [MICROVM.md](./MICROVM.md) (включая troubleshooting)

---

## Дополнительная информация

- [Конфигурация](./CONFIGURATION.md) - все команды и настройки
- [Proxy](./PROXY.md) - настройка прокси и решение проблем подключения
