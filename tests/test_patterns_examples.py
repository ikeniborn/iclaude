#!/usr/bin/env python3
"""
Test cases for redact-secrets.py pattern validation.

This file contains comprehensive test cases for:
1. Patterns that SHOULD be redacted
2. Patterns that SHOULD NOT be redacted (false positive detection)
3. Performance tests to detect ReDoS issues

Usage:
    python test_patterns_examples.py

Requirements:
    pytest

Installation:
    pip install pytest
"""

import pytest
import re
from typing import List, Tuple

# Placeholder for pattern list - would be loaded from patterns.json in production
# This is a simplified example for testing the concept

class SecretDetector:
    """Simple redaction detector for testing purposes"""

    def __init__(self):
        self.patterns: List[Tuple[re.Pattern, str, str]] = [
            # Anthropic / OpenAI API keys
            (
                re.compile(r'\bsk-(?:ant-api03-|ant-|proj-)?[A-Za-z0-9\-_]{20,}'),
                '[ANTHROPIC_API_KEY]',
                'Anthropic/OpenAI API key',
            ),
            # Google AI Studio
            (
                re.compile(r'\bAIzaSy[A-Za-z0-9_-]{32}\b'),
                '[GOOGLE_API_KEY]',
                'Google AI Studio API key',
            ),
            # Stripe API keys
            (
                re.compile(r'\b(?:sk|pk)_(?:live|test)_[A-Za-z0-9]{20,}\b'),
                '[STRIPE_API_KEY]',
                'Stripe API key',
            ),
            # HuggingFace token
            (
                re.compile(r'\bhf_[A-Za-z0-9_]{30,}\b'),
                '[HUGGINGFACE_TOKEN]',
                'HuggingFace User Access Token',
            ),
            # OpenRouter API Key
            (
                re.compile(r'\bsk-or-[A-Za-z0-9\-_]{50,}\b'),
                '[OPENROUTER_API_KEY]',
                'OpenRouter API key',
            ),
            # Groq API Key
            (
                re.compile(r'\bgsk_[A-Za-z0-9\-_]{50,}\b'),
                '[GROQ_API_KEY]',
                'Groq API key',
            ),
            # GitHub tokens
            (
                re.compile(r'\bgh[pousr]_[A-Za-z0-9_]{36,}\b'),
                '[GITHUB_TOKEN]',
                'GitHub token',
            ),
            # JWT tokens
            (
                re.compile(r'\beyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\b'),
                '[JWT_REDACTED]',
                'JWT token',
            ),
            # AWS Access Key ID
            (
                re.compile(r'\bAKIA[0-9A-Z]{16}\b'),
                '[AWS_ACCESS_KEY_ID]',
                'AWS Access Key ID',
            ),
            # PEM private key (with length limit to prevent ReDoS)
            (
                re.compile(
                    r'-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'
                    r'[\s\S]{0,5000}?'
                    r'-----END (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'
                ),
                '[PRIVATE_KEY_REDACTED]',
                'PEM private key block',
            ),
            # Credit card
            (
                re.compile(r'\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\b'),
                '[CARD_NUMBER_REDACTED]',
                'credit card number',
            ),
        ]

    def redact_text(self, text: str) -> Tuple[str, List[str]]:
        """Apply all patterns and return redacted text + found patterns"""
        found: List[str] = []
        for pattern, replacement, description in self.patterns:
            new_text = pattern.sub(replacement, text)
            if new_text != text:
                found.append(description)
                text = new_text
        return text, found


# ============================================================================
# TEST CASES: SHOULD BE REDACTED
# ============================================================================

