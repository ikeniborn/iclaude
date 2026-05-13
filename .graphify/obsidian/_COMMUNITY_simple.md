---
type: community
cohesion: 0.17
members: 16
---

# simple

**Cohesion:** 0.17 - loosely connected
**Members:** 16 nodes

## Members
- [[.__init__()]] - code - tests/test_patterns_examples.py
- [[.test_url_credentials_at_in_password()]] - code - tests/test_patterns_examples.py
- [[.test_url_credentials_performance()]] - code - tests/test_patterns_examples.py
- [[.test_url_credentials_simple()]] - code - tests/test_patterns_examples.py
- [[.test_url_no_credentials_not_masked()]] - code - tests/test_patterns_examples.py
- [[Long URL with credentials should not cause ReDoS.]] - rationale - tests/test_patterns_examples.py
- [[Password containing @ must not leak after masking.]] - rationale - tests/test_patterns_examples.py
- [[SecretDetector]] - code - tests/test_patterns_examples.py
- [[Simple redaction detector for testing purposes]] - rationale - tests/test_patterns_examples.py
- [[Simple userpass@host should be masked.]] - rationale - tests/test_patterns_examples.py
- [[TestServerRegexMask]] - code - tests/test_patterns_examples.py
- [[Tests for server.py regex_mask — imported directly to catch divergence.]] - rationale - tests/test_patterns_examples.py
- [[URLs without credentials must not be altered.]] - rationale - tests/test_patterns_examples.py
- [[detector()]] - code - tests/test_patterns_examples.py
- [[mask()]] - code - tests/test_patterns_examples.py
- [[test_patterns_examples.py]] - code - tests/test_patterns_examples.py

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/simple
SORT file.name ASC
```

## Connections to other communities
- 3 edges to [[_COMMUNITY_redacted  should]]
- 1 edge to [[_COMMUNITY_should]]
- 1 edge to [[_COMMUNITY_should  with]]
- 1 edge to [[_COMMUNITY_mask_token]]

## Top bridge nodes
- [[test_patterns_examples.py]] - degree 9, connects to 4 communities
- [[SecretDetector]] - degree 5, connects to 1 community