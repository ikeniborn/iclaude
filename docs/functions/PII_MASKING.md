# Маскирование персональных данных в iclaude: PasteGuard и альтернативы

> Исследование инструментов маскирования PII/конфиденциальных данных при работе с Claude Code.
> Анализ PasteGuard, точек интеграции в изолированную среду и альтернативных решений.
>
> Дата: 2026-02-25 | Версия: 1.0

---

## Содержание

- [Зачем маскировать данные при работе с AI](#зачем-маскировать-данные-при-работе-с-ai)
- [Анализ PasteGuard](#анализ-pasteguard)
- [Текущая защита в iclaude](#текущая-защита-в-iclaude)
- [Интеграция PasteGuard с iclaude](#интеграция-pasteguard-с-iclaude)
- [Альтернативные решения](#альтернативные-решения)
- [Сравнительная таблица](#сравнительная-таблица)
- [Рекомендации](#рекомендации)
- [Архитектура предлагаемого решения](#архитектура-предлагаемого-решения)

---

## Зачем маскировать данные при работе с AI

При работе с Claude Code в реальных проектах в контекст неизбежно попадают:

| Категория | Примеры |
|-----------|---------|
| **Персональные данные (PII)** | Имена клиентов, email, телефоны, адреса, СНИЛС, ИНН |
| **Учётные данные** | API-ключи, токены, пароли, JWT, SSH-ключи |
| **Корпоративные данные** | Внутренние имена проектов, ID клиентов, финансовые данные |
| **Медицинские данные** | Диагнозы, результаты анализов, истории болезни |
| **Финансовые данные** | Номера карт, IBAN, суммы транзакций |

Проблема: **всё это передаётся в Anthropic API в облако**, даже если пользователь этого не осознаёт — через код, конфиги, логи, тестовые данные.

### Сценарии риска в Claude Code

```
Пользователь: "Отладь этот код"
→ Код содержит БД-строку с паролем: mysql://admin:secret123@prod.db:3306/customers
→ Контекст содержит customer_data.json с реальными email 50K клиентов
→ Всё это уходит в Anthropic API → сохраняется в логах → попадает в training data
```

---

## Анализ PasteGuard

**Репозиторий:** https://github.com/sgasser/pasteguard
**Версия:** v0.3.2 (20 февраля 2026)
**Лицензия:** Apache 2.0

### Концепция

PasteGuard — **локальный HTTP-прокси** между клиентом и облачным LLM. Принцип: "AI gets the context. Not your secrets."

```
Клиент (Claude Code)
    ↓ запрос с данными
PasteGuard (localhost:3000)
    ↓ маскирование PII: user@example.com → [[EMAIL_ADDRESS_1]]
    ↓ маскирование секретов: sk-abc123 → [[API_KEY_SK_1]]
Anthropic API / OpenAI API
    ↓ ответ с [[EMAIL_ADDRESS_1]]
PasteGuard
    ↓ восстановление: [[EMAIL_ADDRESS_1]] → user@example.com
Клиент (Claude Code)
```

### Два режима работы

| Режим | Описание | Когда использовать |
|-------|----------|-------------------|
| **`mask`** | Маскирование → Облачный LLM → Восстановление | Доверяем облаку, нужно скрыть конкретные данные |
| **`route`** | При обнаружении PII → перенаправление на локальный LLM (Ollama) | Полная изоляция чувствительных запросов |

### Что маскирует

#### PII (через Microsoft Presidio — 24 языка)

| Тип | Пример | Плейсхолдер |
|-----|--------|-------------|
| PERSON | Иван Петров | `[[PERSON_1]]` |
| EMAIL_ADDRESS | user@company.com | `[[EMAIL_ADDRESS_1]]` |
| PHONE_NUMBER | +7 (495) 123-4567 | `[[PHONE_NUMBER_1]]` |
| CREDIT_CARD | 4111-1111-1111-1111 | `[[CREDIT_CARD_1]]` |
| IP_ADDRESS | 192.168.1.100 | `[[IP_ADDRESS_1]]` |
| LOCATION | Москва, ул. Ленина 1 | `[[LOCATION_1]]` |
| IBAN_CODE | DE89 3704 0044 0532 0130 00 | `[[IBAN_CODE_1]]` |
| URL | https://internal.company.com | `[[URL_1]]` |

#### Секреты (regex-паттерны)

| Тип | Пример | Плейсхолдер |
|-----|--------|-------------|
| API_KEY_SK | sk-proj-aBcD...XyZ | `[[API_KEY_SK_1]]` |
| OPENSSH_PRIVATE_KEY | -----BEGIN OPENSSH PRIVATE KEY----- | `[[OPENSSH_PRIVATE_KEY_1]]` |
| JWT | eyJhbGciOiJIUzI1NiIs... | `[[JWT_1]]` |
| AWS_SECRET_KEY | wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY | `[[AWS_SECRET_KEY_1]]` |

### Технический стек

| Компонент | Технология |
|-----------|------------|
| Язык | TypeScript 96.7%, Python 2.3% |
| Runtime | Bun |
| Web-фреймворк | Hono v4.11 |
| PII-детекция | Microsoft Presidio (Python-сервис на порту 5002) |
| Секреты-детекция | Regex-паттерны |
| БД (логи) | SQLite |
| Контейнеризация | Docker + supervisord |
| Версия | v0.3.2 (активно поддерживается: 6 релизов за 5 недель) |

### Конфигурация

```yaml
# config.yaml
mode: route  # или mask

server:
  port: 3000
  host: 0.0.0.0

providers:
  anthropic:
    base_url: https://api.anthropic.com
    api_key: ${ANTHROPIC_API_KEY}

# Для route-режима: локальный LLM
local:
  type: ollama
  base_url: http://localhost:11434
  model: llama3.2

pii_detection:
  enabled: true
  presidio_url: http://localhost:5002
  languages: ["en", "ru"]
  score_threshold: 0.7
  entities: [PERSON, EMAIL_ADDRESS, PHONE_NUMBER, CREDIT_CARD, IP_ADDRESS]
  scan_roles: [user]

secrets_detection:
  enabled: true
  action: mask  # mask | block | route_local
  entities: [OPENSSH_PRIVATE_KEY, API_KEY_SK, JWT]

masking:
  whitelist:
    - "You are Claude Code"
    - "CLAUDE.md"
```

### Ограничения PasteGuard

| Ограничение | Детали |
|-------------|--------|
| **Требует Docker** | Presidio (Python NLP) запускается только в Docker |
| **Латентность** | +50-200мс на запрос из-за NLP-обработки |
| **False negatives** | NLP-модели не 100% точны; редкие форматы могут пропускаться |
| **Потребление ресурсов** | Presidio использует ~500MB RAM |
| **Только OpenAI/Anthropic API** | Не поддерживает нестандартные API |
| **Браузерное расширение в beta** | Для ChatGPT/Claude.ai — пока нестабильно |
| **Мультиязычность** | Требует явного указания языков; русский поддерживается, но хуже EN |

---

## Текущая защита в iclaude

iclaude уже имеет несколько механизмов защиты данных:

### 1. block-secrets.py (PreToolUse Hook)

**Путь:** `.nvm-isolated/.claude-isolated/hooks/block-secrets.py`

**Работает:** Перехватывает каждый вызов инструментов Read/Edit/Write/Bash **до** передачи в Claude Code.

```python
# Защищённые паттерны в путях файлов
SENSITIVE_PATH_PATTERNS = [
    '.env', '.pem', '.key',
    'credentials', 'secret', '.ssh', '.aws',
    '.gnupg', '.kube', 'token', 'id_rsa',
    'id_ed25519', 'id_ecdsa', 'private_key',
    '.netrc', '.pgpass'
]

# Безопасные суффиксы (шаблоны — не блокируются)
SAFE_SUFFIXES = ('.example', '.sample', '.template', '.dist')
```

**Что НЕ делает:** Не маскирует контент файлов, не проверяет содержимое промптов.

### 2. Конфигурационная изоляция

- `.claude_config` (chmod 600) — учётные данные не попадают в git
- `CLAUDE_CONFIG_DIR` → `.nvm-isolated/.claude-isolated/` — изоляция от системного `~/.claude/`
- `.gitignore` исключает session data, history.jsonl

### 3. Отсутствующая защита

| Что не защищено | Риск |
|-----------------|------|
| Контент файлов (не пути) | Код с паролями/токенами попадает в Claude Code |
| Пользовательские промпты | PII в тексте запросов уходит в API |
| history.jsonl | Хранит все взаимодействия без фильтрации |
| Аргументы инструментов | JSON с данными виден Claude Code (и Anthropic) |
| Ответы Claude | Могут содержать воспроизведённые PII |

---

## Интеграция PasteGuard с iclaude

### Архитектура интеграции

```mermaid
graph TB
    User["Пользователь\n./iclaude.sh"] --> iclaude["iclaude.sh\nEntry Point"]

    subgraph iclaude_env["Изолированная среда (.nvm-isolated)"]
        iclaude --> Launcher["lib/launcher/launch.sh"]
        Launcher --> Claude["Claude Code CLI\n(claude binary)"]
    end

    subgraph pasteguard_env["PasteGuard (Docker)"]
        PG["PasteGuard\nlocalhost:3000"]
        Presidio["Microsoft Presidio\nlocalhost:5002"]
        PG --> Presidio
    end

    Claude -->|"ANTHROPIC_BASE_URL=\nhttp://localhost:3000/anthropic"| PG
    PG -->|"Маскированный запрос"| AnthropicAPI["Anthropic API\n(облако)"]
    AnthropicAPI -->|"Ответ с плейсхолдерами"| PG
    PG -->|"Восстановленный ответ"| Claude

    style pasteguard_env fill:#e8f5e9
    style iclaude_env fill:#e3f2fd
```

### Метод 1: Переменная окружения (РЕКОМЕНДУЕТСЯ — Сложность: ⭐)

Самый простой способ — переопределить `ANTHROPIC_BASE_URL` в `.claude_config`:

**Шаг 1: Запустить PasteGuard**

```bash
# Создать config.yaml (скопировать из примера ниже)
docker run -d \
  --name pasteguard \
  -p 3000:3000 \
  -v $(pwd)/pasteguard-config.yaml:/pasteguard/config.yaml \
  ghcr.io/sgasser/pasteguard:en
```

**Шаг 2: Добавить в `.claude_config`**

```bash
# В файл .claude_config добавить:
export ANTHROPIC_BASE_URL=http://localhost:3000/anthropic

# Проверить что PasteGuard запущен перед iclaude:
# curl http://localhost:3000/health
```

**Шаг 3: Запустить iclaude**

```bash
./iclaude.sh
```

Claude Code автоматически подхватит `ANTHROPIC_BASE_URL` и начнёт отправлять запросы через PasteGuard.

**Проверка:**

```bash
# Dashboard PasteGuard покажет маскированные запросы
open http://localhost:3000/dashboard
```

### Метод 2: Автозапуск PasteGuard через iclaude (Сложность: ⭐⭐⭐)

Интегрировать как модуль iclaude с автозапуском:

**Файл: `lib/pasteguard/detect.sh`**

```bash
#!/usr/bin/env bash
# Определяет доступность PasteGuard

is_pasteguard_running() {
    curl -s --max-time 2 http://localhost:3000/health >/dev/null 2>&1
}

setup_pasteguard_proxy() {
    if [[ "${USE_PASTEGUARD:-false}" == "true" ]]; then
        if ! is_pasteguard_running; then
            print_warning "PasteGuard не запущен. Запуск..."
            docker start pasteguard 2>/dev/null || \
                print_error "PasteGuard не найден. Установите: ./iclaude.sh --install-pasteguard"
            return 1
        fi
        export ANTHROPIC_BASE_URL="http://localhost:3000/anthropic"
        print_info "PasteGuard активен: PII маскируется перед отправкой в Anthropic API"
    fi
}
```

**В `.claude_config`:**

```bash
USE_PASTEGUARD=true
```

### Метод 3: Интеграция через Claude Code Hook (Сложность: ⭐⭐)

Создать PreToolUse hook для маскирования через PasteGuard API:

**Файл: `.nvm-isolated/.claude-isolated/hooks/mask-pii.py`**

```python
#!/usr/bin/env python3
"""
PreToolUse hook: Маскирует PII в аргументах инструментов через PasteGuard /api/mask
Дополняет block-secrets.py — тот блокирует доступ к файлам с секретами,
этот маскирует PII в передаваемом тексте.
"""
import json
import sys
import urllib.request

PASTEGUARD_URL = "http://localhost:3000/api/mask"
MASK_TOOL_CALLS = {"Write", "Edit", "Bash"}  # Только запись/исполнение

def mask_text(text: str) -> str:
    """Маскирует PII через PasteGuard /api/mask endpoint."""
    try:
        payload = json.dumps({"text": text}).encode()
        req = urllib.request.Request(
            PASTEGUARD_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=2) as resp:
            result = json.load(resp)
            return result.get("masked_text", text)
    except Exception:
        return text  # Fallback: не блокировать при недоступности PasteGuard

def main():
    hook_input = json.load(sys.stdin)
    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})

    if tool_name not in MASK_TOOL_CALLS:
        sys.exit(0)  # Пропустить — инструмент не записывает данные

    # Маскировать content/command аргументы
    for key in ("content", "command", "new_string"):
        if key in tool_input and isinstance(tool_input[key], str):
            tool_input[key] = mask_text(tool_input[key])

    # Вернуть модифицированный вход (для поддерживаемых hook-систем)
    print(json.dumps({"tool_input": tool_input}))
    sys.exit(0)

if __name__ == "__main__":
    main()
```

> **Важно (Claude Code v2.0.10+):** Начиная с v2.0.10, `PreToolUse` хуки **могут модифицировать** аргументы инструментов перед выполнением. Для вывода модифицированных данных хук должен напечатать JSON в stdout: `{"hookSpecificOutput": {"toolInputOverride": {...}}}`. Это позволяет реализовать **прозрачное маскирование PII** — Claude видит только маскированные данные, операция продолжается.

### Конфигурация PasteGuard для iclaude

```yaml
# pasteguard-config.yaml — конфиг для работы с iclaude

mode: mask  # или route если есть локальный Ollama

server:
  port: 3000
  host: 0.0.0.0

providers:
  anthropic:
    base_url: https://api.anthropic.com
    # API key берётся из Authorization header — iclaude передаёт его автоматически

pii_detection:
  enabled: true
  presidio_url: http://localhost:5002  # Presidio внутри Docker
  languages: ["ru", "en"]  # Русский + английский
  score_threshold: 0.65  # Чуть ниже порога для лучшего recall
  entities:
    - PERSON
    - EMAIL_ADDRESS
    - PHONE_NUMBER
    - CREDIT_CARD
    - IBAN_CODE
    - IP_ADDRESS
    - LOCATION
    - URL
  scan_roles: [user]  # Сканировать только сообщения пользователя

secrets_detection:
  enabled: true
  action: block  # Заблокировать при обнаружении секретов (Claude Code не должен их видеть)
  entities:
    - OPENSSH_PRIVATE_KEY
    - PEM_PRIVATE_KEY
    - API_KEY_SK
    - AWS_SECRET_KEY
    - JWT
  log_detected_types: true

masking:
  whitelist:
    - "You are Claude Code"
    - "CLAUDE.md"
    - "iclaude.sh"
    - ".nvm-isolated"
    - "ANTHROPIC_BASE_URL"

logging:
  database: /pasteguard/data/pasteguard.db
  retention_days: 7
  log_content: false       # Не логировать исходный контент
  log_masked_content: true  # Логировать только маскированный вариант

dashboard:
  enabled: true
  auth:
    username: admin
    password: changeme  # Сменить!
```

### Docker Compose для PasteGuard + Ollama (режим route)

```yaml
# docker-compose.pasteguard.yml
version: "3.8"

services:
  pasteguard:
    image: ghcr.io/sgasser/pasteguard:eu  # eu-образ поддерживает русский язык
    container_name: pasteguard
    ports:
      - "3000:3000"
    volumes:
      - ./pasteguard-config.yaml:/pasteguard/config.yaml
      - pasteguard_data:/pasteguard/data
    restart: unless-stopped
    environment:
      - TZ=Europe/Moscow

  ollama:
    image: ollama/ollama
    container_name: ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    restart: unless-stopped

volumes:
  pasteguard_data:
  ollama_data:
```

```bash
# Запуск
docker compose -f docker-compose.pasteguard.yml up -d

# Загрузка локальной модели
docker exec ollama ollama pull llama3.2:3b

# Проверка
curl http://localhost:3000/health
```

---

## Альтернативные решения

### 1. Microsoft Presidio (standalone)

**Тип:** Open source библиотека + REST API
**Технологии:** Python, spaCy, transformers
**GitHub:** https://github.com/microsoft/presidio

**Описание:** Движок NLP-детекции PII, который PasteGuard использует внутри. Можно использовать напрямую как Python-сервис.

**Интеграция с Claude Code:**

```python
# Скрипт-обёртка вместо PasteGuard
from presidio_analyzer import AnalyzerEngine
from presidio_anonymizer import AnonymizerEngine

analyzer = AnalyzerEngine()
anonymizer = AnonymizerEngine()

def mask_pii(text: str) -> str:
    results = analyzer.analyze(text=text, language="en")
    return anonymizer.anonymize(text=text, analyzer_results=results).text
```

| Параметр | Значение |
|----------|----------|
| Сложность интеграции | ⭐⭐⭐ (нужно писать обёртку) |
| Изолированная среда | ✅ Можно установить в `.nvm-isolated` через pip |
| Open source | ✅ MIT License |
| Требования | Python 3.9+, ~500MB для spaCy моделей |
| Преимущества | Максимальная гибкость, нет HTTP overhead |
| Ограничения | Нет готовой прокси-обёртки, нет веб-дашборда |

### 2. LiteLLM (LLM-прокси с базовой безопасностью)

**Тип:** Open source LLM-прокси
**GitHub:** https://github.com/BerriAI/litellm

**Описание:** Унифицированный прокси для 100+ LLM-провайдеров. Базовая защита через input/output guardrails.

**PII-возможности LiteLLM:**

```yaml
# litellm_config.yaml
guardrails:
  - guardrail_name: "presidio"
    litellm_params:
      guardrail: presidio
      mode: "pre_call"  # до отправки в LLM
      presidio_analyzer_api_base: http://localhost:5002
      entities_to_mask: [PERSON, EMAIL_ADDRESS, PHONE_NUMBER]
```

| Параметр | Значение |
|----------|----------|
| Сложность интеграции | ⭐⭐ (drop-in замена base_url) |
| Изолированная среда | ✅ pip install litellm |
| Open source | ✅ MIT License |
| PII-маскирование | ⚠️ Через интеграцию с Presidio (не нативное) |
| Преимущества | Многофункциональный: мониторинг, retry, load balancing |
| Ограничения | PII-функции менее специализированы чем у PasteGuard |

### 3. Scrubadub (Python-библиотека)

**Тип:** Open source Python-библиотека
**GitHub:** https://github.com/LeapBeyond/scrubadub
**PyPI:** `pip install scrubadub`

**Описание:** Лёгкая библиотека для очистки PII в тексте. Без Docker, без тяжёлых NLP-моделей.

```python
import scrubadub

text = "Contact John Smith at john@example.com or call +1-555-123-4567"
scrubber = scrubadub.Scrubber()
clean = scrubber.clean(text)
# → "Contact {{NAME}} at {{EMAIL}} or call {{PHONE}}"
```

**Использование в Claude Code Hook:**

```python
# В .nvm-isolated/.claude-isolated/hooks/scrub-pii.py
import scrubadub
import json
import sys

def main():
    hook_input = json.load(sys.stdin)
    # Логировать попытки доступа к чувствительным данным
    tool_input = hook_input.get("tool_input", {})
    content = tool_input.get("content", "")

    if content and scrubadub.Scrubber().has_pii(content):
        # Предупредить пользователя
        sys.stderr.write("⚠️  Обнаружены персональные данные в передаваемом контенте\n")

    sys.exit(0)

if __name__ == "__main__":
    main()
```

| Параметр | Значение |
|----------|----------|
| Сложность интеграции | ⭐ (pip install + 10 строк кода) |
| Изолированная среда | ✅ Отлично подходит |
| Open source | ✅ MIT License |
| Точность | ⚠️ Ниже Presidio, regex-based |
| Преимущества | Нет зависимостей, быстро, легко |
| Ограничения | Нет восстановления данных, нет русского языка |

### 4. Mitmproxy + Python-скрипт

**Тип:** Open source HTTP-прокси с scriptable перехватом
**GitHub:** https://github.com/mitmproxy/mitmproxy

**Описание:** Профессиональный инструмент для перехвата и модификации HTTP-трафика. Можно написать скрипт для маскирования запросов к Anthropic API.

```python
# pii_masker.py — аддон для mitmproxy
import json
import re
from mitmproxy import http

EMAIL_RE = re.compile(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b')
TOKEN_RE = re.compile(r'\bsk-[A-Za-z0-9]{20,}\b')

def request(flow: http.HTTPFlow):
    if "anthropic.com" in flow.request.host:
        body = flow.request.text
        if body:
            body = EMAIL_RE.sub('[EMAIL]', body)
            body = TOKEN_RE.sub('[TOKEN]', body)
            flow.request.text = body
```

**Запуск:**

```bash
# В отдельном терминале
mitmproxy --mode regular -p 8080 --scripts pii_masker.py

# В .claude_config
HTTPS_PROXY=http://localhost:8080
NODE_TLS_REJECT_UNAUTHORIZED=0  # Для перехвата TLS (небезопасно!)
```

| Параметр | Значение |
|----------|----------|
| Сложность интеграции | ⭐⭐⭐⭐ (TLS interception сложно настроить) |
| Изолированная среда | ✅ pip install mitmproxy |
| Open source | ✅ MIT License |
| Преимущества | Максимальный контроль, перехват на уровне TCP |
| Ограничения | Требует отключения TLS verification, только regex |

### 5. Claude Code Hooks (нативный подход — ОБНОВЛЕНО v2.0.10+)

**Тип:** Встроенный механизм Claude Code
**Документация:** https://docs.anthropic.com/en/docs/claude-code/hooks

**Описание:** Хуки PreToolUse/PostToolUse позволяют перехватывать каждый вызов инструментов и блокировать/модифицировать их.

**Ключевое обновление v2.0.10:** `PreToolUse` хуки теперь могут **модифицировать аргументы инструментов** перед выполнением. Это позволяет реализовать прозрачное маскирование PII без блокировки операций.

**Три типа реакции хука:**

| Действие | Exit code | stdout | Эффект |
|----------|:---------:|--------|--------|
| Разрешить | `0` | пусто | Инструмент выполняется без изменений |
| Модифицировать | `0` | JSON с `toolInputOverride` | Инструмент выполняется с изменёнными аргументами |
| Блокировать | `2` | сообщение | Инструмент не выполняется, Claude видит причину |

**Hook для маскирования PII в аргументах инструментов (v2.0.10+):**

```python
#!/usr/bin/env python3
"""
PreToolUse hook: Маскирует PII и секреты в аргументах инструментов.
Работает в режиме МОДИФИКАЦИИ (не блокировки) — инструмент выполняется,
но с уже маскированными данными.

Claude Code v2.0.10+ поддерживает toolInputOverride в stdout.
"""
import json
import sys
import re

# Паттерны для маскирования (regex → placeholder)
REDACT_PATTERNS = [
    # API ключи
    (re.compile(r'\bsk-(?:ant-|proj-)?[A-Za-z0-9\-_]{20,}'), '[ANTHROPIC_KEY]'),
    (re.compile(r'\bAKIA[0-9A-Z]{16}\b'), '[AWS_ACCESS_KEY]'),
    (re.compile(r'(?i)(?:api[_-]?key|secret|token)\s*[=:]\s*["\']?([^\s"\']{16,})'),
     '[SECRET_VALUE]'),
    # Приватные ключи
    (re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
     '[PRIVATE_KEY_REDACTED]'),
    # Credentials в URL
    (re.compile(r'(https?://)[^:@\s]+:[^@\s]+@'), r'\1[CREDENTIALS]@'),
    # Номера банковских карт (Luhn-like pattern)
    (re.compile(r'\b(?:\d{4}[- ]?){3}\d{4}\b'), '[CARD_NUMBER]'),
    # Email (опционально — раскомментировать если нужно)
    # (re.compile(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), '[EMAIL]'),
]

# Инструменты для маскирования в аргументах
REDACT_TOOLS = {"Write", "Edit", "MultiEdit", "Bash"}

# Поля аргументов для сканирования
REDACT_FIELDS = {"content", "command", "new_string", "old_string"}


def redact_text(text: str) -> tuple[str, bool]:
    """Маскирует секреты в тексте. Возвращает (текст, изменён_ли)."""
    changed = False
    for pattern, replacement in REDACT_PATTERNS:
        new_text = pattern.sub(replacement, text)
        if new_text != text:
            changed = True
            text = new_text
    return text, changed


def main():
    hook_input = json.load(sys.stdin)
    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})

    if tool_name not in REDACT_TOOLS:
        sys.exit(0)  # Не наш инструмент

    modified = False
    new_tool_input = dict(tool_input)

    for field in REDACT_FIELDS:
        if field in tool_input and isinstance(tool_input[field], str):
            redacted, changed = redact_text(tool_input[field])
            if changed:
                new_tool_input[field] = redacted
                modified = True
                sys.stderr.write(
                    f"[pii-hook] Маскированы секреты в поле '{field}' "
                    f"инструмента {tool_name}\n"
                )

    if modified:
        # Вернуть модифицированные аргументы (Claude Code v2.0.10+)
        print(json.dumps({
            "hookSpecificOutput": {
                "toolInputOverride": new_tool_input
            }
        }))

    sys.exit(0)


if __name__ == "__main__":
    main()
```

**Конфигурация в settings.json:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 /path/to/.claude-isolated/hooks/redact-secrets.py"
          }
        ]
      }
    ]
  }
}
```

**Расширение block-secrets.py для обнаружения PII в содержимом файлов:**

```python
# Добавить в существующий block-secrets.py (в конец функции check_tool_use)

import re

# Паттерны для предупреждений в содержимом (не блокировка, только предупреждение)
CONTENT_WARN_PATTERNS = [
    (re.compile(r'AKIA[0-9A-Z]{16}'), "AWS Access Key ID"),
    (re.compile(r'-----BEGIN [A-Z ]+PRIVATE KEY-----'), "Private key"),
    (re.compile(r'(?i)password\s*[=:]\s*[^\s\n]{8,}'), "Password in plaintext"),
    (re.compile(r'\b(?:\d{4}[- ]?){3}\d{4}\b'), "Credit card number"),
]

def warn_content_for_secrets(content: str, file_path: str) -> None:
    """Предупреждает о найденных секретах в содержимом (не блокирует)."""
    for pattern, description in CONTENT_WARN_PATTERNS:
        if pattern.search(content):
            sys.stderr.write(
                f"⚠️  Найден {description} в {file_path}. "
                f"Проверьте, что это не реальные данные.\n"
            )
```

| Параметр | Значение |
|----------|----------|
| Сложность интеграции | ⭐ (расширение существующего block-secrets.py) |
| Изолированная среда | ✅ Уже в `.claude-isolated/hooks/` |
| Open source | ✅ Часть iclaude |
| Версия CC | Claude Code v2.0.10+ для модификации аргументов |
| Преимущества | Нет внешних зависимостей, встроено, прозрачно |
| Ограничения | Только regex (без NLP), нет русских имён |

### 6. AWS Comprehend / Google DLP

**Тип:** Облачный API
**Провайдеры:** AWS, Google Cloud

**Описание:** Коммерческие NLP-сервисы с высокой точностью детекции PII.

```python
# AWS Comprehend
import boto3

comprehend = boto3.client('comprehend')
response = comprehend.detect_pii_entities(Text=text, LanguageCode='en')
# Поддерживает 20+ типов PII с высокой точностью
```

| Параметр | Значение |
|----------|----------|
| Сложность интеграции | ⭐⭐ (SDK + API keys) |
| Изолированная среда | ✅ через pip install boto3 |
| Open source | ❌ Коммерческий |
| Стоимость | ~$0.001/1000 символов |
| Преимущества | Высокая точность, 12+ языков, enterprise SLA |
| Ограничения | Данные уходят в AWS/Google (парадокс приватности!), платно |

---

## Сравнительная таблица

| Решение | Тип | OS | Сложность | Точность | Производительность | Изоляция | Стоимость |
|---------|-----|:--:|:---------:|:--------:|:------------------:|:--------:|:---------:|
| **PasteGuard** | Прокси | ✅ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ Docker | Бесплатно |
| **Presidio (standalone)** | Library | ✅ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ pip | Бесплатно |
| **LiteLLM + Presidio** | Прокси | ✅ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ pip | Бесплатно |
| **Scrubadub** | Library | ✅ | ⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ pip | Бесплатно |
| **block-secrets.py (расширение)** | Hook | ✅ | ⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ встроен | Бесплатно |
| **Mitmproxy** | Прокси | ✅ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ✅ pip | Бесплатно |
| **AWS Comprehend** | API | ❌ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⚠️ облако | Платно |
| **Google DLP** | API | ❌ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⚠️ облако | Платно |
| **Private AI** | Service | ❌ | ⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ self-hosted | Платно |

**OS** = Open Source | **Изоляция** = Работает в изолированной среде без Docker (если не указано иное)

---

## Рекомендации

### Стратегия по уровням защиты

```
Уровень 1 (МИНИМУМ, уже есть): block-secrets.py
  → Блокирует доступ к файлам с секретами (.env, .key, .pem)
  → Нулевые затраты, нет зависимостей

Уровень 2 (БЫСТРО, без Docker): редактирующий PreToolUse hook (CC v2.0.10+)
  → Regex-маскирование секретов в аргументах инструментов
  → Прозрачно для пользователя: инструмент выполняется с маскированными данными
  → toolInputOverride в stdout → Claude видит только маскированный контент
  → 30 минут работы, нет зависимостей

Уровень 3 (РЕКОМЕНДУЕТСЯ): PasteGuard в Docker
  → Полноценное NLP-маскирование через Presidio
  → Поддержка русского языка (образ :eu)
  → Восстановление данных в ответах
  → Веб-дашборд для мониторинга
  → Сочетается с Уровнем 2 для двойной защиты

Уровень 4 (МАКСИМУМ): PasteGuard режим route + Ollama
  → При обнаружении PII → локальная модель
  → Данные никогда не покидают машину
  → Требует GPU/CPU для Ollama
```

### Что делать прямо сейчас (без Docker)

**Вариант A (Claude Code v2.0.10+): редактирующий PreToolUse hook**

Создать `/path/to/.claude-isolated/hooks/redact-secrets.py` (полный код в разделе "Альтернативные решения → Claude Code Hooks").

Зарегистрировать в `.nvm-isolated/.claude-isolated/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .nvm-isolated/.claude-isolated/hooks/redact-secrets.py"
          }
        ]
      }
    ]
  }
}
```

**Вариант B: Расширение block-secrets.py** — добавить предупреждения о контенте:

```python
# Добавить в конец block-secrets.py перед основной логикой

