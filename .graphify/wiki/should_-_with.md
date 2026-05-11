# should / with

> 10 nodes · cohesion 0.20

## Key Concepts

- **TestPerformance** (6 connections) — `tests/test_patterns_examples.py`
- **.test_many_matches_in_text()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_pem_key_with_long_content_no_timeout()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_pem_key_with_malformed_no_timeout()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_long_url_with_credentials_no_timeout()** (2 connections) — `tests/test_patterns_examples.py`
- **Performance tests to detect potential ReDoS issues** (1 connections) — `tests/test_patterns_examples.py`
- **PEM key with maximum allowed content should complete quickly** (1 connections) — `tests/test_patterns_examples.py`
- **Malformed PEM (no END marker) should not cause timeout** (1 connections) — `tests/test_patterns_examples.py`
- **Long URLs with credentials should process quickly** (1 connections) — `tests/test_patterns_examples.py`
- **Text with many matches should process efficiently** (1 connections) — `tests/test_patterns_examples.py`

## Relationships

- No strong cross-community connections detected

## Source Files

- `tests/test_patterns_examples.py`

## Audit Trail

- EXTRACTED: 22 (100%)
- INFERRED: 0 (0%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*