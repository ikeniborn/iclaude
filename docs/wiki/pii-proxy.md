# PII Proxy

## Overview

A local HTTP proxy (`lib/pii-proxy/server.py`) that intercepts `POST /v1/messages` requests before they reach the Anthropic API, scans user-authored content for PII and secrets, replaces detected spans with a configurable token (`REDACTED` by default), then forwards the masked request upstream. Operates on `127.0.0.1` only and supports SSE streaming responses.

## Architecture

The server runs as a `ThreadingHTTPServer` bound to `127.0.0.1` on a dynamic port (range `PII_PROXY_PORT_MIN`–`PII_PROXY_PORT_MAX`, default 20000–40000). Claude Code's `ANTHROPIC_BASE_URL` is redirected to the proxy's local address. The proxy forwards the masked request to `ANTHROPIC_UPSTREAM_URL`, which defaults to the Anthropic API but can be set to a CCR instance for combined routing. See [[router#Combined Mode: PII Proxy + Router]] for that topology.

When `USE_LANGFUSE_CAPTURE` is set, the proxy also acts as a passive capture hop: it tees each relayed `/v1/messages` response and emits a secrets-scrubbed trace to self-hosted Langfuse. See [[langfuse-capture]].

A supervisor process forks a worker child to serve requests. If the worker dies (OOM, crash, signal), the supervisor re-forks it on the same port so the running Claude Code session never encounters a `ConnectionRefused`. The supervisor gives up after more than 5 restarts within 10 seconds. This behavior is controlled by `PII_PROXY_SUPERVISE` (default `true`).

Per-session port files are written to `PII_PROXY_LOG_DIR` as `pii-proxy-<ICLAUDE_SESSION_ID>.port`. Multiple concurrent sessions each run their own proxy instance on distinct ports.

## Masking Levels

Three masking levels are controlled by `PII_PROXY_MASKING_LEVEL`:

| Level | Behavior |
|---|---|
| `off` | No masking; content forwarded unchanged (proxy still runs for credential injection) |
| `secrets` | Regex-only: API keys, tokens, passwords, credit cards, PEM keys, URL credentials |
| `standard` | Presidio NLP + regex (default); falls back to regex when Presidio is unavailable |

The replacement token for every detected span is `PII_PROXY_MASK_TOKEN` (default `REDACTED`). Setting it to an empty string enables deletion mode: the span is removed while any structural prefix (assignment operator, quotes, URL scheme) is preserved.

## Regex Patterns

`REDACT_PATTERNS` in `server.py` covers deterministic secrets regardless of masking level:

- Anthropic/OpenAI/Stripe API keys (`sk-ant-...`, `sk-proj-...`, `sk-or-v1-...`)
- AWS Access Key IDs (`AKIA...`) and Secret Access Keys
- PEM private key blocks
- GitHub tokens (`ghp_`, `ghs_`, `ghu_`, `ghr_`, `github_pat_`)
- HuggingFace (`hf_`), Groq (`gsk_`), Google AI Studio (`AIzaSy...`) tokens
- Credentials in URLs (`scheme://user:pass@host`)
- Passwords in config files (`password = "..."`)
- Generic `secret`/`api_key`/`access_token` assignments
- JWT tokens (`eyJ...`)
- Credit card numbers (Visa, MasterCard, Amex patterns)
- `.env`-style secret variable assignments (value ≥ 20 chars)

## NLP Engine (Presidio)

In `standard` mode, `init_presidio()` lazy-initializes `presidio_analyzer.AnalyzerEngine` with spaCy models. Initialization runs in a background thread on startup. The NLP entity allowlist is restricted to pattern-based recognizers with low false-positive rates:

- `EMAIL_ADDRESS`, `PHONE_NUMBER`, `CREDIT_CARD`, `IBAN_CODE`, `IP_ADDRESS`, `URL`

NER-based types (`PERSON`, `LOCATION`, `ORGANIZATION`, `DATE_TIME`) are excluded because spaCy NER incorrectly classifies common Russian words and project names as person names. A static `_PERSON_ALLOWLIST` (containing `Claude`, `claude`, `CLAUDE`) further filters false positives. `<system-reminder>` blocks injected by the Claude Code harness are passed through unchanged in all modes to prevent masking harness instructions.

Once `_presidio_failed` is set (permanent import failure), the lock is never acquired again and regex fallback activates automatically.

## Masking Scope (Asymmetric Design)

`mask_request_body()` applies masking asymmetrically:

| Field | Action |
|---|---|
| `system` | Skipped — contains Claude Code harness instructions; masking breaks the session |
| `messages[role=user]` | Fully masked: text content + `tool_result` blocks (file contents read by tools) |
| `messages[role=assistant]` text blocks | Skipped — Claude's own prose carries no original user PII |
| `messages[role=assistant]` `tool_use` input | Masked — `new_string`, `content`, etc. may contain user-authored text verbatim |

Tool input keys that are structural pointers — `file_path`, `path`, `notebook_path`, `command`, `pattern`, `glob` — are skipped via `_TOOL_INPUT_SKIP_KEYS` to avoid corrupting filesystem paths that NLP incorrectly flags as person names.

Response bodies from Anthropic are forwarded unmasked: they originate from the model, not from user input, and contain no original PII.

## Detection

`detect_pii_proxy()` in `lib/pii-proxy/detect.sh` checks:

1. Isolated environment (`ISOLATED_NVM_DIR`) is present.
2. `PII_PROXY_SERVER_SCRIPT` file exists (symlink into the isolated config dir).
3. `PII_PROXY_VENV` directory exists.
4. Python ≥ 3.8 is executable at `$PII_PROXY_VENV/bin/python3`.

`get_pii_proxy_python()` returns the venv interpreter path. System Python is not used: it has no Presidio installation.

## Installation

`install_isolated_pii_proxy()` in `lib/pii-proxy/install.sh` runs a cascading installation:

1. **Level 1 (presidio-full):** `presidio-analyzer presidio-anonymizer spacy` — full NLP, ~450 MB.
2. **Level 2 (presidio-legacy):** Same packages with `spacy>=3.6,<3.8` — uses pre-built `blis` wheels for systems where the C extension fails to compile (common on ALT Linux without `gcc-c++`).
3. **Level 3 (regex-only):** `requests` only — no NLP; only regex patterns are applied.

The installed mode is written to `$PII_PROXY_VENV/pii_proxy_mode`.

When NLP mode is active, `_pii_proxy_download_model()` downloads spaCy models: `en_core_web_lg` (English, ~560 MB) falling back to `en_core_web_sm` (~15 MB), and `ru_core_news_lg` (Russian, ~500 MB) falling back to `ru_core_news_sm` (~15 MB). The chosen model name is stored in `$PII_PROXY_VENV/spacy_model_en` and `spacy_model_ru`.

`_pii_proxy_install_server()` symlinks `lib/pii-proxy/server.py` into the isolated config dir as `PII_PROXY_SERVER_SCRIPT`.

**Install command:**
```bash
./iclaude.sh --install-pii-proxy
```

## Status

`check_pii_proxy_status()` in `lib/pii-proxy/status.sh` reports:

- Python version
- Server script path
- Venv path and size
- Installed mode (`presidio-full`, `presidio-legacy`, `regex-only`, or import-test fallback)
- spaCy models (EN and RU), flagging `_sm` models as reduced accuracy
- Log directory and last error line from `access.log`
- Shared proxy PID/port and per-session proxy PIDs

**Status command:**
```bash
./iclaude.sh --check-pii-proxy
```

## Configuration Variables

| Variable | Default | Purpose |
|---|---|---|
| `ANTHROPIC_UPSTREAM_URL` | Anthropic API | Upstream the proxy forwards to |
| `PII_PROXY_PORT` | `0` (auto) | Fixed port; `0` = pick randomly from range |
| `PII_PROXY_PORT_MIN` / `PII_PROXY_PORT_MAX` | `20000` / `40000` | Auto-port range |
| `PII_PROXY_MASKING_LEVEL` | `standard` | `off` / `secrets` / `standard` |
| `PII_PROXY_MASK_TOKEN` | `REDACTED` | Replacement string; empty = delete span |
| `PII_PROXY_LOG_LEVEL` | `info` | `info` (count only) / `debug` (entity types; auto-deleted on exit) |
| `PII_PROXY_ENABLE_FALLBACK` | `true` | Use regex when Presidio unavailable |
| `PII_PROXY_CONNECT_TIMEOUT` | `10` | TCP connect timeout to upstream (seconds) |
| `PII_PROXY_READ_TIMEOUT` | `300` | Response read timeout (seconds) |
| `PII_PROXY_SUPERVISE` | `true` | Respawn worker on crash |
| `ICLAUDE_SESSION_ID` | — | 12-char hex; scopes port files per session |

The proxy respects `HTTPS_PROXY`/`HTTP_PROXY` for upstream connections. SSL verification reads `REQUESTS_CA_BUNDLE` or `NODE_EXTRA_CA_CERTS`; set `NODE_TLS_REJECT_UNAUTHORIZED=0` to disable verification. See [[proxy#TLS Certificate Handling]] for CA cert configuration in iclaude.
