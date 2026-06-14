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

## Workflow Gate: idd-gate.py

A third PreToolUse hook, but not a secret guard — it gates the IDD→SDD workflow. It intercepts the `Skill` tool and blocks each phase transition until the upstream artifact has passed its validator.

Fail-open: any internal error → exit 0 (the opposite of `block-secrets.py`, which is fail-closed).

| Skill | Upstream artifact | Validator |
|-------|-------------------|-----------|
| `brainstorming` | `intents/*-intent.md` | `/check-intent` |
| `writing-plans` | `specs/*-design.md` | `/check-spec` |
| `executing-plans` / `subagent-driven-development` | `plans/*-plan.md` | `/check-plan` |
| `finishing-a-development-branch` | `plans/*-plan.md` (`result_check`) | `/check-result` |

The gate is **open** when no matching artifact exists (hotfix escape) or when the artifact's state frontmatter passes its predicate:

- `review:` artifacts (intent / spec / plan): matching body hash, all phases `passed`, no open CRITICAL (`severity: CRITICAL` + `verdict: open`).
- `result_check:` artifacts (plan): matching body hash and top-level `verdict: OK`.

Otherwise it blocks (`exit 2`) with a message naming the fix command. The hook validates nothing itself — validation is done by `/check-*` (dispatched to a clean-context subagent), which write the `review:` / `result_check:` frontmatter the gate reads. The body hash is computed by shelling out to the identical bash pipeline the validators use (`awk … | sha256sum | cut -c1-16`), guaranteeing parity. Wired in `settings.json` as a `PreToolUse` entry with `matcher: "Skill"`. Tests: `tests/test-idd-gate.sh` (14 stdin→exit-code cases).

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
