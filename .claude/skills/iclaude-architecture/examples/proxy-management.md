# Proxy Management Component Example

This example demonstrates the Proxy Management component architecture and usage patterns.

## Component Overview

**Module**: Proxy Management
**Location**: iclaude.sh:1343-1666
**Functions**: `save_credentials`, `load_credentials`, `configure_proxy_from_url`, `validate_proxy_url`, `resolve_domain_to_ip`, `parse_proxy_url`

## Key Features

1. **Proxy URL Validation**
   - Protocol checking (HTTP/HTTPS only, SOCKS5 not supported)
   - Domain/IP detection
   - Port validation

2. **Credential Storage**
   - Secure file storage with chmod 600
   - Git exclusion (.gitignore)
   - Persistent across sessions

3. **Domain Resolution**
   - Automatic domain-to-IP conversion for HTTP proxies
   - Domain preservation for HTTPS proxies (OAuth compatibility)
   - Fallback chain: getent → host → dig → nslookup

4. **Environment Configuration**
   - HTTPS_PROXY and HTTP_PROXY export
   - NO_PROXY bypass list
   - TLS certificate support (NODE_EXTRA_CA_CERTS)

## Example Usage

### Validate Proxy URL

```bash
# Valid HTTP proxy with IP
validate_proxy_url "http://192.168.1.100:8118"
# Returns: 0 (success)

# Valid HTTPS proxy with domain (warning shown, but continues)
validate_proxy_url "https://proxy.example.com:8118"
# Returns: 2 (warning)

# Invalid SOCKS5 proxy
validate_proxy_url "socks5://proxy:1080"
# Returns: 1 (error)
```

### Save Proxy Credentials

```bash
# Save HTTP proxy with credentials
save_credentials "http://user:pass@192.168.1.100:8118"

# Save HTTPS proxy (domain preserved)
save_credentials "https://user:pass@proxy.example.com:8118"

# Result: Creates .claude_proxy_credentials with chmod 600
```

### Load Proxy Credentials

```bash
# Load saved credentials and configure environment
load_credentials

# Exports:
# - HTTPS_PROXY="https://user:pass@proxy.example.com:8118"
# - HTTP_PROXY="https://user:pass@proxy.example.com:8118"
# - NO_PROXY="localhost,127.0.0.1,github.com,..."
```

### Configure Proxy from URL

```bash
# Configure proxy with domain resolution (HTTP)
configure_proxy_from_url "http://proxy.example.com:8118"
# Prompts user: Convert domain to IP? [y/N]
# If yes: resolves domain → saves as IP
# If no: saves as-is

# Configure HTTPS proxy (domain ALWAYS preserved)
configure_proxy_from_url "https://proxy.example.com:8118"
# Domain is preserved (required for OAuth and TLS)
```

## Workflow Example

### Initial Setup with HTTP Proxy

```bash
# Step 1: User provides proxy URL
./iclaude.sh --proxy http://myproxy.local:8118

# Step 2: Validate URL
validate_proxy_url "http://myproxy.local:8118"
# Returns: 2 (domain warning)

# Step 3: Offer domain resolution
echo "Proxy URL contains domain name. Convert to IP? [y/N]"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
  resolved_ip=$(resolve_domain_to_ip "myproxy.local")
  # Result: "192.168.1.100"
  proxy_url="http://192.168.1.100:8118"
fi

# Step 4: Save credentials
save_credentials "$proxy_url"

# Step 5: Configure environment
load_credentials
# Exports HTTPS_PROXY, HTTP_PROXY, NO_PROXY
```

### Using HTTPS Proxy (OAuth Compatible)

```bash
# HTTPS proxy with authentication
./iclaude.sh --proxy https://user:pass@proxy.company.com:8118

# Domain is PRESERVED (not converted to IP)
# Reason: OAuth token refresh requires correct Host header
# Result: HTTPS_PROXY="https://user:pass@proxy.company.com:8118"
```

## Integration with Other Components

### OAuth Token Management Integration

