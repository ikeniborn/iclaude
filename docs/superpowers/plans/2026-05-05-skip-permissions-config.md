# CLAUDE_CODE_SKIP_PERMISSIONS + расширение .claude_config.example — Plan реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить переменную `CLAUDE_CODE_SKIP_PERMISSIONS` в `.claude_config` для включения bypass-permissions режима без CLI-флага `--no-save`, и расширить `.claude_config.example` ~25 практически полезными переменными Claude Code.

**Architecture:** Флаг читается через grep-блок в `iclaude.sh` (строки 202–231) — существующий паттерн для boolean-флагов из конфига. CLI-флаг `--no-save` имеет приоритет: он принудительно выставляет `skip_permissions=true` после чтения конфига.

**Tech Stack:** bash

---

## Файлы, затрагиваемые изменениями

| Файл | Тип изменения |
|------|--------------|
| `iclaude.sh` | Modify: добавить grep-блок для `CLAUDE_CODE_SKIP_PERMISSIONS` в секцию 202–231 |
| `.claude_config.example` | Modify: добавить `CLAUDE_CODE_SKIP_PERMISSIONS` + новую секцию ~24 переменными |

`lib/core/init.sh` — **не меняется** (паттерн `${VAR:-false}` не подходит: config не sourced в init_environment; флаги читаются через grep в основном скрипте).

---

## Task 1: Добавить чтение CLAUDE_CODE_SKIP_PERMISSIONS из конфига

**Files:**
- Modify: `iclaude.sh:202–231`

### Контекст

Существующий блок чтения конфига выглядит так (строки 202–231):

```bash
if [[ -f "$CREDENTIALS_FILE" ]]; then
    _cfg_pii=$(grep -E \
        "^[[:space:]]*(export[[:space:]]+)?USE_PII_PROXY[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
        "$CREDENTIALS_FILE" 2>/dev/null || true)
    [[ -n "$_cfg_pii" ]] && USE_PII_PROXY_FLAG=true
    unset _cfg_pii

    _cfg_microvm=$(grep -E \
        "^[[:space:]]*(export[[:space:]]+)?MICRO_VM_ENABLED[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
        "$CREDENTIALS_FILE" 2>/dev/null || true)
    [[ -n "$_cfg_microvm" ]] && USE_MICRO_VM_FLAG=true
    unset _cfg_microvm

    _cfg_no_attr=$(grep -E \
        "^[[:space:]]*(export[[:space:]]+)?NO_ATTRIBUTION_HEADER[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
        "$CREDENTIALS_FILE" 2>/dev/null || true)
    [[ -n "$_cfg_no_attr" ]] && NO_ATTRIBUTION_HEADER=true
    unset _cfg_no_attr

    _cfg_chrome=$(grep -E \
        "^[[:space:]]*(export[[:space:]]+)?USE_CHROME[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
        "$CREDENTIALS_FILE" 2>/dev/null || true)
    [[ -n "$_cfg_chrome" ]] && USE_CHROME=true
    unset _cfg_chrome
fi
```

- [ ] **Step 1: Добавить grep-блок для CLAUDE_CODE_SKIP_PERMISSIONS**

В файле `iclaude.sh` найти строку:
```bash
    _cfg_chrome=$(grep -E \
        "^[[:space:]]*(export[[:space:]]+)?USE_CHROME[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
        "$CREDENTIALS_FILE" 2>/dev/null || true)
    [[ -n "$_cfg_chrome" ]] && USE_CHROME=true
    unset _cfg_chrome
fi
```

Заменить на:
```bash
    _cfg_chrome=$(grep -E \
        "^[[:space:]]*(export[[:space:]]+)?USE_CHROME[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
        "$CREDENTIALS_FILE" 2>/dev/null || true)
    [[ -n "$_cfg_chrome" ]] && USE_CHROME=true
    unset _cfg_chrome

    _cfg_skip_perm=$(grep -E \
        "^[[:space:]]*(export[[:space:]]+)?CLAUDE_CODE_SKIP_PERMISSIONS[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
        "$CREDENTIALS_FILE" 2>/dev/null || true)
    [[ -n "$_cfg_skip_perm" ]] && skip_permissions=true
    unset _cfg_skip_perm
fi
```

