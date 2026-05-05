# Переменные окружения Claude Code

Справочник по всем переменным, поддерживаемым iclaude.sh и Claude Code.

## Расположение конфигурации

**Файл:** `.claude_config` в корне репозитория

```bash
cp .claude_config.example .claude_config
# Отредактировать: заполнить нужные значения
chmod 600 .claude_config   # устанавливается автоматически
```

> ⚠️ `.claude_config` добавлен в `.gitignore` — содержит секреты, не коммитить.
> `.claude_config.example` — безопасный шаблон, хранится в git.

Файл загружается автоматически при каждом запуске `./iclaude.sh`.

---

## Прокси-сервер

### `PROXY_URL`
URL прокси-сервера.

| | |
|---|---|
| **По умолчанию** | не задан (прокси не используется) |
| **Формат** | `https://[user:pass@]host:port` |

```bash
PROXY_URL=https://user:password@proxy.company.com:8118
```

**Протоколы:**
- `https://` — рекомендуется (сохраняет домены для OAuth/TLS)
- `http://` — не рекомендуется (проблемы с TLS Anthropic)
- SOCKS5 — не поддерживается (сбой в undici)

Задать через CLI: `./iclaude.sh --proxy https://user:pass@proxy:8118`

---

### `PROXY_INSECURE`
Отключить проверку TLS-сертификата прокси.

| | |
|---|---|
| **По умолчанию** | `false` |
| **Значения** | `true` / `false` |

```bash
PROXY_INSECURE=false
```

> Используйте `PROXY_CA` вместо `PROXY_INSECURE=true` — безопаснее.

---

### `PROXY_CA`
Путь к CA-сертификату прокси (PEM-формат).

| | |
|---|---|
| **По умолчанию** | не задан (NODE_EXTRA_CA_CERTS не устанавливается) |

```bash
PROXY_CA=/etc/ssl/certs/corporate-ca.pem
```

При наличии файла автоматически устанавливает `NODE_EXTRA_CA_CERTS`.

---

### `NO_PROXY`
Список хостов, обходящих прокси (через запятую).

| | |
|---|---|
| **По умолчанию** | `localhost,127.0.0.1,::1,github.com,githubusercontent.com,gitlab.com,bitbucket.org,registry.npmjs.org,nodejs.org` |

```bash
NO_PROXY=localhost,127.0.0.1,internal.company.com
```

---

## Выбор модели

### `CLAUDE_CODE_MODEL`
Принудительно задать модель через флаг `--model` при запуске.

| | |
|---|---|
| **По умолчанию** | `claude-sonnet-4-6` |

```bash
CLAUDE_CODE_MODEL=claude-opus-4-6
```

> Применяется только в нативном режиме (без `--router`).
> При `--router` модели задаются в `router.json`.

Задать через CLI: `./iclaude.sh --model claude-opus-4-6`

---

### `ANTHROPIC_MODEL`
Нативная переменная Claude Code для выбора модели. Альтернатива `CLAUDE_CODE_MODEL` — не требует флага `--model`.

| | |
|---|---|
| **По умолчанию** | `claude-sonnet-4-6` |

```bash
ANTHROPIC_MODEL=claude-sonnet-4-6
```

> Если заданы оба — `CLAUDE_CODE_MODEL` (`--model`) имеет приоритет.

---

### `ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL` / `ANTHROPIC_DEFAULT_HAIKU_MODEL`
Переопределить alias-маппинг семейств моделей на конкретную версию.

| Переменная | По умолчанию |
|---|---|
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `claude-opus-4-6` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `claude-sonnet-4-6` |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `claude-haiku-4-5-20251001` |

```bash
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6
ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5-20251001
```

Полезно для закрепления точной версии модели без изменения конфигов роутера.

---

## Настройки Claude Code

### `CLAUDE_CODE_MAX_OUTPUT_TOKENS`
Максимальное количество токенов в одном ответе.

| | |
|---|---|
| **По умолчанию** | зависит от модели (обычно 8192) |

