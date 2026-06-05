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


class _FakeResp:
    """Minimal stand-in for a requests streaming Response context manager."""
    def __init__(self, status=200, headers=None, content=b'', chunks=None, raise_iter=None, raise_content=None):
        self.status_code = status
        self.headers = headers or {'Content-Type': 'application/json'}
        self._content = content
        self._chunks = chunks or []
        self._raise_iter = raise_iter
        self._raise_content = raise_content

    @property
    def content(self):
        if self._raise_content:
            raise self._raise_content
        return self._content

    def iter_content(self, chunk_size=4096):
        for c in self._chunks:
            yield c
        if self._raise_iter:
            raise self._raise_iter

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


class _FakeSession:
    def __init__(self, resp):
        self.resp = resp
        self.calls = []

    def request(self, **kw):
        self.calls.append(kw)
        return self.resp


def _make_forward_handler(command='POST', path='/v1/messages'):
    """A PIIProxyHandler wired for _forward without a real socket."""
    h = pii.PIIProxyHandler.__new__(pii.PIIProxyHandler)
    h.path = path
    h.command = command
    h.headers = {}
    h.wfile = io.BytesIO()
    h.rfile = io.BytesIO()
    h._codes = []
    h.send_response = lambda code, msg=None: h._codes.append(code)
    h.send_header = lambda k, v: None
    h.end_headers = lambda: None
    return h


class TestSplitTimeout:
    def test_forward_passes_timeout_tuple(self, monkeypatch):
        resp = _FakeResp(status=200, headers={'Content-Type': 'application/json'}, content=b'{}')
        sess = _FakeSession(resp)
        monkeypatch.setattr(pii, '_get_http_session', lambda: sess)
        h = _make_forward_handler()
        h._forward(b'{}')
        assert sess.calls[0]['timeout'] == (pii.CONNECT_TIMEOUT, pii.READ_TIMEOUT)

    def test_proxy_head_passes_timeout_tuple(self, monkeypatch):
        resp = _FakeResp(status=200, headers={'Content-Type': 'text/plain'})
        sess = _FakeSession(resp)
        monkeypatch.setattr(pii, '_get_http_session', lambda: sess)
        h = _make_forward_handler(command='HEAD', path='/v1/messages')
        h._proxy_head()
        assert sess.calls[0]['timeout'] == (pii.CONNECT_TIMEOUT, pii.READ_TIMEOUT)


class TestStreamGuard:
    def test_read_timeout_midstream_does_not_double_send(self, monkeypatch):
        resp = _FakeResp(
            status=200,
            headers={'Content-Type': 'text/event-stream'},
            chunks=[b'data: hello\n\n'],
            raise_iter=pii._ReqTimeout('read timed out'),
        )
        sess = _FakeSession(resp)
        monkeypatch.setattr(pii, '_get_http_session', lambda: sess)
        h = _make_forward_handler()
        # Must not raise; must not emit a 502 over the already-started 200.
        h._forward(b'{}')
        assert h._codes == [200]
        assert b'hello' in h.wfile.getvalue()

    def test_conn_reset_midstream_does_not_double_send(self, monkeypatch):
        resp = _FakeResp(
            status=200,
            headers={'Content-Type': 'text/event-stream'},
            chunks=[b'data: partial\n\n'],
            raise_iter=pii._ReqConnError('Connection reset by peer'),
        )
        sess = _FakeSession(resp)
        monkeypatch.setattr(pii, '_get_http_session', lambda: sess)
        h = _make_forward_handler()
        h._forward(b'{}')
        assert h._codes == [200]
        assert b'partial' in h.wfile.getvalue()


    def test_chunked_encoding_error_midstream_does_not_double_send(self, monkeypatch):
        resp = _FakeResp(
            status=200,
            headers={'Content-Type': 'text/event-stream'},
            chunks=[b'data: partial\n\n'],
            raise_iter=pii._requests.exceptions.ChunkedEncodingError('stream truncated'),
        )
        sess = _FakeSession(resp)
        monkeypatch.setattr(pii, '_get_http_session', lambda: sess)
        h = _make_forward_handler()
        h._forward(b'{}')
        assert h._codes == [200]
        assert b'partial' in h.wfile.getvalue()


class TestNonStreamingGuard:
    def test_read_error_buffering_body_sends_clean_502(self, monkeypatch):
        # Non-streaming (no text/event-stream): resp.content is read to buffer the
        # body. If that read raises, the upstream status must NOT have been emitted
        # yet — otherwise the client gets a corrupt 200-then-502 double status line.
        resp = _FakeResp(
            status=200,
            headers={'Content-Type': 'application/json'},
            raise_content=pii._ReqTimeout('read timed out'),
        )
        sess = _FakeSession(resp)
        monkeypatch.setattr(pii, '_get_http_session', lambda: sess)
        h = _make_forward_handler()
        h._forward(b'{}')
        assert h._codes == [502]  # single clean 502, not [200, 502]