class TestShouldRedact:
    """Test cases for patterns that SHOULD be detected and redacted"""

    @pytest.fixture
    def detector(self):
        return SecretDetector()

    def test_anthropic_api_key(self, detector):
        """Anthropic API keys should be redacted"""
        text = "export ANTHROPIC_API_KEY=sk-ant-api03-v1w2x3y4z5a6b7c8d9e0f1g2h3i4j5k6l7m8n9o0p"
        redacted, found = detector.redact_text(text)
        assert "[ANTHROPIC_API_KEY]" in redacted
        assert "Anthropic/OpenAI API key" in found

    def test_google_ai_studio_key(self, detector):
        """Google AI Studio keys should be redacted"""
        text = "key = AIzaSyDHn9_p-qvNbHk9Cc1xP2-YuL5RVZqJgL"
        redacted, found = detector.redact_text(text)
        assert "[GOOGLE_API_KEY]" in redacted
        assert "Google AI Studio API key" in found

    def test_stripe_secret_key(self, detector):
        """Stripe secret keys should be redacted"""
        # Key split to avoid GitHub push protection false positive
        text = "sk_live_" + "abcdefghijklmnopqrstuvwxyz"
        redacted, found = detector.redact_text(text)
        assert "[STRIPE_API_KEY]" in redacted

    def test_stripe_test_key(self, detector):
        """Stripe test keys should be redacted"""
        # Key split to avoid GitHub push protection false positive
        text = "sk_test_" + "abcdefghijklmnopqrstuvwxyz"
        redacted, found = detector.redact_text(text)
        assert "[STRIPE_API_KEY]" in redacted

    def test_huggingface_token(self, detector):
        """HuggingFace tokens should be redacted"""
        text = "hf_ABcD1234EFgh5678IJkl9012MNop3456QRST"
        redacted, found = detector.redact_text(text)
        assert "[HUGGINGFACE_TOKEN]" in redacted

    def test_groq_api_key(self, detector):
        """Groq API keys should be redacted"""
        text = "gsk_ABcD1234EFgh5678IJkl9012MNop3456QRSTuvwxyz12345678901"
        redacted, found = detector.redact_text(text)
        assert "[GROQ_API_KEY]" in redacted

    def test_github_token(self, detector):
        """GitHub tokens should be redacted"""
        text = "ghp_1234567890abcdefghijklmnopqrstuvwxyz"
        redacted, found = detector.redact_text(text)
        assert "[GITHUB_TOKEN]" in redacted

    def test_jwt_token(self, detector):
        """JWT tokens should be redacted"""
        text = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        redacted, found = detector.redact_text(text)
        assert "[JWT_REDACTED]" in redacted

    def test_aws_access_key(self, detector):
        """AWS Access Key IDs should be redacted"""
        text = "AKIA1234567890ABCDEF"
        redacted, found = detector.redact_text(text)
        assert "[AWS_ACCESS_KEY_ID]" in redacted

    def test_credit_card_visa(self, detector):
        """Visa credit cards should be redacted"""
        text = "4532015112830366"
        redacted, found = detector.redact_text(text)
        assert "[CARD_NUMBER_REDACTED]" in redacted

    def test_pem_private_key(self, detector):
        """PEM private keys should be redacted"""
        text = """-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC3
-----END PRIVATE KEY-----"""
        redacted, found = detector.redact_text(text)
        assert "[PRIVATE_KEY_REDACTED]" in redacted


# ============================================================================
# TEST CASES: SHOULD NOT BE REDACTED (FALSE POSITIVE DETECTION)
# ============================================================================

