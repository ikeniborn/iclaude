# План: Поддержка множественных провайдеров в statusline

## Контекст

### Проблема

Текущая реализация statusline (`claude-statusline.sh`) жестко привязана к формату Claude API (Anthropic) и использует специфичные поля:
- `.context_window.total_input_tokens` - биллинговые токены
- `.context_window.used_percentage` - процент использования контекста
- `.context_window.current_usage.cache_*` - метрики кэша
- `.cost.total_cost_usd` - стоимость в USD

При использовании **Claude Code Router** с альтернативными провайдерами (DeepSeek, OpenRouter, Ollama, Gemini) поведение **неизвестно**. Существует **критическая неопределенность**:

**Вариант A**: Router нормализует ответы провайдеров в формат Claude API
- Если да → statusline работает без изменений
- Система "transformers" в router.json предполагает нормализацию

**Вариант B**: Router передает сырые ответы от провайдеров
- Если да → statusline ломается (показывает `[awaiting session data...]`)
- Разные API имеют разные форматы (`.usage.*` vs `.context_window.*`)

### Критическая неопределенность

**НЕ ПОДТВЕРЖДЕНО** как Router передает данные в Claude Code CLI:
- Router имеет систему "transformers" (router.json line 105)
- Но transformers **пустые** в текущей конфигурации
- Router source код скомпилирован (dist/), логика нормализации неизвестна
- **Требуется эмпирическая проверка** перед реализацией

### Цель

**Phase 0 (ОБЯЗАТЕЛЬНАЯ)**: Проверить фактическое поведение Router через debug режим

**Основная цель**: Добавить поддержку множественных LLM провайдеров с сохранением **100% backward compatibility**, но **ТОЛЬКО если Router не нормализует данные**.

### Scope

**Поддерживаемые провайдеры:**
1. ✅ **Anthropic (Claude)** - сохранение текущей функциональности
2. ✅ **OpenAI-compatible** - DeepSeek, OpenRouter, custom OpenAI endpoints
3. ✅ **Ollama** - локальные модели (zero cost)
4. ✅ **Google Gemini** - прямой Google API
5. ✅ **Generic fallback** - graceful degradation для неизвестных провайдеров

## Архитектурное решение

### Strategy Pattern с адаптерами

```
Session JSON → Detect Provider → Load Adapter → Parse → Unified Data → Display
                     ↓
              ┌──────┴──────┐
         anthropic  openai  ollama  gemini  generic
              ↓       ↓       ↓       ↓       ↓
            Claude  DeepSeek Local  Google  Unknown
                    OpenRouter
```

### Ключевые принципы

1. **Provider Detection** - автоматическое определение типа провайдера по структуре JSON
2. **Adapter Pattern** - каждый провайдер имеет свой модуль парсинга
3. **Unified Interface** - все адаптеры возвращают единую структуру данных
4. **Graceful Degradation** - fallback при отсутствии данных
5. **Zero Breaking Changes** - существующий код продолжает работать

## Структура файлов

### Новые файлы

```
.nvm-isolated/.claude-isolated/scripts/
├── claude-statusline.sh              # ИЗМЕНЯЕТСЯ - интеграция адаптеров
├── lib/                              # НОВАЯ ДИРЕКТОРИЯ
│   ├── provider-adapter.sh           # Фабрика адаптеров + детекция провайдера
│   ├── pricing-lookup.sh             # Расчет стоимости для не-Claude моделей
│   └── adapters/                     # Адаптеры для каждого провайдера
│       ├── anthropic.sh              # Claude API (100% backward compat)
│       ├── openai.sh                 # OpenAI/DeepSeek/OpenRouter
│       ├── ollama.sh                 # Локальные модели (zero cost)
│       ├── gemini.sh                 # Google Gemini API
│       └── generic.sh                # Fallback для неизвестных
└── test/                             # НОВАЯ ДИРЕКТОРИЯ
    ├── test-adapters.sh              # Тесты для всех адаптеров
    └── fixtures/                     # Mock session data
        ├── anthropic-session.json
        ├── openai-session.json
        ├── ollama-session.json
        └── gemini-session.json
```

## Детальный план реализации

### 1. Provider Adapter Factory

**Файл:** `.nvm-isolated/.claude-isolated/scripts/lib/provider-adapter.sh`

