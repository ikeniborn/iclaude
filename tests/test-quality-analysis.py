#!/usr/bin/env python3
"""
Комплексный анализ качества маскирования — redact-secrets.py

Тестирует:
  1. True positives  — реальные секреты должны быть замаскированы
  2. False positives — легитимные данные НЕ должны маскироваться
  3. False negatives — реальные секреты, которые ПРОПУСКАЮТСЯ (дыры)
  4. PII покрытие   — персданные, которые НЕ покрыты хуком
  5. Edge cases      — граничные случаи каждого паттерна
  6. Производительность — большие строки, catastrophic backtracking

Запуск: python3 tests/test-quality-analysis.py
"""
import sys
import os
import json
import time
import subprocess

# Путь к хуку относительно корня проекта
HOOK = os.path.join(
    os.path.dirname(__file__),
    '../.nvm-isolated/.claude-isolated/hooks/redact-secrets.py'
)

# --- счётчики ---
PASS = FAIL = WARN = 0
RESULTS = []          # (status, category, label, detail)


def run_hook(content: str, tool: str = 'Write', field: str = 'content') -> tuple[str, str]:
    """Запускает хук и возвращает (stdout, stderr)."""
    if tool == 'Bash':
        payload = json.dumps({'tool_name': 'Bash', 'tool_input': {'command': content}})
    else:
        payload = json.dumps({'tool_name': tool, 'tool_input': {'file_path': 'test.py', field: content}})
    result = subprocess.run(
        ['python3', HOOK],
        input=payload, capture_output=True, text=True
    )
    return result.stdout, result.stderr


def get_masked(content: str, tool: str = 'Write') -> str | None:
    """Возвращает маскированное содержимое или None если не изменено."""
    stdout, _ = run_hook(content, tool)
    if not stdout.strip():
        return None
    try:
        data = json.loads(stdout)
        inp = data['hookSpecificOutput']['toolInputOverride']
        return inp.get('content') or inp.get('command')
    except Exception:
        return None


def record(status: str, category: str, label: str, detail: str = ''):
    global PASS, FAIL, WARN
    RESULTS.append((status, category, label, detail))
    if status == 'PASS':
        PASS += 1
    elif status == 'FAIL':
        FAIL += 1
    elif status == 'WARN':
        WARN += 1


def assert_masked(category: str, label: str, content: str,
                  expected_placeholder: str, tool: str = 'Write'):
    """Утверждает что контент ДОЛЖЕН быть замаскирован с указанным плейсхолдером."""
    masked = get_masked(content, tool)
    if masked is None:
        record('FAIL', category, label, f'НЕ замаскировано (пустой stdout)\nВход: {content[:120]}')
    elif expected_placeholder not in masked:
        record('FAIL', category, label,
               f'Плейсхолдер "{expected_placeholder}" не найден\nРезультат: {masked[:120]}')
    elif content in masked:
        # Оригинал остался в тексте вместе с плейсхолдером
        record('FAIL', category, label, f'Оригинал сохранился в выводе: {masked[:120]}')
    else:
        record('PASS', category, label)


def assert_clean(category: str, label: str, content: str, tool: str = 'Write'):
    """Утверждает что контент НЕ должен быть изменён хуком."""
    masked = get_masked(content, tool)
    if masked is not None:
        record('FAIL', category, label,
               f'False positive — легитимные данные замаскированы!\nРезультат: {masked[:120]}')
    else:
        record('PASS', category, label)


def assert_missed(category: str, label: str, content: str,
                  secret_substring: str, tool: str = 'Write'):
    """Документирует ПРОПУЩЕННЫЙ секрет (false negative — дыра в защите)."""
    masked = get_masked(content, tool)
    if masked is None or secret_substring in (masked or content):
        record('WARN', category, label,
               f'[FALSE NEGATIVE] Секрет не замаскирован: {secret_substring}\nВход: {content[:120]}')
    else:
        record('PASS', category, label)


def assert_pii_missed(category: str, label: str, content: str, pii: str):
    """Документирует PII, который хук НЕ покрывает по дизайну."""
    masked = get_masked(content)
    if masked is None:
        record('WARN', category, label,
               f'[PII НЕ ПОКРЫТ] "{pii}" — хук не маскирует этот тип PII\nВход: {content[:120]}')
    else:
        # Если вдруг покрыл — PASS
        record('PASS', category, label)


# ═══════════════════════════════════════════════════════════════
# 1. TRUE POSITIVES — реальные секреты, которые ДОЛЖНЫ маскироваться
# ═══════════════════════════════════════════════════════════════

print('\n══════════════════════════════════════════')
print('  1. TRUE POSITIVES (должны маскироваться)')
print('══════════════════════════════════════════\n')

