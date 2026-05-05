---
wiki_sources: ["docs/functions/PROXY.md"]
wiki_updated: 2026-05-05
wiki_status: developing
tags: [iclaude, features, proxy]
aliases: ["HTTP прокси", "HTTPS прокси", "прокси-сервер"]
---

# Proxy (HTTP/HTTPS прокси)

Функция прокси позволяет направить весь трафик Claude Code через HTTP/HTTPS прокси-сервер. Используется в корпоративных сетях с обязательным прокси, а также для перехвата и анализа трафика.

## Основные характеристики

| Протокол | Статус | Рекомендация |
|----------|--------|--------------|
| HTTPS | Полная поддержка | Рекомендуется |
| HTTP | Полная поддержка | Только для localhost |
| SOCKS5 | Не поддерживается | Вызывает краш приложения |

### Запуск с прокси

```bash
# HTTPS прокси с учётными данными
./iclaude.sh --proxy https://[CREDENTIALS]@proxy.example.com:8118

# HTTP прокси (только localhost)
./iclaude.sh --proxy http://localhost:8118

# Запуск без прокси (игнорировать сохранённые настройки)
./iclaude.sh --no-proxy

# Тест подключения
./iclaude.sh --test
```

### TLS-стратегии

**С сертификатом (безопасно):**

```bash
# Экспортировать сертификат прокси
openssl s_client -showcerts -connect proxy:8118 < /dev/null 2>/dev/null | \
  openssl x509 -outform PEM > proxy-cert.pem

./iclaude.sh --proxy https://proxy:8118 --proxy-ca ./proxy-cert.pem
```

**Без проверки TLS (небезопасно — только для разработки):**

```bash
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

Предпочтительный вариант — `--proxy-ca` вместо `--proxy-insecure`.

## Конфигурация через .claude_config

```bash
PROXY_URL=https://[CREDENTIALS]@proxy.company.com:8118
PROXY_CA=/path/to/proxy-cert.pem   # опционально
PROXY_INSECURE=false               # не рекомендуется
```

## Ограничения

- SOCKS5 не поддерживается из-за ограничений `undici` (HTTP-клиент Node.js)
- HTTP-прокси рекомендован только для localhost: при внешнем HTTP-прокси возникают проблемы с TLS Anthropic API
- `undici` не проверяет сертификаты целевого сервера при проксировании HTTPS ([HackerOne #1583680](https://hackerone.com/reports/1583680))

## Связанные концепции

- [[функции/возможности/oauth]] — OAuth токены требуют HTTPS прокси для правильного обновления
- [[функции/конфигурация/переменные-прокси]] — переменные PROXY_URL, PROXY_CA, PROXY_INSECURE
