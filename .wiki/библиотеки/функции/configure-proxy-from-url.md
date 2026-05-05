---
wiki_sources:
  - "lib/proxy/configure.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "configure_proxy_from_url"
---

# configure_proxy_from_url

`configure_proxy_from_url()` — настраивает прокси: экспортирует `HTTPS_PROXY`, `HTTP_PROXY`, `NO_PROXY` и устанавливает TLS-стратегию.

## Основные характеристики

Модуль: `lib/proxy/configure.sh`

Сигнатура: `configure_proxy_from_url(proxy_url [no_proxy])`

Последовательность:

1. Проверка: если URL совпадает с сохранённым в `.claude_config` — skip save (чтобы не затереть `PROXY_CA` и `PROXY_INSECURE`)
2. Иначе: `save_credentials()` — может конвертировать домен в IP
3. Экспорт `HTTPS_PROXY=$final_proxy_url`, `HTTP_PROXY=$final_proxy_url`
4. Экспорт `NO_PROXY` (дефолт: `localhost,127.0.0.1,github.com,...`)

TLS-стратегии (взаимоисключающие):
- `PROXY_CA=/path/ca.crt` → `NODE_EXTRA_CA_CERTS=$PROXY_CA` (безопасный режим)
- `PROXY_INSECURE=true` → `NODE_TLS_REJECT_UNAUTHORIZED=0` (небезопасный fallback)

Git-прокси: через env переменные (глобальный git config не модифицируется — было сломано для других инструментов).

`test_proxy()` проверяет curl с `-x $proxy_url` к `https://api.anthropic.com/v1/models`:
- Важно: перед curl делает `unset HTTPS_PROXY HTTP_PROXY` чтобы избежать proxy-through-proxy (возвращает 000)

## Связанные концепции

- [[библиотека/категории/proxy]]
