---
wiki_sources:
  - "docs/architecture/overview.yaml"
  - "docs/architecture/diagrams/README.md"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - architecture
  - proxy
  - iclaude
aliases:
  - "proxy"
  - "управление прокси"
---

# Proxy Management

Модуль управления HTTP/HTTPS прокси в iclaude. Обеспечивает валидацию URL, хранение учётных данных, конфигурацию окружения и тестирование соединения.

## Основные характеристики

**Расположение в коде:** `iclaude.sh:60-2015` (с учётом всех подфункций)

### Поддерживаемые протоколы

| Протокол | Поддержка | Примечание |
|----------|-----------|-----------|
| HTTPS | Рекомендуется | Сохраняет доменные имена, совместим с OAuth |
| HTTP | Опционально | Требует преобразования домена в IP |
| SOCKS5 | Не поддерживается | Вызывает сбой в undici |

### Субкомпоненты

- `validate_proxy_url` (`iclaude.sh:60-88`) — проверка формата и протокола
- `resolve_domain_to_ip` (`iclaude.sh:114-157`) — DNS-резолвинг для HTTP прокси; цепочка: getent → host → dig → nslookup
- `parse_proxy_url` (`iclaude.sh:159-202`) — извлечение протокола, пользователя, пароля, хоста, порта
- `configure_proxy_from_url` (`iclaude.sh:1830-1873`) — установка `HTTPS_PROXY`, `HTTP_PROXY`, `NO_PROXY`
- `test_proxy` (`iclaude.sh:1969-2013`) — тест HTTP (google.com) и HTTPS (anthropic.com) через curl

### Хранение credentials

Файл `.claude_proxy_credentials`:
- Права: chmod 600 (только владелец)
- Не коммитится в git
- Считывается при каждом запуске

### Известные ограничения

Библиотека `undici` (используется Claude Code) не проверяет сертификаты целевого сервера при проксировании HTTPS ([HackerOne #1583680](https://hackerone.com/reports/1583680)). Рекомендуется использовать доверенные прокси и `--proxy-ca` вместо `--proxy-insecure`.

## Связанные концепции

- [[../потоки/поток-настройки-прокси]]
- [[../концепции/изолированное-окружение]]
