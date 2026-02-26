# Улучшения паттернов маскирования секретов в redact-secrets.py

## Статус: Исследовательский документ

Этот документ содержит конкретные рекомендации по расширению паттернов маскирования в хуке redact-secrets.py на основе глубокого исследования актуальных форматов API токенов 2025-2026.

---

## Новые паттерны для добавления

### 1. Google AI Studio (Gemini) API Key

**Статус покрытия:** НЕ ПОКРЫТО

```python
(
    re.compile(r'\bAIzaSy[A-Za-z0-9_-]{32}\b'),
    '[GOOGLE_API_KEY]',
    'Google AI Studio (Gemini) API key',
),
```

**Примеры:**
- `AIzaSyDHn9_p-qvNbHk9Cc1xP2-YuL5RVZqJgLI`

**Риск false positive:** Очень низкий (уникальный префикс AIzaSy)

**Тестовый случай:**
```python
assert 'AIzaSyDHn9_p-qvNbHk9Cc1xP2-YuL5RVZqJgLI' in redact_text("key = AIzaSyDHn9_p-qvNbHk9Cc1xP2-YuL5RVZqJgLI")
```

---

### 2. Stripe API Keys (Live и Test)

**Статус покрытия:** НЕ ПОКРЫТО

```python
(
    re.compile(r'\b(?:sk|pk)_(?:live|test)_[A-Za-z0-9]{20,}\b'),
    '[STRIPE_API_KEY]',
    'Stripe API key (secret or publishable)',
),
```

**Варианты:**
- Secret Live: `sk_live_FAKE_EXAMPLE_NOT_REAL_KEY_XX`
- Secret Test: `sk_test_FAKE_EXAMPLE_NOT_REAL_KEY_XX`
- Publishable Live: `pk_live_51234567890abcdefghijklm`
- Publishable Test: `pk_test_51234567890abcdefghijklm`

**Риск false positive:** Низкий (специфичный формат)

**Примечание:** sk_live и sk_test используются не только Stripe, но и другими платежными провайдерами

---

### 3. HuggingFace User Access Token

**Статус покрытия:** НЕ ПОКРЫТО

```python
(
    re.compile(r'\bhf_[A-Za-z0-9_]{30,}\b'),
    '[HUGGINGFACE_TOKEN]',
    'Hugging Face User Access Token',
),
```

**Примеры:**
- `hf_ABcD1234EFgh5678IJkl9012MNop3456QRST`

**Риск false positive:** Очень низкий (уникальный префикс hf_)

**Тестовый случай:**
```python
assert 'hf_ABcD1234EFgh5678IJkl9012MNop3456QRST' in redact_text("token = hf_ABcD1234EFgh5678IJkl9012MNop3456QRST")
```

---

### 4. OpenRouter API Key

**Статус покрытия:** НЕ ПОКРЫТО

```python
(
    re.compile(r'\bsk-or-[A-Za-z0-9\-_]{50,}\b'),
    '[OPENROUTER_API_KEY]',
    'OpenRouter API key',
),
```

**Примеры:**
- `sk-or-ABcD1234EFgh5678IJkl9012MNop3456QRST...XYZ`

**Риск false positive:** Низкий (начинается с sk-or-, редкий префикс)

---

### 5. Groq API Key

**Статус покрытия:** НЕ ПОКРЫТО

```python
(
    re.compile(r'\bgsk_[A-Za-z0-9\-_]{50,}\b'),
    '[GROQ_API_KEY]',
    'Groq API key',
),
```

**Примеры:**
- `gsk_ABcD1234EFgh5678IJkl9012MNop3456QRST...XYZ`

**Риск false positive:** Очень низкий (уникальный префикс gsk_)

---

### 6. GitHub Fine-Grained Token (новое в 2024-2025)

**Статус покрытия:** НЕ ПОКРЫТО (текущий ghp_ паттерн ловит это, но можно уточнить)

```python
(
    re.compile(r'\bgithub_pat_[A-Za-z0-9_]{36,255}\b'),
    '[GITHUB_PAT_TOKEN]',
    'GitHub fine-grained personal access token',
),
```

**Примеры:**
- `github_pat_11ABCDEF1234567890abcdef1234567890`

**Риск false positive:** Очень низкий (уникальный префикс github_pat_)

**Примечание:** Старые токены (ghp_, ghs_) все еще должны ловиться существующим паттерном

---

### 7. SendGrid API Key

**Статус покрытия:** НЕ ПОКРЫТО

```python
(
    re.compile(r'\bSG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\b'),
    '[SENDGRID_API_KEY]',
    'SendGrid API key',
),
```

**Примеры:**
- `SG.x123abc_DEf456ghi-JKl789mnO_pqRSTUV`

**Риск false positive:** Низкий (уникальный префикс SG. с двумя точками-разделителями)

---

### 8. Mistral AI API Key

**Статус покрытия:** НЕ ПОКРЫТО

```python
(
    re.compile(r'\b(?:mistral_)?[A-Za-z0-9]{32,}\b(?=\s*[=:])|mistral_[A-Za-z0-9_]{32,}'),
    '[MISTRAL_API_KEY]',
    'Mistral AI API key',
),
```