```bash
# OAuth token refresh through HTTPS proxy
# Component: OAuth Token Management (iclaude.sh:2749-2874)

# 1. Load proxy credentials
load_credentials
# Exports: HTTPS_PROXY="https://proxy:8118"

# 2. Attempt token refresh
refresh_oauth_token
# Uses proxy for API calls to api.anthropic.com
# Domain-based proxy required (Host header validation)
```

### Router Integration

```bash
# Router API calls through proxy
# Component: Router Management (iclaude.sh:324-379)

# 1. Configure proxy
load_credentials

# 2. Launch via router
USE_ROUTER_FLAG=true
ccr code
# Router inherits HTTPS_PROXY environment variable
# Works for both Claude API and provider API (DeepSeek, OpenRouter, etc.)
```

## Files Created

```
.claude_proxy_credentials           # Proxy credentials (chmod 600)
  Format:
  PROXY_URL=https://user:pass@proxy:8118
  PROXY_CONFIGURED=1
  DEBUG_STATUSLINE=1                # Optional
```

## Environment Variables

```bash
HTTPS_PROXY="https://user:pass@proxy:8118"
HTTP_PROXY="https://user:pass@proxy:8118"
NO_PROXY="localhost,127.0.0.1,github.com,*.github.com,anthropic.com,*.anthropic.com"
NODE_EXTRA_CA_CERTS="/path/to/proxy-cert.pem"  # Optional
```

## Security Considerations

1. **Credential File Permissions**
   - Always chmod 600 (owner read/write only)
   - Never commit to git (.gitignore entry)

2. **Password Display**
   - Hidden by default (replaced with ****)
   - Use `--show-password` flag for debugging

3. **HTTPS Proxy MitM Risk**
   - undici ProxyAgent doesn't verify target TLS certs
   - Only use trusted proxy servers
   - Prefer `--proxy-ca` over `--proxy-insecure`

4. **Domain Preservation**
   - HTTPS proxies MUST preserve domains (OAuth requirement)
   - HTTP proxies can optionally convert to IP

## Troubleshooting

### Domain Resolution Fails

```bash
# If all resolution methods fail
resolve_domain_to_ip "proxy.example.com"
# Returns: empty string

# Fallback: Use domain as-is (may cause issues with HTTP proxy)
# Solution: Switch to HTTPS proxy or use IP directly
```

### SOCKS5 Not Supported

```bash
# Error: SOCKS5 causes crash
InvalidArgumentError: Invalid URL protocol: the URL must start with `http:` or `https:`

# Solution: Use Privoxy or Squid to convert SOCKS5 → HTTPS
ssh -D 1080 user@proxy-server
privoxy /etc/privoxy/config  # Configure SOCKS5→HTTP conversion
./iclaude.sh --proxy http://localhost:8118
```

### OAuth Fails with IP-based Proxy

```bash
# Symptom: Token refresh fails
# Cause: Using IP instead of domain for HTTPS proxy

# Wrong:
./iclaude.sh --proxy https://192.168.1.100:8118

# Correct:
./iclaude.sh --proxy https://proxy.company.com:8118
```

## Testing

```bash
# Test proxy without launching Claude Code
./iclaude.sh --test

# Test with password visible
./iclaude.sh --proxy https://proxy:8118 --test --show-password

# Verify environment variables
./iclaude.sh --proxy https://proxy:8118 --test
env | grep -E "(HTTPS_PROXY|HTTP_PROXY|NO_PROXY)"
```

## Related Components

- **OAuth Token Management** - Uses proxy for token refresh API calls
- **Router Management** - Inherits proxy settings for provider APIs
- **Isolated Environment** - Proxy configured in isolated shell environment

## References

- Main implementation: iclaude.sh:1343-1666
- Test function: `test_proxy_connection()` - iclaude.sh:~1600
- Validation: `validate_proxy_url()` - iclaude.sh:56
- Resolution: `resolve_domain_to_ip()` - iclaude.sh:110