cat = 'TP: Anthropic/OpenAI/sk-...'
assert_masked(cat, 'sk-ant-api03-... полный формат', 'KEY="sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWxYz01234567890"', '[API_KEY_REDACTED]')
assert_masked(cat, 'sk-proj-... (OpenAI project)', 'key = "sk-proj-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789ab"', '[API_KEY_REDACTED]')
assert_masked(cat, 'sk-or-v1-... (OpenRouter)', 'X-API-Key: sk-or-v1-AbCdEfGhIjKlMnOpQrStUvWxYz01234567890ABC', '[API_KEY_REDACTED]')
assert_masked(cat, 'sk-... без префикса (generic)', 'openai_key = "sk-AbCdEfGhIjKlMnOpQrStUvWx"', '[API_KEY_REDACTED]')
assert_masked(cat, 'sk-... в curl -H', 'curl -H "Authorization: Bearer sk-proj-abcdefghijklmnopqrstuvwxyz012345"', '[API_KEY_REDACTED]', 'Bash')
assert_masked(cat, 'sk-... внутри Python dict', '{"api_key": "sk-ant-api03-abc123def456ghi789jkl012mno345"}', '[API_KEY_REDACTED]')
assert_masked(cat, 'sk-... в .env export', 'export OPENAI_API_KEY=sk-AbCdEfGhIjKlMnOpQrStUv', '[API_KEY_REDACTED]')

cat = 'TP: AWS'
assert_masked(cat, 'AKIA... в bash export', 'export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE', '[AWS_ACCESS_KEY_ID]', 'Bash')
assert_masked(cat, 'AKIA... в env файле', 'AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE', '[AWS_ACCESS_KEY_ID]')
assert_masked(cat, 'AWS Secret: имя переменной сохраняется', 'AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY', 'AWS_SECRET_ACCESS_KEY=[AWS_SECRET_KEY_REDACTED]')
assert_masked(cat, 'aws-secret-key (дефисы)', 'aws-secret-key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY', '[AWS_SECRET_KEY_REDACTED]')

cat = 'TP: GitHub токены'
assert_masked(cat, 'ghp_ (Personal Access Token)', 'GH_TOKEN=ghp_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8', '[GITHUB_TOKEN]')
assert_masked(cat, 'gho_ (OAuth token)', 'token = "gho_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8S9"', '[GITHUB_TOKEN]')
assert_masked(cat, 'ghu_ (user-to-server)', 'GITHUB_TOKEN=ghu_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8S9', '[GITHUB_TOKEN]')
assert_masked(cat, 'ghs_ (server-to-server)', 'auth = "ghs_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8S9"', '[GITHUB_TOKEN]')
assert_masked(cat, 'ghr_ (refresh token)', 'refresh = "ghr_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8S9"', '[GITHUB_TOKEN]')
assert_masked(cat, 'github_pat_ (fine-grained PAT, 82+ символов)',
    'git -c http.extraHeader="Authorization: Bearer github_pat_11ABCDEF0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ab" clone',
    '[GITHUB_TOKEN]', 'Bash')

cat = 'TP: JWT'
assert_masked(cat, 'JWT в Authorization заголовке',
    'curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiI0MiJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"',
    '[JWT_REDACTED]', 'Bash')
assert_masked(cat, 'JWT в Python переменной',
    'token = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature123"',
    '[JWT_REDACTED]')
assert_masked(cat, 'JWT без подписи (unsigned, пустой третий сегмент)',
    'unsigned_jwt = "eyJhbGciOiJub25lIn0.eyJzdWIiOiJ0ZXN0In0."',
    '[JWT_REDACTED]')

cat = 'TP: URL credentials'
assert_masked(cat, 'postgresql://user:pass@host', 'DB=postgresql://admin:S3cur3P4ss@prod-db.corp:5432/appdb', '[CREDENTIALS]')
assert_masked(cat, 'mysql://user:pass@host', 'MYSQL_URL=mysql://root:mysecret123@localhost:3306/mydb', '[CREDENTIALS]')
assert_masked(cat, 'mongodb://user:pass@host', 'MONGODB_URI=mongodb://mongo_user:SecureP@ss@cluster0.mongodb.net/mydb', '[CREDENTIALS]')
assert_masked(cat, 'redis://user:pass@host', 'REDIS_URL=redis://default:RedisP@ss123@redis.example.com:6379', '[CREDENTIALS]')
assert_masked(cat, 'amqp://user:pass@host (RabbitMQ)', 'AMQP_URL=amqp://mquser:MQpass123@rabbitmq.corp:5672/vhost', '[CREDENTIALS]')
assert_masked(cat, 'smtp://user:pass@host', 'MAIL_URL="smtp://smtp_user:mailpass123@mail.example.com:587"', '[CREDENTIALS]')
assert_masked(cat, 'https://user:pass@proxy', 'PROXY=https://proxyuser:P4ssw0rd@proxy.corp.example.com:8118', '[CREDENTIALS]')
assert_masked(cat, 'ldap://user:pass@host', 'LDAP_URL=ldap://cn=admin,dc=example,dc=com:adminpassword123@ldap.corp:389', '[CREDENTIALS]')
assert_masked(cat, 'ftp://user:pass@host', 'backup_url = ftp://ftpuser:FtpP4ss123@ftp.example.com/backup/', '[CREDENTIALS]')

