# Graph Report - iclaude  (2026-05-06)

## Corpus Check
- 3 files · ~61,703 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 167 nodes · 244 edges · 8 communities
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `2341dae3`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]

## God Nodes (most connected - your core abstractions)
1. `PIIProxyHandler` - 20 edges
2. `TestShouldRedact` - 13 edges
3. `TestFalsePositives` - 10 edges
4. `TestMaskToken` - 10 edges
5. `presidio_mask()` - 8 edges
6. `get_masked()` - 7 edges
7. `TestPerformance` - 6 edges
8. `TestEdgeCases` - 6 edges
9. `TestServerRegexMask` - 6 edges
10. `mask_request_body()` - 6 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (8 total, 0 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.08
Nodes (20): Apply all patterns and return redacted text + found patterns, Test cases for patterns that SHOULD be detected and redacted, Anthropic API keys should be redacted, Google AI Studio keys should be redacted, Stripe secret keys should be redacted, Stripe test keys should be redacted, HuggingFace tokens should be redacted, Groq API keys should be redacted (+12 more)

### Community 1 - "Community 1"
Cohesion: 0.11
Nodes (12): _get_http_session(), PIIProxyHandler, Return this thread's requests.Session, creating it on first access., HTTP request handler for PII-proxy.      Design: asymmetric masking — only REQUE, Build request headers for upstream forwarding.          In API-key mode (ANTHROP, HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2)., GET /api/metrics — return live masking metrics for statusline integration., Read request body with Content-Length validation.          Handles both Content- (+4 more)

### Community 2 - "Community 2"
Cohesion: 0.12
Nodes (23): _detect_spacy_models(), init_presidio(), main(), mask_content_block(), mask_request_body(), _mask_value(), _prefix(), presidio_mask() (+15 more)

### Community 3 - "Community 3"
Cohesion: 0.11
Nodes (10): Test cases for patterns that SHOULD NOT be redacted (false positive risks), UUIDs should NOT be redacted even if 32+ hex chars, Git commit hashes should NOT be treated as tokens, Version tags should NOT be redacted, Docker image references should not be completely redacted, Template variables should NOT be redacted, Bash placeholders should NOT be redacted, Test/example passwords in test files should preferably not be redacted (+2 more)

### Community 4 - "Community 4"
Cohesion: 0.16
Nodes (9): Tests for configurable MASK_TOKEN in server.py masking modes., Default MASK_TOKEN must be 'REDACTED' (not '[PII_REDACTED]', no brackets)., Custom MASK_TOKEN value is preserved at module level., Empty-string MASK_TOKEN (deletion mode) is accepted without error., secrets mode: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., secrets mode: JWT uses [JWT_REDACTED], not MASK_TOKEN., standard mode regex_mask: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., ${var+x} idiom: empty PII_PROXY_MASK_TOKEN is SET, not missing. (+1 more)

### Community 5 - "Community 5"
Cohesion: 0.17
Nodes (10): detector(), mask(), Simple redaction detector for testing purposes, Tests for server.py regex_mask — imported directly to catch divergence., Simple user:pass@host should be masked., Password containing @ must not leak after masking., URLs without credentials must not be altered., Long URL with credentials should not cause ReDoS. (+2 more)

### Community 6 - "Community 6"
Cohesion: 0.24
Nodes (13): assert_clean(), assert_masked(), assert_missed(), assert_pii_missed(), get_masked(), Документирует PII, который хук НЕ покрывает по дизайну., Запускает хук и возвращает (stdout, stderr)., Возвращает маскированное содержимое или None если не изменено. (+5 more)

### Community 7 - "Community 7"
Cohesion: 0.2
Nodes (6): Performance tests to detect potential ReDoS issues, PEM key with maximum allowed content should complete quickly, Malformed PEM (no END marker) should not cause timeout, Long URLs with credentials should process quickly, Text with many matches should process efficiently, TestPerformance

## Knowledge Gaps
- **73 isolated node(s):** `Запускает хук и возвращает (stdout, stderr).`, `Возвращает маскированное содержимое или None если не изменено.`, `Утверждает что контент ДОЛЖЕН быть замаскирован с указанным плейсхолдером.`, `Утверждает что контент НЕ должен быть изменён хуком.`, `Документирует ПРОПУЩЕННЫЙ секрет (false negative — дыра в защите).` (+68 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `TestMaskToken` connect `Community 4` to `Community 5`?**
  _High betweenness centrality (0.100) - this node is a cross-community bridge._
- **Why does `TestShouldRedact` connect `Community 0` to `Community 5`?**
  _High betweenness centrality (0.065) - this node is a cross-community bridge._
- **Why does `PIIProxyHandler` connect `Community 1` to `Community 2`?**
  _High betweenness centrality (0.062) - this node is a cross-community bridge._
- **What connects `Запускает хук и возвращает (stdout, stderr).`, `Возвращает маскированное содержимое или None если не изменено.`, `Утверждает что контент ДОЛЖЕН быть замаскирован с указанным плейсхолдером.` to the rest of the system?**
  _73 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.11 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.12 - nodes in this community are weakly interconnected._