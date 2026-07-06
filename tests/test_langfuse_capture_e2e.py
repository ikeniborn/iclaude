import json
import os
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
PROXY = ROOT / ".nvm-isolated" / ".claude-isolated" / "pii-proxy-server.py"

# A credential-shaped secret long enough to match the proxy's REDACT_PATTERNS
# (sk- prefix + 20+ body chars). It is planted in the upstream completion so the
# test can assert it survives to the client but is scrubbed in the Langfuse copy.
SECRET = "sk-LEAKEDKEYaaaaaaaaaaaaaaaa"


def _free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


class _Upstream(BaseHTTPRequestHandler):
    """Mock Anthropic: returns a fixed SSE stream containing a secret in the completion."""
    def do_POST(self):
        self.rfile.read(int(self.headers.get("content-length", 0) or 0))
        sse = (
            b'event: message_start\n'
            b'data: {"type":"message_start","message":{"model":"claude-sonnet-4-6",'
            b'"usage":{"input_tokens":3}}}\n\n'
            b'event: content_block_delta\n'
            b'data: {"type":"content_block_delta","delta":{"type":"text_delta",'
            b'"text":"token ' + SECRET.encode() + b' done"}}\n\n'
            b'event: message_delta\n'
            b'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},'
            b'"usage":{"output_tokens":5}}\n\n'
        )
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        self.wfile.write(sse)

    def log_message(self, *a):
        pass


class _UpstreamJSON(BaseHTTPRequestHandler):
    """Mock Anthropic: returns a NON-streaming JSON response with a secret in content.

    Exercises the buffered (non-SSE) branch of the proxy's _forward tee.
    """
    def do_POST(self):
        self.rfile.read(int(self.headers.get("content-length", 0) or 0))
        body = (b'{"model":"claude-sonnet-4-6","stop_reason":"end_turn",'
                b'"content":[{"type":"text","text":"token ' + SECRET.encode() + b' done"}],'
                b'"usage":{"input_tokens":3,"output_tokens":5}}')
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


class _Langfuse(BaseHTTPRequestHandler):
    received = []

    def do_POST(self):
        n = int(self.headers.get("content-length", 0) or 0)
        body = self.rfile.read(n)
        _Langfuse.received.append((self.headers.get("Authorization"), body))
        self.send_response(207)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"successes":[],"errors":[]}')

    def log_message(self, *a):
        pass


