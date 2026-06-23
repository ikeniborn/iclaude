# Langfuse Non-Router Capture

## Overview

Tees each Claude Code `POST /v1/messages` call (full prompt + completion) on the non-router path and emits it to self-hosted Langfuse as a `project:<repo>`-tagged trace. Both request and completion are always secrets-scrubbed before leaving. It rides the [[pii-proxy]] as a passive observer, enabled by the `USE_LANGFUSE_CAPTURE` toggle.

## Architecture

The capture path is a "Langfuse observer" layered onto the existing [[pii-proxy#Architecture]] MITM. After the proxy relays a `/v1/messages` response to the client, the `_forward` handler in `lib/pii-proxy/server.py` tees the response bytes (both SSE and buffered branches, accumulation capped at `MAX_CAPTURE_BYTES`) and hands the request+response to the emitter. The client byte stream is never altered — the tee is purely passive. In `--router` mode capture is skipped because LiteLLM already emits to Langfuse there (avoids double traces). See [[router#Per-Project Tagging (X-Project-Id → Langfuse)]] and [[router#Combined Mode: PII Proxy + Router]].

## Emitter Module

`lib/pii-proxy/langfuse_emitter.py` is a standalone, dependency-injected module so it can be unit-tested in isolation (`tests/test_langfuse_emitter.py`). It is the canonical source; `lib/pii-proxy/install.sh` symlinks it beside `server.py` in the isolated config dir, so the proxy resolves `import langfuse_emitter` at runtime (Python sets `sys.path[0]` to the executed script's real directory). Pure helpers — `parse_request`, `parse_response` (SSE + JSON), `build_payload`, `_deep_scrub` — are stdlib-only; emission (`post_batch`, `_emit`, `capture`) uses the `requests` library vendored in the PII-proxy venv.

## Request & Response Parsing

`parse_request` pulls `model`, `system`, `messages`, and `max_tokens` from the Anthropic request body. `parse_response` dispatches on `is_streaming`: `_parse_sse` reassembles `text_delta`/`thinking_delta` fragments and reads usage from `message_start`/`message_delta` events; `_parse_json` concatenates `text`/`thinking` content blocks and reads the `usage` object. Both yield a flat dict (`output`, `thinking`, `model`, token counts, `stop_reason`). Either parser fails soft to empty defaults on malformed bytes. Bodies over `MAX_CAPTURE_BYTES` (10 MB) are truncated and flagged `truncated: true`.

## Always-On Secret Scrubbing

The emitter scrubs credentials from BOTH the request and the completion before they reach Langfuse, regardless of the upstream masking level. The proxy injects `scrub = lambda t: regex_mask(t)[0]` — the same secrets regex used by [[pii-proxy#Regex Patterns]] — and `_deep_scrub` applies it recursively to every string value in the request (string content, text blocks, `tool_use.input`, nested `tool_result.content`, and system-as-list with `cache_control`); dict keys are left intact as structural. `scrub` is applied directly to the completion `output` and `thinking`. This is why capture is safe even in capture-only sessions where masking is `off`.

## Ingestion Payload

`build_payload` builds a Langfuse `/api/public/ingestion` batch of two events. The `trace-create` (name `claude-code`) carries `sessionId`, `tags: ["project:<repo>"]`, and metadata `{pwd, upstream_masking_level, langfuse_scrubbed: true}`. The `generation-create` (name `messages`) carries the resolved model, scrubbed `input.system`/`input.messages`, scrubbed `output`, `usage = {input, output, total=input+output}`, `startTime`/`endTime`, and metadata holding `stop_reason`, scrubbed `thinking`, `max_tokens`, both cache-token counts, and the `truncated` flag. Event/trace/generation IDs are UUIDv4; timestamps are UTC ISO-8601. `post_batch` POSTs it with HTTP Basic auth (`base64(public_key:secret_key)`).

## Fail-Soft & Non-Blocking

`capture()` spawns a daemon thread and returns immediately (or `None` if the thread cannot be spawned), so the proxied request is never delayed. Every layer is fail-soft: the module import is guarded (capture disables if `langfuse_emitter` is unimportable), `post_batch` returns `False` on any error instead of raising, `_emit` swallows all exceptions, and the proxy's capture call site is wrapped so even inline `_meta` construction (`os.getcwd()` can raise on a deleted cwd) cannot trigger a spurious `502` on an already-completed response. A bounded `POST_TIMEOUT` of `(5, 5)` seconds prevents a Langfuse outage from leaking threads. End-to-end behaviour is covered by `tests/test_langfuse_capture_e2e.py`.

## Activation

The launcher (`lib/launcher/launch.sh`) reads `USE_LANGFUSE_CAPTURE` from `.claude_config`. `_should_capture` gates capture on `USE_LANGFUSE_CAPTURE=true` AND non-router mode (router sessions are skipped to avoid double traces; the exclusion is enforced here, never re-checked in `server.py`). `_should_start_proxy` starts the PII proxy when masking OR capture is requested; `_proxy_masking_default` forces `PII_PROXY_MASKING_LEVEL=off` for capture-only sessions (no `--pii-proxy`, no explicit level), so the proxy runs purely as the auth + capture hop. `_init_project_id` exports `ICLAUDE_PROJECT_ID` (the tag-safe repo slug from `_derive_project_id`, shared with the [[router#Per-Project Tagging (X-Project-Id → Langfuse)]] transformer) in router OR capture mode. Capture is disabled in `--system` mode (no isolated venv) — the launcher aborts if the proxy is requested there. See [[launcher#PII Proxy Start]].

## Configuration Variables

| Variable | Default | Purpose |
|---|---|---|
| `USE_LANGFUSE_CAPTURE` | `false` | Enable non-router capture (starts the PII proxy as the capture hop) |
| `LANGFUSE_HOST` | — | Self-hosted Langfuse base URL (e.g. `https://langfuse.example`) |
| `LANGFUSE_PUBLIC_KEY` | — | Langfuse public key (Basic-auth username) |
| `LANGFUSE_SECRET_KEY` | — | Langfuse secret key (Basic-auth password) — keep `.claude_config` at chmod 600 |
| `ICLAUDE_PROJECT_ID` | derived | Tag-safe repo slug; trace tag is `project:<id>` (falls back to `unknown`) |

If `USE_LANGFUSE_CAPTURE=true` but any of `LANGFUSE_HOST`/`LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY` is missing, `server.py` logs a warning and disables capture (fail-soft). See [[pii-proxy#Configuration Variables]] for the shared proxy settings and [[telemetry]] for the broader observability picture.
