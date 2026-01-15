# Basic Usage Example - proxy-management

## Scenario

Настройка, тестирование и отладка HTTP/HTTPS/SOCKS5 прокси для Claude Code с автоматической валидацией и credential storage.

**Use cases:**
- Первая настройка прокси для Claude Code
- Тестирование прокси подключения
- Отладка проблем с OAuth token refresh
- Выбор между HTTP и HTTPS протоколом

---

## Input

```json
{
  "proxy_url": "https://proxy.example.com:8118",
  "credentials": {
    "username": "user",
    "password": "***"
  },
  "test_mode": true
}
```

---

## Execution

proxy-management skill выполняет следующие шаги:

### Step 1: Protocol Validation
- Проверка протокола: HTTP ✓ / HTTPS ✓ / SOCKS5 ✗ (not supported by undici)

### Step 2: Domain Resolution (для HTTP)
- HTTPS: domain PRESERVED (required для OAuth/TLS)
- HTTP: опция convert domain → IP (optional)

### Step 3: Credential Storage
- Сохранение в `.claude_proxy_credentials`
- chmod 600 (owner-only)
- Format: `https://user:pass@proxy.example.com:8118`

### Step 4: Connection Test
- HTTP request to `http://www.google.com`
- HTTPS request to `https://www.anthropic.com`
- Validate response codes (200)

---

## Output

```
✓ Proxy URL validated: https://proxy.example.com:8118
✓ Protocol: HTTPS (recommended для OAuth)
✓ Domain preserved (required для TLS/SNI)
✓ Credentials сохранены в .claude_proxy_credentials (chmod 600)

🔍 Testing connection...
✓ HTTP request: www.google.com → 200 OK
✓ HTTPS request: www.anthropic.com → 200 OK

✅ Proxy подключение работает!

📝 Environment variables:
   HTTPS_PROXY=https://user:***@proxy.example.com:8118
   HTTP_PROXY=https://user:***@proxy.example.com:8118
   NO_PROXY=localhost,127.0.0.1,github.com,anthropic.com
```

---

## Explanation

### HTTPS vs HTTP Protocol:

**HTTPS (recommended):**
- Domain names preserved (NOT converted to IP)
- Required для Anthropic OAuth token refresh
- TLS SNI and Host header работают корректно
- **Security note:** undici ProxyAgent не проверяет TLS сертификаты target servers ([HackerOne #1583680](https://hackerone.com/reports/1583680))

**HTTP (not recommended):**
- Опция convert domain → IP (для избежания DNS issues)
- Может break OAuth token refresh (Host header mismatch)

### SOCKS5 NOT supported:

```
❌ Invalid protocol: socks5
InvalidArgumentError: Invalid URL protocol: the URL must start with `http:` or `https:`

💡 Workaround: Use Privoxy or Squid to convert SOCKS5 → HTTPS locally
```

### Troubleshooting OAuth failures:

```
# Проблема: OAuth token refresh fails
# Причина: Domain был converted to IP

# Проверка:
cat .claude_proxy_credentials
# Если видите IP вместо домена:
# https://user:pass@192.168.1.100:8118  ← BAD

# Решение:
./iclaude.sh --proxy https://proxy.example.com:8118
# Должно быть:
# https://user:pass@proxy.example.com:8118  ← GOOD
```

### TLS Certificate Support:

```bash
# Self-signed proxy certificate
./iclaude.sh --proxy https://proxy:8118 --proxy-ca /path/to/cert.pem

# OR insecure mode (не рекомендуется)
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

---

## Related

- [proxy-management/SKILL.md](../SKILL.md)
- [iclaude.sh proxy functions](../../../CLAUDE.md#proxy-protocol-support)