- [ ] **Step 2: Проверить синтаксис bash**

```bash
bash -n iclaude.sh
```

Ожидаемый вывод: пусто (нет ошибок).

- [ ] **Step 3: Проверить поведение — конфиг задаёт true**

```bash
# Создать тестовый конфиг с флагом
echo 'CLAUDE_CODE_SKIP_PERMISSIONS=true' > /tmp/test_skip.conf

# Имитировать чтение конфига как это делает iclaude.sh
_cfg_skip_perm=$(grep -E \
    "^[[:space:]]*(export[[:space:]]+)?CLAUDE_CODE_SKIP_PERMISSIONS[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
    /tmp/test_skip.conf 2>/dev/null || true)
echo "Result (should be non-empty): '$_cfg_skip_perm'"

# Проверить export-форму
echo 'export CLAUDE_CODE_SKIP_PERMISSIONS=true' > /tmp/test_skip2.conf
_cfg2=$(grep -E \
    "^[[:space:]]*(export[[:space:]]+)?CLAUDE_CODE_SKIP_PERMISSIONS[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
    /tmp/test_skip2.conf 2>/dev/null || true)
echo "Export form (should be non-empty): '$_cfg2'"

# Проверить false — должно быть пусто
echo 'CLAUDE_CODE_SKIP_PERMISSIONS=false' > /tmp/test_skip3.conf
_cfg3=$(grep -E \
    "^[[:space:]]*(export[[:space:]]+)?CLAUDE_CODE_SKIP_PERMISSIONS[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
    /tmp/test_skip3.conf 2>/dev/null || true)
echo "False value (should be empty): '$_cfg3'"

rm -f /tmp/test_skip.conf /tmp/test_skip2.conf /tmp/test_skip3.conf
```

Ожидаемый вывод:
```
Result (should be non-empty): 'CLAUDE_CODE_SKIP_PERMISSIONS=true'
Export form (should be non-empty): 'export CLAUDE_CODE_SKIP_PERMISSIONS=true'
False value (should be empty): ''
```

- [ ] **Step 4: Commit**

```bash
git add iclaude.sh
git commit -m "feat(config): читать CLAUDE_CODE_SKIP_PERMISSIONS из .claude_config"
```

---

## Task 2: Добавить CLAUDE_CODE_SKIP_PERMISSIONS в .claude_config.example

**Files:**
- Modify: `.claude_config.example:139–141`

### Контекст

Сейчас секция «НАСТРОЙКИ CLAUDE CODE» заканчивается на строке 139:
```
CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=

# ============================================================
#  ROUTER: API-КЛЮЧИ LLM-ПРОВАЙДЕРОВ
```

- [ ] **Step 1: Добавить CLAUDE_CODE_SKIP_PERMISSIONS после строки 139**

В файле `.claude_config.example` найти строку:
```
CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=

# ============================================================
#  ROUTER: API-КЛЮЧИ LLM-ПРОВАЙДЕРОВ
```

Заменить на:
```
CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=

# Разрешить Claude Code пропускать подтверждение опасных операций (bypass permissions).
# true  — передаёт --dangerously-skip-permissions при запуске (аналог флага --no-save)
# false — безопасный режим (по умолчанию, подтверждение требуется)
#
# ВАЖНО: включайте только в автоматизированных/доверенных средах.
# Флаг --no-save в командной строке всегда имеет приоритет над этой переменной.
# CLAUDE_CODE_SKIP_PERMISSIONS=false

# ============================================================
#  ROUTER: API-КЛЮЧИ LLM-ПРОВАЙДЕРОВ
```

- [ ] **Step 2: Проверить что файл не сломан — найти секцию**

```bash
grep -n "CLAUDE_CODE_SKIP_PERMISSIONS\|ROUTER: API-КЛЮЧИ" .claude_config.example
```

