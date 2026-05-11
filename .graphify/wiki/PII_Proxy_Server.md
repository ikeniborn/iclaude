# PII Proxy Server

> 57 nodes · cohesion 0.06

## Key Concepts

- **PIIProxyHandler** (20 connections) — `lib/pii-proxy/server.py`
- **server.py** (17 connections) — `lib/pii-proxy/server.py`
- **._proxy_passthrough()** (10 connections) — `lib/pii-proxy/server.py`
- **presidio_mask()** (8 connections) — `lib/pii-proxy/server.py`
- **mask_request_body()** (6 connections) — `lib/pii-proxy/server.py`
- **._forward()** (6 connections) — `lib/pii-proxy/server.py`
- **._proxy_messages()** (6 connections) — `lib/pii-proxy/server.py`
- **mask_content_block()** (5 connections) — `lib/pii-proxy/server.py`
- **._proxy_head()** (5 connections) — `lib/pii-proxy/server.py`
- **._read_body()** (5 connections) — `lib/pii-proxy/server.py`
- **_get_http_session()** (4 connections) — `lib/pii-proxy/server.py`
- **init_presidio()** (4 connections) — `lib/pii-proxy/server.py`
- **_mask_value()** (4 connections) — `lib/pii-proxy/server.py`
- **._build_upstream_headers()** (4 connections) — `lib/pii-proxy/server.py`
- **.do_GET()** (4 connections) — `lib/pii-proxy/server.py`
- **regex_mask()** (4 connections) — `lib/pii-proxy/server.py`
- **_snippet()** (4 connections) — `lib/pii-proxy/server.py`
- **_detect_spacy_models()** (3 connections) — `lib/pii-proxy/server.py`
- **.do_HEAD()** (3 connections) — `lib/pii-proxy/server.py`
- **.do_POST()** (3 connections) — `lib/pii-proxy/server.py`
- **._health_head()** (3 connections) — `lib/pii-proxy/server.py`
- **._metrics()** (3 connections) — `lib/pii-proxy/server.py`
- **_prefix()** (3 connections) — `lib/pii-proxy/server.py`
- **setup_logging()** (3 connections) — `lib/pii-proxy/server.py`
- **main()** (2 connections) — `lib/pii-proxy/server.py`
- *... and 32 more nodes in this community*

## Relationships

- No strong cross-community connections detected

## Source Files

- `lib/pii-proxy/server.py`
- `tests/test-quality-analysis.py`
- `tests/test_patterns_examples.py`

## Audit Trail

- EXTRACTED: 174 (98%)
- INFERRED: 4 (2%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*