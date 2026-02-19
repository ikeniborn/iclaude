# Example: Proxy Configuration

This example shows how to configure and test HTTP/HTTPS proxy with iclaude.sh.

## Scenario

You're behind a corporate firewall and need to route Claude Code traffic through a proxy.

## Quick Setup

```bash
# Launch with proxy (credentials saved for future use)
./iclaude.sh --proxy https://user:password@proxy.example.com:8118

# Future launches use saved credentials automatically
./iclaude.sh
```

## Testing Proxy Configuration

```bash
# Test without launching Claude Code
./iclaude.sh --test

# Expected output:
# Testing proxy configuration...
# ✓ HTTP request to http://www.google.com succeeded
# ✓ HTTPS request to https://www.anthropic.com succeeded
# Proxy configuration is working correctly
```

## Advanced Configuration

### With TLS Certificate

```bash
# For self-signed proxy certificates
./iclaude.sh --proxy https://proxy:8118 --proxy-ca /path/to/cert.pem
```

### Insecure Mode (NOT Recommended)

```bash
# Disable TLS verification (security risk!)
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

### NO_PROXY Configuration

Edit `.claude_proxy_credentials` to add NO_PROXY entries:

```
PROXY_URL=https://proxy.example.com:8118
NO_PROXY=localhost,127.0.0.1,github.com
```

## Proxy Protocols

### ✅ HTTPS (Recommended)

```bash
./iclaude.sh --proxy https://proxy:8118
```

**Why HTTPS?**
- Preserves domain names (required for OAuth)
- TLS Server Name Indication (SNI) works correctly
- Compatible with Anthropic authentication

### ⚠️ HTTP (Not Recommended)

```bash
./iclaude.sh --proxy http://proxy:8118
```

**Limitations:**
- Domain names may be converted to IPs
- Breaks OAuth token refresh
- Use only for testing

### ❌ SOCKS5 (NOT Supported)

SOCKS5 is not supported by Claude Code's `undici` HTTP client.

**Workaround:** Use Privoxy or Squid to convert SOCKS5 → HTTPS locally.

## Troubleshooting

### Proxy Connection Fails

```bash
# Show saved proxy URL (with password hidden)
./iclaude.sh --test

# Show proxy URL with password (for debugging)
./iclaude.sh --test --show-password
```

### OAuth Token Refresh Fails

**Problem:** Using HTTP proxy or IP address instead of domain name.

**Solution:**

```bash
# Use HTTPS proxy with domain name (NOT IP)
./iclaude.sh --proxy https://proxy.example.com:8118

# NOT: https://192.168.1.100:8118 (breaks OAuth)
```

### Remove Saved Proxy

```bash
# Launch without proxy
./iclaude.sh --no-proxy

# Delete saved credentials
rm .claude_proxy_credentials
```

## Related Commands

- `--test` - Test proxy without launching
- `--show-password` - Show proxy password for debugging
- `--no-proxy` - Temporarily disable proxy
- `--check-config` - Check which proxy is active