CONTENT_SECRET_PATTERNS = [
    (re.compile(r'sk-(?:ant-|proj-)?[A-Za-z0-9\-_]{20,}'), "Anthropic/OpenAI API key"),
    (re.compile(r'AKIA[0-9A-Z]{16}'), "AWS Access Key ID"),
    (re.compile(r'-----BEGIN (?:RSA |EC )?PRIVATE KEY-----'), "Private key"),
    (re.compile(r'(?i)password\s*[=:]\s*[^\s\n]{8,}'), "Password in plaintext"),
    (re.compile(r'(?i)(?:secret|token)\s*[=:]\s*[^\s\n]{8,}'), "Secret/Token"),
]
```

### Конкретные use cases

| Сценарий | Рекомендация |
|----------|--------------|
| **Корпоративная среда, данные клиентов** | PasteGuard (mask режим) + Presidio EU-образ |
| **Медицинские/финансовые данные** | PasteGuard (route режим) + Ollama локально |
| **Личные проекты, базовая защита** | Расширение block-secrets.py |
| **Без Docker** | LiteLLM + Presidio через pip |
| **Команда разработчиков** | PasteGuard с дашбордом + basic auth |
| **Корпоративная сеть с прокси** | PasteGuard совместим с iclaude proxy (см. ниже) |

### Совместимость с iclaude proxy

PasteGuard и iclaude proxy работают вместе:

```
Claude Code
    ↓ ANTHROPIC_BASE_URL=http://localhost:3000/anthropic
