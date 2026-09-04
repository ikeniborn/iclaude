#!/usr/bin/env bash
# tests/test-redact-hook.sh — тесты хука redact-secrets.py
#
# Использование: ./tests/test-redact-hook.sh
# Запускать из корня проекта iclaude.

set -euo pipefail

HOOK=".claude-isolated/hooks/redact-secrets.py"
BLOCK_HOOK=".claude-isolated/hooks/block-secrets.py"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

run_hook() {
    python3 "$HOOK" <<< "$1"
}

# Проверяет что stdout содержит строку (fixed-string, нет shell-injection)
assert_masked() {
    local label="$1" payload="$2" expected="$3"
    local out
    out=$(run_hook "$payload" 2>/dev/null)
    if echo "$out" | grep -qF "$expected"; then
        pass "$label"
    else
        fail "$label (не найдено: $expected)"
        echo "    stdout: $out"
    fi
}

# Проверяет что stdout пустой (нет изменений)
assert_clean() {
    local label="$1" payload="$2"
    local out
    out=$(run_hook "$payload" 2>/dev/null)
    if [[ -z "$out" ]]; then
        pass "$label"
    else
        fail "$label (ожидали пустой stdout, получили: $out)"
    fi
}

# Проверяет exit code
assert_exit() {
    local label="$1" payload="$2" expected_code="$3"
    local actual_code=0
    python3 "$HOOK" <<< "$payload" >/dev/null 2>&1 || actual_code=$?
    if [[ "$actual_code" == "$expected_code" ]]; then
        pass "$label"
    else
        fail "$label (exit=$actual_code, ожидали $expected_code)"
    fi
}

# Проверяет exit code block-secrets.py
assert_blocked() {
    local label="$1" payload="$2"
    local actual_code=0
    python3 "$BLOCK_HOOK" <<< "$payload" >/dev/null 2>&1 || actual_code=$?
    if [[ "$actual_code" == "2" ]]; then
        pass "$label"
    else
        fail "$label (exit=$actual_code, ожидали 2/blocked)"
    fi
}

echo "=== test-redact-hook.sh ==="
echo ""

echo "─ Anthropic/OpenAI/Stripe API keys (sk-...)"
assert_masked "sk-ant-... маскируется" \
    '{"tool_name":"Write","tool_input":{"file_path":"f.py","content":"KEY=\"sk-ant-api03-abc123xyz456def789\""}}' \
    '[API_KEY_REDACTED]'
assert_masked "sk-proj-... маскируется" \
    '{"tool_name":"Write","tool_input":{"file_path":"f.py","content":"KEY=\"sk-proj-abc123xyz456def789ghi\""}}' \
    '[API_KEY_REDACTED]'
assert_masked "sk-or-v1-... (OpenRouter) маскируется" \
    '{"tool_name":"Bash","tool_input":{"command":"curl -H \"X-Key: sk-or-v1-abc123xyz456def789ghi012jkl\""}}' \
    '[API_KEY_REDACTED]'

echo ""
echo "─ AWS"
assert_masked "AWS Access Key ID маскируется" \
    '{"tool_name":"Bash","tool_input":{"command":"export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"}}' \
    '[AWS_ACCESS_KEY_ID]'
# AWS Secret — имя переменной должно сохраняться (bugfix: capture group)
assert_masked "AWS Secret Key: имя переменной сохраняется" \
    '{"tool_name":"Write","tool_input":{"file_path":"deploy.sh","content":"AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"}}' \
    'AWS_SECRET_ACCESS_KEY=[AWS_SECRET_KEY_REDACTED]'

echo ""
echo "─ GitHub токены"
assert_masked "ghp_ (классический PAT) маскируется" \
    '{"tool_name":"Write","tool_input":{"file_path":"deploy.sh","content":"GH_PAT=ghp_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8"}}' \
    '[GITHUB_TOKEN]'
assert_masked "github_pat_ (fine-grained PAT) маскируется" \
    '{"tool_name":"Bash","tool_input":{"command":"git -c http.extraHeader=\"Authorization: Bearer github_pat_11ABCDEF0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ab\" clone https://github.com/org/repo"}}' \
    '[GITHUB_TOKEN]'