```bash
CLAUDE_CODE_MAX_OUTPUT_TOKENS=32000
```

> Увеличьте при ошибке "Claude's response exceeded the output token maximum".

---

### `CLAUDE_CODE_ENABLE_TASKS`
Включить систему задач (TaskCreate/TaskUpdate/TaskList).

| | |
|---|---|
| **По умолчанию** | `true` (в iclaude) |

```bash
CLAUDE_CODE_ENABLE_TASKS=true
```

---

### `CLAUDE_CODE_NO_CHROME`
Отключить интеграцию с браузером Chrome.

| | |
|---|---|
| **По умолчанию** | `false` (Chrome включён) |

```bash
CLAUDE_CODE_NO_CHROME=true
```

Отключить через CLI: `./iclaude.sh --no-chrome`

---

### `CLAUDE_CODE_SESSION_TIMEOUT`
Таймаут сессии в секундах.

| | |
|---|---|
| **По умолчанию** | не задан (Claude Code не ограничивает длительность) |

```bash
CLAUDE_CODE_SESSION_TIMEOUT=7200
```

---

### `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`
Экспериментальная функция Agent Teams — несколько экземпляров Claude Code в одной сессии.

| | |
|---|---|
| **По умолчанию** | не задан (отключено) |
| **Значение для включения** | `1` |

```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

> ⚠️ Экспериментальная функция. Увеличивает расход токенов. Не поддерживает `/resume`.

---

### `CLAUDE_CODE_SUBAGENT_MODEL`
Отдельная модель для субагентов (Task tool, параллельные агенты).

| | |
|---|---|
| **По умолчанию** | `claude-haiku-4-5-20251001` |

```bash
CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6
```

---

### `CLAUDE_CODE_EFFORT_LEVEL`
Уровень усилий — влияет на глубину extended thinking и анализа.

| | |
|---|---|
| **По умолчанию** | `medium` |
| **Значения** | `low` / `medium` / `high` |

```bash
CLAUDE_CODE_EFFORT_LEVEL=high
```

| Значение | Поведение |
|---|---|
| `low` | Быстро, минимум thinking |
| `medium` | Баланс скорости и качества |
| `high` | Максимальное качество, больше thinking (дороже) |

---

### `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`
Отключить extended thinking (adaptive thinking) у Opus/Sonnet 4.6.

| | |
|---|---|
| **По умолчанию** | не задан (adaptive thinking включён) |
| **Значение для отключения** | `1` |

```bash
CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1
```

> Ускоряет ответы и снижает стоимость. Отключает глубокий анализ.

---

### `CLAUDE_CODE_DISABLE_1M_CONTEXT`
Отключить расширенный контекст (200K context window).

| | |
|---|---|
| **По умолчанию** | не задан (расширенный контекст активен) |
| **Значение для отключения** | `1` |

```bash
CLAUDE_CODE_DISABLE_1M_CONTEXT=1
```

---

### `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS`
Использовать только стабильные API (отключить beta endpoints).

| | |
|---|---|
| **По умолчанию** | не задан (experimental betas включены) |
| **Значение для отключения** | `1` |

```bash
CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
```

---

## API-ключи для роутера

Используются в `router.json` через плейсхолдеры `${VAR_NAME}`.
Активация роутера: `./iclaude.sh --router`

| Переменная | Провайдер | По умолчанию |
|---|---|---|
| `ANTHROPIC_API_KEY` | Anthropic (для CCR) | не нужен в нативном режиме |
| `DEEPSEEK_API_KEY` | DeepSeek | не задан |
| `OPENROUTER_API_KEY` | OpenRouter | не задан |
| `GOOGLE_API_KEY` | Google Gemini | не задан |
| `GROQ_API_KEY` | Groq (опционально) | не задан |
| `VOLCENGINE_API_KEY` | Volcengine/ByteDance (опционально) | не задан |
| `SILICONFLOW_API_KEY` | SiliconFlow (опционально) | не задан |

```bash
export ANTHROPIC_API_KEY=sk-ant-api03-...
export DEEPSEEK_API_KEY=sk-...
export OPENROUTER_API_KEY=sk-or-v1-...
export GOOGLE_API_KEY=AIzaSy-...
```

> ⚠️ `ANTHROPIC_API_KEY`: OAuth-токен подписки (`sk-ant-oat01-...`) не принимается при роутинге через CCR. Нужен обычный API-ключ из [console.anthropic.com](https://console.anthropic.com/settings/keys).

---

## PII Proxy

### `USE_PII_PROXY`
Автозапуск HTTP-прокси с Presidio NLP для маскирования PII в API-трафике.

| | |
|---|---|
| **По умолчанию** | `false` |

```bash
USE_PII_PROXY=true
```

Установка перед первым использованием: `./iclaude.sh --install-pii-proxy`

Разовое включение: `./iclaude.sh --pii-proxy`

---

### `PII_PROXY_PORT` / `PII_PROXY_PORT_MIN` / `PII_PROXY_PORT_MAX`
Управление портом PII proxy.

| Переменная | По умолчанию | Описание |
|---|---|---|
| `PII_PROXY_PORT` | `0` (авто) | Зафиксировать конкретный порт |
| `PII_PROXY_PORT_MIN` | `20000` | Нижняя граница диапазона |
| `PII_PROXY_PORT_MAX` | `40000` | Верхняя граница диапазона |

```bash
# Фиксированный порт (для firewall-правил)
PII_PROXY_PORT=9000