**Варианты:**
- `mistral_abc123def456ghi789jkl012mnopqr`
- Prefix: `mistral_`

**Риск false positive:** Средний (требует контекста переменной)

---

### 9. Cohere API Key

**Статус покрытия:** НЕ ПОКРЫТО (только через generic secret pattern)

```python
(
    re.compile(r'\b(?:cohere_)?[a-f0-9]{32,}\b(?=\s*[=:])|cohere_[A-Za-z0-9_]{32,}'),
    '[COHERE_API_KEY]',
    'Cohere API key',
),
```

**Варианты:**
- UUID-like: `3485c8a9-1234-5678-9abc-def0123456789`
- With prefix: `cohere_abc123def456ghi789jkl012`

**Риск false positive:** Средний (UUID может быть легитимным)

---

### 10. OpenAI Service Account Key (новое)

**Статус покрытия:** ЧАСТИЧНО (существует sk-proj-)

```python
(
    re.compile(r'\bsk-(?:svc|org|proj)-[A-Za-z0-9\-_]{20,}\b'),
    '[OPENAI_API_KEY]',
    'OpenAI API key (service/org/project)',
),
```

**Варианты:**
- Service: `sk-svc-ABcD1234...`
- Organization: `sk-org-ABcD1234...`
- Project: `sk-proj-ABcD1234...` (уже покрыто)

**Риск false positive:** Низкий (начинается с sk-, достаточно специфичен)

---

## Улучшения существующих паттернов

### Проблема 1: PEM Private Key может вызвать ReDoS

**Текущий паттерн (строки 56-64):**
```python
(
    re.compile(
        r'-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'
        r'[\s\S]*?'
        r'-----END (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'
    ),
    '[PRIVATE_KEY_REDACTED]',
    'PEM private key block',
),
```

**Проблема:** [\s\S]*? может быть медленным на поврежденных PEM блоках (когда нет -----END)

**Рекомендованное улучшение:**
```python
(
    re.compile(
        r'-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'
        r'[\s\S]{0,5000}?'  # Ограничить максимальную длину
        r'-----END (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'
    ),
    '[PRIVATE_KEY_REDACTED]',
    'PEM private key block',
),
```

**Альтернатива (более безопасная):**
```python
(
    re.compile(
        r'-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----\n'
        r'(?:[A-Za-z0-9+/\n]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?\n'
        r'-----END (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'
    ),
    '[PRIVATE_KEY_REDACTED]',
    'PEM private key block',
),
```

---

### Проблема 2: URL Credentials паттерн может быть медленным

**Текущий паттерн (строка 74):**
```python
(
    re.compile(r'((?:https?|ftp|postgresql|mysql|mongodb|redis)://)[^:@\s/]+:[^@\s/]+@'),
    r'\1[CREDENTIALS]@',
    'credentials in URL',
),
```

**Проблема:** [^@\s/]+ жадно ловит длинные пароли, может быть медленным

**Рекомендованное улучшение:**
```python
(
    re.compile(r'((?:https?|ftp|postgresql|mysql|mongodb|redis)://)[^:@\s/]{1,100}:[^@\s/]{1,100}@'),
    r'\1[CREDENTIALS]@',
    'credentials in URL',
),
```

---

### Проблема 3: Generic Secret паттерн может быть слишком широким

**Текущий паттерн (строки 88-91):**
```python
(
    re.compile(
        r'(?i)((?:secret|api[_\-]?key|access[_\-]?token|auth[_\-]?token)'
        r'\s*[=:]\s*)["\']([A-Za-z0-9\-_./+]{16,})["\']'
    ),
    r'\1"[SECRET_REDACTED]"',
    'generic secret/token in config',
),
```

**Проблема:** [A-Za-z0-9\-_./+]{16,} может быть очень длинным и медленным

**Рекомендованное улучшение:**
```python
(
    re.compile(
        r'(?i)((?:secret|api[_\-]?key|access[_\-]?token|auth[_\-]?token|token|password|passwd|pwd)'
        r'\s*[=:]\s*)["\']([A-Za-z0-9\-_./+]{16,256})["\']'
    ),
    r'\1"[SECRET_REDACTED]"',
    'generic secret/token in config',
),
```

---

### Проблема 4: .env Format паттерн может маскировать не-секреты

**Текущий паттерн (строки 112-123):**
```python
(
    re.compile(
        r'(?m)^((?:export\s+)?[A-Z][A-Z0-9_]*'
        r'(?:SECRET|TOKEN|KEY|PASSWORD|PASSWD|PWD|APIKEY)'
        r'[A-Z0-9_]*\s*=\s*)'
        r'(?!["\']?\$\{)'      # не маскировать ${VAR} плейсхолдеры
        r'(?!\[)'              # не перемаскировать уже замаскированные [...] значения
        r'([^\s#\n]{20,})'
    ),
    r'\1[REDACTED]',
    '.env secret variable',
),
```

