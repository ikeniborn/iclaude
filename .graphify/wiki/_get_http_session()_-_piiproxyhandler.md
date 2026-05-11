# _get_http_session() / piiproxyhandler

> 30 nodes · cohesion 0.11

## Key Concepts

- **PIIProxyHandler** (20 connections) — `lib/pii-proxy/server.py`
- **._proxy_passthrough()** (10 connections) — `lib/pii-proxy/server.py`
- **._forward()** (6 connections) — `lib/pii-proxy/server.py`
- **._proxy_messages()** (6 connections) — `lib/pii-proxy/server.py`
- **._proxy_head()** (5 connections) — `lib/pii-proxy/server.py`
- **._read_body()** (5 connections) — `lib/pii-proxy/server.py`
- **_get_http_session()** (4 connections) — `lib/pii-proxy/server.py`
- **._build_upstream_headers()** (4 connections) — `lib/pii-proxy/server.py`
- **.do_GET()** (4 connections) — `lib/pii-proxy/server.py`
- **.do_HEAD()** (3 connections) — `lib/pii-proxy/server.py`
- **.do_POST()** (3 connections) — `lib/pii-proxy/server.py`
- **._health_head()** (3 connections) — `lib/pii-proxy/server.py`
- **._metrics()** (3 connections) — `lib/pii-proxy/server.py`
- **.do_DELETE()** (2 connections) — `lib/pii-proxy/server.py`
- **.do_OPTIONS()** (2 connections) — `lib/pii-proxy/server.py`
- **.do_PATCH()** (2 connections) — `lib/pii-proxy/server.py`
- **.do_PUT()** (2 connections) — `lib/pii-proxy/server.py`
- **._error_response()** (2 connections) — `lib/pii-proxy/server.py`
- **._health()** (2 connections) — `lib/pii-proxy/server.py`
- **.log_message()** (1 connections) — `lib/pii-proxy/server.py`
- **Return this thread's requests.Session, creating it on first access.** (1 connections) — `lib/pii-proxy/server.py`
- **HTTP request handler for PII-proxy.      Design: asymmetric masking — only REQUE** (1 connections) — `lib/pii-proxy/server.py`
- **Build request headers for upstream forwarding.          In API-key mode (ANTHROP** (1 connections) — `lib/pii-proxy/server.py`
- **HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2).** (1 connections) — `lib/pii-proxy/server.py`
- **GET /api/metrics — return live masking metrics for statusline integration.** (1 connections) — `lib/pii-proxy/server.py`
- *... and 5 more nodes in this community*

## Relationships

- No strong cross-community connections detected

## Source Files

- `lib/pii-proxy/server.py`

## Audit Trail

- EXTRACTED: 99 (100%)
- INFERRED: 0 (0%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*