PasteGuard (маскирование)
    ↓ HTTPS_PROXY=https://corp-proxy:8118 (от iclaude)
Корпоративный прокси
    ↓
Anthropic API
```

Конфиг в `.claude_config`:

```bash
# Корпоративный прокси (iclaude)
PROXY_URL=https://user:pass@corp-proxy.example.com:8118

# PasteGuard (маскирование PII)
export ANTHROPIC_BASE_URL=http://localhost:3000/anthropic
```

PasteGuard наследует `HTTPS_PROXY` из окружения и использует его для исходящих запросов.

---

## Архитектура предлагаемого решения

### Полная схема с PasteGuard (Уровень 3)

```
┌──────────────────────────────────────────────────────────────┐
│                    Машина пользователя                        │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              iclaude (изолированная среда)               │ │
│  │                                                          │ │
│  │  iclaude.sh → launcher/launch.sh → exec claude          │ │
│  │                                                          │ │
│  │  Переменные окружения:                                   │ │
│  │  • CLAUDE_CONFIG_DIR=.nvm-isolated/.claude-isolated/    │ │
│  │  • ANTHROPIC_BASE_URL=http://localhost:3000/anthropic   │ │
│  │  • HTTPS_PROXY=https://corp-proxy:8118 (если нужно)     │ │
│  │                                                          │ │
│  │  Хуки (.claude-isolated/hooks/):                        │ │
│  │  • block-secrets.py → Блокировка доступа к файлам       │ │
│  │  • postToolUse.hook.sh → Мониторинг контекста           │ │
│  └─────────────────────────────────────────────────────────┘ │
│                         │                                     │
│                    HTTP запрос                                │
│                         ↓                                     │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              PasteGuard (Docker)                         │ │
│  │              localhost:3000                              │ │
│  │                                                          │ │
│  │  1. Принять запрос от Claude Code                       │ │
│  │  2. Presidio: обнаружить PII в тексте                  │ │
│  │     user@company.com → [[EMAIL_ADDRESS_1]]              │ │
│  │  3. Regex: обнаружить секреты                           │ │
│  │     sk-ant-xxx → [[API_KEY_SK_1]]                       │ │
│  │  4. Форвардинг маскированного запроса                   │ │
│  │  5. Восстановление в ответе                             │ │
│  │  6. Логирование в SQLite (без исходных данных)          │ │
│  └─────────────────────────────────────────────────────────┘ │
│                         │                                     │
└─────────────────────────│─────────────────────────────────────┘
                          │ HTTPS (через корп. прокси если нужно)
                          ↓
              ┌───────────────────────┐
              │    Anthropic API      │
              │   api.anthropic.com   │
              │   (только маскиров.)  │
              └───────────────────────┘
