# Proxy

HTTPS/HTTP proxy configuration for Claude Code API traffic. Configured via `PROXY_URL` in `.claude_config` or via `--proxy URL` flag. Applies `HTTPS_PROXY`, `HTTP_PROXY`, `NO_PROXY` to the environment before `launch_claude()`.

## Configuration

`[[lib/proxy/configure.sh#configure_proxy_from_url]]` sets env vars and TLS handling:

1. Loads saved credentials from `.claude_config` (skips re-save if URL unchanged)
2. Exports `HTTPS_PROXY`, `HTTP_PROXY`, `NO_PROXY`
3. Configures TLS — prefers `NODE_EXTRA_CA_CERTS` (CA cert), falls back to `NODE_TLS_REJECT_UNAUTHORIZED=0` (insecure)
4. Calls `configure_git_no_proxy` to set git proxy bypass

## TLS Modes

| Variable | Mode | Notes |
|----------|------|-------|
| `PROXY_CA=/path/ca.crt` | Secure (CA cert) | Recommended for corporate MITM proxies |
| `PROXY_INSECURE=true` | Insecure (skip verify) | Default when no CA cert provided |

**Warning:** `undici` (Node.js HTTP client) does not verify target server certificates when proxying HTTPS — see [HackerOne #1583680](https://hackerone.com/reports/1583680).

## Default NO_PROXY

`localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org`

## Credentials File

`.claude_config` (chmod 600, never committed to git). Template: `.claude_config.example`.

Key fields read by proxy module:
- `PROXY_URL` — full proxy URL including scheme
- `PROXY_CA` — path to CA certificate
- `PROXY_INSECURE` — `"true"` to disable TLS verification
