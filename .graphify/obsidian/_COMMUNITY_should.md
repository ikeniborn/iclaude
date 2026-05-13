---
type: community
cohesion: 0.11
members: 18
---

# should

**Cohesion:** 0.11 - loosely connected
**Members:** 18 nodes

## Members
- [[.test_bash_placeholder_not_redacted()]] - code - tests/test_patterns_examples.py
- [[.test_docker_image_reference_not_fully_redacted()]] - code - tests/test_patterns_examples.py
- [[.test_git_commit_hash_not_redacted()]] - code - tests/test_patterns_examples.py
- [[.test_long_hex_string_not_obviously_secret()]] - code - tests/test_patterns_examples.py
- [[.test_template_variables_not_redacted()]] - code - tests/test_patterns_examples.py
- [[.test_test_password_should_not_be_redacted()]] - code - tests/test_patterns_examples.py
- [[.test_uuid_should_not_be_redacted()]] - code - tests/test_patterns_examples.py
- [[.test_version_tag_not_redacted()]] - code - tests/test_patterns_examples.py
- [[Bash placeholders should NOT be redacted]] - rationale - tests/test_patterns_examples.py
- [[Docker image references should not be completely redacted]] - rationale - tests/test_patterns_examples.py
- [[Git commit hashes should NOT be treated as tokens]] - rationale - tests/test_patterns_examples.py
- [[Long hex strings that are not obviously secrets]] - rationale - tests/test_patterns_examples.py
- [[Template variables should NOT be redacted]] - rationale - tests/test_patterns_examples.py
- [[Test cases for patterns that SHOULD NOT be redacted (false positive risks)]] - rationale - tests/test_patterns_examples.py
- [[Testexample passwords in test files should preferably not be redacted]] - rationale - tests/test_patterns_examples.py
- [[TestFalsePositives]] - code - tests/test_patterns_examples.py
- [[UUIDs should NOT be redacted even if 32+ hex chars]] - rationale - tests/test_patterns_examples.py
- [[Version tags should NOT be redacted]] - rationale - tests/test_patterns_examples.py

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/should
SORT file.name ASC
```

## Connections to other communities
- 8 edges to [[_COMMUNITY_redacted  should]]
- 1 edge to [[_COMMUNITY_simple]]

## Top bridge nodes
- [[TestFalsePositives]] - degree 10, connects to 1 community
- [[.test_bash_placeholder_not_redacted()]] - degree 3, connects to 1 community
- [[.test_docker_image_reference_not_fully_redacted()]] - degree 3, connects to 1 community
- [[.test_git_commit_hash_not_redacted()]] - degree 3, connects to 1 community
- [[.test_long_hex_string_not_obviously_secret()]] - degree 3, connects to 1 community