Ожидаемый вывод (номера строк могут отличаться):
```
141:# CLAUDE_CODE_SKIP_PERMISSIONS=false
148:# ============================================================
149:#  ROUTER: API-КЛЮЧИ LLM-ПРОВАЙДЕРОВ
```

- [ ] **Step 3: Commit**

```bash
git add .claude_config.example
git commit -m "docs(config): добавить CLAUDE_CODE_SKIP_PERMISSIONS в .claude_config.example"
```

---

## Task 3: Добавить новую секцию «ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ CLAUDE CODE»

**Files:**
- Modify: `.claude_config.example` (перед секцией «ОТЛАДКА»)

### Контекст

Перед секцией «ОТЛАДКА» (строка 524 в оригинале, после добавления Task 2 — сдвинется на ~8 строк) нужно вставить новый блок ~24 переменных.

- [ ] **Step 1: Добавить секцию в .claude_config.example**

Найти в `.claude_config.example`:
```
# ============================================================
#  ОТЛАДКА
# ============================================================
# Включить подробный вывод при запуске claude в launch.sh.
# 1 — показывать: путь к бинарю, аргументы, переменные окружения
# (оставить пустым для отключения)
DEBUG_LAUNCH=
```

Вставить перед этим блоком следующий текст:

```
# ============================================================
#  ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ CLAUDE CODE
# ============================================================
# Переменные Claude Code, используемые при запуске процесса.
# Все переменные передаются в окружение Claude Code автоматически
# при старте через iclaude.sh.

# --- API / Сеть ---

# Переопределить endpoint API Anthropic (кастомный gateway, локальный прокси).
# По умолчанию: https://api.anthropic.com
# Пример: ANTHROPIC_BASE_URL=http://localhost:8080/proxy/anthropic
# export ANTHROPIC_BASE_URL=

# Альтернативный токен аутентификации для корпоративных AI-gateway.
# Используется когда gateway не принимает стандартный ANTHROPIC_API_KEY.
# export ANTHROPIC_AUTH_TOKEN=

# Дополнительные CA-сертификаты для Node.js (корпоративные PKI).
# Пример: NODE_EXTRA_CA_CERTS=/etc/ssl/certs/corporate-ca.crt
# export NODE_EXTRA_CA_CERTS=

# --- Контекст / Память ---

# Лимит контекстного окна в токенах.
# По умолчанию: максимум модели (200K для claude-sonnet-4-6).
# Уменьшите для экономии или при работе с ограниченными провайдерами.
# CLAUDE_CODE_MAX_CONTEXT_TOKENS=

# Отключить автоматическую память (сохранение контекста между сессиями).
# 1 — отключить (каждая сессия начинается с чистого листа)
# CLAUDE_CODE_DISABLE_AUTO_MEMORY=

# Переопределить размер окна для авто-компакции контекста.
# По умолчанию: зависит от модели (обычно 80% от MAX_CONTEXT_TOKENS).
# CLAUDE_CODE_AUTO_COMPACT_WINDOW=

# Порог авто-компакции в % заполнения контекста (0–100).
# По умолчанию: ~95. Уменьшите если компакция происходит слишком поздно.
# CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=

# --- Производительность ---

# Максимальное число параллельных вызовов инструментов.
# По умолчанию: 10. Уменьшите при проблемах с rate-limit провайдера.
# CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=

# Лимит вывода Bash-инструмента в символах.
# По умолчанию: 30000. Увеличьте для длинных логов.
# BASH_MAX_OUTPUT_LENGTH=

# Лимит токенов при чтении файлов (Read tool).
# По умолчанию: зависит от модели. Уменьшите для сокращения расхода токенов.
# CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS=

# Бюджет токенов для extended thinking (работает только с DISABLE_ADAPTIVE_THINKING=1).
# По умолчанию: 10000. Используйте с Opus/Sonnet 4.6 в режиме фиксированного бюджета.
# MAX_THINKING_TOKENS=

# --- Дисплей / UI ---

# Скрыть рабочую директорию в логотипе при запуске.
# 1 — скрыть (полезно в shared/demo окружениях)
# CLAUDE_CODE_HIDE_CWD=

# Компактный режим вывода (сокращённые сообщения).
# 1 — включить
# CLAUDE_CODE_BRIEF=

# Множитель скорости прокрутки терминала (float, 0.1–20).
# По умолчанию: 3 в Windows Terminal, 1 иначе.
# CLAUDE_CODE_SCROLL_SPEED=

# Сохранять truecolor под tmux (предотвращает деградацию до 256 цветов).
# 1 — включить
# CLAUDE_CODE_TMUX_TRUECOLOR=

# Уменьшить мерцание при перерисовке терминала.
# 1 — включить (рекомендуется при мерцании в slow terminal)
# CLAUDE_CODE_NO_FLICKER=

# Отключить захват мыши в терминале.
# 1 — отключить (если мышь мешает выделению текста в терминале)
# CLAUDE_CODE_DISABLE_MOUSE=

# --- Сессия ---

# Порог (в минутах) для предложения возобновить предыдущую сессию при запуске.
# По умолчанию: 5. 0 — никогда не предлагать.
# CLAUDE_CODE_RESUME_THRESHOLD_MINUTES=

# Автоматически возобновлять прерванный ход без запроса подтверждения.
# 1 — включить (удобно в автоматизированных сценариях)
# CLAUDE_CODE_RESUME_INTERRUPTED_TURN=

# --- Провайдеры (Bedrock / Vertex) ---

# Использовать AWS Bedrock вместо Anthropic API.
# 1 — включить (требует настройки AWS credentials)
# CLAUDE_CODE_USE_BEDROCK=

# Использовать Google Vertex AI вместо Anthropic API.
# 1 — включить (требует настройки GCP credentials)
# CLAUDE_CODE_USE_VERTEX=

# Tier сервиса AWS Bedrock.
# default  — стандартный tier
# flex     — гибкий tier (pay-per-token, без резервирования)
# priority — приоритетный tier (зарезервированные ресурсы)
# ANTHROPIC_BEDROCK_SERVICE_TIER=default

# --- Прочее ---

# Отключить весь нецелевой трафик (телеметрия, аналитика, ping).
# 1 — отключить (рекомендуется в air-gapped средах)
# CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=

# Управление заголовком атрибуции (x-anthropic-attribution).
# 0 — отключить заголовок (ускоряет локальные/прокси модели, сохраняет KV-кэш)
# По умолчанию: 1 (заголовок отправляется)
# CLAUDE_CODE_ATTRIBUTION_HEADER=

```

