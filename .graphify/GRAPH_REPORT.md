# Graph Report - .  (2026-05-12)

## Corpus Check
- Corpus is ~14,342 words - fits in a single context window. You may not need a graph.

## Summary
- 226 nodes · 311 edges · 16 communities (11 shown, 5 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.9)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1800964b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_redacted  should|redacted / should]]
- [[_COMMUNITY__get_http_session()  piiproxyhandler|_get_http_session() / piiproxyhandler]]
- [[_COMMUNITY_cluster_2|cluster_2]]
- [[_COMMUNITY_vendored  graphify|vendored / graphify]]
- [[_COMMUNITY_should|should]]
- [[_COMMUNITY_mask_token|mask_token]]
- [[_COMMUNITY_simple|simple]]
- [[_COMMUNITY_документирует|документирует]]
- [[_COMMUNITY_hook  token|hook / token]]
- [[_COMMUNITY_should  string|should / string]]
- [[_COMMUNITY_should  with|should / with]]
- [[_COMMUNITY_libpii-proxyserver.py|lib/pii-proxy/server.py]]
- [[_COMMUNITY_graphify  patches|graphify / patches]]
- [[_COMMUNITY_claude  code|claude / code]]
- [[_COMMUNITY_oauth  token|oauth / token]]
- [[_COMMUNITY_readme|readme]]

## God Nodes (most connected - your core abstractions)
1. `TestShouldRedact` - 21 edges
2. `PIIProxyHandler` - 20 edges
3. `PII Proxy Server` - 17 edges
4. `iclaude` - 13 edges
5. `TestFalsePositives` - 10 edges
6. `TestMaskToken` - 10 edges
7. `presidio_mask()` - 8 edges
8. `get_masked()` - 7 edges
9. `mask_request_body()` - 6 edges
10. `TestPortabilityE2E` - 6 edges

## Surprising Connections (you probably didn't know these)
- `PII Proxy Server` --shares_data_with--> `Quality Analysis Tests`  [INFERRED]
  lib/pii-proxy/server.py → tests/test-quality-analysis.py
- `PII Proxy Server` --shares_data_with--> `Pattern Examples Tests`  [INFERRED]
  lib/pii-proxy/server.py → tests/test_patterns_examples.py

## Communities (16 total, 5 thin omitted)

### Community 0 - "redacted / should"
Cohesion: 0.07
Nodes (22): Apply all patterns and return redacted text + found patterns, Test cases for patterns that SHOULD be detected and redacted, Anthropic API keys should be redacted, Google AI Studio keys should be redacted, Stripe secret keys should be redacted, Stripe test keys should be redacted, HuggingFace tokens should be redacted, Groq API keys should be redacted (+14 more)

### Community 1 - "_get_http_session() / piiproxyhandler"
Cohesion: 0.11
Nodes (12): _get_http_session(), PIIProxyHandler, Return this thread's requests.Session, creating it on first access., HTTP request handler for PII-proxy.      Design: asymmetric masking — only REQUE, Build request headers for upstream forwarding.          In API-key mode (ANTHROP, HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2)., GET /api/metrics — return live masking metrics for statusline integration., Read request body with Content-Length validation.          Handles both Content- (+4 more)

### Community 2 - "cluster_2"
Cohesion: 0.11
Nodes (26): PII Proxy Server, _detect_spacy_models(), init_presidio(), main(), mask_content_block(), mask_request_body(), _mask_value(), _prefix() (+18 more)

### Community 3 - "vendored / graphify"
Cohesion: 0.12
Nodes (12): fake_pkg(), Проверяет что vendored graphifyy уже патчен (precondition)., Создаёт минимальный faux graphify пакет для патчинга., Idempotent: после первого apply повторный — no-op., Если dry-run patch fails — best-effort exit 0, fails counted., Скопировать реальные vendored файлы в fake_pkg для valid patch context., End-to-end: после apply_patches graphify update пишет relative paths., run_apply() (+4 more)

### Community 4 - "should"
Cohesion: 0.11
Nodes (10): Test cases for patterns that SHOULD NOT be redacted (false positive risks), UUIDs should NOT be redacted even if 32+ hex chars, Git commit hashes should NOT be treated as tokens, Version tags should NOT be redacted, Docker image references should not be completely redacted, Template variables should NOT be redacted, Bash placeholders should NOT be redacted, Test/example passwords in test files should preferably not be redacted (+2 more)

### Community 5 - "mask_token"
Cohesion: 0.16
Nodes (9): Tests for configurable MASK_TOKEN in server.py masking modes., Default MASK_TOKEN must be 'REDACTED' (not '[PII_REDACTED]', no brackets)., Custom MASK_TOKEN value is preserved at module level., Empty-string MASK_TOKEN (deletion mode) is accepted without error., secrets mode: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., secrets mode: JWT uses [JWT_REDACTED], not MASK_TOKEN., standard mode regex_mask: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., ${var+x} idiom: empty PII_PROXY_MASK_TOKEN is SET, not missing. (+1 more)

### Community 6 - "simple"
Cohesion: 0.17
Nodes (10): detector(), mask(), Simple redaction detector for testing purposes, Tests for server.py regex_mask — imported directly to catch divergence., Simple user:pass@host should be masked., Password containing @ must not leak after masking., URLs without credentials must not be altered., Long URL with credentials should not cause ReDoS. (+2 more)

### Community 7 - "документирует"
Cohesion: 0.24
Nodes (13): assert_clean(), assert_masked(), assert_missed(), assert_pii_missed(), get_masked(), Документирует PII, который хук НЕ покрывает по дизайну., Запускает хук и возвращает (stdout, stderr)., Возвращает маскированное содержимое или None если не изменено. (+5 more)

### Community 8 - "hook / token"
Cohesion: 0.14
Nodes (14): block-secrets.py hook, Caveman token compression, Claude Code Router, Chrome integration, Claude Code, Graphify knowledge graph, iclaude, Isolated NVM Environment (+6 more)

### Community 9 - "should / string"
Cohesion: 0.18
Nodes (6): Empty string should not crash, String with 'None' should not crash, Unicode characters should be handled gracefully, Text with multiple different secret types should redact all, Partial patterns should not be redacted if incomplete, TestEdgeCases

### Community 10 - "should / with"
Cohesion: 0.2
Nodes (6): Performance tests to detect potential ReDoS issues, PEM key with maximum allowed content should complete quickly, Malformed PEM (no END marker) should not cause timeout, Long URLs with credentials should process quickly, Text with many matches should process efficiently, TestPerformance

## Knowledge Gaps
- **107 isolated node(s):** `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.`, `Detect installed spaCy models from venv marker files or by probing spacy.      R`, `Lazy-initialize Presidio NLP engine with all available language models.      Thr` (+102 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `TestShouldRedact` connect `redacted / should` to `simple`?**
  _High betweenness centrality (0.065) - this node is a cross-community bridge._
- **Why does `TestMaskToken` connect `mask_token` to `simple`?**
  _High betweenness centrality (0.064) - this node is a cross-community bridge._
- **Why does `PII Proxy Server` connect `cluster_2` to `_get_http_session() / piiproxyhandler`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `PII Proxy Server` (e.g. with `Quality Analysis Tests` and `Pattern Examples Tests`) actually correct?**
  _`PII Proxy Server` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.` to the rest of the system?**
  _107 weakly-connected nodes found - possible documentation gaps or missing edges._