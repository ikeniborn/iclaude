# PII Proxy

## Overview

A loopback-only HTTP proxy (`lib/pii-proxy/server.py`) that intercepts `POST /v1/messages` before it reaches Anthropic, masks PII and secrets in user-authored content with a configurable token, re-injects trusted credentials, then forwards upstream. Covers masking levels, Presidio NLP, regex secrets, SSE streaming, the worker supervisor, HTTP control endpoints, detection, installation, and status.

## Architecture

The server runs as a `ThreadingHTTPServer` bound to `127.0.0.1` on a dynamic port (range `PII_PROXY_PORT_MIN`–`PII_PROXY_PORT_MAX`, default 20000–40000; `_build_server()` tries an explicit port, then up to 30 random candidates, then OS-assigned). The launcher redirects Claude Code's `ANTHROPIC_BASE_URL` to the proxy, which forwards the masked request to `ANTHROPIC_UPSTREAM_URL` (default Anthropic API, validated to `https://` or `http://localhost` only to prevent SSRF).

In combined mode the upstream is a CCR instance, so traffic flows Claude → PII proxy → CCR → providers. See [[router#Combined Mode: PII Proxy + Router]] and [[launcher]] for how the upstream is chained.

Per-session port files are written to `PII_PROXY_LOG_DIR` as `pii-proxy-<ICLAUDE_SESSION_ID>.port` (session id is a 12-char hex, `shared`, or `default`). Concurrent sessions each run their own instance; a child session can also inherit the parent's `ANTHROPIC_BASE_URL` and reuse its proxy. When `USE_LANGFUSE_CAPTURE` is set the proxy also tees each relayed `/v1/messages` response to self-hosted Langfuse — see [[langfuse-capture]]. PII masking also composes with the [[sandbox]] microVM.

## Supervisor

A supervisor process (`_supervise()`) binds the listening socket once, then forks a worker child to serve requests on the inherited socket. If the worker dies (OOM, crash, signal) the supervisor re-forks it on the same port, so a running Claude session — which baked `ANTHROPIC_BASE_URL` at launch — never hits `ConnectionRefused`. A restart-storm guard gives up after more than 5 restarts within 10 seconds. Controlled by `PII_PROXY_SUPERVISE` (default `true`); when `false`, `_run_worker()` serves directly without a supervisor.

## Masking Levels

Three masking levels are controlled by `PII_PROXY_MASKING_LEVEL`:

| Level | Behavior |
|---|---|
| `off` | No masking; raw body forwarded unchanged (proxy still runs for credential injection) |
| `secrets` | Regex-only: API keys, tokens, passwords, credit cards, PEM keys, URL credentials |
| `standard` | Presidio NLP + regex (default); falls back to regex when Presidio is unavailable |

The replacement token for every detected span is `PII_PROXY_MASK_TOKEN` (default `REDACTED`), applied at both `secrets` and `standard` levels. Setting it to an empty string enables deletion mode: the span is removed while structural context (assignment operator, quotes, URL scheme) is preserved so the regex keeps anchoring.

## Regex Patterns

`REDACT_PATTERNS` in `server.py` covers deterministic secrets at the `secrets` and `standard` levels (ported from the [[security-hooks]] `redact-secrets.py`):

- Anthropic/OpenAI/Stripe API keys (`sk-ant-...`, `sk-proj-...`, `sk-or-v1-...`)
- AWS Access Key IDs (`AKIA...`) and Secret Access Keys
- PEM private key blocks
- GitHub tokens (`ghp_`/`ghs_`/`ghu_`/`ghr_`) and fine-grained PATs (`github_pat_`)
- HuggingFace (`hf_`), Groq (`gsk_`), Google AI Studio (`AIzaSy...`) tokens
- Credentials in URLs (`scheme://MASKING@host`)
- Passwords in config files (`password = "..."`)
- Generic `secret`/`api_key`/`access_token` assignments
- JWT tokens (`eyJ...`)
- Credit card numbers (Visa, MasterCard, Amex patterns)
- `.env`-style secret variable assignments (value ≥ 20 chars)

## NLP Engine (Presidio)

In `standard` mode, `init_presidio()` lazy-initializes `presidio_analyzer.AnalyzerEngine` with spaCy models on a background thread at worker startup. It is thread-safe (`_presidio_lock`); once `_presidio_failed` is set on permanent import failure, the lock is never acquired again and regex fallback activates automatically (when `PII_PROXY_ENABLE_FALLBACK` is on).

The NLP entity allowlist is restricted to pattern-based recognizers with low false-positive rates: `EMAIL_ADDRESS`, `PHONE_NUMBER`, `CREDIT_CARD`, `IBAN_CODE`, `IP_ADDRESS`, `URL`, analyzed at `score_threshold=0.8`. NER-based types (`PERSON`, `LOCATION`, `ORGANIZATION`, `DATE_TIME`) are excluded because spaCy NER misclassifies common Russian/Cyrillic words and project names as person names. Only the English model is used for analysis even when Russian is installed (Russian NER adds the same false positives without new pattern recognizers). A static `_PERSON_ALLOWLIST` (`Claude`/`claude`/`CLAUDE`) filters residual false positives, and regex patterns are always applied on top of Presidio output.

## Masking Scope (Asymmetric Design)

`mask_request_body()` applies masking asymmetrically by role:

| Field | Action |
|---|---|
| `system` | Skipped — contains Claude Code harness instructions; masking breaks the session |
| `messages[role=user]` | Fully masked: text content, `tool_result` blocks, `document` source/context |
| `messages[role=assistant]` text blocks | Skipped — Claude's own prose carries no original user PII |
| `messages[role=assistant]` `tool_use` input | Masked — `new_string`, `content`, etc. may contain user-authored text verbatim |

Tool input keys that are structural pointers — `file_path`, `path`, `notebook_path`, `command`, `pattern`, `glob` — are skipped via `_TOOL_INPUT_SKIP_KEYS` to avoid corrupting filesystem paths that NLP flags as person names. `<system-reminder>` blocks injected by the harness are passed through unchanged in all modes (`_SYSTEM_REMINDER_RE` split). Response bodies from Anthropic are forwarded unmasked — they originate from the model, not user input.

## SSE Streaming

`_forward()` streams responses back with `requests` (stream=True) and branches on `Content-Type`. For `text/event-stream`, the status line and headers are sent before the first chunk, then chunks are relayed with `iter_content(4096)` and flushed; once the 200 is committed a mid-stream upstream error can only end the stream (client keeps partial output), never become a 502. Non-streaming responses are fully buffered first, so a read error before the status line still yields a clean 502. Hop-by-hop and recomputed headers (`transfer-encoding`, `connection`, `content-encoding`, `content-length`) are stripped/recalculated. `requests` is used (not stdlib `urllib`) because urllib cannot TLS-handshake to an `HTTPS_PROXY`.

## Credential Injection

`_build_upstream_headers()` strips connection/hop-by-hop headers unconditionally. In API-key mode (`ANTHROPIC_API_KEY` set in the proxy's own environment) it also strips inbound `authorization`/`x-api-key` and re-injects the trusted env key — preventing credential relay, where a rogue local process routes calls through the proxy with stolen credentials. In OAuth mode (no env key) auth headers are forwarded as-is, since stripping would break requests. Connect-only retry (`connect=2`, `read=0`, `status=0`) makes connection establishment robust without ever retrying after a partial response (no duplicate generation or double billing on the non-idempotent POST).

## HTTP Control Endpoints

Beyond proxying, the server answers a few local control endpoints:

- `GET /api/health` — readiness JSON (`analyzer_ready`, `supported_languages`, `masking_level`, `log_level`); `HEAD` variant returns headers only.
- `GET /api/metrics` — live masking metrics (`masked_items_total`, `uptime_seconds`, `masking_level`, `analyzer_ready`) for [[statusline]] integration.
- `GET /api/meta` — startup metadata (session id, pwd, upstream URL, started_at).

All other methods/paths (`PUT`, `PATCH`, `DELETE`, `OPTIONS`, non-`/v1/messages`) are forwarded upstream unmasked via `_proxy_passthrough()`.

## Detection

`detect_pii_proxy()` in `lib/pii-proxy/detect.sh` checks:

1. Isolated environment (`ISOLATED_NVM_DIR`) is present.
2. `PII_PROXY_SERVER_SCRIPT` file exists (symlink into the isolated config dir).
3. `PII_PROXY_VENV` directory exists.
4. Python ≥ 3.8 is executable at `$PII_PROXY_VENV/bin/python3`.

`get_pii_proxy_python()` returns the venv interpreter path. System Python is not used: it has no Presidio installation.

## Installation

`install_isolated_pii_proxy()` in `lib/pii-proxy/install.sh` creates a Python venv (`PII_PROXY_VENV`), upgrades pip, then runs a cascading install with a live progress bar (driven by site-packages size growth):

1. **Level 1 (presidio-full):** `presidio-analyzer presidio-anonymizer spacy` — full NLP, ~450 MB.
2. **Level 2 (presidio-legacy):** Same packages pinned `spacy>=3.6,<3.8` — uses pre-built `blis` wheels for systems where the C extension fails to compile (common on ALT Linux without `gcc-c++`; the installer detects ALT Linux and prints a `gcc-c++` hint).
3. **Level 3 (regex-only):** `requests` only — no NLP; only regex patterns apply.

The chosen mode is written to `$PII_PROXY_VENV/pii_proxy_mode`. In NLP modes `_pii_proxy_download_model()` downloads spaCy models: `en_core_web_lg` (~560 MB) falling back to `en_core_web_sm`, and `ru_core_news_lg` (~500 MB) falling back to `ru_core_news_sm`; on reinstall it upgrades only when a newer version exists. Model names are stored in `$PII_PROXY_VENV/spacy_model_en` and `spacy_model_ru`. `_pii_proxy_install_server()` symlinks `server.py` (and its sibling `langfuse_emitter.py`) into the isolated config dir as `PII_PROXY_SERVER_SCRIPT`. Pip and `spacy download` honor `HTTPS_PROXY`/`HTTP_PROXY`.

**Install command:**
```bash
./iclaude.sh --install-pii-proxy
```

Enable with `ICLAUDE_USE_PII_PROXY=true` in `.claude_config`, or per-launch with `./iclaude.sh --pii-proxy` (the flag overrides the config). See [[launcher]] for startup wiring and [[config]].

## Status

`check_pii_proxy_status()` in `lib/pii-proxy/status.sh` reports:

- Python version and server-script path
- Venv path and size
- Installed mode (`presidio-full`, `presidio-legacy`, `regex-only`, or an `import presidio_analyzer` fallback test)
- spaCy models (EN and RU), flagging `_sm` models as reduced accuracy
- Log directory size and last error line from `access.log`
- Shared proxy PID/port plus its consumer PIDs, and per-session proxy PIDs (new `PII_PROXY_PID_DIR` layout and legacy layout, deduplicated; orphan PID/port files are swept)
- Effective `.claude_config` values (`USE_PII_PROXY`, masking level, log level, port, fallback)

**Status command:**
```bash
./iclaude.sh --check-pii-proxy
```

## Configuration Variables

| Variable | Default | Purpose |
|---|---|---|
| `ICLAUDE_USE_PII_PROXY` | `false` | Enable PII proxy from `.claude_config` (`--pii-proxy` overrides) |
| `ANTHROPIC_UPSTREAM_URL` | Anthropic API | Upstream the proxy forwards to (https or http://localhost) |
| `PII_PROXY_PORT` | `0` (auto) | Fixed port; `0` = pick from range |
| `PII_PROXY_PORT_MIN` / `PII_PROXY_PORT_MAX` | `20000` / `40000` | Auto-port range |
| `PII_PROXY_MASKING_LEVEL` | `standard` | `off` / `secrets` / `standard` |
| `PII_PROXY_MASK_TOKEN` | `REDACTED` | Replacement string; empty = delete span |
| `PII_PROXY_LOG_LEVEL` | `info` | `info` (count only) / `debug` (entity types; auto-deleted on exit) |
| `PII_PROXY_ENABLE_FALLBACK` | `true` | Use regex when Presidio unavailable |
| `PII_PROXY_CONNECT_TIMEOUT` | `10` | TCP connect timeout to upstream (seconds) |
| `PII_PROXY_READ_TIMEOUT` | `300` | Response read timeout (seconds) |
| `PII_PROXY_SUPERVISE` | `true` | Respawn worker on crash |
| `ICLAUDE_SESSION_ID` | — | 12-char hex; scopes port files per session |

The proxy respects `HTTPS_PROXY`/`HTTP_PROXY` for upstream connections. SSL verification reads `REQUESTS_CA_BUNDLE` or `NODE_EXTRA_CA_CERTS`; set `NODE_TLS_REJECT_UNAUTHORIZED=0` to disable verification. See [[proxy#TLS Certificate Handling]] for CA cert configuration.
