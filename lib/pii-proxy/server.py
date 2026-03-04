#!/usr/bin/env python3
"""
PII-Proxy Server - HTTP proxy for Presidio NLP masking.

Intercepts POST /v1/messages requests to Anthropic API,
scans system prompt + messages[] + tool_results for PII/secrets,
forwards masked request to ANTHROPIC_UPSTREAM_URL.

Usage:
    python3 server.py [--port PORT] [--log-dir DIR]

Environment:
    ANTHROPIC_UPSTREAM_URL    - upstream API URL (default: https://api.anthropic.com)
    PII_PROXY_PORT            - default listen port (default: 9000)
    PII_PROXY_LOG_DIR         - log directory (default: /tmp/pii-proxy-logs)
    PII_PROXY_ENABLE_FALLBACK - use regex if Presidio unavailable (default: true)
    PII_PROXY_MASKING_LEVEL   - masking aggressiveness: off|secrets|standard (default: standard)
                                  off      - pass content through unmodified (proxy still runs)
                                  secrets  - regex-only: API keys, tokens, credentials
                                  standard - full: Presidio NLP + regex (default)
    ICLAUDE_SESSION_ID        - 12-char hex session ID for per-session port file naming
"""
from __future__ import annotations

import argparse
import http.server
import json
import logging
from logging.handlers import RotatingFileHandler
import os
import random
import re
import signal
import sys
import threading
from pathlib import Path
from typing import Any

