---
review:
  spec_hash: c2466758ed7d2e86
  last_run: 2026-06-21
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: clarity
      severity: WARNING
      section: "R3 — Langfuse emission (REST ingestion API)"
      section_hash: 1b4f9f67fdd66fd0
      text: >-
        generation-create carries usage.total but no requirement defines how
        total is derived. R2 captures input_tokens (+ cache_creation_input_tokens,
        cache_read_input_tokens) and output_tokens, leaving total ambiguous
        (input+output, or including cache tokens?). Specify the derivation rule.
      verdict: fixed
      verdict_at: 2026-06-21
    - id: F-002
      phase: clarity
      severity: INFO
      section: "R3 — Langfuse emission (REST ingestion API)"
      section_hash: 1b4f9f67fdd66fd0
      text: >-
        R3 lists the trace-create / generation-create body fields but not the
        /api/public/ingestion envelope (top-level {batch:[{id,type,timestamp,body}]}).
        Field-level shape is deferred to langfuse_emitter (R7) and asserted by the
        unit test, so this is informational, but the envelope is left implicit.
      verdict: fixed
      verdict_at: 2026-06-21
chain:
  intent: null
---

# Spec: Langfuse Capture of Claude Code LLM Traffic Without the Router

**Version:** 1.0 (design)
**Date:** 2026-06-21
**Status:** design approved; implementation pending
**Owner:** iclaude
**Related:** [[langfuse-project-tagging-spec]] (router-path tagging via `X-Project-Id`), PII proxy (`pii-proxy-server.py`), telemetry (`lib/telemetry/otel.sh`)

---

## 1. Goal

Capture the **full prompt + completion** of each Claude Code LLM call in the **non-router** path and send it to self-hosted Langfuse as a trace, tagged per project (`project:<repo>`). This gives the same prompt/completion visibility in Langfuse that the `--router` path already gets from LiteLLM — but for direct (non-router) sessions, where no LiteLLM exists in the chain.

OTEL telemetry (`lib/telemetry/otel.sh` → Grafana) is unchanged and out of scope: it stays the metrics/events channel; Langfuse becomes the full prompt/completion channel.

## 2. Background — data flow

Non-router path, with the PII proxy active:

```
claude → PII proxy (:PORT, plaintext HTTP) → [HTTPS proxy] → Anthropic API
              │  request: mask observer → langfuse observer (secrets-scrub copy)
              │  response: stream tee → langfuse observer (secrets-scrub copy)
              └─────────────────── async POST ──────────────→ Langfuse /api/public/ingestion
```

- The PII proxy (`pii-proxy-server.py`, `PIIProxyHandler`) is a Python HTTP MITM: claude points `ANTHROPIC_BASE_URL` at it (plaintext), it masks the request, forwards over TLS to the upstream, and relays the response. It is the **only** body-level interception point in the non-router path (without it, claude opens a TLS CONNECT tunnel and bodies are encrypted).
- `_forward(body)` (line ~998) forwards the request with `stream=True`. For Server-Sent-Events responses it streams `iter_content` chunks straight to the client (no buffering); for non-SSE it buffers `resp.content`.
- `ICLAUDE_SESSION_ID` (validated 12-hex or `shared`, else `default`) is available in the worker — used as the Langfuse `sessionId`.

## 3. Architecture (decision: generalized MITM + observers)

One MITM (the existing PII proxy) carries two **independent observers**:

1. **Mask observer** (existing) — `MASKING_LEVEL` controls request masking.
2. **Langfuse observer** (new) — `USE_LANGFUSE_CAPTURE` controls emission.

The two toggles are orthogonal: capture can run with masking off. Enabling capture provisions the local proxy hop itself (the launcher starts the proxy when `USE_LANGFUSE_CAPTURE=true` even if `--pii-proxy` was not requested, defaulting `MASKING_LEVEL=off` in that case).

Rejected alternatives: (A) bolt capture onto the PII proxy but hard-tie it to `--pii-proxy`/masking — less flexible; (B) a separate always-on capture proxy — duplicates the whole MITM transport (TLS forward, SSE relay, supervisor, proxy bypass), two MITMs to maintain.

## 4. Requirements

### R1 — Request capture point (post-PII)

Capture the request body at the point it is forwarded to upstream — i.e. the value passed to `_forward(body)` (the masked body when `MASKING_LEVEL != off`, the raw body when `off`). Parse the Anthropic Messages shape: `model`, `messages[]`, `system`, `max_tokens`, sampling params. The captured copy is then secrets-scrubbed before emission per R2a.

