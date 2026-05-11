---
type: community
cohesion: 0.16
members: 17
---

# mask_token

**Cohesion:** 0.16 - loosely connected
**Members:** 17 nodes

## Members
- [[${var+x} idiom empty PII_PROXY_MASK_TOKEN is SET, not missing.]] - rationale - tests/test_patterns_examples.py
- [[._load_mod()]] - code - tests/test_patterns_examples.py
- [[.test_custom_token_stored()]] - code - tests/test_patterns_examples.py
- [[.test_default_token_value()]] - code - tests/test_patterns_examples.py
- [[.test_empty_token_accepted()]] - code - tests/test_patterns_examples.py
- [[.test_env_empty_string_is_set()]] - code - tests/test_patterns_examples.py
- [[.test_secrets_mode_github_uses_hardcoded_token()]] - code - tests/test_patterns_examples.py
- [[.test_secrets_mode_jwt_uses_hardcoded_token()]] - code - tests/test_patterns_examples.py
- [[.test_standard_regex_path_uses_hardcoded_token()]] - code - tests/test_patterns_examples.py
- [[Custom MASK_TOKEN value is preserved at module level.]] - rationale - tests/test_patterns_examples.py
- [[Default MASK_TOKEN must be 'REDACTED' (not 'PII_REDACTED', no brackets).]] - rationale - tests/test_patterns_examples.py
- [[Empty-string MASK_TOKEN (deletion mode) is accepted without error.]] - rationale - tests/test_patterns_examples.py
- [[TestMaskToken]] - code - tests/test_patterns_examples.py
- [[Tests for configurable MASK_TOKEN in server.py masking modes.]] - rationale - tests/test_patterns_examples.py
- [[secrets mode GitHub token uses GITHUB_TOKEN, not MASK_TOKEN.]] - rationale - tests/test_patterns_examples.py
- [[secrets mode JWT uses JWT_REDACTED, not MASK_TOKEN.]] - rationale - tests/test_patterns_examples.py
- [[standard mode regex_mask GitHub token uses GITHUB_TOKEN, not MASK_TOKEN.]] - rationale - tests/test_patterns_examples.py

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/mask_token
SORT file.name ASC
```

## Connections to other communities
- 1 edge to [[_COMMUNITY_simple]]

## Top bridge nodes
- [[TestMaskToken]] - degree 10, connects to 1 community