**Функции:**

#### `detect_provider_type(session_data)`
Определяет тип провайдера по структуре JSON:
- Anthropic: наличие `.context_window.total_input_tokens`
- OpenAI: наличие `.usage.prompt_tokens` + общие модели
- Ollama: наличие `.usage.prompt_tokens` + локальные модели (llama, mistral, qwen)
- Gemini: наличие `.usageMetadata`
- Unknown: fallback к generic адаптеру

**Возвращает:** "anthropic" | "openai" | "ollama" | "gemini" | "unknown"

#### `get_provider_adapter(provider_type)`
Возвращает путь к файлу адаптера:
- Проверяет существование `adapters/${provider_type}.sh`
- Fallback к `adapters/generic.sh` если не найден

**Возвращает:** Путь к файлу адаптера

#### `create_unified_data(...)`
Создает стандартизированный JSON со всеми метриками:
```json
{
  "total_input_tokens": 50000,
  "total_output_tokens": 2000,
  "context_limit": 200000,
  "cache_read_tokens": 1000,
  "cache_creation_tokens": 500,
  "model_name": "Claude Sonnet 4.5",
  "total_cost_usd": 1.06
}
```

### 2. Pricing Lookup Module

**Файл:** `.nvm-isolated/.claude-isolated/scripts/lib/pricing-lookup.sh`

**Pricing database (hardcoded):**
```bash
declare -A MODEL_PRICING_INPUT=(
    ["gpt-4-turbo"]="10.00"
    ["gpt-4"]="30.00"
    ["gpt-3.5-turbo"]="0.50"
    ["deepseek-chat"]="0.27"
    ["deepseek-coder"]="0.27"
    ["claude-opus-4"]="15.00"
    ["claude-sonnet-4.5"]="3.00"
)

declare -A MODEL_PRICING_OUTPUT=(
    ["gpt-4-turbo"]="30.00"
    ["gpt-4"]="60.00"
    ["gpt-3.5-turbo"]="1.50"
    ["deepseek-chat"]="1.10"
    ["deepseek-coder"]="1.10"
    ["claude-opus-4"]="75.00"
    ["claude-sonnet-4.5"]="15.00"
)
```

**Функция:** `calculate_cost(model, input_tokens, output_tokens)`
- Нормализует имя модели (удаляет версии, даты)
- Lookup pricing из таблиц
- Расчет: `(input/1M) × input_price + (output/1M) × output_price`
- Fallback к 0 для неизвестных моделей

**Возвращает:** Стоимость в USD (строка, например "0.0042")

### 3. Anthropic Adapter

**Файл:** `.nvm-isolated/.claude-isolated/scripts/lib/adapters/anthropic.sh`

**Функция:** `parse_anthropic_data(session_data)`

**Логика:**
- Извлекает поля **точно так же** как текущий `claude-statusline.sh` (строки 55-117)
- 100% backward compatibility - нулевые изменения в парсинге Claude API
- Возвращает unified data структуру

**Парсинг:**
```bash
total_input=$(jq -r '.context_window.total_input_tokens // 0')
total_output=$(jq -r '.context_window.total_output_tokens // 0')
context_limit=$(jq -r '.context_window.context_window_size // 200000')
cache_read=$(jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cache_creation=$(jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
model_name=$(jq -r '.model.display_name // "Claude"')
cost=$(jq -r '.cost.total_cost_usd // 0')
```

### 4. OpenAI-Compatible Adapter

**Файл:** `.nvm-isolated/.claude-isolated/scripts/lib/adapters/openai.sh`

**Функция:** `parse_openai_data(session_data)`

**Логика:**
- Парсит OpenAI API формат (DeepSeek, OpenRouter используют его)
- Извлекает `.usage.prompt_tokens` и `.usage.completion_tokens`
- Кэш токены = 0 (OpenAI не поддерживает prompt cache)
- Context limit - lookup по имени модели
- **Расчет стоимости** через `pricing-lookup.sh`

**Парсинг:**
```bash
prompt_tokens=$(jq -r '.usage.prompt_tokens // 0')
completion_tokens=$(jq -r '.usage.completion_tokens // 0')
model_name=$(jq -r '.model // "unknown"')
context_limit=$(get_context_limit_for_model "$model_name")
cost=$(calculate_cost "$model_name" "$prompt_tokens" "$completion_tokens")
```

