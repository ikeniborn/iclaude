---
type: community
cohesion: 0.05
members: 53
---

# redacted / should

**Cohesion:** 0.05 - loosely connected
**Members:** 53 nodes

## Members
- [[.redact_text()]] - code - tests/test_patterns_examples.py
- [[.test_anthropic_api_key()]] - code - tests/test_patterns_examples.py
- [[.test_aws_access_key()]] - code - tests/test_patterns_examples.py
- [[.test_aws_secret_key()]] - code - tests/test_patterns_examples.py
- [[.test_credit_card_visa()]] - code - tests/test_patterns_examples.py
- [[.test_dotenv_secret_variable()]] - code - tests/test_patterns_examples.py
- [[.test_empty_string()]] - code - tests/test_patterns_examples.py
- [[.test_generic_secret_in_config()]] - code - tests/test_patterns_examples.py
- [[.test_github_token()]] - code - tests/test_patterns_examples.py
- [[.test_google_ai_studio_key()]] - code - tests/test_patterns_examples.py
- [[.test_google_ai_studio_key_real()]] - code - tests/test_patterns_examples.py
- [[.test_groq_api_key()]] - code - tests/test_patterns_examples.py
- [[.test_groq_api_key_real()]] - code - tests/test_patterns_examples.py
- [[.test_huggingface_token()]] - code - tests/test_patterns_examples.py
- [[.test_huggingface_token_real()]] - code - tests/test_patterns_examples.py
- [[.test_jwt_token()]] - code - tests/test_patterns_examples.py
- [[.test_multiple_secrets_in_text()]] - code - tests/test_patterns_examples.py
- [[.test_none_like_string()]] - code - tests/test_patterns_examples.py
- [[.test_partial_match_not_redacted()]] - code - tests/test_patterns_examples.py
- [[.test_password_in_config()]] - code - tests/test_patterns_examples.py
- [[.test_pem_private_key()]] - code - tests/test_patterns_examples.py
- [[.test_stripe_secret_key()]] - code - tests/test_patterns_examples.py
- [[.test_stripe_test_key()]] - code - tests/test_patterns_examples.py
- [[.test_unicode_characters()]] - code - tests/test_patterns_examples.py
- [[.test_url_credentials()]] - code - tests/test_patterns_examples.py
- [[AWS Access Key IDs should be redacted]] - rationale - tests/test_patterns_examples.py
- [[AWS Secret Access Keys should be redacted]] - rationale - tests/test_patterns_examples.py
- [[Anthropic API keys should be redacted]] - rationale - tests/test_patterns_examples.py
- [[Apply all patterns and return redacted text + found patterns]] - rationale - tests/test_patterns_examples.py
- [[Credentials in URLs should be redacted]] - rationale - tests/test_patterns_examples.py
- [[Empty string should not crash]] - rationale - tests/test_patterns_examples.py
- [[Generic secret assignments should be redacted]] - rationale - tests/test_patterns_examples.py
- [[GitHub tokens should be redacted]] - rationale - tests/test_patterns_examples.py
- [[Google AI Studio keys should be redacted]] - rationale - tests/test_patterns_examples.py
- [[Google AI Studio keys should be redacted_1]] - rationale - tests/test_patterns_examples.py
- [[Groq API keys should be redacted]] - rationale - tests/test_patterns_examples.py
- [[Groq API keys should be redacted_1]] - rationale - tests/test_patterns_examples.py
- [[HuggingFace tokens should be redacted]] - rationale - tests/test_patterns_examples.py
- [[HuggingFace tokens should be redacted_1]] - rationale - tests/test_patterns_examples.py
- [[JWT tokens should be redacted]] - rationale - tests/test_patterns_examples.py
- [[Long .env secret variables should be redacted]] - rationale - tests/test_patterns_examples.py
- [[PEM private keys should be redacted]] - rationale - tests/test_patterns_examples.py
- [[Partial patterns should not be redacted if incomplete]] - rationale - tests/test_patterns_examples.py
- [[Passwords in config files should be redacted]] - rationale - tests/test_patterns_examples.py
- [[String with 'None' should not crash]] - rationale - tests/test_patterns_examples.py
- [[Stripe secret keys should be redacted]] - rationale - tests/test_patterns_examples.py
- [[Stripe test keys should be redacted]] - rationale - tests/test_patterns_examples.py
- [[Test cases for patterns that SHOULD be detected and redacted]] - rationale - tests/test_patterns_examples.py
- [[TestEdgeCases]] - code - tests/test_patterns_examples.py
- [[TestShouldRedact]] - code - tests/test_patterns_examples.py
- [[Text with multiple different secret types should redact all]] - rationale - tests/test_patterns_examples.py
- [[Unicode characters should be handled gracefully]] - rationale - tests/test_patterns_examples.py
- [[Visa credit cards should be redacted]] - rationale - tests/test_patterns_examples.py

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/redacted_/_should
SORT file.name ASC
```

## Connections to other communities
- 8 edges to [[_COMMUNITY_should]]
- 3 edges to [[_COMMUNITY_simple]]
- 3 edges to [[_COMMUNITY_should  with]]

## Top bridge nodes
- [[.redact_text()]] - degree 37, connects to 3 communities
- [[TestShouldRedact]] - degree 21, connects to 1 community
- [[TestEdgeCases]] - degree 6, connects to 1 community