**Проблема:** [^\s#\n]{20,} может быть бесконечным, рекомендованное улучшение:

```python
(
    re.compile(
        r'(?m)^((?:export\s+)?[A-Z][A-Z0-9_]*'
        r'(?:SECRET|TOKEN|KEY|PASSWORD|PASSWD|PWD|APIKEY)'
        r'[A-Z0-9_]*\s*=\s*)'
        r'(?!["\']?\$\{)'      # не маскировать ${VAR} плейсхолдеры
        r'(?!\[)'              # не перемаскировать уже замаскированные [...] значения
        r'([^\s#\n]{20,256})'  # Ограничить максимальную длину
    ),
    r'\1[REDACTED]',
    '.env secret variable',
),
```

---

## Тестовые случаи для проверки false positives

### Должны маскироваться (should_redact.txt):

```
# API Keys
export ANTHROPIC_API_KEY=sk-ant-api03-v1w2x3y4z5a6b7c8d9e0f1g2h3i4j5k6l7m8n9o0p
export GOOGLE_API_KEY=AIzaSyDHn9_p-qvNbHk9Cc1xP2-YuL5RVZqJgLI
export STRIPE_SECRET_KEY=sk_live_FAKE_EXAMPLE_NOT_REAL_KEY_XX
export STRIPE_PUBLISHABLE_KEY=pk_live_51234567890abcdefghijklm
export GROQ_API_KEY=gsk_ABcD1234EFgh5678IJkl9012MNop3456QRST
export HUGGINGFACE_TOKEN=hf_ABcD1234EFgh5678IJkl9012MNop3456QRST
export OPENROUTER_KEY=sk-or-ABcD1234EFgh5678IJkl9012MNop3456QRSTuvwxyz
export SENDGRID_API_KEY=SG.x123abc_DEf456ghi-JKl789mnO_pqRSTUV

# GitHub tokens
export GITHUB_TOKEN=ghp_1234567890abcdefghijklmnopqrstuvwxyz
export GITHUB_PAT=github_pat_11ABCDEF1234567890abcdef1234567890

# Database URLs with credentials
postgresql://user:secretpass123@localhost:5432/dbname
mongodb+srv://admin:MyP@ssw0rd@cluster.mongodb.net/database

# PEM Private Keys
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC3...
-----END PRIVATE KEY-----

# JWT Tokens
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U

# Credit cards
4532015112830366
5425233010103442
```

### НЕ должны маскироваться (should_keep.txt):

```
# UUIDs in config
user_id = "550e8400-e29b-41d4-a716-446655440000"
project_id = "123e4567-e89b-12d3-a456-426614174000"

# Git commits
commit 1234567890abcdef1234567890abcdef
hash abc123def456ghi789jkl012mnopqr

# Docker image references
gcr.io/my-project/image@sha256:abc123def456xyz789abc123def456xyz

# Version tags
v1.2.3-abc123xyz
version: 2.0.0-beta.1

# Template variables
export DATABASE_URL="${DB_HOST}:${DB_PORT}/${DB_NAME}"
secret: "{{ default_password }}"

# Test file passwords
test_password = "Test@123!XyZ456"
temp_password = "TempPass123"

# Config examples
# This is an example: password = "ExamplePassword"

# SQL hashes
SELECT user_id FROM users WHERE hash = "550e8400e29b41d4a716446655440000"

# Long hex strings (but not obviously tokens)
signature = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

# Base64 encoded data (not secrets)
data = "SGVsbG8gV29ybGQgQmFzZTY0IGVuY29kZWQgc3RyaW5n"
```

---

## Порядок добавления паттернов

Рекомендуется добавить новые паттерны в следующем порядке:

1. **High Priority (Tier 1):** Google AI, Stripe, OpenRouter, Groq, HuggingFace
2. **Medium Priority (Tier 2):** GitHub PAT, SendGrid, OpenAI (svc/org)
3. **Low Priority (Tier 3):** Mistral, Cohere
4. **Bug Fixes:** Улучшения PEM, URL credentials, generic secret паттернов

---

## Документирование в коде

Каждый паттерн должен содержать:

```python
(
    re.compile(r'...'),
    '[PLACEHOLDER]',
    'Description: what this is, where it appears, risk level',
),
```

Улучшенное документирование:

```python
# НОВОЕ в v2.2 (2025-02-25): Google AI Studio API Key
# Format: AIzaSy{32 base64url chars}
# Risk: Very low (unique prefix AIzaSy)
# Test: https://ai.google.dev/
(
    re.compile(r'\bAIzaSy[A-Za-z0-9_-]{32}\b'),
    '[GOOGLE_API_KEY]',
    'Google AI Studio (Gemini) API key - v2.2 NEW',
),
```

---

## Контрольный список перед deployment

- [ ] Все новые паттерны протестированы на test cases
- [ ] False positive проверки пройдены
- [ ] Performance тесты (нет ReDoS)
- [ ] Обновлена версия (v2.2 → v2.3)
- [ ] Обновлен CHANGELOG
- [ ] Документация обновлена
- [ ] Нет conflicts с существующими паттернами
- [ ] Regex паттерны имеют максимальные длины
