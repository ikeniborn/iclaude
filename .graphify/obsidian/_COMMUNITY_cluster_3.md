---
type: community
cohesion: 0.11
members: 27
---

# cluster_3

**Cohesion:** 0.11 - loosely connected
**Members:** 27 nodes

## Members
- [[Apply deterministic regex patterns. Returns (masked_text, found_descriptions).]] - rationale - lib/pii-proxy/server.py
- [[Apply masking according to MASKING_LEVEL.      'off'      - return text unchange]] - rationale - lib/pii-proxy/server.py
- [[Configure 'pii-proxy' logger directly (not root logger) for reliability.]] - rationale - lib/pii-proxy/server.py
- [[Detect installed spaCy models from venv marker files or by probing spacy.      R]] - rationale - lib/pii-proxy/server.py
- [[Lazy-initialize Presidio NLP engine with all available language models.      Thr]] - rationale - lib/pii-proxy/server.py
- [[Mask PII in user messages and assistant tool_use inputs only.      Masking scope]] - rationale - lib/pii-proxy/server.py
- [[Mask a single content block. Returns (masked_block, found_descriptions).]] - rationale - lib/pii-proxy/server.py
- [[PII Proxy Server]] - code - lib/pii-proxy/server.py
- [[Pattern Examples Tests]] - code - tests/test_patterns_examples.py
- [[Prefix each found description with field location (used in debug logging).]] - rationale - lib/pii-proxy/server.py
- [[Quality Analysis Tests]] - code - tests/test-quality-analysis.py
- [[Recursively mask PII in a JSON value (str, dict, list).      Handles arbitrary n]] - rationale - lib/pii-proxy/server.py
- [[Truncate a matched value for debug logging. Keeps first max_len chars.]] - rationale - lib/pii-proxy/server.py
- [[Validate upstream URL must be HTTPS or loopback HTTP (prevents SSRF via file]] - rationale - lib/pii-proxy/server.py
- [[_build_ssl_verify()]] - code - lib/pii-proxy/server.py
- [[_detect_spacy_models()]] - code - lib/pii-proxy/server.py
- [[_mask_value()]] - code - lib/pii-proxy/server.py
- [[_prefix()]] - code - lib/pii-proxy/server.py
- [[_snippet()]] - code - lib/pii-proxy/server.py
- [[_validate_upstream_url()]] - code - lib/pii-proxy/server.py
- [[init_presidio()]] - code - lib/pii-proxy/server.py
- [[main()]] - code - lib/pii-proxy/server.py
- [[mask_content_block()]] - code - lib/pii-proxy/server.py
- [[mask_request_body()]] - code - lib/pii-proxy/server.py
- [[presidio_mask()]] - code - lib/pii-proxy/server.py
- [[regex_mask()]] - code - lib/pii-proxy/server.py
- [[setup_logging()]] - code - lib/pii-proxy/server.py

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/cluster_3
SORT file.name ASC
```

## Connections to other communities
- 3 edges to [[_COMMUNITY__get_http_session()  piiproxyhandler]]

## Top bridge nodes
- [[PII Proxy Server]] - degree 17, connects to 1 community
- [[mask_request_body()]] - degree 6, connects to 1 community