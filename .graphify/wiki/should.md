# should

> 18 nodes · cohesion 0.11

## Key Concepts

- **TestFalsePositives** (10 connections) — `tests/test_patterns_examples.py`
- **.test_bash_placeholder_not_redacted()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_docker_image_reference_not_fully_redacted()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_git_commit_hash_not_redacted()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_long_hex_string_not_obviously_secret()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_template_variables_not_redacted()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_test_password_should_not_be_redacted()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_uuid_should_not_be_redacted()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_version_tag_not_redacted()** (3 connections) — `tests/test_patterns_examples.py`
- **Test cases for patterns that SHOULD NOT be redacted (false positive risks)** (1 connections) — `tests/test_patterns_examples.py`
- **UUIDs should NOT be redacted even if 32+ hex chars** (1 connections) — `tests/test_patterns_examples.py`
- **Git commit hashes should NOT be treated as tokens** (1 connections) — `tests/test_patterns_examples.py`
- **Version tags should NOT be redacted** (1 connections) — `tests/test_patterns_examples.py`
- **Docker image references should not be completely redacted** (1 connections) — `tests/test_patterns_examples.py`
- **Template variables should NOT be redacted** (1 connections) — `tests/test_patterns_examples.py`
- **Bash placeholders should NOT be redacted** (1 connections) — `tests/test_patterns_examples.py`
- **Test/example passwords in test files should preferably not be redacted** (1 connections) — `tests/test_patterns_examples.py`
- **Long hex strings that are not obviously secrets** (1 connections) — `tests/test_patterns_examples.py`

## Relationships

- No strong cross-community connections detected

## Source Files

- `tests/test_patterns_examples.py`

## Audit Trail

- EXTRACTED: 43 (100%)
- INFERRED: 0 (0%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*