echo ""
echo "─ JWT"
assert_masked "JWT в Bearer маскируется" \
    '{"tool_name":"Bash","tool_input":{"command":"curl -H \"Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiI0MiJ9.abc123sig\""}}' \
    '[JWT_REDACTED]'

echo ""
echo "─ Credentials в URL (расширенное покрытие схем)"
assert_masked "postgresql://user:pass@ маскируется" \
    '{"tool_name":"Bash","tool_input":{"command":"psql postgresql://admin:pass123@db.host:5432/mydb -c \"SELECT 1\""}}' \
    '[CREDENTIALS]'
assert_masked "https://user:pass@ маскируется" \
    '{"tool_name":"Write","tool_input":{"file_path":"config.sh","content":"PROXY=https://proxyuser:pass123@proxy.example.com:8118"}}' \
    '[CREDENTIALS]'
assert_masked "amqp://user:pass@ маскируется (RabbitMQ)" \
    '{"tool_name":"Bash","tool_input":{"command":"export AMQP_URL=amqp://mquser:Str0ngPass123@rabbitmq.corp.example.com:5672/vhost"}}' \
    '[CREDENTIALS]'
assert_masked "smtp://user:pass@ маскируется" \
    '{"tool_name":"Write","tool_input":{"file_path":"mailer.py","content":"MAIL_URL=\"smtp://smtp_user:mailpass123@mail.example.com:587\""}}' \
    '[CREDENTIALS]'

echo ""
echo "─ Пароли в конфигах"
assert_masked "password = \"...\" (с кавычками) маскируется" \
    '{"tool_name":"Write","tool_input":{"file_path":"config.ini","content":"password = \"Tr0ub4dor_3SecurePass\""}}' \
    '[PASSWORD_REDACTED]'
assert_masked "password = value (без кавычек) маскируется" \
    '{"tool_name":"Write","tool_input":{"file_path":"config.ini","content":"password = mysupersecretpassword123"}}' \
    '[PASSWORD_REDACTED]'
assert_masked "PGPASSWORD= маскируется" \
    '{"tool_name":"Bash","tool_input":{"command":"PGPASSWORD=S3cur3P4ssw0rd pg_dump mydb > dump.sql"}}' \
    '[PASSWORD_REDACTED]'

echo ""
echo "─ .env формат (bugfix: export PREFIX + PASS суффикс + negative lookahead)"
assert_masked "export VARNAME=значение маскируется (.env паттерн)" \
    '{"tool_name":"Write","tool_input":{"file_path":"config.sh","content":"export GROQ_API_KEY=gsk_abc123xyz456def789ghi012jkl345"}}' \
    '[REDACTED]'
assert_masked "export VAR= сохраняет имя переменной" \
    '{"tool_name":"Write","tool_input":{"file_path":"config.sh","content":"export GOOGLE_API_KEY=AIzaSyA1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7"}}' \
    'export GOOGLE_API_KEY=[REDACTED]'
assert_masked "DB_PASS= маскируется (db_pass в password паттерне)" \
    '{"tool_name":"Write","tool_input":{"file_path":"deploy.sh","content":"DB_PASS=VerySecureDbPassword123456"}}' \
    '[PASSWORD_REDACTED]'
# Плейсхолдер ${VAR} не маскируется
assert_clean "Placeholder \${VAR} не маскируется" \
    '{"tool_name":"Write","tool_input":{"file_path":"config.sh","content":"export OPENROUTER_API_KEY=\"${OPENROUTER_API_KEY}\""}}'
assert_clean "Placeholder без кавычек не маскируется" \
    '{"tool_name":"Write","tool_input":{"file_path":"config.sh","content":"export DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}"}}'

echo ""
echo "─ PEM private keys"
assert_masked "ENCRYPTED PRIVATE KEY (PKCS#8) маскируется" \
    '{"tool_name":"Write","tool_input":{"file_path":"app.py","content":"KEY=\"-----BEGIN ENCRYPTED PRIVATE KEY-----\\nMIIFHDBOBgkqhkiG9w0BBQ0wQTApBgkqhkiG9w0BBQww\\n-----END ENCRYPTED PRIVATE KEY-----\""}}' \
    '[PRIVATE_KEY_REDACTED]'

