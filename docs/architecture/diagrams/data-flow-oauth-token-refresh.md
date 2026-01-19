# Поток обновления OAuth токена

Описывает автоматическую проверку и обновление OAuth токена при запуске.

## Ключевые особенности

- Токен проверяется при **каждом** запуске
- Автоматическое обновление за **7 дней** до истечения (настраивается)
- Новый токен действителен **~1 год**
- При ошибке credentials **не удаляются** (сохраняется refreshToken)

## Диаграмма

```mermaid
graph TD
    %% OAuth Token Refresh Flow
    USER[User] -->|1. Launch Claude| CLI[CLI Main]
    CLI -->|2. Check token| CHECK[Check OAuth Token]

    CHECK -->|3. Read credentials| CRED_FILE[.credentials.json]
    CRED_FILE -->|4. Extract expiresAt| TOKEN_DATA{Token Data}

    TOKEN_DATA -->|5. Parse timestamp| EXP_CHECK[Check Token Expiration]
    EXP_CHECK -->|6. Current time + threshold| CALC[Calculate<br/>expires_in < 7 days?]

    CALC -->|NO: Token valid| LAUNCH[Launch Claude]
    CALC -->|YES: Expiring soon| REFRESH[Refresh OAuth Token]

    REFRESH -->|7. Execute command| SETUP_TOKEN[claude setup-token]
    SETUP_TOKEN -->|8. Open browser| BROWSER[Browser Authentication]

    BROWSER -->|9. User authorizes| ANTHROPIC[Anthropic OAuth Server]
    ANTHROPIC -->|10. Return new tokens| NEW_TOKEN[New Access Token<br/>New Refresh Token<br/>New expiresAt]

    NEW_TOKEN -->|11. Update credentials| UPDATE[Update Credential Storage]
    UPDATE -->|12. Write JSON| CRED_FILE

    CRED_FILE -->|13. Credentials saved| SUCCESS[Success Message]
    SUCCESS -->|14. Continue launch| LAUNCH

    LAUNCH -->|15. Start with valid token| CLAUDE[Claude Code CLI]

    %% Error handling
    SETUP_TOKEN -.->|Error: Failed| ERROR[Display Warning]
    ERROR -.->|Preserve credentials| CRED_FILE
    ERROR -.->|User action required| USER_ACTION[User runs /login manually]

    %% Styling
    classDef userClass fill:#e1f5ff,stroke:#1976d2,stroke-width:2px
    classDef processClass fill:#fff4e1,stroke:#f57c00,stroke-width:2px
    classDef storageClass fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef externalClass fill:#f0f0f0,stroke:#616161,stroke-width:2px
    classDef errorClass fill:#ffebee,stroke:#d32f2f,stroke-width:2px

    class USER userClass
    class CLI,CHECK,EXP_CHECK,REFRESH,UPDATE processClass
    class CRED_FILE,TOKEN_DATA,SUCCESS storageClass
    class SETUP_TOKEN,BROWSER,ANTHROPIC,NEW_TOKEN,LAUNCH,CLAUDE externalClass
    class ERROR,USER_ACTION errorClass
```

## Структура токена

Файл `.credentials.json`:
```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-...",
    "refreshToken": "sk-ant-ort01-...",
    "expiresAt": 1766460813792,
    "scopes": ["user:inference", "user:profile", "user:sessions:claude_code"],
    "subscriptionType": "max"
  }
}
```

## Алгоритм проверки

```
current_time = now()
expires_at = credentials.claudeAiOauth.expiresAt
threshold = 7 * 24 * 60 * 60 * 1000  # 7 дней в миллисекундах

if (expires_at - current_time) < threshold:
    refresh_token()
else:
    launch_claude()
```

## Обработка ошибок

При неудачном обновлении токена:

1. **Credentials сохраняются** — refreshToken остаётся в файле
2. **Выводится предупреждение** — пользователь информируется о проблеме
3. **Claude Code может продолжить работу** — используя внутренний механизм refresh

### Ручное обновление

Если автоматическое обновление не сработало:

```bash
# Ручной refresh через iclaude
./iclaude.sh --refresh-token

# Или внутри Claude Code
/login
```

## Конфигурация

Порог обновления настраивается константой в `iclaude.sh`:

```bash
TOKEN_REFRESH_THRESHOLD=604800  # 7 дней в секундах
```

## Ограничения

- `setup-token` требует **интерактивной** браузерной аутентификации
- Не подходит для полностью headless/CI окружений
- Требуется доступ к GUI для открытия браузера