**Context limits:**
- gpt-4* → 128000
- gpt-3.5* → 16385
- deepseek-chat → 64000
- default → 8192

### 5. Ollama Adapter

**Файл:** `.nvm-isolated/.claude-isolated/scripts/lib/adapters/ollama.sh`

**Функция:** `parse_ollama_data(session_data)`

**Логика:**
- Использует OpenAI-compatible формат (`.usage.*`)
- **Cost = 0** (локальные модели бесплатны)
- Context limit по имени модели:
  - llama3* → 8192
  - llama2* → 4096
  - mistral* → 8192
  - default → 4096

### 6. Gemini Adapter

**Файл:** `.nvm-isolated/.claude-isolated/scripts/lib/adapters/gemini.sh`

**Функция:** `parse_gemini_data(session_data)`

**Логика:**
- Парсит Google Gemini формат (`.usageMetadata`)
- Извлекает `.usageMetadata.promptTokenCount` и `.usageMetadata.candidatesTokenCount`
- Расчет стоимости через `pricing-lookup.sh`

### 7. Generic Fallback Adapter

**Файл:** `.nvm-isolated/.claude-isolated/scripts/lib/adapters/generic.sh`

**Функция:** `parse_generic_data(session_data)`

**Логика:**
- Пробует извлечь токены из любых возможных полей:
  - `.usage.total_tokens`
  - `.tokens.total`
  - `.token_count`
- Показывает минимальную информацию с graceful degradation
- Cost = 0 (неизвестная модель)

### 8. Изменения в claude-statusline.sh

**Критические изменения:**

#### A. Source адаптеров (после строки 50)

```bash
# Source provider adapter library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/provider-adapter.sh" ]]; then
    source "$SCRIPT_DIR/lib/provider-adapter.sh"
    PROVIDER_ADAPTER_AVAILABLE=1
else
    PROVIDER_ADAPTER_AVAILABLE=0
fi
```

#### B. Новая функция parse_session_data() (замена строк 52-120)

**Логика:**
1. Проверка доступности adapter system
2. Если доступен → `parse_with_adapter()`
3. Если недоступен → `parse_legacy_anthropic()` (backward compat)

**Функция `parse_with_adapter()`:**
1. Детект провайдера через `detect_provider_type()`
2. Получение пути адаптера через `get_provider_adapter()`
3. Source файла адаптера
4. Вызов `parse_<provider>_data()`
5. Парсинг unified JSON и установка глобальных переменных

**Функция `parse_legacy_anthropic()`:**
- Полная копия текущей логики (строки 55-117)
- Запускается если adapter system недоступен
- 100% backward compatibility

#### C. Provider icon display (строка 148)

```bash
# Show provider-specific icon
if [[ "$PROVIDER_ADAPTER_AVAILABLE" == "1" ]]; then
    case "$provider_type" in
        anthropic) ;; # No icon for native Claude
        openai) output+=" 🤖" ;;
        ollama) output+=" 🦙" ;;
        gemini) output+=" ✨" ;;
        *) output+=" ❓" ;;
    esac
fi
```

## Используемые паттерны обработки ошибок

Из исследования найдено **12 готовых паттернов**. Используем:

### 1. Graceful Degradation
```bash
if [[ "$PROVIDER_ADAPTER_AVAILABLE" == "1" ]]; then
    parse_with_adapter "$session_data"
else
    parse_legacy_anthropic "$session_data"  # Fallback
fi
```

### 2. Fallback Chain
```bash
adapter_path=$(get_provider_adapter "$provider_type")
[[ ! -f "$adapter_path" ]] && adapter_path="$SCRIPT_DIR/lib/adapters/generic.sh"
```

### 3. Data Validation (из lib/oauth/token.sh)
```bash
local tokens
tokens=$(jq -r '.usage.prompt_tokens // 0')
# Всегда есть fallback значение (0)
```

### 4. Guard Clauses (из lib/core/validation.sh)
```bash
[[ -z "$session_data" ]] && return 1
[[ "$session_data" == "null" ]] && return 1
```