```

### Матрица решений

```
              Простота интеграции
                     ▲
              ⭐⭐⭐⭐⭐│  Scrubadub         block-secrets
                     │  (pip, no Docker)  (уже есть)
              ⭐⭐⭐⭐ │
                     │        LiteLLM+Presidio
              ⭐⭐⭐  │
                     │           PasteGuard ◄── РЕКОМЕНДУЕТСЯ
              ⭐⭐   │
                     │
              ⭐     │  Mitmproxy
                     │
                     └─────────────────────────────► Точность маскирования
                        ⭐⭐    ⭐⭐⭐   ⭐⭐⭐⭐   ⭐⭐⭐⭐⭐
                       Regex   NLP  NLP+context  ML+cloud
```

---

## Быстрый старт

### Вариант A: Минимальный (без Docker)

```bash
# 1. Расширить block-secrets.py regex-проверкой контента
# (см. раздел "Что делать прямо сейчас")

# 2. Добавить в .claude_config предупреждение при наличии PII
echo "# PII warnings enabled in block-secrets.py" >> .claude_config

# Результат: предупреждения при обнаружении секретов в коде
```

### Вариант B: PasteGuard (рекомендуется)

```bash
# 1. Скачать конфиг
curl -o pasteguard-config.yaml \
  https://raw.githubusercontent.com/sgasser/pasteguard/main/config.example.yaml

