#!/usr/bin/env python3
"""
PII-Proxy Server - HTTP proxy for Presidio NLP masking.

Intercepts POST /v1/messages requests to Anthropic API,
scans system prompt + messages[] + tool_results for PII/secrets,
forwards masked request to ANTHROPIC_UPSTREAM_URL.

Usage:
    python3 server.py [--port PORT] [--log-dir DIR]

Environment:
    ANTHROPIC_UPSTREAM_URL  - upstream API URL (default: https://api.anthropic.com)
    PII_PROXY_PORT          - default listen port (default: 9000)
    PII_PROXY_LOG_DIR       - log directory (default: /tmp/pii-proxy-logs)
    PII_PROXY_ENABLE_FALLBACK - use regex if Presidio unavailable (default: true)
"""
from __future__ import annotations

import argparse
import http.server
import json
import logging
import os
import re
import signal
import socket
import sys
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Deterministic regex patterns (ported from redact-secrets.py)
# Applied when Presidio is unavailable or as pre-filter
# ---------------------------------------------------------------------------
REDACT_PATTERNS: list[tuple[re.Pattern, str, str]] = [
    (re.compile(r'\bsk-(?:ant-api03-|ant-|proj-|or-v1-)?[A-Za-z0-9\-_]{20,}'),
     '[API_KEY_REDACTED]', 'Anthropic/OpenAI/Stripe API key'),
    (re.compile(r'\bAKIA[0-9A-Z]{16}\b'),
     '[AWS_ACCESS_KEY_ID]', 'AWS Access Key ID'),
    (re.compile(
        r'(?i)((?:aws[_\-]?secret[_\-]?(?:access[_\-]?)?key|AWS_SECRET_ACCESS_KEY)'
        r'\s*[=:]\s*)["\']?[A-Za-z0-9/+]{40}["\']?'),
     r'\1[AWS_SECRET_KEY_REDACTED]', 'AWS Secret Access Key'),
    (re.compile(
        r'-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED |PGP )?PRIVATE KEY(?:-----| BLOCK-----)'
        r'[\s\S]*?'
        r'-----END (?:RSA |EC |DSA |OPENSSH |ENCRYPTED |PGP )?PRIVATE KEY(?:-----| BLOCK-----)'),
     '[PRIVATE_KEY_REDACTED]', 'PEM private key block'),
    (re.compile(r'\bgh[pousr]_[A-Za-z0-9_]{36,}\b'),
     '[GITHUB_TOKEN]', 'GitHub token'),
    (re.compile(r'\bgithub_pat_[A-Za-z0-9_]{82,}\b'),
     '[GITHUB_TOKEN]', 'GitHub fine-grained PAT'),
    (re.compile(r'([a-zA-Z][a-zA-Z0-9+\-.]*://)[^:@\s/]+:[^@\s/]+@'),
     r'\1[CREDENTIALS]@', 'credentials in URL'),
    (re.compile(
        r'(?i)((?:password|passwd|pwd|db_pass|pgpassword)\s*[=:]\s*)'
        r'(?!\$\{)'
        r'(?:["\']([^"\']{8,})["\']|([^\s#\n"\'$]{8,}))'),
     r'\1"[PASSWORD_REDACTED]"', 'password in config'),
    (re.compile(
        r'(?i)((?:secret|api[_\-]?key|access[_\-]?token|auth[_\-]?token)'
        r'\s*[=:]\s*)["\']([A-Za-z0-9\-_./+=]{16,})["\']'),
     r'\1"[SECRET_REDACTED]"', 'generic secret/token'),
    (re.compile(r'\beyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]*'),
     '[JWT_REDACTED]', 'JWT token'),
    (re.compile(r'\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\b'),
     '[CARD_NUMBER_REDACTED]', 'credit card number'),
    (re.compile(
        r'(?m)^((?:export\s+)?[A-Z][A-Z0-9_]*'
        r'(?:SECRET|TOKEN|KEY|PASSWORD|PASSWD|PWD|PASS|APIKEY)'
        r'[A-Z0-9_]*\s*=\s*)'
        r'(?!["\']?\$\{)'
        r'(?!["\']?\[)'
        r'([^\s#\n]{20,})'),
     r'\1[REDACTED]', '.env secret variable'),
]

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
UPSTREAM_URL = os.environ.get('ANTHROPIC_UPSTREAM_URL', 'https://api.anthropic.com')
DEFAULT_PORT = int(os.environ.get('PII_PROXY_PORT', '9000'))
LOG_DIR = Path(os.environ.get('PII_PROXY_LOG_DIR', '/tmp/pii-proxy-logs'))
ENABLE_FALLBACK = os.environ.get('PII_PROXY_ENABLE_FALLBACK', 'true').lower() != 'false'