cat = 'TP: Пароли в конфигах'
assert_masked(cat, 'password = "..." (двойные кавычки)', 'password = "Tr0ub4dor_3SecurePass!"', '[PASSWORD_REDACTED]')
assert_masked(cat, "password = '...' (одинарные кавычки)", "password = 'Tr0ub4dor_3SecurePass!'", '[PASSWORD_REDACTED]')
assert_masked(cat, 'password = value (без кавычек)', 'password = mysupersecretpassword123', '[PASSWORD_REDACTED]')
assert_masked(cat, 'PASSWORD: value (YAML стиль)', 'PASSWORD: S3cur3P4ssw0rd_Database', '[PASSWORD_REDACTED]')
assert_masked(cat, 'passwd = value', 'passwd = correcthorsebatterystaple', '[PASSWORD_REDACTED]')
assert_masked(cat, 'PGPASSWORD= (bash)', 'PGPASSWORD=VerySecretDbPass123 pg_dump mydb > dump.sql', '[PASSWORD_REDACTED]', 'Bash')
assert_masked(cat, 'DB_PASS= (.env)', 'DB_PASS=VerySecureDbPassword123456', '[PASSWORD_REDACTED]')
assert_masked(cat, 'db_pass: (YAML, case-insensitive)', 'db_pass: ProductionP4ssw0rd!', '[PASSWORD_REDACTED]')

cat = 'TP: PEM private keys'
assert_masked(cat, 'RSA PRIVATE KEY (классический)',
    '-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA0Z3VS5JJcds3xHn/ygWep4\n-----END RSA PRIVATE KEY-----',
    '[PRIVATE_KEY_REDACTED]')
assert_masked(cat, 'PRIVATE KEY (PKCS#8 без типа)',
    '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcw\n-----END PRIVATE KEY-----',
    '[PRIVATE_KEY_REDACTED]')
assert_masked(cat, 'ENCRYPTED PRIVATE KEY (PKCS#8 зашифрованный)',
    '-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFHDBOBgkqhkiG9w0BBQ0wQTAp\n-----END ENCRYPTED PRIVATE KEY-----',
    '[PRIVATE_KEY_REDACTED]')
assert_masked(cat, 'EC PRIVATE KEY (эллиптическая кривая)',
    '-----BEGIN EC PRIVATE KEY-----\nMHQCAQEEIOaLsXNnsfBnJUuEfQ\n-----END EC PRIVATE KEY-----',
    '[PRIVATE_KEY_REDACTED]')
assert_masked(cat, 'OPENSSH PRIVATE KEY',
    '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQ==\n-----END OPENSSH PRIVATE KEY-----',
    '[PRIVATE_KEY_REDACTED]')

cat = 'TP: .env переменные'
assert_masked(cat, 'ANTHROPIC_API_KEY=sk-ant-... (маскируется sk- паттерном)', 'ANTHROPIC_API_KEY=sk-ant-abc123xyz456def789ghi012jkl345', '[API_KEY_REDACTED]')
assert_masked(cat, 'GROQ_API_KEY= (Groq)', 'GROQ_API_KEY=gsk_abc123xyz456def789ghi012jkl345mno678', '[REDACTED]')
assert_masked(cat, 'export GOOGLE_API_KEY= с именем', 'export GOOGLE_API_KEY=AIzaSyA1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7', 'GOOGLE_API_KEY=[REDACTED]')
assert_masked(cat, 'MYSECRET=... (суффикс SECRET)', 'MYSECRET=abcdefghijklmnopqrstuvwxyz0123456789', '[REDACTED]')
assert_masked(cat, 'MY_TOKEN=... (суффикс TOKEN)', 'MY_TOKEN=abcdefghijklmnopqrstuvwxyz0123456789', '[REDACTED]')
assert_masked(cat, 'DB_PASSWORD= (маскируется password паттерном)', 'DB_PASSWORD=VerySecureProductionPass123', '[PASSWORD_REDACTED]')

cat = 'TP: Generic secret/token в assignments'
assert_masked(cat, 'api_key: "..." (YAML)', 'api_key: "abc123def456ghi789jkl012mno345"', '[SECRET_REDACTED]')
assert_masked(cat, 'secret = "..." (Python)', 'secret = "abc123def456ghi789jkl012mno345"', '[SECRET_REDACTED]')
assert_masked(cat, 'access_token: "..."', 'access_token: "AbCdEfGhIjKlMnOpQrStUvWx"', '[SECRET_REDACTED]')
assert_masked(cat, 'auth_token = "..." (base64 с padding ==)', 'auth_token = "YWJjZGVmZ2hpamtsbW5vcA=="', '[SECRET_REDACTED]')


# ═══════════════════════════════════════════════════════════════
# 2. FALSE POSITIVES — легитимные данные, которые НЕ должны маскироваться
# ═══════════════════════════════════════════════════════════════