# 2. Настроить (выбрать режим, языки, сущности)
vim pasteguard-config.yaml

# 3. Запустить PasteGuard
docker run -d \
  --name pasteguard \
  -p 3000:3000 \
  -v $(pwd)/pasteguard-config.yaml:/pasteguard/config.yaml \
  -v pasteguard_data:/pasteguard/data \
  ghcr.io/sgasser/pasteguard:eu

# 4. Добавить в .claude_config
echo "export ANTHROPIC_BASE_URL=http://localhost:3000/anthropic" >> .claude_config

# 5. Запустить iclaude
./iclaude.sh

# 6. Мониторинг
open http://localhost:3000/dashboard
```

### Вариант C: PasteGuard + Ollama (максимальная защита)

```bash
# 1. Установить Ollama
curl -fsSL https://ollama.ai/install.sh | sh
ollama pull llama3.2:3b

# 2. Docker Compose
docker compose -f docker-compose.pasteguard.yml up -d

# 3. Настроить режим route в pasteguard-config.yaml
# mode: route
# local:
#   type: ollama
#   base_url: http://host.docker.internal:11434
#   model: llama3.2:3b

# 4. Добавить в .claude_config
echo "export ANTHROPIC_BASE_URL=http://localhost:3000/anthropic" >> .claude_config
./iclaude.sh
```

---

## Идемпотентная установка PII Proxy

> **Статус:** Реализовано (2026-03-03)
> **Файл:** `lib/pii-proxy/install.sh` — функция `install_isolated_pii_proxy()`

`--install-pii-proxy` полностью идемпотентна: повторный запуск безопасен и не перекачивает уже установленные компоненты.

### Проверки по шагам

| Шаг | Что проверяется | Экономия при пропуске |
|-----|-----------------|----------------------|
| **venv** | `$PII_PROXY_VENV/bin/python3` существует и версия ≥ 3.8 | Пересоздание venv + pip upgrade |
| **Presidio** | `pip show presidio-analyzer presidio-anonymizer spacy` | ~100MB pip install |
| **spaCy lg** | `spacy.load('en_core_web_lg')` загружается без ошибки | **587MB скачивания** |
| **spaCy sm** | Fallback: `spacy.load('en_core_web_sm')` | 12MB (при использовании sm) |
| **Server script** | `diff -q` источника и установленного файла | Копирование файла |

### Вывод при повторном запуске (всё актуально)

```
✓ Python 3.11: OK
✓ venv: already exists, skipping creation
✓ Presidio: already installed, skipping pip install
✓ spaCy model: en_core_web_lg already installed, skipping download (587MB saved)
✓ Server script: up to date, skipping copy

