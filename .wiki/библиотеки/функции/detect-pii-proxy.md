---
wiki_sources:
  - "lib/pii-proxy/detect.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "detect_pii_proxy"
  - "get_pii_proxy_python"
---

# detect_pii_proxy / get_pii_proxy_python

`detect_pii_proxy()` — проверяет готовность PII Proxy к работе. `get_pii_proxy_python()` — возвращает путь к Python интерпретатору venv.

## Основные характеристики

Модуль: `lib/pii-proxy/detect.sh`

**`detect_pii_proxy(skip_isolated)`** — последовательность проверок (все должны пройти):

1. `skip_isolated == "false"` и `$ISOLATED_NVM_DIR` существует (PII proxy только в изолированном режиме)
2. `$PII_PROXY_SERVER_SCRIPT` существует (`pii-proxy-server.py`)
3. `$PII_PROXY_VENV` существует (Python venv с Presidio)
4. `$PII_PROXY_VENV/bin/python3` исполняем
5. Версия Python ≥ 3.8 (целочисленное сравнение: `%d%02d` → 308 ≥ 308)

**`get_pii_proxy_python()`**: возвращает `$PII_PROXY_VENV/bin/python3` или пустую строку. Системный Python не используется — нет Presidio.

## Связанные концепции

- [[библиотека/категории/pii-proxy]]
- [[библиотека/функции/start-pii-proxy-server]]