- [ ] **Step 2: Проверить что файл не сломан**

```bash
grep -c "^#\|^[A-Z]\|^$\|^export" .claude_config.example
```

Ожидаемый вывод: число строк ≥ 700 (файл увеличился корректно).

```bash
grep -n "ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ\|ОТЛАДКА\|DEBUG_LAUNCH" .claude_config.example
```

Ожидаемый вывод: секции идут в правильном порядке — сначала «ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ», потом «ОТЛАДКА», потом `DEBUG_LAUNCH=`.

- [ ] **Step 3: Commit**

```bash
git add .claude_config.example
git commit -m "docs(config): добавить ~24 переменных Claude Code в .claude_config.example"
```

---

## Self-review checklist

- [x] **Spec coverage:** Task 1 реализует Часть 1 спека. Tasks 2–3 реализуют Часть 2. Все три файла из таблицы покрыты (lib/core/init.sh исключён с обоснованием).
- [x] **Placeholder scan:** Нет TBD, нет TODO. Весь код показан полностью.
- [x] **Type consistency:** Переменная `skip_permissions` используется одинаково во всех задачах.
- [x] **Уточнение к спеку:** Спек предлагал `init_environment()`, но паттерн кода требует grep-блок в `iclaude.sh` — это задокументировано в преамбуле плана.