def _serve(handler):
    port = _free_port()
    srv = ThreadingHTTPServer(("127.0.0.1", port), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, port


@pytest.mark.skipif(not PROXY.exists(), reason="pii-proxy-server.py missing")
def test_capture_forwards_scrubbed_trace_to_langfuse():
    _Langfuse.received.clear()
    up_srv, up_port = _serve(_Upstream)
    lf_srv, lf_port = _serve(_Langfuse)
    proxy_port = _free_port()

    env = dict(os.environ)
    env.update({
        "ANTHROPIC_UPSTREAM_URL": f"http://127.0.0.1:{up_port}",
        "PII_PROXY_PORT": str(proxy_port),
        "PII_PROXY_MASKING_LEVEL": "off",
        "PII_PROXY_SUPERVISE": "false",
        "PII_PROXY_LOG_DIR": "/tmp/lf-e2e-logs",
        "USE_LANGFUSE_CAPTURE": "true",
        "LANGFUSE_HOST": f"http://127.0.0.1:{lf_port}",
        "LANGFUSE_PUBLIC_KEY": "pk-test",
        "LANGFUSE_SECRET_KEY": "sk-test",
        "ICLAUDE_PROJECT_ID": "myrepo",
        "ICLAUDE_SESSION_ID": "abcdef012345",
    })
    proc = subprocess.Popen([sys.executable, str(PROXY)], env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        # Wait for the proxy port to accept connections.
        for _ in range(50):
            try:
                socket.create_connection(("127.0.0.1", proxy_port), timeout=0.2).close()
                break
            except OSError:
                time.sleep(0.2)
        else:
            pytest.fail("proxy did not start")

        import urllib.request
        req = urllib.request.Request(
            f"http://127.0.0.1:{proxy_port}/v1/messages",
            data=b'{"model":"claude-sonnet-4-6","max_tokens":16,'
                 b'"messages":[{"role":"user","content":"hi"}]}',
            headers={"Content-Type": "application/json", "x-api-key": "test"},
        )
        resp_body = urllib.request.urlopen(req, timeout=10).read()
        # Client still receives the raw completion (capture never alters the client stream).
        assert SECRET.encode() in resp_body

        # Langfuse should have received exactly one batch within a short window.
        for _ in range(25):
            if _Langfuse.received:
                break
            time.sleep(0.2)
        assert _Langfuse.received, "Langfuse received no ingestion POST"
        auth, body = _Langfuse.received[0]
        assert auth == "Basic " + __import__("base64").b64encode(b"pk-test:sk-test").decode()
        payload = json.loads(body)
        types = [e["type"] for e in payload["batch"]]
        assert types == ["trace-create", "generation-create"]
        assert payload["batch"][0]["body"]["tags"] == ["project:myrepo"]
        # The secret must be scrubbed out of the Langfuse copy of the completion.
        assert SECRET not in body.decode()
    finally:
        proc.terminate()
        proc.wait(timeout=5)
        up_srv.shutdown()
        lf_srv.shutdown()


@pytest.mark.skipif(not PROXY.exists(), reason="pii-proxy-server.py missing")
def test_capture_forwards_scrubbed_buffered_response():
    # Buffered (non-SSE) branch: a JSON upstream response is fully buffered, teed, scrubbed.
    _Langfuse.received.clear()
    up_srv, up_port = _serve(_UpstreamJSON)
    lf_srv, lf_port = _serve(_Langfuse)
    proxy_port = _free_port()

    env = dict(os.environ)
    env.update({
        "ANTHROPIC_UPSTREAM_URL": f"http://127.0.0.1:{up_port}",
        "PII_PROXY_PORT": str(proxy_port),
        "PII_PROXY_MASKING_LEVEL": "off",
        "PII_PROXY_SUPERVISE": "false",
        "PII_PROXY_LOG_DIR": "/tmp/lf-e2e-logs",
        "USE_LANGFUSE_CAPTURE": "true",
        "LANGFUSE_HOST": f"http://127.0.0.1:{lf_port}",
        "LANGFUSE_PUBLIC_KEY": "pk-test",
        "LANGFUSE_SECRET_KEY": "sk-test",
        "ICLAUDE_PROJECT_ID": "myrepo",
        "ICLAUDE_SESSION_ID": "abcdef012345",
    })
    proc = subprocess.Popen([sys.executable, str(PROXY)], env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(50):
            try:
                socket.create_connection(("127.0.0.1", proxy_port), timeout=0.2).close()
                break
            except OSError:
                time.sleep(0.2)
        else:
            pytest.fail("proxy did not start")

        import urllib.request
        req = urllib.request.Request(
            f"http://127.0.0.1:{proxy_port}/v1/messages",
            data=b'{"model":"claude-sonnet-4-6","max_tokens":16,'
                 b'"messages":[{"role":"user","content":"hi"}]}',
            headers={"Content-Type": "application/json", "x-api-key": "test"},
        )
        resp_body = urllib.request.urlopen(req, timeout=10).read()
        # Client receives the raw buffered JSON (capture never alters the client response).
        assert SECRET.encode() in resp_body

        for _ in range(25):
            if _Langfuse.received:
                break
            time.sleep(0.2)
        assert _Langfuse.received, "Langfuse received no ingestion POST"
        _auth, body = _Langfuse.received[0]
        payload = json.loads(body)
        assert [e["type"] for e in payload["batch"]] == ["trace-create", "generation-create"]
        gen = payload["batch"][1]["body"]
        # Parsed from the buffered JSON body: model + stop_reason captured.
        assert gen["model"] == "claude-sonnet-4-6"
        assert gen["metadata"]["stop_reason"] == "end_turn"
        # The secret must be scrubbed out of the Langfuse copy of the buffered completion.
        assert SECRET not in body.decode()
    finally:
        proc.terminate()
        proc.wait(timeout=5)
        up_srv.shutdown()
        lf_srv.shutdown()


@pytest.mark.skipif(not PROXY.exists(), reason="pii-proxy-server.py missing")
def test_capture_failsoft_when_langfuse_down():
    up_srv, up_port = _serve(_Upstream)
    proxy_port = _free_port()
    dead_port = _free_port()  # nothing listens here

    env = dict(os.environ)
    env.update({
        "ANTHROPIC_UPSTREAM_URL": f"http://127.0.0.1:{up_port}",
        "PII_PROXY_PORT": str(proxy_port),
        "PII_PROXY_MASKING_LEVEL": "off",
        "PII_PROXY_SUPERVISE": "false",
        "PII_PROXY_LOG_DIR": "/tmp/lf-e2e-logs",
        "USE_LANGFUSE_CAPTURE": "true",
        "LANGFUSE_HOST": f"http://127.0.0.1:{dead_port}",
        "LANGFUSE_PUBLIC_KEY": "pk-test",
        "LANGFUSE_SECRET_KEY": "sk-test",
        "ICLAUDE_PROJECT_ID": "myrepo",
        "ICLAUDE_SESSION_ID": "abcdef012345",
    })
    proc = subprocess.Popen([sys.executable, str(PROXY)], env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(50):
            try:
                socket.create_connection(("127.0.0.1", proxy_port), timeout=0.2).close()
                break
            except OSError:
                time.sleep(0.2)
        else:
            pytest.fail("proxy did not start")
        import urllib.request
        req = urllib.request.Request(
            f"http://127.0.0.1:{proxy_port}/v1/messages",
            data=b'{"model":"claude-sonnet-4-6","max_tokens":16,'
                 b'"messages":[{"role":"user","content":"hi"}]}',
            headers={"Content-Type": "application/json"},
        )
        # Client request still succeeds even though Langfuse is unreachable.
        body = urllib.request.urlopen(req, timeout=10).read()
        assert SECRET.encode() in body
    finally:
        proc.terminate()
        proc.wait(timeout=5)
        up_srv.shutdown()