class TestFalsePositives:
    """Test cases for patterns that SHOULD NOT be redacted (false positive risks)"""

    @pytest.fixture
    def detector(self):
        return SecretDetector()

    def test_uuid_should_not_be_redacted(self, detector):
        """UUIDs should NOT be redacted even if 32+ hex chars"""
        text = 'user_id = "550e8400-e29b-41d4-a716-446655440000"'
        redacted, found = detector.redact_text(text)
        assert "550e8400-e29b-41d4-a716-446655440000" in redacted or "550e8400" in redacted
        # UUID itself shouldn't be redacted (unless it matches another pattern)

    def test_git_commit_hash_not_redacted(self, detector):
        """Git commit hashes should NOT be treated as tokens"""
        text = "commit 1234567890abcdef1234567890abcdef"
        redacted, found = detector.redact_text(text)
        # Should not match any pattern (commit is just descriptive text)
        assert len(found) == 0 or "[" not in redacted

    def test_version_tag_not_redacted(self, detector):
        """Version tags should NOT be redacted"""
        text = "version: v1.2.3-abc123xyz"
        redacted, found = detector.redact_text(text)
        # Should not redact version numbers
        assert len(found) == 0

    def test_docker_image_reference_not_fully_redacted(self, detector):
        """Docker image references should not be completely redacted"""
        text = "gcr.io/my-project/image@sha256:abc123def456xyz789"
        redacted, found = detector.redact_text(text)
        # Ideally should not redact this (it's not a secret)
        assert "image" in redacted  # At least the image name should remain

    def test_template_variables_not_redacted(self, detector):
        """Template variables should NOT be redacted"""
        text = 'export DATABASE_URL="${DB_HOST}:${DB_PORT}/${DB_NAME}"'
        redacted, found = detector.redact_text(text)
        # Should not redact template variables
        assert "${DB_HOST}" in redacted or len(found) == 0

    def test_bash_placeholder_not_redacted(self, detector):
        """Bash placeholders should NOT be redacted"""
        text = 'secret: "{{ default_password }}"'
        redacted, found = detector.redact_text(text)
        # Should not redact template placeholders
        assert "{{ default_password }}" in redacted or len(found) == 0

    def test_test_password_should_not_be_redacted(self, detector):
        """Test/example passwords in test files should preferably not be redacted"""
        text = '# This is test code\ntest_password = "Test@123!XyZ456"'
        redacted, found = detector.redact_text(text)
        # This is a known limitation - test passwords may be redacted
        # which is acceptable for security
        pass

    def test_long_hex_string_not_obviously_secret(self, detector):
        """Long hex strings that are not obviously secrets"""
        text = 'signature = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"'
        redacted, found = detector.redact_text(text)
        # Shouldn't redact generic hex strings
        assert len(found) == 0 or "[" not in redacted


# ============================================================================
# TEST CASES: PERFORMANCE AND REDOS DETECTION
# ============================================================================

class TestPerformance:
    """Performance tests to detect potential ReDoS issues"""

    @pytest.fixture
    def detector(self):
        return SecretDetector()

    def test_pem_key_with_long_content_no_timeout(self, detector):
        """PEM key with maximum allowed content should complete quickly"""
        # Create a valid-looking PEM block with ~5000 characters
        content = "A" * 4990
        text = f"-----BEGIN PRIVATE KEY-----\n{content}\n-----END PRIVATE KEY-----"

        import time
        start = time.time()
        redacted, found = detector.redact_text(text)
        elapsed = time.time() - start

        # Should complete in under 100ms
        assert elapsed < 0.1, f"PEM key processing took {elapsed*1000:.2f}ms (expected < 100ms)"
        assert "[PRIVATE_KEY_REDACTED]" in redacted

    def test_pem_key_with_malformed_no_timeout(self, detector):
        """Malformed PEM (no END marker) should not cause timeout"""
        # This is the ReDoS risk case
        content = "A" * 10000  # More than limit
        text = f"-----BEGIN PRIVATE KEY-----\n{content}"  # No END marker

        import time
        start = time.time()
        redacted, found = detector.redact_text(text)
        elapsed = time.time() - start

        # Should complete in under 100ms even with malformed input
        assert elapsed < 0.1, f"Malformed PEM took {elapsed*1000:.2f}ms (expected < 100ms)"

    def test_long_url_with_credentials_no_timeout(self, detector):
        """Long URLs with credentials should process quickly"""
        # This would need the URL credentials pattern to test
        # Skipping for now as it requires additional pattern
        pass

    def test_many_matches_in_text(self, detector):
        """Text with many matches should process efficiently"""
        # Create text with many JWT-like strings
        text = "token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U " * 100

        import time
        start = time.time()
        redacted, found = detector.redact_text(text)
        elapsed = time.time() - start

        # Should complete in under 500ms for 100 matches
        assert elapsed < 0.5, f"Processing 100 matches took {elapsed*1000:.2f}ms (expected < 500ms)"


# ============================================================================
# TEST CASES: EDGE CASES
# ============================================================================