print('\n══════════════════════════════════════════')
print('  2. FALSE POSITIVES (не должны маскироваться)')
print('══════════════════════════════════════════\n')

cat = 'FP: Короткие значения'
assert_clean(cat, 'sk- но короткий (< 20 символов после sk-)', 'key = "sk-shortkey"')
assert_clean(cat, 'password = "test" (7 символов)', 'password = "test123"')
assert_clean(cat, 'password = "pass" (4 символа)', 'password = "pass"')
assert_clean(cat, 'Короткий .env (< 20 символов значение)', 'MY_API_KEY=shortvalue')

cat = 'FP: Конфиг без секретов'
assert_clean(cat, 'PORT=8080 — простой конфиг', 'PORT=8080\nDEBUG=true\nHOST=localhost')
assert_clean(cat, 'git log команда', 'git log --oneline -10 -- lib/', 'Bash')
assert_clean(cat, 'docker команда', 'docker ps -a --format "table {{.Names}}\t{{.Status}}"', 'Bash')
assert_clean(cat, 'обычный Python код', 'def authenticate(username: str, password: str) -> bool:\n    return db.verify(username, password)')

cat = 'FP: ${VAR} плейсхолдеры в .env'
assert_clean(cat, 'OPENAI_API_KEY="${OPENAI_API_KEY}"', 'OPENAI_API_KEY="${OPENAI_API_KEY}"')
assert_clean(cat, 'MY_TOKEN=${MY_TOKEN}', 'MY_TOKEN=${MY_TOKEN}')
assert_clean(cat, 'export API_KEY="${API_KEY}"', 'export API_KEY="${API_KEY}"')
assert_clean(cat, 'DB_PASSWORD=${DB_PASSWORD} (bugfix: ${VAR} в password паттерне)', 'DB_PASSWORD=${DB_PASSWORD}')

cat = 'FP: URL без авторизации'
assert_clean(cat, 'https без credentials', 'url = "https://api.anthropic.com/v1/messages"')
assert_clean(cat, 'postgresql без credentials', 'DB_HOST=postgresql://localhost:5432/mydb')
assert_clean(cat, 'redis без credentials', 'redis://localhost:6379/0')

cat = 'FP: Обычные числа (не карты)'
assert_clean(cat, 'Телефон в коде (false positive риск)', 'phone = "+79991234567"')
assert_clean(cat, 'ID пользователя (длинный)', 'user_id = "1234567890123456789"')
assert_clean(cat, 'Версия в формате', 'version = "1.0.0-build.20240101.123456"')

cat = 'FP: Технические строки'
assert_clean(cat, 'Docker SHA256', 'image = "sha256:abcdef1234567890abcdef1234567890abcdef12"')
assert_clean(cat, 'Git commit SHA', 'commit = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"')
assert_clean(cat, 'Base64 контент (не JWT)', 'content = "SGVsbG8gV29ybGQhIFRoaXMgaXMgYSB0ZXN0Lg=="')
assert_clean(cat, 'Случайная строка > 20 символов без ключевого слова', 'some_var = "abcdefghijklmnopqrstuvwxyz0123456789"')

cat = 'FP: .env файл с описательными значениями'
assert_clean(cat, 'LOG_LEVEL=info', 'LOG_LEVEL=info\nNODE_ENV=production')
assert_clean(cat, 'DESCRIPTION с длинным текстом (не секрет)', 'APP_DESCRIPTION=This is the application description without any secrets in it')
# Ключевое слово в значении, не в имени
assert_clean(cat, 'ERROR_MESSAGE с "token" в значении', 'ERROR_MESSAGE=Invalid access token provided by the user')


# ═══════════════════════════════════════════════════════════════
# 3. FALSE NEGATIVES — реальные секреты, которые ПРОПУСКАЮТСЯ (дыры)
# ═══════════════════════════════════════════════════════════════

print('\n══════════════════════════════════════════')
print('  3. FALSE NEGATIVES (пропущенные секреты — дыры)')
print('══════════════════════════════════════════\n')

cat = 'FN: Провайдеры без специфичных паттернов'
assert_missed(cat, 'Google AI Studio (AIzaSy...)', 'GOOGLE_AI_KEY=AIzaSyDHn9_p-qvNbHk9Cc1xP2-YuL5RVZqJgLI', 'AIzaSy')
assert_missed(cat, 'Stripe sk_live_...', 'stripe.api_key = "sk_live_FAKE_EXAMPLE_NOT_REAL_KEY_XX"', 'sk_live_')
assert_missed(cat, 'Stripe sk_test_...', 'test_key = "sk_test_FAKE_EXAMPLE_NOT_REAL_KEY_XX"', 'sk_test_')
assert_missed(cat, 'HuggingFace (hf_...)', 'HF_TOKEN=hf_abcdefghijklmnopqrstuvwxyz012345', 'hf_')
assert_missed(cat, 'Groq (gsk_...)', 'GROQ_KEY=gsk_abcdefghijklmnopqrstuvwxyz012345678901234567890', 'gsk_')
assert_missed(cat, 'Mistral API key (32+ hex)',
    'MISTRAL_API_KEY=abcdef1234567890abcdef1234567890', 'abcdef1234567890abcdef')