✓ PII-Proxy: already up to date (4 steps skipped)
  Use --force to reinstall: ./iclaude.sh --install-pii-proxy --force
```

### Принудительная переустановка

```bash
./iclaude.sh --install-pii-proxy --force
```

Флаг `--force`:
- Удаляет существующий venv (`rm -rf`) и создаёт заново
- Запускает `pip install` безусловно
- Скачивает spaCy модель заново
- Перезаписывает server script

---

## Известные проблемы и ограничения

### 1. Маскирование системных промптов (ложные срабатывания)

PasteGuard может маскировать технические данные в системных промптах Claude Code (CLAUDE.md, пути файлов). Решение — использовать `whitelist` в конфиге.

### 2. Потеря контекста при маскировании кода

Если Claude видит `[[EMAIL_ADDRESS_1]]` вместо реального email, он не сможет помочь с валидацией email-адресов. Решение — использовать тестовые данные в паттерне `*@example.com`.

### 3. Latency

Presidio добавляет 50-200мс к каждому запросу. Для интерактивного использования незаметно, для batch-обработки значительно.

### 4. Русский язык

PasteGuard v0.3.2 поддерживает русский, но Presidio хуже распознаёт русские имена/адреса чем английские. Рекомендуется повысить `score_threshold: 0.5` для русского.

### 5. Streaming responses

PasteGuard поддерживает streaming — маскирование восстанавливается в буфере. Возможны артефакты при частичных токенах.

### 6. 502 PII proxy upstream unavailable

При медленном ответе upstream (Opus + extended thinking + большие промпты время до первого байта превышает таймаут) прокси возвращал `502 PII proxy upstream unavailable`. Таймаут теперь разделён на connect/read и настраивается через переменные окружения:

| Переменная | Назначение | По умолчанию |
|-----------|-----------|--------------|
| `PII_PROXY_CONNECT_TIMEOUT` | Таймаут TCP-соединения с upstream (секунды) | `10` |
| `PII_PROXY_READ_TIMEOUT` | Таймаут чтения ответа upstream (секунды); повысить для длинных extended-thinking ответов | `300` |

Дополнительно: транзиентные ошибки установки соединения повторяются (connect-retry, 2 попытки), а таймаут/сброс соединения в середине SSE-стрима завершает поток без порчи уже начатого ответа.

---

## Реализованное решение: двухуровневые хуки

> **Статус:** Реализовано и протестировано (2026-02-25)
> **Тесты:** 37/37 passed (`tests/test-redact-hook.sh`)

В iclaude реализована двухуровневая защита через PreToolUse хуки — без внешних зависимостей, только стандартная библиотека Python.

### Архитектура пайплайна

```
Claude Code → PreToolUse
    ├── block-secrets.py    (Слой 1: блокировка по ПУТИ)
    │   ├── .env → exit 2 (блокировать)
    │   ├── .pem → exit 2
    │   ├── .ssh/* → exit 2
    │   └── остальное → exit 0 (пропустить к Слою 2)
    │
    └── redact-secrets.py   (Слой 2: маскирование СОДЕРЖИМОГО)
        ├── toolInputOverride → Claude видит маскированные данные
        └── оригинал → никуда не отправляется
```

### Покрытие паттернов (v2, 2026-02-25)

| Категория | Паттерн | Плейсхолдер |
|-----------|---------|-------------|
| Anthropic/OpenAI/Stripe | `sk-ant-...`, `sk-proj-...`, `sk-or-v1-...` | `[API_KEY_REDACTED]` |
| AWS Access Key ID | `AKIA{16}` | `[AWS_ACCESS_KEY_ID]` |
| AWS Secret Access Key | `VAR_NAME={40}` | `VAR_NAME=[AWS_SECRET_KEY_REDACTED]` |
| PEM private keys | `BEGIN * PRIVATE KEY` | `[PRIVATE_KEY_REDACTED]` |
| GitHub классический PAT | `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_` | `[GITHUB_TOKEN]` |
| GitHub fine-grained PAT | `github_pat_{82+}` | `[GITHUB_TOKEN]` |
| Credentials в URL | `scheme://user:pass@host` (любые схемы) | `[CREDENTIALS]` |
| Пароли в конфигах | `password = value` (с кавычками и без) | `[PASSWORD_REDACTED]` |
| Generic secret/token | `api_key: "value"` в кавычках | `[SECRET_REDACTED]` |
| JWT | `eyJ...` (три части base64url) | `[JWT_REDACTED]` |
| Банковские карты | Visa/MC/Amex по IIN-диапазонам | `[CARD_NUMBER_REDACTED]` |
| .env переменные | `[export] VAR_WITH_KEY_TOKEN_etc=value{20+}` | `[REDACTED]` |

### Ключевые архитектурные решения

**H-4 bugfix:** `Edit.old_string` **не маскируется** — это поисковый паттерн для поиска в файле. Маскирование привело бы к ошибке "строка не найдена".

**Fail-open:** При JSON-ошибке или `tool_input: null` хук выходит с кодом 0 (разрешить). Безопасность жертвует доступностью, а не наоборот.

**Порядок паттернов:** Специфичные (AWS Secret, GitHub PAT) перед общими (.env). Двойное перемаскирование предотвращается lookahead `(?!"?\[)`.

**Python 3.8+:** `from __future__ import annotations` обеспечивает совместимость с Ubuntu 20.04 LTS.

### Известные ограничения

| Ограничение | Обходной путь |
|-------------|--------------|
| Нет Luhn-проверки номеров карт | Повышен false positive риск для числовых ID |
| Нет покрытия: Google AI (`AIzaSy...`), Stripe (`sk_live_`) | Добавить паттерны из `docs/SECURITY_PATTERNS_IMPROVEMENTS.md` |
| Generic secret требует кавычки | YAML без кавычек не покрывается |
| Нет NLP — только regex | PII (имена, email) не маскируются автоматически |

### Расширение паттернов

Для добавления новых провайдеров (Google AI, Stripe, HuggingFace, Groq) — см. детальные рекомендации в:
- [`docs/SECURITY_PATTERNS_IMPROVEMENTS.md`](./SECURITY_PATTERNS_IMPROVEMENTS.md) — конкретные regex с примерами
- [`docs/SECURITY_RESEARCH.md`](./SECURITY_RESEARCH.md) — анализ 14+ провайдеров и инструментов (gitleaks, trufflehog)
- [`.nvm-isolated/.claude-isolated/hooks/patterns.json.example`](../.nvm-isolated/.claude-isolated/hooks/patterns.json.example) — шаблон конфигурации JSON

---

## Метрики и статуслайн

> **Статус:** Реализовано (Вариант B, 2026-03-06)

### GET /api/metrics

PII proxy сервер (`lib/pii-proxy/server.py`) предоставляет endpoint с live-метриками:

```bash
curl http://127.0.0.1:<PORT>/api/metrics
```

Ответ:

```json
{
  "masked_items_total": 42,
  "uptime_seconds": 183.5,
  "masking_level": "standard",
  "log_level": "info",
  "analyzer_ready": true
}
```

| Поле | Описание |
|------|----------|
| `masked_items_total` | Суммарное число замаскированных элементов с момента старта |
| `uptime_seconds` | Время работы прокси в секундах |
| `masking_level` | Уровень маскирования: `off`, `secrets`, `standard` |
| `log_level` | Уровень логирования: `info`, `debug` |
| `analyzer_ready` | Загружен ли Presidio NLP |

### Отображение в статуслайне

При запуске с `--pii-proxy` в статуслайне появляется иконка 🛡 со счётчиком:

```
↓ 42.3k ↑ 5.1k ≈85% [cache: 1.2k] | Sonnet 4.5 | $0.023 | 🔀 anthropic | 🛡42 | #abc123 🧠 | main +2 | 🌐
```

| Режим | Отображение | Описание |
|-------|-------------|----------|
| **full** | `🛡{count}` | Иконка + счётчик замаскированных элементов |
| **compact** | `🛡{count}` | Иконка + счётчик |
| **minimal** | `🛡` | Только иконка (без счётчика) |

Метрики кэшируются 30 секунд в `/tmp/pii-metrics-{SESSION_ID}`.
Запрос к `/api/metrics` выполняется с таймаутом 0.2s — не замедляет обновление статуслайна.

### Переменные окружения (экспортируются launch.sh)

| Переменная | Значение | Описание |
|------------|----------|----------|
| `ICLAUDE_PII_ACTIVE` | `1` | PII proxy запущен и готов |
| `ICLAUDE_PII_MASKING_LEVEL` | `standard` / `secrets` / `off` | Уровень маскирования |
| `ICLAUDE_PII_ACTIVE_PORT` | `<port>` | Порт прокси для curl к `/api/metrics` |
| `ICLAUDE_PII_LOG_PATH` | `{pii-proxy-logs}/{session}.log` | Путь к server log текущей сессии |
| `ICLAUDE_PII_LOG_LEVEL` | `info` / `debug` | Уровень логирования |

### Конфигурация прокси (.claude_config)

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `USE_PII_PROXY` | `false` | Включить прокси автоматически при каждом запуске |
| `PII_PROXY_MASKING_LEVEL` | `standard` | Уровень маскирования: `off` / `secrets` / `standard` |
| `PII_PROXY_LOG_LEVEL` | `info` | Уровень логирования: `info` / `debug` |
| `PII_PROXY_PORT` | `0` (авто) | Фиксированный порт (0 = случайный из диапазона) |
| `PII_PROXY_PORT_MIN` | `20000` | Нижняя граница диапазона авто-выбора порта |
| `PII_PROXY_PORT_MAX` | `40000` | Верхняя граница диапазона авто-выбора порта |
| `PII_PROXY_ENABLE_FALLBACK` | `true` | Regex-fallback если Presidio недоступен |
| `PII_PROXY_MASK_TOKEN` | `REDACTED` | Токен замены PII (пустая строка = удаление без плейсхолдера) |

**Уровни маскирования (`PII_PROXY_MASKING_LEVEL`):**

| Уровень | Что делает | Когда использовать |
|---------|-----------|-------------------|
| `standard` | Presidio NLP + regex | Максимальная защита (по умолчанию) |
| `secrets` | Только regex: API-ключи, токены, пароли | Без NLP, низкая latency |
| `off` | Без маскирования, трафик проходит насквозь | Только для отладки proxy-цепочки |

### Server Log

PII proxy пишет server log в `$PII_PROXY_LOG_DIR` (`.nvm-isolated/.claude-isolated/pii-proxy-logs/`):

```
{pii-proxy-logs}/{SESSION_ID}.log
```

Каждая сессия имеет **отдельный лог-файл** (по `ICLAUDE_SESSION_ID`). Параллельные сессии не перезаписывают друг друга.

**Два режима логирования (`PII_PROXY_LOG_LEVEL`):**

#### info (по умолчанию)

Логируется только количество найденных элементов — без метаданных PII:

```
2026-03-12 11:29:51,667 INFO Masked request: 3 sensitive item(s) found
```

#### debug

Логируется тип найденного, где в запросе (`system`, `user[N].content`), исходное значение и токен замены:

```
2026-03-12 12:02:20,891 INFO Masked request: 3 item(s): system: Anthropic/OpenAI/Stripe API key ("sk-ant-api03-AbCdEf…" → "[API_KEY_REDACTED]"), user[0].content: credentials in URL ("https://user:p4ss@proxy.corp.ru:8080/…" → "https://[CREDENTIALS]@proxy.corp.ru:8080/…"), user[0].content: JWT token ("eyJhbGciOiJIUzI1…" → "[JWT_REDACTED]")
```

Формат каждого элемента: `{поле}: {тип} ("{исходное значение}" → "{замена}")`

Значения обрезаются до 60 символов.

**Включение debug-режима:**

```bash
# В .claude_config:
PII_PROXY_LOG_LEVEL=debug

# Или разово:
./iclaude.sh --pii-proxy  # с PII_PROXY_LOG_LEVEL=debug в .claude_config
```

При старте в debug-режиме выводится предупреждение:

```
⚠ PII proxy: DEBUG mode — log contains PII metadata, auto-deleted on exit
```

**Автоудаление лога в debug-режиме:** при завершении сессии (`EXIT`/`INT`/`TERM`) `stop_pii_proxy_server()` удаляет `{SESSION_ID}.log` — лог содержит чувствительные метаданные и не должен накапливаться на диске.

**Иконка 🛡 в статуслайне** становится кликабельной (OSC 8 гиперссылка) — открывает log-файл сессии в терминале.

**Просмотр лога:**

```bash
tail -f .nvm-isolated/.claude-isolated/pii-proxy-logs/${ICLAUDE_SESSION_ID}.log
```

---

## Дополнительные ресурсы

- [PasteGuard GitHub](https://github.com/sgasser/pasteguard)
- [Microsoft Presidio](https://microsoft.github.io/presidio/)
- [Claude Code Hooks документация](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [`hooks/block-secrets.py`](../.nvm-isolated/.claude-isolated/hooks/block-secrets.py) — блокировка по пути
- [`hooks/redact-secrets.py`](../.nvm-isolated/.claude-isolated/hooks/redact-secrets.py) — маскирование содержимого
- [`tests/test-redact-hook.sh`](../tests/test-redact-hook.sh) — тест-сьют (37 тестов)
- [docs/PROXY.md](./PROXY.md) — прокси конфигурация
- [docs/INTEGRATIONS.md](./INTEGRATIONS.md) — обзор всех интеграций

---

*Документ создан: 2026-02-25 | Версия: 2.0 (добавлена секция реализации)*
*Основан на анализе PasteGuard v0.3.2 и iclaude v4.0*
