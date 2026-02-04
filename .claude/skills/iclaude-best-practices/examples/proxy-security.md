# Proxy Configuration & Security

## Proxy Protocol Support

### ✅ Recommended: HTTPS Proxy

**Why:**
- Preserves domain names (required for Anthropic OAuth token refresh)
- TLS Server Name Indication (SNI) works correctly
- Host header validated by OAuth

**Example:**
```bash
./iclaude.sh --proxy https://proxy.example.com:8118
# Domain preserved: https://proxy.example.com:8118
```

### ⚠️ Supported but not recommended: HTTP Proxy

**Why:**
- Script offers domain-to-IP conversion (optional)
- IP conversion improves reliability (avoids DNS issues)
- BUT: Breaks OAuth if converted to IP

**Example:**
```bash
./iclaude.sh --proxy http://proxy.example.com:8118
# User choice: convert to http://192.168.1.100:8118 or keep domain
```

### ❌ NOT Supported: SOCKS5 Proxy

**Why:**
- Claude Code uses `undici` HTTP client
- undici does NOT support SOCKS5 protocol
- Attempting SOCKS5 causes crash:
  ```
  InvalidArgumentError: Invalid URL protocol: the URL must start with `http:` or `https:`
  ```

**Workaround:**
- Use Privoxy or Squid to convert SOCKS5 → HTTPS locally
- Then use HTTPS proxy URL with iclaude.sh

## HTTPS Proxy Security

### ⚠️ Known Vulnerability

**Issue:** `undici` ProxyAgent does NOT verify TLS certificates of target servers when proxying HTTPS traffic

**Reference:** [HackerOne #1583680](https://hackerone.com/reports/1583680)

**Implications:**
- Proxy server can intercept ALL HTTPS traffic (MitM)
- Only use TRUSTED proxy servers
- Prefer `--proxy-ca` over `--proxy-insecure`

### ✅ Secure Configuration

```bash
# Best: Use trusted proxy with CA certificate
./iclaude.sh --proxy https://proxy:8118 --proxy-ca /path/to/cert.pem

# Alternative: Trust system CA bundle
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# ❌ Avoid: Disable TLS verification (insecure)
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

## Domain Handling in Proxy URLs

### HTTPS Proxies (recommended)

- Domain names are **PRESERVED** (NOT converted to IP)
- Required for OAuth token refresh and TLS (SNI, Host header)
- Converting to IP breaks Anthropic authentication

```bash
# Input: https://proxy.example.com:8118
# Saved as: https://proxy.example.com:8118  (domain preserved!)
```

### HTTP Proxies (not recommended)

- Script offers to convert domain to IP (optional)
- IP conversion improves reliability (avoids DNS lookup issues)

```bash
# Input: http://proxy.example.com:8118
# User choice: convert to http://192.168.1.100:8118 or keep domain
```

### Why This Matters for HTTPS

- Anthropic OAuth validates the Host header during token refresh
- TLS Server Name Indication (SNI) requires the actual domain name
- Using IP instead of domain causes authentication failures

## Testing Proxy Configuration

```bash
# Test connection
./iclaude.sh --test

# Check what will be configured (show password for debugging)
./iclaude.sh --proxy https://proxy:8118 --test --show-password
```

**Test performs:**
1. HTTP request to `http://www.google.com`
2. HTTPS request to `https://www.anthropic.com`
3. Validates response codes and content

**Common Failures:**
- `ECONNREFUSED`: Proxy not running or wrong port
- `ENOTFOUND`: Domain resolution failed
- `ETIMEDOUT`: Firewall blocking connection
- `TLS_ERROR`: Certificate issues (use `--proxy-ca`)

## Security Considerations

1. **Credential Storage**: `.claude_proxy_credentials` uses chmod 600 (owner-only)
2. **Git Exclusion**: Credentials NEVER committed to git (see .gitignore)
3. **Password Display**: Hidden by default, use `--show-password` to debug
4. **HTTPS Proxy**: Prefer `--proxy-ca` over `--proxy-insecure`
5. **Proxy Trust**: Only use TRUSTED proxy servers (MitM risk)
