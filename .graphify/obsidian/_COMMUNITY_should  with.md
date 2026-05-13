---
type: community
cohesion: 0.20
members: 10
---

# should / with

**Cohesion:** 0.20 - loosely connected
**Members:** 10 nodes

## Members
- [[.test_long_url_with_credentials_no_timeout()]] - code - tests/test_patterns_examples.py
- [[.test_many_matches_in_text()]] - code - tests/test_patterns_examples.py
- [[.test_pem_key_with_long_content_no_timeout()]] - code - tests/test_patterns_examples.py
- [[.test_pem_key_with_malformed_no_timeout()]] - code - tests/test_patterns_examples.py
- [[Long URLs with credentials should process quickly]] - rationale - tests/test_patterns_examples.py
- [[Malformed PEM (no END marker) should not cause timeout]] - rationale - tests/test_patterns_examples.py
- [[PEM key with maximum allowed content should complete quickly]] - rationale - tests/test_patterns_examples.py
- [[Performance tests to detect potential ReDoS issues]] - rationale - tests/test_patterns_examples.py
- [[TestPerformance]] - code - tests/test_patterns_examples.py
- [[Text with many matches should process efficiently]] - rationale - tests/test_patterns_examples.py

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/should_/_with
SORT file.name ASC
```

## Connections to other communities
- 3 edges to [[_COMMUNITY_redacted  should]]
- 1 edge to [[_COMMUNITY_simple]]

## Top bridge nodes
- [[TestPerformance]] - degree 6, connects to 1 community
- [[.test_many_matches_in_text()]] - degree 3, connects to 1 community
- [[.test_pem_key_with_long_content_no_timeout()]] - degree 3, connects to 1 community
- [[.test_pem_key_with_malformed_no_timeout()]] - degree 3, connects to 1 community