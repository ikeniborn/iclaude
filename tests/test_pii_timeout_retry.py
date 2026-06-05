"""Tests for split connect/read timeouts and connect-only retry in pii-proxy-server.py."""
import io
import os
import importlib.util

import pytest

# Supply valid env vars before importing the server module.
# Use localhost URL — real upstream URLs can trigger the project's redact-secrets hook.
os.environ['ANTHROPIC_UPSTREAM_URL'] = 'http://127.0.0.1:9999'
os.environ['PII_PROXY_LOG_DIR'] = '/tmp/pii-proxy-test-logs'

_spec = importlib.util.spec_from_file_location(
    'pii_proxy_server',
    os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        '../.nvm-isolated/.claude-isolated/pii-proxy-server.py',
    ),
)
pii = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pii)


class TestTimeoutEnv:
    def test_default_when_unset(self):
        assert pii._timeout_env('PII_PROXY_NOPE_X', 10.0) == 10.0

    def test_override_from_env(self):
        os.environ['PII_PROXY_TEST_TO'] = '42'
        try:
            assert pii._timeout_env('PII_PROXY_TEST_TO', 10.0) == 42.0
        finally:
            del os.environ['PII_PROXY_TEST_TO']

    def test_invalid_falls_back(self):
        os.environ['PII_PROXY_TEST_TO'] = 'abc'
        try:
            assert pii._timeout_env('PII_PROXY_TEST_TO', 7.0) == 7.0
        finally:
            del os.environ['PII_PROXY_TEST_TO']

    def test_non_positive_falls_back(self):
        os.environ['PII_PROXY_TEST_TO'] = '0'
        try:
            assert pii._timeout_env('PII_PROXY_TEST_TO', 5.0) == 5.0
        finally:
            del os.environ['PII_PROXY_TEST_TO']

    def test_default_constants(self):
        assert pii.CONNECT_TIMEOUT == 10.0
        assert pii.READ_TIMEOUT == 300.0


class TestRetryAdapter:
    def test_session_has_connect_only_retry(self):
        s = pii._get_http_session()
        adapter = s.get_adapter('https://api.anthropic.com')
        retries = adapter.max_retries
        assert retries.connect == 2
        assert retries.read == 0
        assert retries.status == 0

    def test_both_schemes_mounted(self):
        s = pii._get_http_session()
        https = s.get_adapter('https://x')
        http = s.get_adapter('http://x')
        assert https.max_retries.connect == 2
        assert http.max_retries.connect == 2