### R2a — Langfuse-copy secrets scrubbing (always)

The Langfuse copy of **both** the request and the completion is **always** secrets-scrubbed via the proxy's existing `regex_mask()` (the secrets patterns: `sk-…`, `Bearer …`, `ghp_`/`github_pat_`, `AKIA…`, JWT, `scheme://creds@host`, …) **before emission, regardless of `MASKING_LEVEL`**. Langfuse therefore never stores credential patterns even when upstream masking is off. This is independent of and additional to upstream masking (which governs only what is forwarded to Anthropic), and it supersedes any "raw when PII off" behaviour for the Langfuse copy. Scope is **secrets** (`regex_mask`); broader Presidio PII masking on the Langfuse copy is inherited from upstream only when `MASKING_LEVEL=standard` (not forced here).

### R2b — Response capture (SSE tee + buffered)

- **SSE** (`text/event-stream`): tee each `iter_content` chunk into an accumulation buffer **while** still writing it to the client (do not delay or alter the client stream). After the stream ends, parse the accumulated SSE:
  - completion text = concatenation of `content_block_delta` deltas where `delta.type == "text_delta"` (`delta.text`); thinking deltas (`thinking_delta`) captured separately into metadata, not the main output.
  - `model`, and `input_tokens` (+ `cache_creation_input_tokens`, `cache_read_input_tokens`) from `message_start`.
  - `output_tokens` and `stop_reason` from `message_delta`.
- **Non-SSE**: parse the buffered `resp.content` JSON (`content[].text`, `usage`, `model`, `stop_reason`).
- The extracted completion text is secrets-scrubbed (R2a) before it is placed in the generation `output`. The scrub applies **only to the Langfuse copy** — the response relayed to the client is never altered.

### R3 — Langfuse emission (REST ingestion API)

- `POST {LANGFUSE_HOST}/api/public/ingestion` with `Authorization: Basic base64(public:secret)`, `Content-Type: application/json`, via the `requests` library (already a PII-proxy dependency — **no new venv package**).
- **Envelope** (top-level): `{ "batch": [ { "id": <uuid>, "type": "trace-create", "timestamp": <iso8601>, "body": {…} }, { "id": <uuid>, "type": "generation-create", "timestamp": <iso8601>, "body": {…} } ] }`. Each batch event has its own `id` + `timestamp`; the typed payload lives under `body`.
- `trace-create` body: `{ id: <trace_id>, name: "claude-code", sessionId: <ICLAUDE_SESSION_ID>, tags: ["project:<repo>"], metadata: { pwd, upstream_masking_level, langfuse_scrubbed: true } }`.
- `generation-create` body: `{ id: <gen_id>, traceId: <trace_id>, name: "messages", model, input: { system, messages }, output: <scrubbed completion text>, usage: { input: <input_tokens>, output: <output_tokens>, total: <input_tokens + output_tokens> }, startTime, endTime, metadata: { stop_reason, cache_creation_input_tokens, cache_read_input_tokens, truncated } }`.
- **`usage.total` is defined as `input_tokens + output_tokens`** (cache tokens are reported separately in `metadata`, not folded into `total`).
- IDs (`trace_id`, `gen_id`, batch event `id`) are UUIDv4; timestamps ISO-8601 UTC (Python `uuid`, `datetime` — available in the proxy runtime).
- **One trace per `/v1/messages` call**, grouped in Langfuse's Sessions view via `sessionId`. No per-session stateful trace management in the proxy.

### R4 — Async, fail-soft, zero-latency

- Emission runs in a **daemon thread** spawned after the response is fully relayed to the client. It must never block, delay, or alter the proxied request/response.
- Any Langfuse error (unreachable, non-2xx, timeout) is caught, logged at warning, and dropped. A failed or slow Langfuse **never** affects the client request.
- Bounded: a short emit timeout (e.g. 5 s connect/read) and best-effort single attempt (no retry storm). If the accumulation buffer would exceed a sane cap (e.g. 10 MB of SSE), truncate the captured output and flag `truncated: true` in metadata rather than holding unbounded memory.

### R5 — Per-project tag (reuse `_init_project_id`)

- The Langfuse `project:<repo>` tag uses `ICLAUDE_PROJECT_ID`, the same value the router path uses (`_derive_project_id`), so both paths agree on the project key.
- `_init_project_id()` (in `lib/launcher/launch.sh`) currently exports only in router mode; extend its activation so it also runs when `USE_LANGFUSE_CAPTURE=true` (i.e. `use_router || use_langfuse_capture`). The launcher passes `ICLAUDE_PROJECT_ID` and `ICLAUDE_SESSION_ID` into the proxy process environment.

