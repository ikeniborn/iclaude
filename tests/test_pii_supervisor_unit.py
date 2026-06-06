"""Unit tests for the PII proxy supervisor/worker split."""
import os
import importlib.util

os.environ['ANTHROPIC_UPSTREAM_URL'] = 'http://127.0.0.1:9999'
os.environ['PII_PROXY_LOG_DIR'] = '/tmp/pii-proxy-test-logs'

_spec = importlib.util.spec_from_file_location(
    'pii_proxy_server_sup',
    os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        '../.nvm-isolated/.claude-isolated/pii-proxy-server.py',
    ),
)
pii = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pii)


class TestSuperviseFlag:
    def test_supervise_default_true(self):
        # default (env unset in this process) must be True
        assert pii.SUPERVISE is True

    def test_helpers_exist(self):
        assert callable(pii._build_server)
        assert callable(pii._run_worker)


class TestBuildServer:
    def test_build_server_binds_in_range(self):
        os.environ['PII_PROXY_PORT_MIN'] = '20000'
        os.environ['PII_PROXY_PORT_MAX'] = '40000'

        class _Args:
            port = 0
        srv = pii._build_server(_Args())
        try:
            host, port = srv.server_address
            assert host == '127.0.0.1'
            assert 20000 <= port <= 40000
        finally:
            srv.server_close()