assert_missed(cat, 'Cohere API key (uuid-like)',
    'CO_API_KEY=AbCdEfGhIjKlMnOpQrStUvWx12345678', 'AbCdEfGhIjKlMnOp')
assert_missed(cat, 'Twilio Account SID (ACxxxxxxx)',
    'TWILIO_SID=TWILIO_SID_FAKE_EXAMPLE_XX', 'TWILIO_SID_FAKE_EXAMPLE')
assert_missed(cat, 'Twilio Auth Token (32 hex)',
    'TWILIO_AUTH=4d7b5e8f9c2a1b6d3e4f5a8c9b2d3e4f', '4d7b5e8f9c2a1b6d')
assert_missed(cat, 'SendGrid (SG.xxx.yyy)',
    'SENDGRID_KEY=SG.abcdefghijklmnop.qrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz', 'SG.')
assert_missed(cat, 'Azure Connection String',
    'DefaultEndpointsProtocol=https;AccountName=mystorageaccount;AccountKey=abcdefghijklmnop+qrstuvwxyz/ABCDEFGHIJKLMNOP0123456789==;EndpointSuffix=core.windows.net',
    'AccountKey=')

cat = 'FN: Секреты без ключевых слов'
assert_missed(cat, 'Generic bearer token без переменной',
    'Authorization: Bearer eyNOT_JWT_just_random_base64_token_string_here_abcdefghij',
    'eyNOT_JWT')  # не начинается с eyJ — JWT не сработает
assert_missed(cat, 'Пароль в YAML без кавычек (>8, нет ключевого слова рядом)',
    'database:\n  host: localhost\n  password_hash: 5f4dcc3b5aa765d61d8327deb882cf99',  # md5 "password"
    'password_hash')

cat = 'FN: Паттерн пароля: пропущенные имена полей'
assert_missed(cat, 'db_password (не db_pass)', 'db_password=VerySecurePassword123456', 'db_password')
assert_missed(cat, 'database_password= (длинный префикс)', 'database_password=VerySecurePassword123456', 'database_password')
assert_missed(cat, 'secret_key = (не api_key)', 'secret_key = "abcdefghijklmnopqrstuvwxyz"', 'secret_key')
assert_missed(cat, 'token = "..." без prefix', 'token = "abcdefghijklmnopqrstuvwxyz012345"', '"abcdefghijklmnopqrstuvwxyz')

cat = 'FN: .env без суффиксов из списка'
assert_missed(cat, 'CREDENTIAL= (не в списке)', 'CREDENTIAL=abcdefghijklmnopqrstuvwxyz012345', 'CREDENTIAL=abcdefghijklmno')
assert_missed(cat, 'MY_AUTH= (AUTH не в списке)', 'MY_AUTH=abcdefghijklmnopqrstuvwxyz012345', 'MY_AUTH=abcdefghijklmnopqr')

cat = 'FN: Пароли в специфичных форматах'
assert_missed(cat, 'Пароль в INI-файле (нет кавычек, с пробелами)',
    '[mysql]\nuser = root\npassword = correcthorsebatterystaple\nhost = localhost',
    'correcthorsebatterystaple')  # без кавычек — должно работать
assert_missed(cat, 'Пароль в URI-encoded виде',
    'jdbc:postgresql://localhost/db?user=admin&password=S3cur3%40Pass',
    'S3cur3%40Pass')

cat = 'FN: Банковские карты'
assert_missed(cat, 'Карта с пробелами (4111 1111 1111 1111)',
    'card_number = "4111 1111 1111 1111"', '4111 1111 1111 1111')
assert_missed(cat, 'Карта с дефисами (4111-1111-1111-1111)',
    'card = "4111-1111-1111-1111"', '4111-1111-1111-1111')
assert_missed(cat, 'Discover card (6011...)',
    'card = "6011111111111117"', '601111')
assert_missed(cat, 'UnionPay (62...)',
    'card = "6212345678901234"', '6212')

cat = 'FN: GitHub Actions токен (gha_)'
assert_missed(cat, 'gha_ токен (Actions GITHUB_TOKEN)',
    'ACTIONS_TOKEN=gha_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8S9T0',
    'gha_')


# ═══════════════════════════════════════════════════════════════
# 4. PII — персональные данные, НЕ покрытые хуком
# ═══════════════════════════════════════════════════════════════

print('\n══════════════════════════════════════════')
print('  4. PII ПОКРЫТИЕ (персональные данные)')
print('══════════════════════════════════════════\n')