### 5. Dependency Check (из claude-statusline.sh:47)
```bash
if ! command -v jq &>/dev/null; then
    echo "[adapter requires jq - install with: ...]"
    return 0
fi
```

## Переиспользуемые утилиты

Из существующего проекта:

1. **lib/core/json.sh** - `get_lockfile_field()`, паттерн `jq -r '.path // default'`
2. **lib/core/validation.sh** - `validate_dependency()` для проверки jq
3. **lib/core/logging.sh** - `print_info/success/warning/error` для debug вывода
4. **lib/router/detect.sh** - `detect_router()` уже используется в statusline

## План тестирования

### 1. Mock Session Data

Создать тестовые JSON файлы в `test/fixtures/`:

**anthropic-session.json** - Claude API формат
**openai-session.json** - DeepSeek/OpenRouter формат
**ollama-session.json** - Локальная модель
**gemini-session.json** - Google Gemini формат

### 2. Unit тесты

**Файл:** `test/test-adapters.sh`

Тесты:
- ✅ `test_provider_detection()` - корректное определение всех 5 типов
- ✅ `test_anthropic_adapter()` - парсинг Claude data
- ✅ `test_openai_adapter()` - парсинг OpenAI data + расчет стоимости
- ✅ `test_ollama_adapter()` - парсинг Ollama data + zero cost
- ✅ `test_gemini_adapter()` - парсинг Gemini data
- ✅ `test_generic_fallback()` - graceful degradation
- ✅ `test_pricing_calculation()` - точность расчета стоимости
- ✅ `test_backward_compatibility()` - Claude API без изменений

### 3. Integration тесты

```bash
# Тест 1: Существующий Claude API продолжает работать
./iclaude.sh
# Ожидается: statusline показывает Claude метрики без изменений

# Тест 2: Router с DeepSeek
./iclaude.sh --router
# router.json с провайдером DeepSeek
# Ожидается: statusline показывает OpenAI-compatible метрики + иконку 🤖

# Тест 3: Ollama локальная модель
./iclauge.sh --router
# router.json с Ollama
# Ожидается: statusline показывает метрики + $0.00 cost + иконку 🦙

# Тест 4: Fallback при отсутствии lib/
rm -rf .nvm-isolated/.claude-isolated/scripts/lib/
./iclaude.sh
# Ожидается: statusline работает через parse_legacy_anthropic()
```

### 4. Debug режим

```bash
# Включить подробное логирование
DEBUG_STATUSLINE=1 ./iclaude.sh

# Ожидаемый вывод:
[DEBUG] Provider adapter loaded
[DEBUG] Detected provider: openai
[DEBUG] Using adapter: /path/to/adapters/openai.sh
[DEBUG] Calculated cost: 0.0156
[DEBUG] Model: deepseek-chat
```

## Порядок реализации

### Phase 0: VERIFICATION (1 день) - ОБЯЗАТЕЛЬНАЯ ПРЕДВАРИТЕЛЬНАЯ ПРОВЕРКА

**Цель**: Определить фактическое поведение Router ПЕРЕД началом реализации.

#### Шаг 1: Настроить Router с DeepSeek
```bash
# Убедиться что router.json настроен
cat .nvm-isolated/.claude-isolated/router.json

# Проверить что провайдер DeepSeek активен
jq '.routing.default' .nvm-isolated/.claude-isolated/router.json
# Должно показать: "claude-sonnet-4-5" → DeepSeek
```

#### Шаг 2: Запустить с DEBUG режимом
```bash
# Включить подробное логирование
export DEBUG_STATUSLINE=1

# Запустить через router
./iclaude.sh --router

# Отправить простое сообщение: "Hello"
```

#### Шаг 3: Проверить RAW session data
```bash
# Прочитать debug лог statusline
cat /tmp/claude-statusline-debug.log

# Искать структуру JSON:
# - Если видно ".context_window.total_input_tokens" → Router НОРМАЛИЗУЕТ (Вариант A)
# - Если видно ".usage.prompt_tokens" → Router НЕ нормализует (Вариант B)
```

#### Шаг 4: Проверить вывод statusline
```bash
# Посмотреть что показывает statusline:
# - Если показывает токены/cost → Router нормализует
# - Если "[Status line: awaiting session data...]" → Router НЕ нормализует
```

