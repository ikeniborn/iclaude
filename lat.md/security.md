# Security

Two-layer PreToolUse hook protection for file access and API traffic. Hooks are Python scripts in `.nvm-isolated/.claude-isolated/hooks/` and configured in `settings.json`.

## Layer 1: block-secrets.py

Blocks file read/write operations that target sensitive paths. Returns exit code 2 (tool blocked).

| Pattern | Action |
|---------|--------|
| `.env`, `.pem`, `.key`, `.p12`, `.pfx` | Blocked |
| `.ssh/`, `.gnupg/` | Blocked |
| `.env.example`, `.env.sample` | Allowed (examples safe to read) |
| `.nvm-isolated/.claude-isolated/hooks/` | Allowed (self-exclusion; hooks must read themselves) |

## Layer 2: redact-secrets.py

Redacts secrets from tool input before passing to Claude. Uses `toolInputOverride` to replace content.

| Pattern | Replacement |
|---------|-------------|
| `sk-ant-...`, `sk-proj-...` | `[ANTHROPIC_API_KEY]` |
| `AKIA[0-9A-Z]{16}` | `[AWS_ACCESS_KEY_ID]` |
| `ghp_`, `github_pat_` | `[GITHUB_TOKEN]` |
| `eyJ...` (JWT) | `[JWT_REDACTED]` |
| `scheme://[CREDENTIALS]@host` | `[CREDENTIALS_REDACTED]` |
| `.env` vars (`KEY=value{20+}`) | `[ENV_VAR_REDACTED]` |
| PEM private keys | `[PRIVATE_KEY_REDACTED]` |

**Note:** `Edit.old_string` is NOT redacted — it is a search pattern; masking would break the Edit tool.

## Credentials File

`.claude_config` — chmod 600, excluded from git. Contains proxy URL, API keys, feature flags. Legacy filename `.claude_proxy_credentials` is auto-migrated on first run.

## API Key Types

| Key prefix | Type | Works with CCR |
|-----------|------|----------------|
| `sk-ant-api03-...` | Real API key | Yes |
| `sk-ant-oat01-...` | OAuth token | No — CCR requires real API key |

## Telemetry and Prompt Logging

When `CLAUDE_CODE_ENABLE_TELEMETRY=1`, `lib/telemetry/otel.sh` always exports `OTEL_LOG_USER_PROMPTS=1` — prompts are forwarded to the OTLP endpoint.

Default endpoint: `http://127.0.0.1:4318` (local). If overridden via `OTEL_EXPORTER_OTLP_ENDPOINT` to a remote host, prompts are sent there with no startup warning.

## Test Suite

28 security hook tests: `python3 -m pytest tests/test_patterns_examples.py -v`

Manual block test:
```bash
echo '{"tool_name":"Read","tool_input":{"file_path":"/project/.env"}}' \
  | python3 .nvm-isolated/.claude-isolated/hooks/block-secrets.py; echo "exit: $?"
# Should print "BLOCKED" and exit 2
```
