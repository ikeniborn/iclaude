"""Tests for GET /api/meta endpoint in pii-proxy-server.py."""
import io
import json
import os
import importlib.util

# Supply valid env vars before importing the server module.
# Use localhost URL — real upstream URLs can trigger the project's redact-secrets hook.
os.environ['ANTHROPIC_UPSTREAM_URL'] = 'http://127.0.0.1:9999'
os.environ['PII_PROXY_LOG_DIR'] = '/tmp/pii-proxy-test-logs'

# Import server module from its non-package path.
_spec = importlib.util.spec_from_file_location(
    'pii_proxy_server',
    os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        '../.nvm-isolated/.claude-isolated/pii-proxy-server.py',
    ),
)
pii = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pii)


def _make_handler(path: str):
    """Return a PIIProxyHandler wired for testing (no real socket)."""
    handler = pii.PIIProxyHandler.__new__(pii.PIIProxyHandler)
    handler.path = path
    handler.wfile = io.BytesIO()
    handler.rfile = io.BytesIO()
    handler.headers = {}
    handler.requestline = f'GET {path} HTTP/1.1'
    handler.request_version = 'HTTP/1.1'
    handler.command = 'GET'
    handler._response_code = None
    handler._response_headers = {}

    def _send_response(code, message=None):
        handler._response_code = code

    def _send_header(key, value):
        handler._response_headers[key] = value

    def _end_headers():
        pass

    handler.send_response = _send_response
    handler.send_header = _send_header
    handler.end_headers = _end_headers
    return handler


class TestMetaEndpoint:
    def test_meta_returns_200(self):
        pii._startup_meta = {
            'session_id': 'shared',
            'pwd': '/home/user/project',
            'upstream_url': 'http://127.0.0.1:9999',
            'masking_level': 'standard',
            'log_level': 'info',
            'started_at': 1716384000.0,
        }
        handler = _make_handler('/api/meta')
        handler._meta()
        assert handler._response_code == 200

    def test_meta_content_type_json(self):
        pii._startup_meta = {
            'session_id': 'shared',
            'pwd': '/tmp',
            'upstream_url': 'http://127.0.0.1:9999',
            'masking_level': 'secrets',
            'log_level': 'debug',
            'started_at': 0.0,
        }
        handler = _make_handler('/api/meta')
        handler._meta()
        assert handler._response_headers.get('Content-Type') == 'application/json'

    def test_meta_body_contains_all_fields(self):
        expected = {
            'session_id': 'abc123def456',
            'pwd': '/srv/myapp',
            'upstream_url': 'http://127.0.0.1:9999',
            'masking_level': 'off',
            'log_level': 'info',
            'started_at': 9999.0,
        }
        pii._startup_meta = expected
        handler = _make_handler('/api/meta')
        handler._meta()
        body = json.loads(handler.wfile.getvalue())
        assert body == expected

    def test_do_get_routes_meta(self):
        pii._startup_meta = {
            'session_id': 'shared', 'pwd': '/x',
            'upstream_url': 'http://127.0.0.1:9999',
            'masking_level': 'standard', 'log_level': 'info',
            'started_at': 0.0,
        }
        handler = _make_handler('/api/meta')
        called = []
        handler._proxy_passthrough = lambda: called.append(True)
        handler.do_GET()
        assert handler._response_code == 200
        assert called == [], '_proxy_passthrough must not be called for /api/meta'

    def test_do_get_unknown_path_falls_through(self):
        pii._startup_meta = {}
        handler = _make_handler('/unknown')
        called = []
        handler._proxy_passthrough = lambda: called.append(True)
        handler.do_GET()
        assert called == [True]