import requests as _requests
from requests.exceptions import ConnectionError as _ReqConnError, Timeout as _ReqTimeout

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
        r'\s*[=:]\s*)(["\']?)[A-Za-z0-9/+]{40}\2'),
     r'\1\2[AWS_SECRET_KEY_REDACTED]\2', 'AWS Secret Access Key'),
    (re.compile(
        r'-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED |PGP )?PRIVATE KEY(?:-----| BLOCK-----)'
        r'[\s\S]*?'
        r'-----END (?:RSA |EC |DSA |OPENSSH |ENCRYPTED |PGP )?PRIVATE KEY(?:-----| BLOCK-----)'),
     '[PRIVATE_KEY_REDACTED]', 'PEM private key block'),
    (re.compile(r'\bgh[pousr]_[A-Za-z0-9_]{36,}\b'),
     '[GITHUB_TOKEN]', 'GitHub token'),
    (re.compile(r'\bgithub_pat_[A-Za-z0-9_]{82,}\b'),
     '[GITHUB_TOKEN]', 'GitHub fine-grained PAT'),
    (re.compile(r'\bhf_[A-Za-z0-9_]{36,}\b'),
     '[HF_TOKEN_REDACTED]', 'HuggingFace API token'),
    (re.compile(r'\bgsk_[A-Za-z0-9\-_]{50,}\b'),
     '[GROQ_API_KEY]', 'Groq API key'),
    (re.compile(r'\bAIzaSy[A-Za-z0-9_\-]{32,}\b'),
     '[GOOGLE_API_KEY]', 'Google AI Studio API key'),
    (re.compile(r'([a-zA-Z][a-zA-Z0-9+\-.]*://)(?:[^@\s/]*@)+'),
     r'\1[CREDENTIALS]@', 'credentials in URL'),
    (re.compile(
        r'(?i)((?:password|passwd|pwd|db_pass|pgpassword)\s*[=:]\s*)'
        r'(?:["\'](?!\$\{)((?:[^"\'\\]|\\.){8,})["\']|([^\s#\n"\'$]{8,}))'),
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
def _validate_upstream_url(url: str) -> str:
    """Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://, etc.)."""
    import urllib.parse
    parsed = urllib.parse.urlparse(url)
    scheme = parsed.scheme.lower()
    host = parsed.hostname or ''
    if scheme == 'https':
        return url
    if scheme == 'http' and host in ('127.0.0.1', 'localhost', '::1', '[::1]'):
        return url
    raise ValueError(
        f'ANTHROPIC_UPSTREAM_URL scheme "{scheme}://" is not allowed. '
        'Only https:// or http://localhost are permitted.'
    )


UPSTREAM_URL = _validate_upstream_url(
    os.environ.get('ANTHROPIC_UPSTREAM_URL', 'https://api.anthropic.com')
)
try:
    DEFAULT_PORT = int(os.environ.get('PII_PROXY_PORT', '9000'))
except (ValueError, TypeError):
    DEFAULT_PORT = 9000
LOG_DIR = Path(os.environ.get('PII_PROXY_LOG_DIR', '/tmp/pii-proxy-logs'))
ENABLE_FALLBACK = os.environ.get('PII_PROXY_ENABLE_FALLBACK', 'true').lower() != 'false'

# Masking level: controls aggressiveness of content masking.
#   'off'      - no masking; content forwarded unchanged (proxy still runs for auth)
#   'secrets'  - regex-only: API keys, tokens, credentials, passwords (fast, no NLP)
#   'standard' - full masking: Presidio NLP + regex (default)
_raw_masking_level = os.environ.get('PII_PROXY_MASKING_LEVEL', 'standard').lower().strip()
MASKING_LEVEL: str = _raw_masking_level if _raw_masking_level in ('off', 'secrets', 'standard') else 'standard'

# ---------------------------------------------------------------------------
# HTTP session (requests library — handles HTTPS proxies correctly via urllib3,
# unlike Python's stdlib urllib.request which can't TLS-handshake to the proxy
# itself, causing BadStatusLine on HTTPS_PROXY=https://... configurations).
# ---------------------------------------------------------------------------
# SSL verification: disabled when NODE_TLS_REJECT_UNAUTHORIZED=0 (insecure mode).
# Custom CA cert: reads REQUESTS_CA_BUNDLE or NODE_EXTRA_CA_CERTS (Node.js compat).
def _build_ssl_verify():
    if os.environ.get('NODE_TLS_REJECT_UNAUTHORIZED') == '0':
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        return False
    ca = os.environ.get('REQUESTS_CA_BUNDLE') or os.environ.get('NODE_EXTRA_CA_CERTS')
    return ca if ca else True

_SSL_VERIFY = _build_ssl_verify()
_HTTP_SESSION = _requests.Session()
_HTTP_SESSION.trust_env = True  # respect HTTPS_PROXY / HTTP_PROXY env vars

# Trusted API key from proxy's own environment.
# Used to re-inject credentials after stripping inbound auth headers,
# preventing credential relay by other local processes.
# Empty string → OAuth mode: auth headers forwarded as-is (no API key to inject).
_API_KEY_FROM_ENV = os.environ.get('ANTHROPIC_API_KEY', '')

# Presidio globals (lazy-loaded, protected by _presidio_lock)
_analyzer = None
_anonymizer = None
_presidio_ready = False
_presidio_failed = False   # set True on import failure; prevents per-request retry loop
_presidio_lock = threading.Lock()

log = logging.getLogger('pii-proxy')


def setup_logging(log_dir: Path) -> None:
    """Configure 'pii-proxy' logger directly (not root logger) for reliability."""
    log_dir.mkdir(parents=True, exist_ok=True)
    fmt = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    file_handler = RotatingFileHandler(
        log_dir / 'access.log',
        maxBytes=5 * 1024 * 1024,  # 5 MB per file
        backupCount=3,
    )
    file_handler.setFormatter(fmt)
    stderr_handler = logging.StreamHandler(sys.stderr)
    stderr_handler.setFormatter(fmt)
    log.addHandler(file_handler)
    log.addHandler(stderr_handler)
    log.setLevel(logging.INFO)


def init_presidio() -> bool:
    """Lazy-initialize Presidio NLP engine. Returns True if ready.

    Thread-safe: _presidio_lock ensures only one thread initializes Presidio.
    _presidio_failed is checked before lock acquisition to avoid per-request
    lock contention when Presidio is permanently unavailable (e.g. not installed).
    Once failed, never retried — callers fall back to regex masking.
    """
    global _analyzer, _anonymizer, _presidio_ready, _presidio_failed
    # Fast path: check failure flag without acquiring lock (GIL-safe, flag is
    # set once and never reset — no data race)
    if _presidio_failed:
        return False
    with _presidio_lock:
        if _presidio_ready:
            return True
        if _presidio_failed:
            return False
        try:
            from presidio_analyzer import AnalyzerEngine  # type: ignore[import]
            from presidio_anonymizer import AnonymizerEngine  # type: ignore[import]
            _analyzer = AnalyzerEngine()
            _anonymizer = AnonymizerEngine()
            # Warm up with a test call (spaCy model load happens here)
            _analyzer.analyze(text='test@example.com', language='en')
            _presidio_ready = True
            log.info('Presidio NLP ready')
            return True
        except Exception as exc:
            log.warning('Presidio unavailable: %s', exc)
            _presidio_failed = True  # prevent future retries
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


_MAX_NESTING_DEPTH = 50  # API payloads realistically max at ~5 levels; 50 is generous


def _mask_value(value: Any, _depth: int = 0) -> tuple[Any, list[str]]:
    """Recursively mask PII in a JSON value (str, dict, list).

    Handles arbitrary nesting depth: dict-of-dicts, list-of-dicts, etc.
    Non-string scalars (bool, int, float, None) are returned unchanged.
    _depth is a guard against DoS via deeply nested payloads — values beyond
    _MAX_NESTING_DEPTH are passed through unmasked rather than crashing with
    RecursionError (Python default limit is ~1000 frames).
    """
    if _depth > _MAX_NESTING_DEPTH:
        return value, []  # skip unrealistically deep nesting, avoid RecursionError
    if isinstance(value, str):
        return presidio_mask(value)
    if isinstance(value, dict):
        result: dict[str, Any] = {}
        found: list[str] = []
        for k, v in value.items():
            masked_v, f = _mask_value(v, _depth + 1)
            result[k] = masked_v
            found.extend(f)
        return result, found
    if isinstance(value, list):
        result_list: list[Any] = []
        list_found: list[str] = []
        for item in value:
            masked_item, f = _mask_value(item, _depth + 1)
            result_list.append(masked_item)
            list_found.extend(f)
        return result_list, list_found
    return value, []  # bool, int, float, None — not maskable


def presidio_mask(text: str) -> tuple[str, list[str]]:
    """Apply masking according to MASKING_LEVEL.

    'off'      - return text unchanged (no masking)
    'secrets'  - regex-only masking (API keys, tokens, passwords, credentials)
    'standard' - Presidio NLP + regex; falls back to regex when Presidio unavailable
    """
    if MASKING_LEVEL == 'off':
        return text, []

    if MASKING_LEVEL == 'secrets':
        masked, found = regex_mask(text)
        return masked, found

    # standard: Presidio NLP + regex fallback
    # Short-circuit when Presidio permanently failed: do NOT call init_presidio().
    # When _presidio_failed is True, the `or` short-circuits — init_presidio() is skipped.
    if _presidio_failed or (not _presidio_ready and not init_presidio()):
        if ENABLE_FALLBACK:
            masked, found = regex_mask(text)
            return masked, [f'[regex-fallback] {d}' for d in found]
        return text, []
    try:
        assert _analyzer is not None
        results = _analyzer.analyze(text=text, language='en')
        if not results:
            # No PII found by Presidio - still apply regex for secrets
            return regex_mask(text)
        from presidio_anonymizer.entities import OperatorConfig  # type: ignore[import]
        assert _anonymizer is not None
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


def mask_content_block(block: Any) -> tuple[Any, list[str]]:
    """Mask a single content block. Returns (masked_block, [found_descriptions])."""
    if isinstance(block, str):
        masked, found = presidio_mask(block)
        return masked, found
    if not isinstance(block, dict):
        return block, []
    block_type = block.get('type', '')
    if block_type == 'text':
        masked, found = presidio_mask(block.get('text', ''))
        return {**block, 'text': masked}, found
    if block_type == 'tool_use':
        # Recursively mask PII in tool input (any JSON structure: dict, list, str, nested)
        if 'input' not in block or block['input'] is None:
            return block, []
        masked_input, block_found = _mask_value(block['input'])
        return {**block, 'input': masked_input}, block_found
    if block_type == 'tool_result':
        if 'content' not in block:
            return block, []
        content = block['content']
        if isinstance(content, list):
            # List of content blocks — recursively mask each via mask_content_block
            new_content: list[Any] = []
            list_found: list[str] = []
            for b in content:
                masked_b, f = mask_content_block(b)
                new_content.append(masked_b)
                list_found.extend(f)
            return {**block, 'content': new_content}, list_found
        # str or dict: _mask_value handles both, including nested dicts
        masked_content, found = _mask_value(content)
        return {**block, 'content': masked_content}, found
    if block_type == 'document':
        # Mask text-type document source and context field
        doc_found: list[str] = []
        new_block = dict(block)
        source = block.get('source', {})
        if isinstance(source, dict) and source.get('type') == 'text':
            raw = source.get('data') or source.get('text', '')
            if isinstance(raw, str) and raw:
                masked_src, f = presidio_mask(raw)
                doc_found.extend(f)
                new_source = dict(source)
                if 'data' in source:
                    new_source['data'] = masked_src
                if 'text' in source:
                    new_source['text'] = masked_src
                new_block['source'] = new_source
        context = block.get('context', '')
        if isinstance(context, str) and context:
            masked_ctx, f = presidio_mask(context)
            doc_found.extend(f)
            new_block['context'] = masked_ctx
        return new_block, doc_found
    return block, []


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
            new_system: list[Any] = []
            for b in system:
                masked_b, found = mask_content_block(b)
                new_system.append(masked_b)
                all_found.extend(found)
            masked_body['system'] = new_system

    # Messages
    if 'messages' in body and isinstance(body['messages'], list):
        new_messages = []
        for msg in body['messages']:
            if not isinstance(msg, dict):
                new_messages.append(msg)
                continue
            masked_msg: dict[str, Any] = dict(msg)

            # Mask message.name (optional participant label — may contain PII)
            if isinstance(msg.get('name'), str):
                masked_name, name_found = presidio_mask(msg['name'])
                masked_msg['name'] = masked_name
                all_found.extend(name_found)

            if 'content' not in msg:
                # Preserve messages without content field (e.g. tool_use-only)
                new_messages.append(masked_msg)
                continue
            content = msg['content']
            if isinstance(content, str):
                masked, found = presidio_mask(content)
                masked_msg['content'] = masked
                all_found.extend(found)
            elif isinstance(content, list):
                new_content: list[Any] = []
                msg_found: list[str] = []
                for b in content:
                    masked_b, found = mask_content_block(b)
                    new_content.append(masked_b)
                    msg_found.extend(found)
                masked_msg['content'] = new_content
                all_found.extend(msg_found)
            new_messages.append(masked_msg)
        masked_body['messages'] = new_messages

    return masked_body, all_found


class PIIProxyHandler(http.server.BaseHTTPRequestHandler):
    """HTTP request handler for PII-proxy.

    Design: asymmetric masking — only REQUEST bodies are masked (outgoing to Anthropic).
    RESPONSE bodies are forwarded unmasked (incoming from Anthropic are already trusted).
    This protects user PII/secrets from being sent to the API.
    """

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        del format, args  # intentionally suppress default HTTP server logging

    # Headers stripped unconditionally (connection-management, hop-by-hop).
    _STRIP_ALWAYS = frozenset({'host', 'content-length', 'transfer-encoding'})
    # Auth headers stripped in API-key mode and replaced with trusted env value.
    _STRIP_AUTH = frozenset({'authorization', 'x-api-key'})

    def _build_upstream_headers(self) -> dict[str, str]:
        """Build request headers for upstream forwarding.

        In API-key mode (ANTHROPIC_API_KEY set): strips inbound auth headers
        and re-injects the trusted key from the proxy's environment. This
        prevents credential relay — a rogue local process cannot route API
        calls through the proxy using stolen credentials.

        In OAuth mode (ANTHROPIC_API_KEY empty): forwards auth headers as-is
        (there is no env-based key to inject, so stripping would break requests).
        """
        if _API_KEY_FROM_ENV:
            strip = self._STRIP_ALWAYS | self._STRIP_AUTH
        else:
            strip = self._STRIP_ALWAYS

        headers = {k: v for k, v in self.headers.items() if k.lower() not in strip}

        if _API_KEY_FROM_ENV:
            headers['x-api-key'] = _API_KEY_FROM_ENV

        return headers

    def do_GET(self) -> None:
        if self.path == '/api/health':
            self._health()
        else:
            self._proxy_passthrough()

    def do_POST(self) -> None:
        if '/v1/messages' in self.path:
            self._proxy_messages()
        else:
            self._proxy_passthrough()

    # Forward all other HTTP methods to upstream without masking
    def do_PUT(self) -> None:
        self._proxy_passthrough()

    def do_PATCH(self) -> None:
        self._proxy_passthrough()

    def do_DELETE(self) -> None:
        self._proxy_passthrough()

    def do_HEAD(self) -> None:
        # RFC 7231 §4.3.2: HEAD MUST NOT send body; forward headers only
        if self.path == '/api/health':
            self._health_head()
        else:
            self._proxy_head()

    def do_OPTIONS(self) -> None:
        self._proxy_passthrough()

    def _health(self) -> None:
        body = json.dumps({
            'status': 'ready',
            'analyzer_ready': _presidio_ready,
            'fallback_enabled': ENABLE_FALLBACK,
            'masking_level': MASKING_LEVEL,
        }).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _health_head(self) -> None:
        """HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2)."""
        body = json.dumps({
            'status': 'ready',
            'analyzer_ready': _presidio_ready,
            'fallback_enabled': ENABLE_FALLBACK,
            'masking_level': MASKING_LEVEL,
        }).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()

    # 100 MB sanity limit: prevents DoS via OOM from huge or negative Content-Length
    _MAX_BODY_BYTES = 100_000_000

    def _read_body(self) -> bytes | None:
        """Read request body with Content-Length validation.

        Handles both Content-Length and Transfer-Encoding: chunked.
        Returns None and sends 400 if Content-Length is invalid (negative, non-integer,
        or exceeds 100 MB). A negative length would cause rfile.read(-1) to consume all
        available data, bypassing PII masking and risking OOM.
        """
        te = self.headers.get('Transfer-Encoding', '').lower()
        if 'chunked' in te:
            # Chunked encoding: no Content-Length; read up to MAX_BODY_BYTES.
            # The Anthropic SDK rarely sends chunked requests, but support it defensively.
            try:
                return self.rfile.read(self._MAX_BODY_BYTES)
            except Exception:
                return b''

        raw_length = self.headers.get('Content-Length', '0')
        try:
            length = int(raw_length)
        except (ValueError, TypeError):
            self._error_response(400, 'Invalid Content-Length header')
            return None
        if length < 0 or length > self._MAX_BODY_BYTES:
            self._error_response(400, f'Content-Length {length} out of allowed range')
            return None
        return self.rfile.read(length) if length else b''

    def _error_response(self, code: int, message: str) -> None:
        body = json.dumps({'type': 'error', 'error': {'message': message}}).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _proxy_messages(self) -> None:
        """Intercept, mask PII, and forward /v1/messages."""
        raw_body = self._read_body()
        if raw_body is None:
            return  # _read_body already sent error response

        if MASKING_LEVEL == 'off':
            self._forward(raw_body)
            return

        try:
            body = json.loads(raw_body)
        except (json.JSONDecodeError, ValueError):
            body = None

        if body:
            masked_body, found = mask_request_body(body)
            if found:
                # Log count only — do NOT log descriptions (metadata leak)
                log.info('Masked request: %d sensitive item(s) found', len(found))
            out_body = json.dumps(masked_body).encode()
        else:
            out_body = raw_body

        self._forward(out_body)

    def _proxy_passthrough(self) -> None:
        """Forward non-messages requests as-is."""
        body = self._read_body()
        if body is None:
            return  # _read_body already sent error response
        self._forward(body)

    def _proxy_head(self) -> None:
        """Forward HEAD request and relay status + headers without body (RFC 7231 §4.3.2)."""
        target = UPSTREAM_URL.rstrip('/') + self.path
        headers = self._build_upstream_headers()
        try:
            resp = _HTTP_SESSION.request(
                method='HEAD',
                url=target,
                headers=headers,
                stream=False,
                verify=_SSL_VERIFY,
                timeout=30,
                allow_redirects=False,
            )
            self.send_response(resp.status_code)
            for key, val in resp.headers.items():
                if key.lower() not in ('transfer-encoding', 'connection'):
                    self.send_header(key, val)
            self.end_headers()
            # Intentionally no body write — RFC 7231 §4.3.2
        except (_ReqConnError, _ReqTimeout) as exc:
            log.error('Upstream HEAD error: %s', exc)
            self.send_response(502)
            self.end_headers()
        except Exception as exc:
            log.error('HEAD proxy error: %s', exc)
            self.send_response(502)
            self.end_headers()

    def _forward(self, body: bytes) -> None:
        """Forward request to upstream and stream response back.

        Uses requests (not urllib.request) because Python's stdlib urllib does NOT
        support HTTPS proxies (HTTPS_PROXY=https://...). When the proxy itself requires
        TLS, urllib connects via plain HTTP → proxy sends a TLS Alert → urllib raises
        http.client.BadStatusLine which is not a URLError subclass → silently returns
        502 'PII-proxy internal error'. requests/urllib3 handles TLS-to-proxy correctly.
        """
        target = UPSTREAM_URL.rstrip('/') + self.path
        headers = self._build_upstream_headers()
        try:
            with _HTTP_SESSION.request(
                method=self.command,
                url=target,
                headers=headers,
                data=body,
                stream=True,
                verify=_SSL_VERIFY,
                timeout=30,
                allow_redirects=False,
            ) as resp:
                self.send_response(resp.status_code)
                # Exclude headers that change after requests decompresses the body:
                # content-encoding (decoded), content-length (recalculated below),
                # transfer-encoding / connection (hop-by-hop, not for client).
                _skip = ('transfer-encoding', 'connection', 'content-encoding', 'content-length')
                for key, val in resp.headers.items():
                    if key.lower() not in _skip:
                        self.send_header(key, val)

                is_streaming = 'text/event-stream' in resp.headers.get('Content-Type', '')
                if is_streaming:
                    # SSE: stream chunks without buffering; no Content-Length.
                    self.end_headers()
                    for chunk in resp.iter_content(chunk_size=4096):
                        if chunk:
                            try:
                                self.wfile.write(chunk)
                                self.wfile.flush()
                            except (BrokenPipeError, ConnectionResetError):
                                break  # client disconnected mid-stream
                else:
                    content = resp.content  # fully buffered (already decompressed by requests)
                    self.send_header('Content-Length', str(len(content)))
                    self.end_headers()
                    self.wfile.write(content)

        except (_ReqConnError, _ReqTimeout) as exc:
            # Network errors: proxy unreachable, DNS failure, connection refused, timeout
            log.error('Upstream connection error: %s', exc)
            error_body = json.dumps({
                'type': 'error',
                'error': {'type': 'api_error', 'message': 'PII proxy upstream unavailable'},
            }).encode()
            self.send_response(502)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(error_body)))
            self.end_headers()
            self.wfile.write(error_body)
        except Exception as exc:
            log.error('Proxy error: %s', exc)
            self.send_response(502)
            self.end_headers()
            self.wfile.write(b'PII-proxy internal error')


