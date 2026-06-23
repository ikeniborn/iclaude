# Proxy Module

## Overview

`lib/proxy/` (`configure.sh`, `credentials.sh`, `git.sh`, `validate.sh`) handles HTTP/HTTPS/SOCKS5 proxy setup for Claude Code: exporting proxy env vars, persisting credentials in `.claude_config`, TLS certificate policy (custom CA vs. insecure), URL validation with domain→IP resolution, git bypass, and connectivity testing.

## Configuration Entry Point

`configure_proxy_from_url()` in `lib/proxy/configure.sh` is the single entry point for activating a proxy. It accepts a proxy URL and an optional `NO_PROXY` list (default: `localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org`), then exports `HTTPS_PROXY`, `HTTP_PROXY`, and `NO_PROXY`. Before exporting it calls `source_iclaude_config` (the [[config#Environment Variable Export]] chokepoint) to load saved settings; if the supplied URL already equals the saved `PROXY_URL`, it skips `save_credentials()` so existing `PROXY_CA`/`PROXY_INSECURE` overrides survive. It finishes by calling `configure_git_no_proxy()`.

## TLS Certificate Handling

After exporting the proxy URLs, `configure_proxy_from_url()` selects one of two TLS modes from the loaded config. If `PROXY_CA` is set and points to an existing file, it exports `NODE_EXTRA_CA_CERTS="$PROXY_CA"` (secure mode, TLS verified against the custom CA). Otherwise, if `PROXY_INSECURE` is unset or `true` (the default), it exports `NODE_TLS_REJECT_UNAUTHORIZED=0`, disabling Node/undici TLS verification.

| Variable | Effect |
|----------|--------|
| `PROXY_CA=/path/to/ca.pem` (file exists) | Sets `NODE_EXTRA_CA_CERTS`; TLS verified against the custom CA |
| `PROXY_INSECURE=true` (default) | Sets `NODE_TLS_REJECT_UNAUTHORIZED=0`; disables TLS verification |

**Security note:** Even in secure mode (`PROXY_CA`), `undici` does not verify the target server's certificate when tunneling HTTPS through a proxy (see [HackerOne #1583680](https://hackerone.com/reports/1583680)). Prefer `--proxy-ca` over `--proxy-insecure` where possible.

## Credentials File

Proxy state is persisted in `.claude_config` (exported as `CREDENTIALS_FILE` by `lib/core/init.sh`), written with `chmod 600` and `.gitignore`-excluded. `lib/proxy/credentials.sh` defines `save_credentials()` (writes `PROXY_URL` + `NO_PROXY`, may convert a domain host to an IP before saving so the stored URL can differ from the input), `load_credentials()`, `clear_credentials()`, and `prompt_proxy_url()` (interactive entry). The file stores variables under the `ICLAUDE_*` prefix (`ICLAUDE_PROXY_URL`, `ICLAUDE_PROXY_CA`, `ICLAUDE_PROXY_INSECURE`, `ICLAUDE_NO_PROXY`); `source_iclaude_config` de-prefixes them to the canonical `PROXY_URL`/`PROXY_CA`/`PROXY_INSECURE`/`NO_PROXY` names that `configure.sh` reads — see [[config#Environment Variable Export]].

> Note: `credentials.sh` is blocked from direct read by the `block-secrets.py` hook (filename contains "credentials"); its function set is verified from callers and grep — see [[security-hooks]].

## Config Loading

Saved proxy/Claude env vars are applied via `load_claude_config()` (defined in `lib/config/isolated.sh`, a thin wrapper over `source_iclaude_config`), invoked by `lib/nvm/setup.sh` during `setup_isolated_nvm()` and by `lib/sandbox/status.sh`. `configure_proxy_from_url()` calls `source_iclaude_config` directly. All paths funnel through the one env-map chokepoint in `lib/config/env-map.sh`, so config is loaded and translated in exactly one place — see [[config]] and [[nvm]].

## URL Validation and Domain Resolution

`lib/proxy/validate.sh` provides the parsing and validation helpers. `validate_proxy_url()` checks the `(http|https|socks5)://[user:pass@]host:port` shape, extracts the host, and returns 0 (valid IP), 1 (invalid format), or 2 (valid but host is a domain). `is_ip_address()` validates IPv4 shape and per-octet 0–255 range. `resolve_domain_to_ip()` resolves a domain to IPv4 via a fallback chain `getent` → `host` → `dig` → `nslookup`, printing the IP on stdout (exit 0 on success). `parse_proxy_url()` splits a URL into `protocol`, `username`, `password`, `host`, `port` as `key=value` lines suitable for `eval`. Domain→IP conversion is applied by `save_credentials()` so undici connects to a stable address.

## Connectivity Test

`test_proxy()` in `lib/proxy/configure.sh` sends a `curl` request via `-x "$proxy_url"` (taken from `HTTPS_PROXY`/`HTTP_PROXY`) to `https://api.anthropic.com/v1/models` with `-k -s -m 15`; for `https://` proxies it also adds `--proxy-insecure`. Any non-`000` HTTP code (e.g. 401 = no API key, but the API was reached) is treated as success; `000` means unreachable or timed out (15 s). Critically, `HTTPS_PROXY`/`HTTP_PROXY`/`https_proxy`/`http_proxy` are cleared inline for the call so curl uses only `-x` and does not proxy-through-proxy. OAuth tokens reaching the API travel this same path — see [[oauth#Token Storage]].

## Git Proxy Backup and Restore

`configure_git_no_proxy()` is intentionally a no-op: git reads `NO_PROXY` from the environment automatically, and global git config is no longer modified (doing so broke other tools). `lib/proxy/git.sh` retains `save_git_proxy_settings()` and `restore_git_proxy()` for compatibility — they back up/restore `http.proxy` and `https.proxy` from `git config --global` via `GIT_BACKUP_FILE` (`.claude_git_proxy_backup`, chmod 600) — but they are not invoked during normal proxy configuration.

## Display

`display_proxy_info()` prints the active `HTTPS_PROXY`, `HTTP_PROXY`, and `NO_PROXY`. By default it masks passwords via `sed` (`user:****@host`); pass `true` as the first argument to reveal them. It also notes that git bypasses the proxy for the `NO_PROXY` hosts.

---

See also: [[config#Environment Variable Export]] (`ICLAUDE_PROXY_*` → de-prefixed canonical vars), [[oauth#Token Storage]] (tokens travel through the proxy), [[launcher]] (where `configure_proxy_from_url` runs at startup), [[router]] (CCR proxy interplay), [[sandbox]] (proxy propagation into the microVM), [[security-hooks]] (`credentials.sh` read block).