# Или ограничить диапазон
PII_PROXY_PORT_MIN=30000
PII_PROXY_PORT_MAX=35000
```

---

## Отладка

### `DEBUG_LAUNCH`
Показать путь к бинарю, аргументы и переменные окружения при запуске.

| | |
|---|---|
| **По умолчанию** | не задан (отключено) |
| **Значение для включения** | `1` |

```bash
DEBUG_LAUNCH=1
```

---

## Примеры конфигураций

### Минимальная (только прокси)
```bash
PROXY_URL=https://user:password@proxy.company.com:8118
PROXY_CA=/etc/ssl/certs/corporate-ca.pem
```

### С роутером (DeepSeek + OpenRouter)
```bash
PROXY_URL=https://user:password@proxy.company.com:8118
PROXY_CA=/etc/ssl/certs/corporate-ca.pem

export DEEPSEEK_API_KEY=sk-...
export OPENROUTER_API_KEY=sk-or-v1-...
export GOOGLE_API_KEY=AIzaSy-...
```

### С PII-маскированием
```bash
USE_PII_PROXY=true
# PII_PROXY_PORT_MIN=30000
# PII_PROXY_PORT_MAX=35000
```

### Максимальное качество (Opus + high effort)
```bash
CLAUDE_CODE_MODEL=claude-opus-4-6
CLAUDE_CODE_EFFORT_LEVEL=high
CLAUDE_CODE_MAX_OUTPUT_TOKENS=32000
CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6
```

### Экономный режим (Haiku + без thinking)
```bash
ANTHROPIC_MODEL=claude-haiku-4-5-20251001
CLAUDE_CODE_EFFORT_LEVEL=low
CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1
```

---

## Безопасность

- `.claude_config` создаётся с правами `600` (только владелец)
- Файл исключён из git через `.gitignore`
- Не передавайте файл третьим лицам и не коммитьте в публичные репозитории
- Шаблон `.claude_config.example` — безопасен для git (не содержит секретов)

---

## См. также

- [`.claude_config.example`](../.claude_config.example) — шаблон со всеми переменными
- [PROXY.md](./PROXY.md) — детальная настройка прокси
- [ROUTER.md](./ROUTER.md) — конфигурация роутера и провайдеров
- [PII_MASKING.md](./PII_MASKING.md) — маскирование секретов
- [CONFIG_HIERARCHY.md](./CONFIG_HIERARCHY.md) — иерархия конфигурационных файлов
