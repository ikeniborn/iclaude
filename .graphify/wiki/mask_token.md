# mask_token

> 17 nodes · cohesion 0.16

## Key Concepts

- **TestMaskToken** (10 connections) — `tests/test_patterns_examples.py`
- **._load_mod()** (7 connections) — `tests/test_patterns_examples.py`
- **.test_custom_token_stored()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_default_token_value()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_empty_token_accepted()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_secrets_mode_github_uses_hardcoded_token()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_secrets_mode_jwt_uses_hardcoded_token()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_standard_regex_path_uses_hardcoded_token()** (3 connections) — `tests/test_patterns_examples.py`
- **.test_env_empty_string_is_set()** (2 connections) — `tests/test_patterns_examples.py`
- **Tests for configurable MASK_TOKEN in server.py masking modes.** (1 connections) — `tests/test_patterns_examples.py`
- **Default MASK_TOKEN must be 'REDACTED' (not '[PII_REDACTED]', no brackets).** (1 connections) — `tests/test_patterns_examples.py`
- **Custom MASK_TOKEN value is preserved at module level.** (1 connections) — `tests/test_patterns_examples.py`
- **Empty-string MASK_TOKEN (deletion mode) is accepted without error.** (1 connections) — `tests/test_patterns_examples.py`
- **secrets mode: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN.** (1 connections) — `tests/test_patterns_examples.py`
- **secrets mode: JWT uses [JWT_REDACTED], not MASK_TOKEN.** (1 connections) — `tests/test_patterns_examples.py`
- **standard mode regex_mask: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN.** (1 connections) — `tests/test_patterns_examples.py`
- **${var+x} idiom: empty PII_PROXY_MASK_TOKEN is SET, not missing.** (1 connections) — `tests/test_patterns_examples.py`

## Relationships

- [[документирует]] (44 shared connections)
- [[should / string]] (1 shared connections)

## Source Files

- `tests/test_patterns_examples.py`

## Audit Trail

- EXTRACTED: 45 (100%)
- INFERRED: 0 (0%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*