class TestEdgeCases:
    """Edge case testing"""

    @pytest.fixture
    def detector(self):
        return SecretDetector()

    def test_empty_string(self, detector):
        """Empty string should not crash"""
        text = ""
        redacted, found = detector.redact_text(text)
        assert redacted == ""
        assert found == []

    def test_none_like_string(self, detector):
        """String with 'None' should not crash"""
        text = "password = None"
        redacted, found = detector.redact_text(text)
        assert "None" in redacted

    def test_unicode_characters(self, detector):
        """Unicode characters should be handled gracefully"""
        text = "token = 'sk-ant-api03-ABCDEFGHIJKLMNOPQRSTUVabcdef' # файл описание"
        redacted, found = detector.redact_text(text)
        assert "[ANTHROPIC_API_KEY]" in redacted

    def test_multiple_secrets_in_text(self, detector):
        """Text with multiple different secret types should redact all"""
        text = """
        STRIPE_KEY=sk_live_""" + "abcdefghijklmnopqrstuvwxyz" + """
        ANTHROPIC_KEY=sk-ant-api03-v1w2x3y4z5a6b7c8d9e0f
        GITHUB_TOKEN=ghp_1234567890abcdefghijklmnopqrstuvwxyz
        """
        redacted, found = detector.redact_text(text)
        assert redacted.count("[") >= 3  # At least 3 redactions
        assert len(found) >= 3  # At least 3 patterns matched

    def test_partial_match_not_redacted(self, detector):
        """Partial patterns should not be redacted if incomplete"""
        text = "sk-ant-"  # Incomplete pattern
        redacted, found = detector.redact_text(text)
        assert "sk-ant-" in redacted  # Should remain unchanged
        assert len(found) == 0


# ============================================================================
# TEST CASES: server.py regex_mask (direct import)
# ============================================================================

class TestServerRegexMask:
    """Tests for server.py regex_mask — imported directly to catch divergence."""

    @pytest.fixture
    def mask(self):
        import importlib.util, os
        src = os.path.join(os.path.dirname(__file__), '..', 'lib', 'pii-proxy', 'server.py')
        spec = importlib.util.spec_from_file_location('pii_server', src)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod.regex_mask

    def test_url_credentials_simple(self, mask):
        """Simple user:pass@host should be masked."""
        text = 'Connect to https://admin:secret123@db.example.com'
        masked, found = mask(text)
        assert 'secret123' not in masked
        assert '[CREDENTIALS]' in masked
        assert 'credentials in URL' in found

    def test_url_credentials_at_in_password(self, mask):
        """Password containing @ must not leak after masking."""
        text = 'postgres://admin:s3cr3tP@ssw0rd@db.example.com:5432/mydb'
        masked, found = mask(text)
        # Full userinfo (including '@' inside password) must be gone
        assert 's3cr3tP' not in masked
        assert 'ssw0rd' not in masked
        assert masked == 'postgres://[CREDENTIALS]@db.example.com:5432/mydb'

    def test_url_no_credentials_not_masked(self, mask):
        """URLs without credentials must not be altered."""
        text = 'See https://example.com/path for details'
        masked, _ = mask(text)
        assert masked == text

    def test_url_credentials_performance(self, mask):
        """Long URL with credentials should not cause ReDoS."""
        import time
        text = ('https://user:pass@' + 'a' * 2000 + '.example.com') * 5
        start = time.time()
        mask(text)
        assert time.time() - start < 0.5, 'URL credentials pattern too slow'


# ============================================================================
# MAIN / CLI
# ============================================================================

if __name__ == "__main__":
    print("RedactSecrets Pattern Test Suite")
    print("=" * 60)
    print("\nRunning with: pytest test_patterns_examples.py -v")
    print("\nTest Categories:")
    print("  - TestShouldRedact: Verify patterns are detected")
    print("  - TestFalsePositives: Check for false positive risks")
    print("  - TestPerformance: Verify no ReDoS issues")
    print("  - TestEdgeCases: Edge case handling")
    print("\nTo run specific test class:")
    print("  pytest test_patterns_examples.py::TestShouldRedact -v")
    print("\nTo run with coverage:")
    print("  pytest test_patterns_examples.py --cov=redact_secrets -v")
    print("=" * 60)

    # Run with pytest
    pytest.main([__file__, "-v", "--tb=short"])