# Presidio globals (lazy-loaded)
_analyzer = None
_anonymizer = None
_presidio_ready = False

log = logging.getLogger('pii-proxy')


def setup_logging(log_dir: Path) -> None:
    log_dir.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s %(levelname)s %(message)s',
        handlers=[
            logging.FileHandler(log_dir / 'access.log'),
            logging.StreamHandler(sys.stderr),
        ],
    )


def init_presidio() -> bool:
    """Lazy-initialize Presidio NLP engine. Returns True if ready."""
    global _analyzer, _anonymizer, _presidio_ready
    if _presidio_ready:
        return True
    try:
        from presidio_analyzer import AnalyzerEngine
        from presidio_anonymizer import AnonymizerEngine
        _analyzer = AnalyzerEngine()
        _anonymizer = AnonymizerEngine()
        # Warm up with a test call
        _analyzer.analyze(text='test@example.com', language='en')
        _presidio_ready = True
        log.info('Presidio NLP ready')
        return True
    except Exception as exc:
        log.warning('Presidio unavailable: %s', exc)
        return False


def regex_mask(text: str) -> tuple[str, list[str]]:
    """Apply deterministic regex patterns. Returns (masked_text, [found_descriptions])."""
    found: list[str] = []
    for pattern, replacement, description in REDACT_PATTERNS:
        new_text = pattern.sub(replacement, text)
        if new_text != text:
            found.append(description)
            text = new_text
    return text, found


def presidio_mask(text: str) -> tuple[str, list[str]]:
    """Apply Presidio NLP masking. Falls back to regex on failure."""
    if not _presidio_ready and not init_presidio():
        if ENABLE_FALLBACK:
            masked, found = regex_mask(text)
            return masked, [f'[regex-fallback] {d}' for d in found]
        return text, []
    try:
        results = _analyzer.analyze(text=text, language='en')
        if not results:
            # No PII found by Presidio - still apply regex for secrets
            return regex_mask(text)
        from presidio_anonymizer.entities import OperatorConfig
        anonymized = _anonymizer.anonymize(
            text=text,
            analyzer_results=results,
            operators={'DEFAULT': OperatorConfig('replace', {'new_value': '[PII_REDACTED]'})},
        )
        # Also apply regex patterns on top of Presidio output
        masked, regex_found = regex_mask(anonymized.text)
        entity_types = list({r.entity_type for r in results})
        return masked, entity_types + regex_found
    except Exception as exc:
        log.warning('Presidio masking error: %s - using regex fallback', exc)
        return regex_mask(text)


def mask_content_block(block: Any) -> Any:
    """Mask a single content block (text, tool_result, etc.)."""
    if isinstance(block, str):
        masked, _ = presidio_mask(block)
        return masked
    if not isinstance(block, dict):
        return block
    block_type = block.get('type', '')
    if block_type == 'text':
        masked, _ = presidio_mask(block.get('text', ''))
        return {**block, 'text': masked}
    if block_type == 'tool_result':
        content = block.get('content', '')
        if isinstance(content, str):
            masked, _ = presidio_mask(content)
            return {**block, 'content': masked}
        if isinstance(content, list):
            return {**block, 'content': [mask_content_block(b) for b in content]}
    return block


def mask_request_body(body: dict) -> tuple[dict, list[str]]:
    """Mask PII in system prompt, messages, and tool results."""
    masked_body = dict(body)
    all_found: list[str] = []

    # System prompt
    if 'system' in body:
        system = body['system']
        if isinstance(system, str):
            masked, found = presidio_mask(system)
            masked_body['system'] = masked
            all_found.extend(found)
        elif isinstance(system, list):
            new_system = [mask_content_block(b) for b in system]
            masked_body['system'] = new_system

    # Messages
    if 'messages' in body and isinstance(body['messages'], list):
        new_messages = []
        for msg in body['messages']:
            if not isinstance(msg, dict):
                new_messages.append(msg)
                continue
            content = msg.get('content', '')
            if isinstance(content, str):
                masked, found = presidio_mask(content)
                new_messages.append({**msg, 'content': masked})
                all_found.extend(found)
            elif isinstance(content, list):
                new_content = [mask_content_block(b) for b in content]
                new_messages.append({**msg, 'content': new_content})
            else:
                new_messages.append(msg)
        masked_body['messages'] = new_messages

    return masked_body, all_found


