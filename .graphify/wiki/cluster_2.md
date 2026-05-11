# cluster_2

> 27 nodes · cohesion 0.11

## Key Concepts

- **PII Proxy Server** (17 connections) — `lib/pii-proxy/server.py`
- **presidio_mask()** (8 connections) — `lib/pii-proxy/server.py`
- **mask_request_body()** (6 connections) — `lib/pii-proxy/server.py`
- **mask_content_block()** (5 connections) — `lib/pii-proxy/server.py`
- **init_presidio()** (4 connections) — `lib/pii-proxy/server.py`
- **_mask_value()** (4 connections) — `lib/pii-proxy/server.py`
- **regex_mask()** (4 connections) — `lib/pii-proxy/server.py`
- **_snippet()** (4 connections) — `lib/pii-proxy/server.py`
- **_detect_spacy_models()** (3 connections) — `lib/pii-proxy/server.py`
- **_prefix()** (3 connections) — `lib/pii-proxy/server.py`
- **setup_logging()** (3 connections) — `lib/pii-proxy/server.py`
- **main()** (2 connections) — `lib/pii-proxy/server.py`
- **_validate_upstream_url()** (2 connections) — `lib/pii-proxy/server.py`
- **_build_ssl_verify()** (1 connections) — `lib/pii-proxy/server.py`
- **Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://** (1 connections) — `lib/pii-proxy/server.py`
- **Configure 'pii-proxy' logger directly (not root logger) for reliability.** (1 connections) — `lib/pii-proxy/server.py`
- **Detect installed spaCy models from venv marker files or by probing spacy.      R** (1 connections) — `lib/pii-proxy/server.py`
- **Lazy-initialize Presidio NLP engine with all available language models.      Thr** (1 connections) — `lib/pii-proxy/server.py`
- **Truncate a matched value for debug logging. Keeps first max_len chars.** (1 connections) — `lib/pii-proxy/server.py`
- **Apply deterministic regex patterns. Returns (masked_text, [found_descriptions]).** (1 connections) — `lib/pii-proxy/server.py`
- **Recursively mask PII in a JSON value (str, dict, list).      Handles arbitrary n** (1 connections) — `lib/pii-proxy/server.py`
- **Apply masking according to MASKING_LEVEL.      'off'      - return text unchange** (1 connections) — `lib/pii-proxy/server.py`
- **Mask a single content block. Returns (masked_block, [found_descriptions]).** (1 connections) — `lib/pii-proxy/server.py`
- **Prefix each found description with field location (used in debug logging).** (1 connections) — `lib/pii-proxy/server.py`
- **Mask PII in user messages and assistant tool_use inputs only.      Masking scope** (1 connections) — `lib/pii-proxy/server.py`
- *... and 2 more nodes in this community*

## Relationships

- [[vendored / graphify]] (76 shared connections)

## Source Files

- `lib/pii-proxy/server.py`
- `tests/test-quality-analysis.py`
- `tests/test_patterns_examples.py`

## Audit Trail

- EXTRACTED: 75 (95%)
- INFERRED: 4 (5%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*