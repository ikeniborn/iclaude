---
wiki_sources:
  - "lib/pii-proxy/detect.sh"
  - "lib/pii-proxy/install.sh"
  - "lib/pii-proxy/status.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/pii-proxy"
  - "pii-proxy module"
  - "PII proxy module"
---

# pii-proxy

Подсистема `lib/pii-proxy/` — обнаружение и управление PII Proxy (Presidio NLP). Проксирует трафик к Anthropic API через локальный Python-сервер, маскирующий персональные данные и секреты.

## Основные характеристики

Файловый состав (3 модуля):

| Файл | Содержимое |
|------|-----------|
| `detect.sh` | `detect_pii_proxy()`, `get_pii_proxy_python()` |
| `install.sh` | `install_pii_proxy()` — создание venv, установка Presidio |
| `status.sh` | `check_pii_proxy_status()` — статус прокси |

`detect_pii_proxy()` — проверяет:
1. Работа в изолированном окружении (не в `--system` режиме)
2. Существование `pii-proxy-server.py` в `ISOLATED_CONFIG_DIR`
3. Наличие venv в `$PII_PROXY_VENV`
4. Python 3.8+ в venv (целочисленное сравнение: 308 = v3.8)

`get_pii_proxy_python()` — возвращает путь `$PII_PROXY_VENV/bin/python3`.

PII proxy только в изолированном режиме: несовместимо с `--system`. При использовании в `--system` выдаётся ошибка и abort запуска.

Per-session архитектура: каждый запуск iclaude стартует свой независимый экземпляр прокси на динамическом порту из диапазона `[PII_PROXY_PORT_MIN, PII_PROXY_PORT_MAX]` (дефолт: 20000–40000). PID и порт записываются в `pii-proxy-pid/<SESSION_ID>.pid` и `pii-proxy-logs/pii-proxy-<SESSION_ID>.port`.

## Связанные концепции

- [[библиотека/функции/detect-pii-proxy]]
- [[библиотека/функции/start-pii-proxy-server]]
- [[библиотека/паттерны/per-session-isolation]]
- [[библиотека/паттерны/detect-start-stop-lifecycle]]
- [[библиотека/категории/launcher]]
