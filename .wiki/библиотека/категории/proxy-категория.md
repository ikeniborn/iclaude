---
wiki_sources: ["lib/proxy/validate.sh", "lib/proxy/configure.sh", "lib/proxy/git.sh", "lib/README.md"]
wiki_updated: 2026-05-05
wiki_status: mature
tags: ["bash", "module", "iclaude"]
aliases: ["lib/proxy", "proxy modules", "Phase 2"]
---

# Proxy — категория управления прокси (lib/proxy/)

Категория `lib/proxy/` реализует полный цикл управления HTTP/HTTPS-прокси: валидацию URL, хранение credentials, конфигурацию переменных окружения и интеграцию с git. Извлечена из монолита в Phase 2 (~711 строк).

## Основные характеристики

| Модуль | Ключевые функции | Назначение |
|--------|-----------------|------------|
| `validate.sh` | `validate_proxy_url()`, `is_ip_address()`, `resolve_domain_to_ip()`, `parse_proxy_url()` | Валидация формата URL, DNS-резолюция |
| `credentials.sh` | `save_credentials()`, `load_credentials()`, `clear_credentials()`, `prompt_proxy_url()` | Хранение и загрузка credentials |
| `configure.sh` | `configure_proxy_from_url()`, `display_proxy_info()`, `test_proxy()`, `configure_git_no_proxy()` | Конфигурация env-переменных, тест связи |
| `git.sh` | `save_git_proxy_settings()`, `restore_git_proxy()` | Резервное копирование git-настроек прокси |

## Коды возврата validate_proxy_url()

```
0 → URL валиден, хост — IPv4-адрес
1 → Неверный формат (не http/https/socks5 или отсутствует порт)
2 → Валиден, но хост — доменное имя (требует DNS-резолюции)
```

## DNS-резолюция (resolve_domain_to_ip)

Цепочка fallback при коде 2 от `validate_proxy_url()`:

```
1. getent hosts <domain>     (наиболее надёжный, системный resolver)
2. host <domain>             (DNS-утилита)
3. dig +short <domain>       (BIND-утилита)
4. nslookup <domain>         (устаревший, но широко доступен)
```

Если ни один не даёт результата — возвращает код 1; credentials сохраняются с доменом как есть.

## Переменные окружения, экспортируемые configure_proxy_from_url()

| Переменная | Назначение |
|-----------|------------|
| `HTTPS_PROXY` | URL прокси для HTTPS-трафика |
| `HTTP_PROXY` | URL прокси для HTTP-трафика |
| `NO_PROXY` | Хосты, обходящие прокси (localhost, 127.0.0.1, github.com, ...) |
| `NODE_EXTRA_CA_CERTS` | CA-сертификат прокси (при `PROXY_CA` в конфиге) |
| `NODE_TLS_REJECT_UNAUTHORIZED` | 0 при `PROXY_INSECURE=true` (небезопасный режим) |

## Тест прокси (test_proxy)

Отправляет запрос к Anthropic API `/v1/models` через `-x proxy_url`. Ожидаемый ответ — HTTP 401 (нет API-ключа): это подтверждает, что прокси достигает Anthropic API. Коды 000 (timeout/refused) означают недоступность прокси.

Важно: перед вызовом `curl` сбрасывает `HTTPS_PROXY`/`HTTP_PROXY` из окружения, чтобы избежать двойного проксирования (curl -x + env var → 000).

## Связанные концепции

- [[категории/обзор-lib]]
- [[категории/core-категория]]
