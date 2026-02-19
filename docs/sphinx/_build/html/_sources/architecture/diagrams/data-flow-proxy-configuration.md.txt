# Поток настройки прокси

Описывает процесс конфигурации HTTP/HTTPS прокси от ввода URL до запуска Claude Code.

## Ключевые этапы

1. **Валидация** — проверка формата URL
2. **Обработка протокола** — HTTP (с конвертацией домена) или HTTPS (домен сохраняется)
3. **Сохранение** — учётные данные в `.claude_proxy_credentials` (chmod 600)
4. **Конфигурация** — установка переменных окружения
5. **Тестирование** — проверка соединения
6. **Запуск** — старт Claude Code с настроенным прокси

## Диаграмма

```mermaid
graph LR
    %% Proxy Configuration Flow
    USER[User] -->|1. Provides proxy URL| CLI[CLI Main]
    CLI -->|2. Validate format| VALIDATE[Validate Proxy URL]
    VALIDATE -->|3. Check protocol| PROTOCOL{Protocol?}

    PROTOCOL -->|HTTP| RESOLVE[Resolve Domain<br/>to IP]
    PROTOCOL -->|HTTPS| PARSE[Parse Proxy URL]
    RESOLVE -->|4. Convert domain| PARSE

    PARSE -->|5. Extract credentials| CRED[Credential Storage]
    CRED -->|6. Save credentials<br/>chmod 600| FILE[.claude_proxy_credentials]

    FILE -->|7. Load credentials| CONFIG[Configure Proxy]
    CONFIG -->|8. Set environment<br/>variables| ENV[HTTPS_PROXY<br/>HTTP_PROXY<br/>NO_PROXY]

    ENV -->|9. Test connectivity| TEST[Test Proxy]
    TEST -->|10. HTTP request| HTTP_TEST[http://www.google.com]
    TEST -->|11. HTTPS request| HTTPS_TEST[https://www.anthropic.com]

    HTTP_TEST -->|12. Success| LAUNCH[Launch Claude]
    HTTPS_TEST -->|12. Success| LAUNCH

    LAUNCH -->|13. Start with proxy| CLAUDE[Claude Code CLI]

    %% Styling
    classDef userClass fill:#e1f5ff,stroke:#1976d2,stroke-width:2px
    classDef processClass fill:#fff4e1,stroke:#f57c00,stroke-width:2px
    classDef storageClass fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef externalClass fill:#f0f0f0,stroke:#616161,stroke-width:2px

    class USER userClass
    class CLI,VALIDATE,RESOLVE,PARSE,CONFIG,TEST processClass
    class CRED,FILE,ENV storageClass
    class HTTP_TEST,HTTPS_TEST,CLAUDE externalClass
```

## Особенности обработки протоколов

### HTTPS (рекомендуется)
- Доменное имя **сохраняется** без изменений
- Необходимо для OAuth token refresh
- TLS SNI и Host header работают корректно

### HTTP (не рекомендуется)
- Предлагается конвертация домена в IP
- Может вызвать проблемы с аутентификацией
- Используйте только если HTTPS недоступен

## Переменные окружения

После настройки устанавливаются:

```bash
HTTPS_PROXY="https://user:pass@proxy:port"
HTTP_PROXY="https://user:pass@proxy:port"
NO_PROXY="localhost,127.0.0.1,github.com,..."
```

## Тестовые запросы

Скрипт проверяет соединение двумя запросами:
- `http://www.google.com` — проверка HTTP через прокси
- `https://www.anthropic.com` — проверка HTTPS через прокси

Оба запроса должны вернуть успешный статус для продолжения.
