---
wiki_sources: ["docs/functions/PII_MASKING.md"]
wiki_updated: 2026-05-05
wiki_status: developing
tags: [iclaude, features, pii, security, presidio]
aliases: ["PII Masking", "Presidio NLP", "маскирование данных", "PasteGuard"]
---

# PII Proxy (маскирование персональных данных)

PII Proxy — локальный HTTP-прокси между Claude Code и Anthropic API, который маскирует персональные данные и секреты перед отправкой в облако и демаскирует их в ответах.

## Основные характеристики

### Принцип работы

```
Claude Code
    ↓ запрос с данными
PII Proxy (localhost:9000)
    ↓ маскирование: user@example.com → [[EMAIL_ADDRESS_1]]
    ↓ маскирование: sk-abc123 → [[API_KEY_SK_1]]
Anthropic API
    ↓ ответ с [[EMAIL_ADDRESS_1]]
PII Proxy
    ↓ демаскирование: [[EMAIL_ADDRESS_1]] → user@example.com
Claude Code
```

### Запуск с PII Proxy

```bash
./iclaude.sh --install-pii-proxy  # Установка (Python venv + Presidio NLP)
./iclaude.sh --pii-proxy          # Запуск с PII маскированием
```

### Категории данных под защитой

| Категория | Примеры |
|-----------|---------|
| Персональные данные (PII) | Имена, email, телефоны, адреса, СНИЛС, ИНН |
| Учётные данные | API-ключи, токены, пароли, JWT, SSH-ключи |
| Корпоративные данные | Внутренние ID проектов, финансовые данные |
| Медицинские данные | Диагнозы, результаты анализов |
| Финансовые данные | Номера карт, IBAN, суммы транзакций |

### Мониторинг

```bash
# Метрики PII proxy
curl http://127.0.0.1:9000/api/metrics
# → {masked_items_total, uptime_seconds, masking_level, log_level}
```

## Реализация

Используется Presidio NLP (Microsoft) — библиотека для распознавания и маскирования PII. Работает только на localhost (127.0.0.1:9000). Устанавливается в Python venv в изолированном окружении.

## Конфигурация через .claude_config

```bash
PII_PROXY_PORT=9000          # порт (по умолчанию 9000)
PII_PROXY_MASKING_LEVEL=high # уровень маскирования
```

## Ограничения

- SSE streaming поддерживается (прокси обрабатывает потоковые ответы)
- Требует Python 3 в системе
- При запуске без `--pii-proxy` прокси не активен

## Связанные концепции

- [[функции/возможности/autoresearch]] — варианты B и C autoresearch используют PII Proxy
- [[библиотеки/функции/start-pii-proxy-server]] — bash-функция запуска/остановки
- [[библиотеки/паттерны/detect-start-stop-lifecycle]] — паттерн lifecycle для внешних серверов