def main() -> None:
    parser = argparse.ArgumentParser(description='PII-Proxy Server')
    parser.add_argument('--port', type=int, default=DEFAULT_PORT)
    parser.add_argument('--log-dir', default=str(LOG_DIR))
    args = parser.parse_args()

    log_dir = Path(args.log_dir)
    setup_logging(log_dir)

    # Port selection strategy:
    #   port == 0  → auto-select a random free port from [PORT_MIN, PORT_MAX]
    #   port != 0  → try exact port first, then fall back to range
    # Trying up to 30 random candidates from the range before last-resort bind(0).
    # Each attempt is an atomic bind (no TOCTOU race).
    try:
        _port_min = int(os.environ.get('PII_PROXY_PORT_MIN', '20000'))
        _port_max = int(os.environ.get('PII_PROXY_PORT_MAX', '40000'))
    except (ValueError, TypeError):
        _port_min, _port_max = 20000, 40000
    # Sanity check: must be valid unprivileged range with at least one port
    if not (1024 <= _port_min < _port_max <= 65535):
        log.warning('Invalid port range [%d, %d]; falling back to [20000, 40000]', _port_min, _port_max)
        _port_min, _port_max = 20000, 40000
    server = None

    if args.port != 0:
        # Explicit port requested — honour it if free
        try:
            server = http.server.HTTPServer(('127.0.0.1', args.port), PIIProxyHandler)
        except OSError:
            pass  # fall through to range selection below

    if server is None:
        # Auto-select: probe a random sample from the range to spread sessions
        # across 20000-40000 without sequential clustering.
        _n = min(30, _port_max - _port_min + 1)
        for _p in random.sample(range(_port_min, _port_max + 1), _n):
            try:
                server = http.server.HTTPServer(('127.0.0.1', _p), PIIProxyHandler)
                break
            except OSError:
                continue
        if server is None:
            # Last resort: let OS pick any free port
            server = http.server.HTTPServer(('127.0.0.1', 0), PIIProxyHandler)

    port = server.server_address[1]  # actual port assigned by OS

    # Per-session port file: named by ICLAUDE_SESSION_ID so concurrent sessions each
    # write their own file and never overwrite each other (eliminates the global server.port
    # race where session-2 could overwrite session-1's file before session-1 read it).
    # Validate session_id to hex-only (12 chars) to prevent path traversal via env variable.
    _raw_sid = os.environ.get('ICLAUDE_SESSION_ID', '')
    session_id = _raw_sid if re.fullmatch(r'[0-9a-f]{12}', _raw_sid) else 'default'
    port_file = log_dir / f'pii-proxy-{session_id}.port'
    port_file.write_text(str(port))

    def _shutdown(signum: int, _: Any) -> None:
        log.info('PII-proxy shutting down (signal %d)', signum)
        server.server_close()
        port_file.unlink(missing_ok=True)
        sys.exit(0)

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    log.info('PII-proxy listening on 127.0.0.1:%d -> %s (masking_level=%s)', port, UPSTREAM_URL, MASKING_LEVEL)

    # Pre-load Presidio in background thread only when needed (threading imported at top)
    if MASKING_LEVEL == 'standard':
        threading.Thread(target=init_presidio, daemon=True).start()

    server.serve_forever()


if __name__ == '__main__':
    main()
