# Документация iclaude.sh

Этот каталог содержит подробную документацию по архитектуре, конфигурации и использованию iclaude.sh.

## Содержание

### [CLAUDE_CONFIG.md](./CLAUDE_CONFIG.md)

Полное руководство по конфигурации Claude Code через переменные окружения.

**Включает:**
- Описание всех переменных `CLAUDE_CODE_*`
- Proxy конфигурация (PROXY_URL, PROXY_CA, NO_PROXY)
- Практические примеры конфигурации
- Troubleshooting и FAQ
- Документация по Agent Teams (экспериментальная функция)

**Основные переменные:**
- `CLAUDE_CODE_MAX_OUTPUT_TOKENS` - Лимит output токенов (решение ошибки "token maximum exceeded")
- `CLAUDE_CODE_ENABLE_TASKS` - Tasks system (вкл/выкл)
- `CLAUDE_CODE_NO_CHROME` - Chrome integration (вкл/выкл)
- `CLAUDE_CODE_MODEL` - Выбор модели (opus/sonnet/haiku)
- `CLAUDE_CODE_SESSION_TIMEOUT` - Таймаут сессии
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` - Agent Teams (⚠️ experimental)

---

## Быстрый старт

### Решение проблемы "output token maximum exceeded"

Если вы столкнулись с ошибкой:
```
API Error: Claude's response exceeded the 32000 output token maximum.
```

**Решение:**

1. Откройте `.claude_proxy_credentials` в корне проекта
2. Добавьте или раскомментируйте:
   ```bash
   CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000
   ```
3. Перезапустите `./iclaude.sh`

### Включение Agent Teams (экспериментально)

Agent Teams позволяет координировать несколько экземпляров Claude Code, работающих как команда.

**Активация:**

1. Откройте `.claude_proxy_credentials`
2. Раскомментируйте:
   ```bash
   CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
   ```
3. Перезапустите `./iclaude.sh`
4. В Claude Code создайте team:
   ```
   Create an agent team with 3 teammates to review PR #142
   ```

**⚠️ Внимание:** Agent Teams значительно увеличивают использование токенов.

---

## Структура конфигурации

```
.claude_proxy_credentials           # Основной файл конфигурации
├── Proxy settings                 # PROXY_URL, PROXY_INSECURE, NO_PROXY
└── Claude Code configuration      # CLAUDE_CODE_* переменные
```

**Важно:**
- Только **раскомментированные** переменные (без `#`) применяются
- Изменения применяются при следующем запуске `./iclaude.sh`
- Файл защищен правами `600` (только владелец)

---

## Проверка конфигурации

```bash
# Просмотр текущей конфигурации
cat .claude_proxy_credentials

# Проверка экспортированных переменных
bash -c "source ./iclaude.sh && load_claude_config && env | grep CLAUDE_CODE"

# Тестирование proxy (без запуска Claude)
./iclaude.sh --test
```

---

## Дополнительная документация

- **Основное README:** [../README.md](../README.md)
- **CLAUDE.md (разработка):** [../.nvm-isolated/.claude-isolated/CLAUDE.md](../.nvm-isolated/.claude-isolated/CLAUDE.md)

---

## Обратная связь

При возникновении проблем:
1. Проверьте [CLAUDE_CONFIG.md](./CLAUDE_CONFIG.md) → раздел Troubleshooting
2. Убедитесь, что переменные раскомментированы в `.claude_proxy_credentials`
3. Проверьте права доступа к файлу: `ls -la .claude_proxy_credentials` (должно быть `-rw-------`)
4. Создайте issue на GitHub: https://github.com/anthropics/claude-code/issues

---

Обновлено: 2026-02-10