cat = 'PII: Email адреса'
assert_pii_missed(cat, 'email в Python переменной', 'user_email = "ivan.ivanov@company.ru"', 'ivan.ivanov@company.ru')
assert_pii_missed(cat, 'email в SQL запросе', "SELECT * FROM users WHERE email = 'user@example.com'", 'user@example.com')
assert_pii_missed(cat, 'email в JSON данных', '{"user": {"email": "john.doe@gmail.com", "name": "John"}}', 'john.doe@gmail.com')
assert_pii_missed(cat, 'список emails', 'recipients = ["alice@example.com", "bob@corp.ru"]', 'alice@example.com')

cat = 'PII: Телефонные номера'
assert_pii_missed(cat, 'Российский телефон +7', 'phone = "+7 (999) 123-45-67"', '+7 (999) 123-45-67')
assert_pii_missed(cat, 'Международный формат', 'contact_phone = "+1-800-555-0100"', '+1-800-555-0100')
assert_pii_missed(cat, 'Телефон без +', 'user_phone = "89991234567"', '89991234567')

cat = 'PII: Паспортные данные (Россия)'
assert_pii_missed(cat, 'Серия и номер паспорта', 'passport = "1234 567890"', '1234 567890')
assert_pii_missed(cat, 'ИНН физического лица (12 цифр)', 'inn = "123456789012"', '123456789012')
assert_pii_missed(cat, 'СНИЛС', 'snils = "123-456-789 00"', '123-456-789 00')
assert_pii_missed(cat, 'Дата рождения в коде', 'birth_date = "01.01.1990"', '01.01.1990')

cat = 'PII: Имена и персональные данные'
assert_pii_missed(cat, 'Имя в Python коде', 'customer_name = "Иванов Иван Иванович"', 'Иванов Иван')
assert_pii_missed(cat, 'Имя в SQL', "INSERT INTO users VALUES ('John Smith', 'john@example.com')", 'John Smith')
assert_pii_missed(cat, 'Адрес в конфиге', 'delivery_address = "г. Москва, ул. Ленина, д. 1, кв. 42"', 'г. Москва')

cat = 'PII: Финансовые данные'
assert_pii_missed(cat, 'IBAN', 'iban = "RU12 3456 7890 1234 5678 9012 3"', 'RU12 3456')
assert_pii_missed(cat, 'Сумма транзакции с именем', 'log = "Transfer: 50000 RUB to Иванов И.И."', '50000 RUB')

cat = 'PII: Медицинские данные'
assert_pii_missed(cat, 'Диагноз в комментарии', '# Patient: Ivan Ivanov, diagnosis: hypertension, DOB: 1980-01-15', 'Ivan Ivanov')
assert_pii_missed(cat, 'Полис ОМС', 'oms_policy = "1234567890123456"', '1234567890123456')

cat = 'PII: IP и сетевые данные'
assert_pii_missed(cat, 'IP адрес клиента в логе', 'log("User 192.168.1.100 accessed /admin")', '192.168.1.100')
assert_pii_missed(cat, 'MAC адрес устройства', 'device_mac = "AA:BB:CC:DD:EE:FF"', 'AA:BB:CC:DD:EE')


# ═══════════════════════════════════════════════════════════════
# 5. EDGE CASES — граничные случаи
# ═══════════════════════════════════════════════════════════════

print('\n══════════════════════════════════════════')
print('  5. EDGE CASES (граничные случаи)')
print('══════════════════════════════════════════\n')

cat = 'Edge: Несколько секретов в одной строке'
content = 'curl -H "X-API-Key: sk-proj-AbCdEfGhIjKlMnOpQrStUvWxYz012345" -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiI0MiJ9.sig"'
masked = get_masked(content, 'Bash')
if masked and '[API_KEY_REDACTED]' in masked and '[JWT_REDACTED]' in masked:
    record('PASS', cat, 'Два секрета в одной строке — оба маскируются')
elif masked:
    record('FAIL', cat, 'Два секрета в одной строке', f'Результат: {masked}')
else:
    record('FAIL', cat, 'Два секрета в одной строке', 'Хук не сработал')

cat = 'Edge: Комментарии с секретами'
assert_masked(cat, 'Секрет в bash-комментарии', '# Старый токен: sk-ant-api03-OldTokenAbcDef123456789012', '[API_KEY_REDACTED]')
assert_masked(cat, 'Секрет в Python-комментарии', '# api_key = "sk-proj-OldAbCdEfGhIjKlMnOpQrStUvWxYz"  # deprecated', '[API_KEY_REDACTED]')

cat = 'Edge: Многострочные конфиги'
multiline = 'DATABASE_URL=postgresql://admin:S3cr3tPass@db.example.com:5432/prod\nANTHROPIC_API_KEY=sk-ant-api03-abc123xyz456def789ghi012jkl345\nDEBUG=false'
masked = get_masked(multiline)
if masked:
    if '[CREDENTIALS]' in masked and ('[REDACTED]' in masked or '[API_KEY_REDACTED]' in masked):
        record('PASS', cat, 'Многострочный .env с несколькими секретами')
    else:
        record('FAIL', cat, 'Многострочный .env — не все секреты замаскированы', f'Результат: {masked}')
