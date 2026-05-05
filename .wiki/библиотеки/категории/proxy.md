---
wiki_sources:
  - "lib/proxy/configure.sh"
  - "lib/proxy/credentials.sh"
  - "lib/proxy/validate.sh"
  - "lib/proxy/git.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/proxy"
  - "proxy module"
---

# proxy

Подсистема `lib/proxy/` — управление HTTP/HTTPS прокси. Читает конфигурацию из `.claude_config`, экспортирует `HTTPS_PROXY`/`HTTP_PROXY`, настраивает TLS-сертификаты и проверяет доступность прокси.

## Основные характеристики

Файловый состав (4 модуля):

| Файл | Содержимое |
|------|-----------|
| `configure.sh` | `configure_proxy_from_url()`, `test_proxy()`, `display_proxy_info()` |
| `credentials.sh` | `save_credentials()`, `load_claude_config()` |
| `validate.sh` | `validate_proxy_url()` |
| `git.sh` | `configure_git_no_proxy()`, `save_git_proxy_settings()` |

`configure_proxy_from_url()` — основная функция настройки:
- Экспортирует `HTTPS_PROXY`, `HTTP_PROXY`, `NO_PROXY`
- При `PROXY_CA` (путь к CA-сертификату): `NODE_EXTRA_CA_CERTS=$PROXY_CA`
- При `PROXY_INSECURE=true`: `NODE_TLS_REJECT_UNAUTHORIZED=0`
- Git-прокси через env переменные (не через `git config`)

`test_proxy()` — тест через curl к `https://api.anthropic.com/v1/models`:
- HTTP 401 = прокси работает (нет API ключа — ожидаемо)
- HTTP 000 = прокси недоступен

NO_PROXY по умолчанию: `localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org`

Безопасность: используйте `PROXY_CA` вместо `PROXY_INSECURE`. Undici не верифицирует целевой сервер при проксировании HTTPS (HackerOne #1583680).

## Связанные концепции

- [[библиотека/функции/configure-proxy-from-url]]
- [[библиотека/категории/core]]
- [[библиотека/категории/config]]