#### Шаг 5: Проверить Router логи
```bash
# Проверить логи Router (если доступны)
ls -la ~/.claude-code-router/logs/
cat ~/.claude-code-router/claude-code-router.log
# Искать упоминания response transformation
```

### РЕШЕНИЕ НА ОСНОВЕ VERIFICATION

**Если Вариант A (Router нормализует)**:
- ✅ **НЕ НУЖНА реализация адаптеров** - statusline уже работает
- ✅ Только добавить provider icon detection (строка 148)
- ✅ Обновить документацию
- ⏱️ **Время: 2-3 дня** вместо 3 недель

**Если Вариант B (Router НЕ нормализует)**:
- ❌ Реализовать полный план адаптеров (см. ниже)
- ⏱️ **Время: 3 недели** как запланировано

---

### Week 1: Foundation + OpenAI Support (ТОЛЬКО если Вариант B)
1. ✅ Создать структуру директорий `lib/` и `lib/adapters/`
2. ✅ Реализовать `lib/provider-adapter.sh` (detection + factory)
3. ✅ Реализовать `lib/pricing-lookup.sh` (pricing database)
4. ✅ Реализовать `lib/adapters/anthropic.sh` (копия текущей логики)
5. ✅ Реализовать `lib/adapters/openai.sh` (DeepSeek/OpenRouter)
6. ✅ Создать mock fixtures для тестирования

### Week 2: Additional Providers + Integration
7. ✅ Реализовать `lib/adapters/ollama.sh`
8. ✅ Реализовать `lib/adapters/gemini.sh`
9. ✅ Реализовать `lib/adapters/generic.sh` (fallback)
10. ✅ Интегрировать в `claude-statusline.sh`:
    - Source adapters (после строки 50)
    - Заменить parse logic (строки 52-120)
    - Добавить provider icons (строка 148)
11. ✅ Сохранить legacy path как fallback

### Week 3: Testing + Documentation
12. ✅ Создать `test/test-adapters.sh` с unit тестами
13. ✅ Запустить integration тесты с реальными провайдерами
14. ✅ Проверить backward compatibility с Claude API
15. ✅ Обновить `docs/STATUSLINE.md` с новой документацией
16. ✅ Добавить troubleshooting guide для новых провайдеров

## Критические файлы

### Новые файлы (создать)
- `.nvm-isolated/.claude-isolated/scripts/lib/provider-adapter.sh` - фабрика адаптеров
- `.nvm-isolated/.claude-isolated/scripts/lib/pricing-lookup.sh` - расчет стоимости
- `.nvm-isolated/.claude-isolated/scripts/lib/adapters/anthropic.sh` - Claude adapter
- `.nvm-isolated/.claude-isolated/scripts/lib/adapters/openai.sh` - OpenAI adapter
- `.nvm-isolated/.claude-isolated/scripts/lib/adapters/ollama.sh` - Ollama adapter
- `.nvm-isolated/.claude-isolated/scripts/lib/adapters/gemini.sh` - Gemini adapter
- `.nvm-isolated/.claude-isolated/scripts/lib/adapters/generic.sh` - fallback adapter
- `.nvm-isolated/.claude-isolated/scripts/test/test-adapters.sh` - unit тесты

### Изменяемые файлы
- `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` - интеграция адаптеров
  - Строка 50: source provider-adapter.sh
  - Строки 52-120: заменить на parse_with_adapter() + parse_legacy_anthropic()
  - Строка 148: добавить provider icons

## Phase 0 Results Documentation

После выполнения Phase 0 задокументировать результаты:

**Файл:** `docs/statusline-router-verification.md`

```markdown
# Statusline + Router Verification Results

## Test Date
YYYY-MM-DD

## Router Configuration
- Provider: DeepSeek
- Model: deepseek-chat
- Router version: X.X.X

## Raw Session Data Format
```json
{... paste actual JSON from /tmp/claude-statusline-debug.log ...}
```

## Findings
- [ ] Вариант A: Router нормализует в Claude формат
- [ ] Вариант B: Router передает сырой формат провайдера

## Statusline Output
- Показывает токены: YES/NO
- Показывает cost: YES/NO
- Показывает "[awaiting data...]": YES/NO

## Decision
На основе тестирования выбрана реализация:
- [ ] Minimal changes (provider icons only)
- [ ] Full adapter system implementation
```