else:
    record('FAIL', cat, 'Многострочный .env — ничего не замаскировано')

cat = 'Edge: Идемпотентность (повторное применение)'
# После маскирования повторный прогон не должен ничего изменять
already_masked = 'KEY=[API_KEY_REDACTED]\nAWS_SECRET_ACCESS_KEY=[AWS_SECRET_KEY_REDACTED]'
result2 = get_masked(already_masked)
if result2 is None:
    record('PASS', cat, 'Уже замаскированный контент — повторно не трогается')
else:
    record('FAIL', cat, 'Двойное маскирование', f'Повторно применено: {result2}')

cat = 'Edge: JSON с экранированными символами'
assert_masked(cat, 'Секрет в JSON строке',
    '{"key": "sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789", "model": "claude-3"}',
    '[API_KEY_REDACTED]')

cat = 'Edge: Секрет в конце файла без newline'
assert_masked(cat, 'API key в последней строке без \\n',
    'config = {\n  "api_key": "sk-proj-AbCdEfGhIjKlMnOpQrStUvWxYz"\n}',
    '[API_KEY_REDACTED]')

cat = 'Edge: Граничные размеры токенов'
# sk- ровно 20 символов после префикса
assert_masked(cat, 'sk- ровно 20 символов после sk-', 'key="sk-AbCdEfGhIjKlMnOpQrSt"', '[API_KEY_REDACTED]')
# sk- 19 символов — НЕ должен маскироваться
assert_clean(cat, 'sk- только 19 символов (ниже порога)', 'key="sk-AbCdEfGhIjKlMnOpQrS"')
# .env ровно 20 символов значение
assert_masked(cat, '.env значение ровно 20 символов', 'MY_API_KEY=AbCdEfGhIjKlMnOpQrSt', '[REDACTED]')
# .env 19 символов — НЕ должен
assert_clean(cat, '.env значение только 19 символов', 'MY_API_KEY=AbCdEfGhIjKlMnOpQrS')

cat = 'Edge: Работа с инструментами'
# Edit — только new_string маскируется
payload_edit = json.dumps({
    'tool_name': 'Edit',
    'tool_input': {
        'file_path': 'app.py',
        'old_string': 'api = "sk-ant-api03-OldTokenAbcDef123456789012"',
        'new_string': 'api = "sk-ant-api03-NewTokenAbcDef123456789012"'
    }
})
stdout, _ = subprocess.run(['python3', HOOK], input=payload_edit, capture_output=True, text=True).communicate() if False else (
    subprocess.run(['python3', HOOK], input=payload_edit, capture_output=True, text=True).stdout, ''
)
if stdout.strip():
    try:
        data = json.loads(stdout)
        inp = data['hookSpecificOutput']['toolInputOverride']
        old_str = inp.get('old_string', '')
        new_str = inp.get('new_string', '')
        old_intact = 'sk-ant-api03-OldTokenAbcDef123456789012' in old_str
        new_masked = '[API_KEY_REDACTED]' in new_str
        if old_intact and new_masked:
            record('PASS', cat, 'Edit: old_string сохранён, new_string замаскирован')
        else:
            record('FAIL', cat, 'Edit: old_string или new_string обработаны неверно',
                   f'old_intact={old_intact}, new_masked={new_masked}')
    except Exception as e:
        record('FAIL', cat, 'Edit: JSON parsing error', str(e))
else:
    record('FAIL', cat, 'Edit: хук не сработал на new_string с секретом')


# ═══════════════════════════════════════════════════════════════
# 6. ПРОИЗВОДИТЕЛЬНОСТЬ
# ═══════════════════════════════════════════════════════════════

print('\n══════════════════════════════════════════')
print('  6. ПРОИЗВОДИТЕЛЬНОСТЬ')
print('══════════════════════════════════════════\n')

cat = 'Perf: Большие строки'

# Тест 1: Большой файл без секретов (должен быть быстрым)
large_clean = 'x = ' + 'a' * 10000 + '\n' + 'y = ' + 'b' * 10000
start = time.time()
result = get_masked(large_clean)
elapsed = time.time() - start
if elapsed < 2.0:
    record('PASS', cat, f'Большой чистый контент (20KB) — {elapsed*1000:.0f}мс')
else:
    record('FAIL', cat, f'Большой чистый контент — слишком медленно', f'{elapsed:.2f}с > 2с')

# Тест 2: PEM-подобная строка без закрытия (не должно быть catastrophic backtracking)
pem_no_end = '-----BEGIN RSA PRIVATE KEY-----\n' + 'A' * 2000  # без END
start = time.time()
result = get_masked(pem_no_end)
elapsed = time.time() - start
if elapsed < 3.0:
    record('PASS', cat, f'PEM без закрытия (незавершённый) — {elapsed*1000:.0f}мс (нет backtracking)')