### R6 — Configuration & launcher activation

`.claude_config`:
```bash
export USE_LANGFUSE_CAPTURE=true
export LANGFUSE_HOST="https://langfuse.example"
export LANGFUSE_PUBLIC_KEY="pk-lf-..."
export LANGFUSE_SECRET_KEY="sk-lf-..."   # secret — chmod 600, never committed
```
- The launcher starts the PII proxy when `use_pii_proxy || use_langfuse_capture`. When capture is on but masking was not requested, `MASKING_LEVEL` defaults to `off` (proxy runs purely as the auth + capture hop).
- The proxy reads `USE_LANGFUSE_CAPTURE` + `LANGFUSE_*` from its environment; if capture is on but any of `LANGFUSE_HOST`/`LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY` is missing, it logs a warning at startup and disables capture (fail-soft, proxy still serves).
- **Router mode:** if `--router` is active, capture is **skipped** (the LiteLLM path already emits to Langfuse — enabling capture would double-emit). Capture is a non-router feature.

### R7 — Module structure

- New module `langfuse_emitter.py` next to `pii-proxy-server.py`, imported by the proxy. It owns: SSE/JSON response parsing, ingestion-payload construction, and the async POST. Keeping it separate keeps the 1250-line proxy file focused and makes the emitter unit-testable in isolation.
- The proxy calls a single entry point (e.g. `langfuse_emitter.capture(request_body, response_bytes, is_streaming, meta)`) from `_forward`, guarded by a module-level `_CAPTURE_ENABLED` flag resolved once at startup.

## 5. Testing

- **Unit (`langfuse_emitter`):**
  - Parse a recorded Anthropic SSE stream → assert `{ completion, model, input_tokens, output_tokens, stop_reason }`.
  - Parse a non-SSE JSON response → same assertions.
  - Build ingestion payload → assert trace+generation shape, `sessionId`, `tags=["project:<repo>"]`, BasicAuth header.
  - Always-scrub (R2a): with `MASKING_LEVEL=off`, feed a request containing `sk-…`/`Bearer …`/`ghp_…`/`AKIA…` AND a completion containing the same patterns; assert NONE appear in the emitted payload (both request input and completion output are secrets-scrubbed regardless of upstream masking).
  - Output-size cap: oversized SSE → `truncated: true`, bounded memory.
- **Integration (skip-aware, exit 77 if python deps absent):** a mock upstream returns a canned SSE response; a mock Langfuse HTTP server records the ingestion POST; drive one `/v1/messages` through the real proxy with capture on → assert the mock Langfuse received a trace + generation with the project tag and the completion text. Fail-soft: mock Langfuse returns 500 → assert the client still received the full response and the proxy did not error.

## 6. Security & privacy

- `LANGFUSE_SECRET_KEY` is a secret: stored only in `.claude_config` (chmod 600), never committed; redacted by the existing hooks if it ever appears in tool I/O.
- Both the request and the completion in the Langfuse copy are **always secrets-scrubbed** (R2a) — Langfuse never stores credential patterns, even with upstream masking off. It still stores prompt/code and non-secret completion text, which operators must accept for self-hosted Langfuse.
- The scrub touches only the Langfuse copy; the request forwarded to Anthropic and the response relayed to the client are governed solely by `MASKING_LEVEL` and are never altered by the capture path.
- Langfuse egress is a consented destination (operator-configured host + keys). The emit timeout and fail-soft guarantee a compromised or slow Langfuse cannot stall or break a session.

## 7. Out of scope

- Grafana "Claude Code — Audit" dashboard simplification (done later, only after this lands).
- Presidio/PII (non-secret) masking of the Langfuse copy beyond what upstream `MASKING_LEVEL=standard` already applies — the always-on scrub here is **secrets only** (`regex_mask`).
- Per-session single-trace modeling (we use trace-per-call + `sessionId`).
- Capture in the pure direct path without any local hop (capture requires the proxy hop, which the capture flag itself provisions).
- Router-mode capture (LiteLLM already covers Langfuse there).

## 8. Rollback

- Set `USE_LANGFUSE_CAPTURE=false` (or unset) — the proxy runs exactly as before; the launcher no longer auto-starts it for capture.
- Remove `langfuse_emitter.py` and its single call site in `pii-proxy-server.py`; revert the `_init_project_id` activation widening. No persistent state is created.