echo ""
echo "─ Edit — только new_string маскируется, old_string сохраняется"
assert_masked "Edit new_string с JWT маскируется" \
    '{"tool_name":"Edit","tool_input":{"file_path":"app.py","old_string":"token = None","new_string":"token = \"eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiI0MiJ9.abc123\""}}' \
    '[JWT_REDACTED]'
# old_string с секретом НЕ должен маскироваться (иначе Edit провалится)
assert_clean "Edit old_string с API key НЕ маскируется (H-4 bugfix)" \
    '{"tool_name":"Edit","tool_input":{"file_path":"app.py","old_string":"api = \"sk-ant-api03-abc123xyz456def789\"","new_string":"api = None"}}'
assert_clean "Edit без секретов — хук не изменяет аргументы" \
    '{"tool_name":"Edit","tool_input":{"file_path":"app.py","old_string":"host = localhost","new_string":"host = prod.example.com"}}'

echo ""
echo "─ MultiEdit — только new_string в каждом edit"
assert_masked "MultiEdit — ключ в new_string маскируется" \
    '{"tool_name":"MultiEdit","tool_input":{"file_path":"r.json","edits":[{"old_string":"old","new_string":"\"api_key\": \"sk-abc123def456ghi789jkl012\""},{"old_string":"x","new_string":"y"}]}}' \
    '[API_KEY_REDACTED]'
assert_clean "MultiEdit old_string с секретом НЕ маскируется" \
    '{"tool_name":"MultiEdit","tool_input":{"file_path":"r.json","edits":[{"old_string":"\"api_key\": \"sk-abc123def456ghi789jkl012\"","new_string":"\"api_key\": null"}]}}'

echo ""
echo "─ Не маскируется (false positives)"
assert_clean "Чистый bash без данных" \
    '{"tool_name":"Bash","tool_input":{"command":"git log --oneline -5"}}'
assert_clean "Read не проверяется" \
    '{"tool_name":"Read","tool_input":{"file_path":"lib/launcher/launch.sh"}}'
assert_clean "Короткие значения не маскируются" \
    '{"tool_name":"Write","tool_input":{"file_path":"config.py","content":"PORT=8080\nDEBUG=true\nHOST=localhost"}}'
assert_clean "Короткий пароль (< 8 символов) не маскируется" \
    '{"tool_name":"Write","tool_input":{"file_path":"test.ini","content":"password = test"}}'

echo ""
echo "─ Изоляция и устойчивость"
assert_clean "Hooks-директория исключена" \
    '{"tool_name":"Write","tool_input":{"file_path":".claude-isolated/hooks/redact-secrets.py","content":"sk-ant-abc123xyz456def789"}}'
# tool_input: null — должен обрабатываться без краша (bugfix: or {})
assert_exit "tool_input=null — fail-open (exit 0)" \
    '{"tool_name":"Write","tool_input":null}' 0
assert_exit "Некорректный JSON — fail-open (exit 0)" \
    'not valid json' 0
assert_exit "Пустой stdin — fail-open (exit 0)" \
    '' 0

echo ""
echo "─ Пайплайн: block-secrets.py блокирует ДО redact"
assert_blocked ".env файл блокируется block-secrets.py" \
    '{"tool_name":"Write","tool_input":{"file_path":"/tmp/app.env","content":"DEEPSEEK_API_KEY=sk-ant-abc123xyz456"}}'
assert_blocked ".pem файл блокируется block-secrets.py" \
    '{"tool_name":"Write","tool_input":{"file_path":"/tmp/server.pem","content":"-----BEGIN CERTIFICATE-----"}}'
assert_blocked ".ssh путь блокируется block-secrets.py" \
    '{"tool_name":"Read","tool_input":{"file_path":"/home/user/.ssh/id_rsa"}}'

echo ""
echo "─────────────────────────────────────"
echo "  Итого: $PASS passed, $FAIL failed"
echo "─────────────────────────────────────"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