else:
    record('FAIL', cat, 'PEM без закрытия — catastrophic backtracking?', f'{elapsed:.2f}с > 3с')

# Тест 3: Контент с одним секретом в конце большого файла
big_with_secret = 'x = 1\n' * 1000 + 'ANTHROPIC_API_KEY=sk-ant-api03-abc123xyz456def789ghi012jkl345'
start = time.time()
result = get_masked(big_with_secret)
elapsed = time.time() - start
if result and '[REDACTED]' in result or (result and '[API_KEY_REDACTED]' in result):
    record('PASS', cat, f'Секрет в конце большого файла (1001 строк) — {elapsed*1000:.0f}мс')
elif elapsed < 2.0:
    record('FAIL', cat, f'Секрет в конце большого файла — не найден', f'Время: {elapsed*1000:.0f}мс, результат: {str(result)[:80]}')
else:
    record('FAIL', cat, 'Секрет в конце большого файла — таймаут', f'{elapsed:.2f}с')


# ═══════════════════════════════════════════════════════════════
# ИТОГОВЫЙ ОТЧЁТ
# ═══════════════════════════════════════════════════════════════

print('\n' + '═' * 55)
print('  ДЕТАЛЬНЫЙ ОТЧЁТ ПО КАТЕГОРИЯМ')
print('═' * 55)

by_category: dict[str, list] = {}
for status, cat, label, detail in RESULTS:
    by_category.setdefault(cat, []).append((status, label, detail))

for cat_name, items in by_category.items():
    cat_pass = sum(1 for s, _, _ in items if s == 'PASS')
    cat_fail = sum(1 for s, _, _ in items if s == 'FAIL')
    cat_warn = sum(1 for s, _, _ in items if s == 'WARN')
    total = len(items)
    status_icon = '✓' if cat_fail == 0 and cat_warn == 0 else ('⚠' if cat_fail == 0 else '✗')
    print(f'\n{status_icon} {cat_name}')
    print(f'  {cat_pass}/{total} passed', end='')
    if cat_fail:
        print(f', {cat_fail} FAIL', end='')
    if cat_warn:
        print(f', {cat_warn} WARN', end='')
    print()
    for s, label, detail in items:
        if s == 'PASS':
            print(f'    ✓ {label}')
        elif s == 'FAIL':
            print(f'    ✗ {label}')
            if detail:
                for line in detail.split('\n'):
                    print(f'      {line}')
        elif s == 'WARN':
            print(f'    ⚠ {label}')
            if detail:
                for line in detail.split('\n')[:2]:
                    print(f'      {line}')

print('\n' + '═' * 55)
print('  СВОДКА АНАЛИЗА КАЧЕСТВА')
print('═' * 55)

tp_pass = sum(1 for s, c, _, _ in RESULTS if s == 'PASS' and c.startswith('TP:'))
tp_total = sum(1 for _, c, _, _ in RESULTS if c.startswith('TP:'))
fp_fail = sum(1 for s, c, _, _ in RESULTS if s == 'FAIL' and c.startswith('FP:'))
fp_total = sum(1 for _, c, _, _ in RESULTS if c.startswith('FP:'))
fn_warn = sum(1 for s, c, _, _ in RESULTS if s == 'WARN' and c.startswith('FN:'))
fn_total = sum(1 for _, c, _, _ in RESULTS if c.startswith('FN:'))
pii_warn = sum(1 for s, c, _, _ in RESULTS if s == 'WARN' and c.startswith('PII:'))
pii_total = sum(1 for _, c, _, _ in RESULTS if c.startswith('PII:'))

print(f'\n  True Positive Rate:   {tp_pass}/{tp_total} ({100*tp_pass//tp_total if tp_total else 0}%) — секреты корректно маскируются')
print(f'  False Positive Rate:  {fp_fail}/{fp_total} ({100*fp_fail//fp_total if fp_total else 0}%) — легитимные данные ошибочно маскируются')
print(f'  False Negatives:      {fn_warn}/{fn_total} — реальные секреты пропускаются (дыры)')
print(f'  PII не покрыто:       {pii_warn}/{pii_total} — персданные за пределами хука')

print(f'\n  ИТОГО: {PASS} PASS / {FAIL} FAIL / {WARN} WARN')

print('\n  ВЕРДИКТ:')
if FAIL == 0 and fn_warn <= 5:
    print('  ✓ Хук работает корректно. Секреты API маскируются.')
elif FAIL > 0:
    print(f'  ✗ Обнаружены ошибки ({FAIL} FAIL) — требует исправления.')
if fn_warn > 0:
    print(f'  ⚠ {fn_warn} дыр в покрытии секретов — рекомендуется расширить паттерны.')
if pii_warn > 0:
    print(f'  ⚠ {pii_warn} типов PII не покрыты — хук не заменяет NLP-решения (PasteGuard/Presidio).')

print()
sys.exit(1 if FAIL > 0 else 0)
