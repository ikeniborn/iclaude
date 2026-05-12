# should / with

> 26 nodes · cohesion 0.09

## Key Concepts

- **test_patterns_examples.py** (9 connections) — `tests/test_patterns_examples.py`
- **TestPerformance** (6 connections) — `tests/test_patterns_examples.py`
- **TestServerRegexMask** (6 connections) — `tests/test_patterns_examples.py`
- **mask()** (5 connections) — `tests/test_patterns_examples.py`
- **SecretDetector** (5 connections) — `tests/test_patterns_examples.py`
- **.test_many_matches_in_text()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_pem_key_with_long_content_no_timeout()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_pem_key_with_malformed_no_timeout()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_url_credentials_at_in_password()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_url_credentials_performance()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_url_credentials_simple()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_url_no_credentials_not_masked()** (3 connections) — `tests/test_patterns_examples.py`
- **detector()** (2 connections) — `tests/test_patterns_examples.py`
- **.test_long_url_with_credentials_no_timeout()** (2 connections) — `tests/test_patterns_examples.py`
- **Simple redaction detector for testing purposes** (1 connections) — `tests/test_patterns_examples.py`
- **Performance tests to detect potential ReDoS issues** (1 connections) — `tests/test_patterns_examples.py`
- **PEM key with maximum allowed content should complete quickly** (1 connections) — `tests/test_patterns_examples.py`
- **Malformed PEM (no END marker) should not cause timeout** (1 connections) — `tests/test_patterns_examples.py`
- **Long URLs with credentials should process quickly** (1 connections) — `tests/test_patterns_examples.py`
- **Text with many matches should process efficiently** (1 connections) — `tests/test_patterns_examples.py`
- **Tests for server.py regex_mask — imported directly to catch divergence.** (1 connections) — `tests/test_patterns_examples.py`
- **Simple user:pass@host should be masked.** (1 connections) — `tests/test_patterns_examples.py`
- **Password containing @ must not leak after masking.** (1 connections) — `tests/test_patterns_examples.py`
- **URLs without credentials must not be altered.** (1 connections) — `tests/test_patterns_examples.py`
- **Long URL with credentials should not cause ReDoS.** (1 connections) — `tests/test_patterns_examples.py`
- *... and 1 more nodes in this community*

## Relationships

- No strong cross-community connections detected

## Source Files

- `tests/test_patterns_examples.py`

## Audit Trail

- EXTRACTED: 68 (100%)
- INFERRED: 0 (0%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*