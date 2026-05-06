---
wiki_sources:
  - "docs/functions/PII_MASKING.md"
wiki_updated: 2026-05-06
wiki_status: stub
wiki_outgoing_links:
  - "[[pii-прокси|PII-прокси]]"
wiki_external_links:
  - "https://microsoft.github.io/presidio/"
  - "https://github.com/microsoft/presidio"
tags:
  - iclaude
  - documentation
aliases:
  - "Presidio"
  - "Microsoft Presidio"
  - "NLP детекция PII"
---

# Microsoft Presidio (NLP-детекция PII)

Open source библиотека от Microsoft для обнаружения и анонимизации персональных данных (PII) с использованием NLP-моделей spaCy. В контексте iclaude используется внутри PII-прокси (`lib/pii-proxy/server.py`) как движок анализа.

## Основные характеристики

### Поддерживаемые типы PII

| Тип | Пример |
|-----|--------|
| PERSON | Иван Петров |
| EMAIL_ADDRESS | user@company.com |
| PHONE_NUMBER | +7 (495) 123-4567 |
| CREDIT_CARD | 4111-1111-1111-1111 |
| IP_ADDRESS | 192.168.1.100 |
| LOCATION | Москва, ул. Ленина 1 |
| IBAN_CODE | DE89 3704 0044 0532 0130 00 |
| URL | https://internal.company.com |

24 языка поддерживается. Русский язык работает, но точность ниже чем для английского.

### Установка в iclaude

Presidio устанавливается в Python venv при `./iclaude.sh --install-pii-proxy`. Занимает ~587MB (spaCy модель `en_core_web_lg`). Установка идемпотентна.

```bash
./iclaude.sh --install-pii-proxy
./iclaude.sh --install-pii-proxy --force  # принудительная переустановка
```

### Производительность

Добавляет +50–200мс к каждому запросу из-за NLP-обработки. Для интерактивного использования незаметно. При недоступности Presidio — regex-fallback (`PII_PROXY_ENABLE_FALLBACK=true`).

## Ограничения

- False negatives: NLP-модели не 100% точны; редкие форматы могут пропускаться
- Потребление RAM: ~500MB
- Русские имена/адреса распознаются хуже английских (рекомендуется `score_threshold: 0.5`)
- Без Docker: можно установить через pip в изолированный venv