---

## Верификация изменений

### Acceptance Criteria

✅ **Backward Compatibility**
- Существующие пользователи Claude API не видят изменений
- Statusline показывает те же метрики что и раньше
- Fallback к legacy parsing если adapter system недоступен

✅ **Multi-Provider Support**
- DeepSeek/OpenRouter: токены + расчет стоимости + иконка 🤖
- Ollama: токены + $0.00 cost + иконка 🦙
- Gemini: токены + расчет стоимости + иконка ✨
- Unknown: базовые метрики через generic adapter

✅ **Graceful Degradation**
- Отсутствие lib/ → fallback к legacy parsing
- Неизвестный провайдер → generic adapter
- Отсутствие данных → "[waiting for data...]"
- Ошибка парсинга → показ минимальной информации

✅ **Performance**
- Overhead ≤20ms на statusline refresh
- Нет network calls (pricing hardcoded)
- Lazy loading адаптеров (source только нужный)

✅ **Debug Support**
- DEBUG_STATUSLINE=1 показывает детальные логи
- Логирование provider type, adapter path, parsed values
- Troubleshooting информация в STATUSLINE.md

### End-to-End Test

```bash
# 1. Тест Claude API (baseline)
./iclaude.sh
# Verify: statusline показывает Claude метрики

# 2. Тест DeepSeek через Router
# Настроить router.json с DeepSeek провайдером
./iclaude.sh --router
# Verify: statusline показывает OpenAI метрики + расчет cost

# 3. Тест Ollama локально
# Запустить ollama serve
# Настроить router.json с Ollama
./iclaude.sh --router
# Verify: statusline показывает метрики + $0.00

# 4. Тест fallback
rm -rf lib/
./iclaude.sh
# Verify: statusline работает через legacy parsing

# 5. Debug режим
DEBUG_STATUSLINE=1 ./iclaude.sh --router
# Verify: логи показывают provider detection и adapter loading
```

## Риски и митигация

### Риск 0: КРИТИЧЕСКИЙ - Неверное предположение о Router нормализации
**Вероятность:** ВЫСОКАЯ (не проверено эмпирически)
**Влияние:** КРИТИЧЕСКОЕ (3 недели работы могут быть не нужны)
**Митигация:**
- ✅ **Phase 0 VERIFICATION обязательна** перед началом реализации
- ✅ Эмпирическая проверка через DEBUG_STATUSLINE=1
- ✅ Документирование фактического поведения Router
- ✅ Условная реализация: Вариант A (минимальная) vs Вариант B (полная)

### Риск 1: Breaking Changes для существующих пользователей
**Митигация:** Сохранение `parse_legacy_anthropic()` как fallback, 100% копия текущей логики

### Риск 2: Неточный расчет стоимости для не-Claude моделей
**Митигация:** Hardcoded pricing с регулярными обновлениями, fallback к 0 для неизвестных

### Риск 3: Производительность при частых вызовах statusline
**Митигация:** Lazy loading адаптеров, нет network calls, минимальные jq операции

### Риск 4: Изменения в API провайдеров
**Митигация:** Generic fallback adapter, graceful degradation, debug логи для диагностики

### Риск 5: Router обновления могут изменить поведение нормализации
**Митигация:** Мониторинг Router releases, версионирование в lockfile, тестирование после обновлений

## Ожидаемый результат

После реализации плана:

1. ✅ Statusline работает с **5 типами провайдеров** (Anthropic, OpenAI, Ollama, Gemini, Generic)
2. ✅ **100% backward compatibility** - существующие пользователи не видят изменений
3. ✅ **Автоматическое определение** провайдера по структуре JSON
4. ✅ **Расчет стоимости** для не-Claude моделей через pricing lookup
5. ✅ **Graceful degradation** при отсутствии данных или неизвестном провайдере
6. ✅ **Debug режим** с подробными логами для troubleshooting
7. ✅ **Модульная архитектура** - легко добавлять новые провайдеры
8. ✅ **Comprehensive testing** - unit + integration тесты для всех адаптеров

Пользователи смогут использовать Claude Code с любым LLM провайдером и видеть актуальные метрики в statusline.