def find_available_port(start: int = 9000, end: int = 9100) -> int:
    """Find first available port in range."""
    for port in range(start, end + 1):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(('127.0.0.1', port))
                return port
            except OSError:
                continue
    raise RuntimeError(f'No available port in range {start}-{end}')


class PIIProxyHandler(http.server.BaseHTTPRequestHandler):
    """HTTP request handler for PII-proxy."""

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        # Suppress default HTTP server logging (we use our own)
        pass

    def do_GET(self) -> None:
        if self.path == '/api/health':
            self._health()
        else:
            self._not_found()

    def do_POST(self) -> None:
        if '/v1/messages' in self.path:
            self._proxy_messages()
        else:
            self._proxy_passthrough()

    def _health(self) -> None:
        body = json.dumps({
            'status': 'ready',
            'analyzer_ready': _presidio_ready,
            'upstream': UPSTREAM_URL,
            'fallback_enabled': ENABLE_FALLBACK,
        }).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _not_found(self) -> None:
        self.send_response(404)
        self.end_headers()

    def _proxy_messages(self) -> None:
        """Intercept, mask PII, and forward /v1/messages."""
        length = int(self.headers.get('Content-Length', 0))
        raw_body = self.rfile.read(length) if length else b''

        try:
            body = json.loads(raw_body)
        except (json.JSONDecodeError, ValueError):
            body = None

        if body:
            masked_body, found = mask_request_body(body)
            if found:
                log.info('Masked %d item(s): %s', len(found),
                         ', '.join(dict.fromkeys(found)))
            out_body = json.dumps(masked_body).encode()
        else:
            out_body = raw_body

        self._forward(out_body)

    def _proxy_passthrough(self) -> None:
        """Forward non-messages requests as-is."""
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length else b''
        self._forward(body)

    def _forward(self, body: bytes) -> None:
        """Forward request to upstream and stream response back."""
        target = UPSTREAM_URL.rstrip('/') + self.path
        headers = {
            k: v for k, v in self.headers.items()
            if k.lower() not in ('host', 'content-length', 'transfer-encoding')
        }
        headers['Content-Length'] = str(len(body))

        req = urllib.request.Request(target, data=body, headers=headers, method=self.command)
        try:
            with urllib.request.urlopen(req) as resp:
                self.send_response(resp.status)
                for key, val in resp.headers.items():
                    if key.lower() not in ('transfer-encoding', 'connection'):
                        self.send_header(key, val)
                self.end_headers()

                is_streaming = 'text/event-stream' in (resp.headers.get('Content-Type', ''))
                if is_streaming:
                    # Stream SSE without buffering
                    while True:
                        chunk = resp.read(4096)
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                        self.wfile.flush()
                else:
                    self.wfile.write(resp.read())

        except urllib.error.HTTPError as exc:
            self.send_response(exc.code)
            self.end_headers()
            self.wfile.write(exc.read())
        except Exception as exc:
            log.error('Upstream error: %s', exc)
            self.send_response(502)
            self.end_headers()
            self.wfile.write(f'PII-proxy upstream error: {exc}'.encode())


def main() -> None:
    parser = argparse.ArgumentParser(description='PII-Proxy Server')
    parser.add_argument('--port', type=int, default=DEFAULT_PORT)
    parser.add_argument('--log-dir', default=str(LOG_DIR))
    args = parser.parse_args()

    log_dir = Path(args.log_dir)
    setup_logging(log_dir)

    # Find available port
    try:
        port = find_available_port(args.port, args.port + 100)
    except RuntimeError as exc:
        log.error(str(exc))
        sys.exit(1)

    # Write actual port to env file so shell can read it
    port_file = log_dir / 'server.port'
    port_file.write_text(str(port))

    server = http.server.HTTPServer(('127.0.0.1', port), PIIProxyHandler)

    def _shutdown(signum: int, frame: Any) -> None:
        log.info('PII-proxy shutting down (signal %d)', signum)
        server.server_close()
        port_file.unlink(missing_ok=True)
        sys.exit(0)

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    log.info('PII-proxy listening on 127.0.0.1:%d -> %s', port, UPSTREAM_URL)

    # Pre-load Presidio in background thread
    import threading
    threading.Thread(target=init_presidio, daemon=True).start()

    server.serve_forever()


if __name__ == '__main__':
    main()
