# Proxy Module

The proxy module lives in `lib/proxy/` and is split across four files: `configure.sh`, `credentials.sh`, `git.sh`, and `validate.sh`. Together they handle proxy URL configuration, credential persistence, TLS certificate policy, git integration, and connectivity testing.

## Configuration Entry Point

`configure_proxy_from_url()` in `lib/proxy/configure.sh` is the single entry point for activating a proxy. It accepts a proxy URL and an optional `NO_PROXY` list, then exports `HTTPS_PROXY`, `HTTP_PROXY`, and `NO_PROXY`. It also sets either `NODE_EXTRA_CA_CERTS` (secure mode, when `PROXY_CA` points to a valid CA certificate file) or `NODE_TLS_REJECT_UNAUTHORIZED=0` (insecure fallback when `PROXY_INSECURE=true`). Before exporting, it compares the given URL against the saved `CREDENTIALS_FILE`; if the URL already matches, it skips `save_credentials()` to preserve any existing `PROXY_CA` or `PROXY_INSECURE` overrides in the file.

The function calls `configure_git_no_proxy()` at the end. That function is intentionally a no-op: git respects `NO_PROXY` from the environment automatically and global git config is no longer modified (doing so broke other tools).

## Credentials File

`lib/proxy/credentials.sh` manages the config file at `.claude_config` (the path is exported as `CREDENTIALS_FILE` by `lib/core/init.sh`). The file is written with `chmod 600` and stores `PROXY_URL`, `NO_PROXY`, `PROXY_CA`, and `PROXY_INSECURE`. The function `save_credentials()` may convert a domain-based host to an IP address before saving, so the stored URL and the final `HTTPS_PROXY`/`HTTP_PROXY` values can differ from the originally supplied URL.

`load_claude_config()` (also in `credentials.sh`) is called by `lib/nvm/setup.sh` during `setup_isolated_nvm()` to apply any saved proxy and Claude-specific environment variables before Claude Code starts.

> Note: `credentials.sh` is blocked from direct read by the `block-secrets.py` security hook because its filename contains "credentials". The logic is inferred from callers and `lib/core/init.sh`.

## URL Validation and Domain Resolution

`lib/proxy/validate.sh` provides three utilities:

- **`validate_proxy_url()`** — checks `http(s)|socks5://[user:pass@]host:port` format, then calls `is_ip_address()`. Returns 0 for valid IP, 1 for invalid format, 2 for valid-but-domain host.
- **`is_ip_address()`** — validates IPv4 format and per-octet range (0–255).
- **`resolve_domain_to_ip()`** — resolves a domain to IPv4 using a fallback chain: `getent` → `host` → `dig` → `nslookup`. Returns the IP on stdout with exit code 0.
- **`parse_proxy_url()`** — splits a proxy URL into `protocol`, `username`, `password`, `host`, `port` as `key=value` lines suitable for `eval`.

Domain-to-IP conversion is applied by `save_credentials()` when the URL contains a domain rather than an IP, ensuring Node.js (which uses `undici`) connects to a stable address.

## TLS Certificate Handling

Two modes are supported, selected by what is stored in `CREDENTIALS_FILE`:

| Variable | Effect |
|----------|--------|
| `PROXY_CA=/path/to/ca.pem` | Sets `NODE_EXTRA_CA_CERTS`; TLS is verified against the custom CA |
| `PROXY_INSECURE=true` (default) | Sets `NODE_TLS_REJECT_UNAUTHORIZED=0`; disables TLS verification |

**Security note:** Even in secure mode (`PROXY_CA`), `undici` does not verify the target server's certificate when tunneling HTTPS through a proxy (see [HackerOne #1583680](https://hackerone.com/reports/1583680)). Prefer `--proxy-ca` over `--proxy-insecure` where possible, and see [[config#Configuration Variables]].

## Connectivity Test

`test_proxy()` in `lib/proxy/configure.sh` sends a `curl` request with `-x "$proxy_url"` to the Anthropic API `/v1/models` endpoint. A `200` or `401` response (401 = no API key, but proxy reached the API) is treated as success. Code `000` means the proxy is unreachable or the connection timed out (15 s). Critically, `HTTPS_PROXY` and `HTTP_PROXY` environment variables are explicitly unset before the `curl` call to avoid proxy-through-proxy double-proxying.

## Git Proxy Backup and Restore

`lib/proxy/git.sh` provides `save_git_proxy_settings()` and `restore_git_proxy()`. These read/write `http.proxy` and `https.proxy` from `git config --global` into `GIT_BACKUP_FILE` (`.claude_git_proxy_backup`, chmod 600). These functions are retained for compatibility with any restore path, but `configure_git_no_proxy()` no longer actually modifies git config — git reads `NO_PROXY` from the environment instead.

## Display

`display_proxy_info()` prints the active `HTTPS_PROXY`, `HTTP_PROXY`, and `NO_PROXY` values. By default passwords are masked via `sed` substitution (`user:****@host`); pass `true` as the first argument to reveal them.

---

See also: [[oauth#OAuth Token Storage]] (tokens travel through the proxy), [[config#Configuration Variables]] (`PROXY_CA`, `PROXY_INSECURE`), [[launcher]] (where `configure_proxy_from_url` is called at startup).
