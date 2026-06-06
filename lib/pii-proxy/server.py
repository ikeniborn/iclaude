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
    PII_PROXY_LOG_LEVEL       - logging verbosity: info|debug (default: info)
                                  info     - log count of masked items only (default)
                                  debug    - log count + entity types/descriptions found (PII metadata);
                                             log file is auto-deleted on session exit
    PII_PROXY_CONNECT_TIMEOUT - upstream TCP connect timeout, seconds (default: 10)
    PII_PROXY_READ_TIMEOUT    - upstream read timeout, seconds (default: 300; raise for
                                long extended-thinking responses)
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
import time
from pathlib import Path
from typing import Any

import requests as _requests
from requests.adapters import HTTPAdapter
from requests.exceptions import ConnectionError as _ReqConnError, Timeout as _ReqTimeout
from urllib3.util.retry import Retry

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
# Tool-input keys that are structural pointers, not content — never mask.
# File paths and search patterns carry no PII; masking them corrupts conversation
# history (NLP models flag usernames/tokens in paths as PERSON entities).
# Content fields (content, old_string, new_string) are intentionally absent —
# they hold actual text that may contain PII and must still be scanned.
# ---------------------------------------------------------------------------
_TOOL_INPUT_SKIP_KEYS: frozenset[str] = frozenset({
    'file_path',      # Read, Write, Edit, NotebookEdit
    'path',           # Glob, Grep (directory scope)
    'notebook_path',  # NotebookEdit
    'command',        # Bash — paths/flags, not user-authored text
    'pattern',        # Grep — regex search expression
    'glob',           # Grep — file filter expression
})

# Regex for <system-reminder> blocks injected by Claude Code harness into user messages.
# These blocks contain trusted machine-generated content (skills list, CLAUDE.md, MEMORY.md)
# and must NOT be processed by NLP — identical rationale to skipping the `system` field.
_SYSTEM_REMINDER_RE = re.compile(
    r'(<system-reminder>[\s\S]*?</system-reminder>)',
    re.DOTALL,
)

# Known false-positive PERSON entities: product/project names that spaCy's NER
# incorrectly classifies as human names. These are filtered from Presidio results
# before anonymization to prevent over-masking of legitimate content.
_PERSON_ALLOWLIST: frozenset[str] = frozenset({
    'Claude', 'claude', 'CLAUDE',   # Anthropic product name, not a person
})

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
MASK_TOKEN: str = os.environ.get('PII_PROXY_MASK_TOKEN', 'REDACTED')

# ---------------------------------------------------------------------------
# Upstream timeouts (split connect/read; env-configurable).
# A single 30s scalar previously tripped ReadTimeout on slow time-to-first-byte
# (Opus + extended thinking + large prompts) → 502. The Anthropic SDK uses ~600s
# read for /v1/messages; 300s is a safe default that still fails fast on a dead host.
# ---------------------------------------------------------------------------
def _timeout_env(name: str, default: float) -> float:
    """Parse a positive-float timeout from env; fall back to default on missing/invalid."""
    try:
        v = float(os.environ.get(name, ''))
        return v if v > 0 else default
    except (ValueError, TypeError):
        return default


CONNECT_TIMEOUT: float = _timeout_env('PII_PROXY_CONNECT_TIMEOUT', 10.0)
READ_TIMEOUT: float = _timeout_env('PII_PROXY_READ_TIMEOUT', 300.0)

# Supervisor: re-fork the request-serving worker if it dies (OOM / kill / crash), keeping the
# listening socket — and therefore the port — stable for the proxy's whole lifetime. A Claude
# session bakes ANTHROPIC_BASE_URL once at launch; without this, a vanished worker is unrecoverable.
SUPERVISE: bool = os.environ.get('PII_PROXY_SUPERVISE', 'true').lower() != 'false'

# Restart-storm guard: if the worker dies more than _MAX_RESTARTS times within _RESTART_WINDOW
# seconds, the supervisor gives up instead of busy-looping on an unrecoverable startup crash.
_MAX_RESTARTS = 5
_RESTART_WINDOW = 10.0

# Supervisor state (module-level so the SIGTERM handler can reach them).
_supervisor_stop = False
_current_worker_pid = 0

# Log level: controls verbosity of masking log entries.
#   'info'  - log count of masked items only (default, no PII metadata in logs)
#   'debug' - log count + entity types/descriptions found (contains PII metadata;
#             log file is auto-deleted by iclaude.sh on session exit)
_raw_log_level = os.environ.get('PII_PROXY_LOG_LEVEL', 'info').lower().strip()
LOG_LEVEL: str = _raw_log_level if _raw_log_level in ('info', 'debug') else 'info'

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

# Thread-local HTTP sessions: each request-handler thread gets its own Session so
# concurrent requests don't share mutable state (cookie jar, adapter state).
# Per-thread connection pooling still applies — urllib3 pools are per-Session.
# Connect-only retry: retries connection ESTABLISHMENT (no bytes sent yet) — safe for
# the non-idempotent POST /v1/messages. read=0/status=0 → never retry after a partial
# response, so no duplicate generation or double billing.
_RETRY = Retry(
    total=None,
    connect=2,
    read=0,
    status=0,
    redirect=0,
    backoff_factor=0.5,
    raise_on_status=False,
)

_thread_local = threading.local()


def _get_http_session() -> _requests.Session:
    """Return this thread's requests.Session, creating it on first access."""
    if not hasattr(_thread_local, 'session'):
        s = _requests.Session()
        s.trust_env = True  # respect HTTPS_PROXY / HTTP_PROXY env vars
        adapter = HTTPAdapter(max_retries=_RETRY)
        s.mount('http://', adapter)
        s.mount('https://', adapter)
        _thread_local.session = s
    return _thread_local.session

# Trusted API key from proxy's own environment.
# Used to re-inject credentials after stripping inbound auth headers,
# preventing credential relay by other local processes.
# Empty string → OAuth mode: auth headers forwarded as-is (no API key to inject).
_API_KEY_FROM_ENV = os.environ.get('ANTHROPIC_API_KEY', '')

# Global masked items counter (thread-safe)
_masked_items_total: int = 0
_startup_meta: dict = {}  # populated in main() after server binds
_masked_items_lock = threading.Lock()
_server_start_time: float = 0.0  # set in main() after server binds

# Presidio globals (lazy-loaded, protected by _presidio_lock)
_analyzer = None
_anonymizer = None
_presidio_ready = False
_presidio_failed = False   # set True on import failure; prevents per-request retry loop
_presidio_lock = threading.Lock()

log = logging.getLogger('pii-proxy')


def setup_logging(log_dir: Path, session_id: str = 'default') -> None:
    """Configure 'pii-proxy' logger directly (not root logger) for reliability."""
    log_dir.mkdir(parents=True, exist_ok=True)
    fmt = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    _sid = session_id if (re.fullmatch(r'[0-9a-f]{12}', session_id) or session_id == 'shared') else 'default'
    file_handler = RotatingFileHandler(
        log_dir / f'{_sid}.log',
        maxBytes=5 * 1024 * 1024,  # 5 MB per file
        backupCount=3,
    )
    file_handler.setFormatter(fmt)
    log.addHandler(file_handler)
    log.setLevel(logging.INFO)
    if LOG_LEVEL == 'debug':
        log_path = log_dir / f'{_sid}.log'
        log.warning(
            'DEBUG mode active: this log contains PII metadata (entity types found). '
            'Log will be auto-deleted by iclaude on session exit. Path: %s',
            log_path,
        )


def _detect_spacy_models() -> list[dict[str, str]]:
    """Detect installed spaCy models from venv marker files or by probing spacy.

    Returns a list of {"lang_code": "xx", "model_name": "xx_..."} dicts.
    Falls back to probing spacy.util.is_package() if marker files are absent.
    """
    models: list[dict[str, str]] = []
    # Check marker files written by install.sh
    venv_dir = Path(sys.executable).parent.parent
    for lang, marker in [('en', 'spacy_model_en'), ('ru', 'spacy_model_ru')]:
        marker_path = venv_dir / marker
        if marker_path.is_file():
            model_name = marker_path.read_text().strip()
            if model_name:
                models.append({'lang_code': lang, 'model_name': model_name})

    if models:
        return models

    # Fallback: probe common model names via spacy
    try:
        import spacy.util  # type: ignore[import]
        for lang, candidates in [
            ('en', ['en_core_web_lg', 'en_core_web_sm']),
            ('ru', ['ru_core_news_lg', 'ru_core_news_sm']),
        ]:
            for name in candidates:
                if spacy.util.is_package(name):
                    models.append({'lang_code': lang, 'model_name': name})
                    break
    except Exception:
        pass

    return models or [{'lang_code': 'en', 'model_name': 'en_core_web_lg'}]


# Languages supported by the current Presidio instance (set during init)
_supported_languages: list[str] = []


def init_presidio() -> bool:
    """Lazy-initialize Presidio NLP engine with all available language models.

    Thread-safe: _presidio_lock ensures only one thread initializes Presidio.
    _presidio_failed is checked before lock acquisition to avoid per-request
    lock contention when Presidio is permanently unavailable (e.g. not installed).
    Once failed, never retried — callers fall back to regex masking.
    """
    global _analyzer, _anonymizer, _presidio_ready, _presidio_failed, _supported_languages
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
            from presidio_analyzer.nlp_engine import NlpEngineProvider  # type: ignore[import]
            from presidio_anonymizer import AnonymizerEngine  # type: ignore[import]

            models = _detect_spacy_models()
            langs = [m['lang_code'] for m in models]

            provider = NlpEngineProvider(nlp_configuration={
                'nlp_engine_name': 'spacy',
                'models': models,
            })
            nlp_engine = provider.create_engine()

            _analyzer = AnalyzerEngine(
                nlp_engine=nlp_engine,
                supported_languages=langs,
            )
            _anonymizer = AnonymizerEngine()
            _supported_languages = langs

            # Warm up with test calls (spaCy model load happens here)
            _analyzer.analyze(text='test@example.com', language='en')
            if 'ru' in langs:
                _analyzer.analyze(text='Иванов Иван', language='ru')

            _presidio_ready = True
            model_info = ', '.join(f"{m['lang_code']}={m['model_name']}" for m in models)
            log.info('Presidio NLP ready (models: %s)', model_info)
            return True
        except Exception as exc:
            log.warning('Presidio unavailable: %s', exc)
            _presidio_failed = True  # prevent future retries
            return False


def _snippet(value: str, max_len: int = 60) -> str:
    """Truncate a matched value for debug logging. Keeps first max_len chars."""
    value = value.replace('\n', '\\n').replace('\r', '\\r')
    return value[:max_len] + '…' if len(value) > max_len else value


def regex_mask(text: str) -> tuple[str, list[str]]:
    """Apply deterministic regex patterns. Returns (masked_text, [found_descriptions])."""
    found: list[str] = []
    for pattern, replacement, description in REDACT_PATTERNS:
        matches: list[re.Match[str]] = list(pattern.finditer(text)) if LOG_LEVEL == 'debug' else []
        new_text = pattern.sub(replacement, text)
        if new_text != text:
            if LOG_LEVEL == 'debug' and matches:
                snippets = ', '.join(
                    f'"{_snippet(m.group(0))}" → "{_snippet(pattern.sub(replacement, m.group(0)))}"'
                    for m in matches
                )
                found.append(f'{description} ({snippets})')
            else:
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

    <system-reminder> blocks are preserved unchanged in all modes — they contain
    trusted machine-generated content (Claude Code harness instructions, CLAUDE.md,
    skills list) injected into user messages, not user-authored PII.
    """
    if MASKING_LEVEL == 'off':
        return text, []

    # Preserve <system-reminder> blocks — trusted harness content injected into user
    # messages. NLP models incorrectly flag these (e.g. "Claude" as PERSON, dates, IPs).
    # Rationale mirrors the system-field skip in mask_request_body().
    if '<system-reminder>' in text:
        parts = _SYSTEM_REMINDER_RE.split(text)
        # len(parts) > 1 means at least one complete paired tag was found.
        # If the tag is unclosed (no matching </system-reminder>), split returns a
        # single-element list with the original text — fall through to normal masking
        # to avoid infinite recursion (recursive call would see the same text again).
        if len(parts) > 1:
            result_parts: list[str] = []
            all_found: list[str] = []
            for part in parts:
                if part.startswith('<system-reminder>'):
                    result_parts.append(part)           # pass through unchanged
                else:
                    masked, found = presidio_mask(part) # recurse — no full tags in parts
                    result_parts.append(masked)
                    all_found.extend(found)
            return ''.join(result_parts), all_found
        # Unclosed tag — fall through to normal masking path below

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
        # NLP entity type allowlist: only pattern-based recognizers with low false-positive rate.
        # NER-based types (PERSON, LOCATION, ORGANIZATION, DATE_TIME) are excluded:
        # they misclassify common Russian/Cyrillic words as person names (e.g. "привет",
        # "Сегодня", "После" → PERSON in both English and Russian models).
        # Technical secrets (API keys, tokens, passwords) are covered by regex below.
        _NLP_ENTITIES = [
            'EMAIL_ADDRESS',    # pattern-based, highly reliable
            'PHONE_NUMBER',     # pattern-based, reliable
            'CREDIT_CARD',      # pattern-based (Luhn check), reliable
            'IBAN_CODE',        # pattern-based, reliable
            'IP_ADDRESS',       # pattern-based, reliable
            'URL',              # pattern-based; catches credentials in URLs not covered by regex
        ]
        # Use English model only: Russian NER produces the same false positives on Cyrillic
        # text as the English model, while adding no unique pattern-based recognizer value.
        _nlp_langs = [l for l in _supported_languages if l == 'en'] or _supported_languages
        results = []
        for lang in _nlp_langs:
            results.extend(_analyzer.analyze(
                text=text, language=lang,
                entities=_NLP_ENTITIES,
                score_threshold=0.8,
            ))
        # Filter false-positive PERSON entities (product names misclassified as humans)
        results = [
            r for r in results
            if not (r.entity_type == 'PERSON' and text[r.start:r.end] in _PERSON_ALLOWLIST)
        ]
        if not results:
            # No PII found by Presidio - still apply regex for secrets
            return regex_mask(text)
        from presidio_anonymizer.entities import OperatorConfig  # type: ignore[import]
        assert _anonymizer is not None
        anonymized = _anonymizer.anonymize(
            text=text,
            analyzer_results=results,
            operators={'DEFAULT': OperatorConfig('replace', {'new_value': MASK_TOKEN})},
        )
        # Also apply regex patterns on top of Presidio output
        masked, regex_found = regex_mask(anonymized.text)
        if LOG_LEVEL == 'debug':
            entity_types = [
                f'{r.entity_type} ("{_snippet(text[r.start:r.end])}" → "{MASK_TOKEN}")'
                for r in results
            ]
        else:
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
        # Mask PII in tool input, but skip filesystem path keys — NLP models incorrectly
        # flag usernames and path tokens (e.g. "ikeniborn", "iclaude") as PERSON entities,
        # corrupting file paths in conversation history and breaking filesystem navigation.
        # Only structural path keys are skipped; content fields (content, old_string,
        # new_string, command, pattern) are still passed through presidio_mask().
        if 'input' not in block or block['input'] is None:
            return block, []
        raw_input = block['input']
        if not isinstance(raw_input, dict):
            # Non-dict input (rare): mask as-is
            masked_input, block_found = _mask_value(raw_input)
            return {**block, 'input': masked_input}, block_found
        masked_dict: dict[str, Any] = {}
        block_found: list[str] = []
        for k, v in raw_input.items():
            if k in _TOOL_INPUT_SKIP_KEYS:
                masked_dict[k] = v  # structural pointer — pass through unchanged
            else:
                masked_v, f = _mask_value(v)
                masked_dict[k] = masked_v
                block_found.extend(f)
        return {**block, 'input': masked_dict}, block_found
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


def _prefix(items: list[str], location: str) -> list[str]:
    """Prefix each found description with field location (used in debug logging)."""
    return [f'{location}: {d}' for d in items] if LOG_LEVEL == 'debug' else items


def mask_request_body(body: dict) -> tuple[dict, list[str]]:
    """Mask PII in user messages and assistant tool_use inputs only.

    Masking scope (asymmetric by design):
      - system field          → SKIPPED: contains Claude Code instructions / CLAUDE.md;
                                masking distorts model directives and breaks sessions.
      - role "user"           → MASKED fully: user text input + file contents from
                                tool_result blocks.
      - role "assistant" text → SKIPPED: Claude's own prose carries no original user PII.
      - role "assistant"      → tool_use blocks MASKED via mask_content_block():
        tool_use input          input fields (new_string, content, etc.) may contain
                                user-authored text verbatim; structural keys (file_path,
                                command, pattern…) are already skipped by _TOOL_INPUT_SKIP_KEYS.
    """
    masked_body = dict(body)
    all_found: list[str] = []

    # System prompt — intentionally not masked.
    # Contains Claude Code wrapper instructions (tools, CLAUDE.md, session setup).
    # These are trusted, machine-generated, and NLP masking breaks them.

    # Messages — selective masking by role
    if 'messages' in body and isinstance(body['messages'], list):
        new_messages = []
        for i, msg in enumerate(body['messages']):
            if not isinstance(msg, dict):
                new_messages.append(msg)
                continue
            role = msg.get('role', '')

            if role == 'user':
                # Full masking: user text + tool_result file contents
                masked_msg: dict[str, Any] = dict(msg)
                loc = f'user[{i}]'

                if isinstance(msg.get('name'), str):
                    masked_name, name_found = presidio_mask(msg['name'])
                    masked_msg['name'] = masked_name
                    all_found.extend(_prefix(name_found, f'{loc}.name'))

                if 'content' not in msg:
                    new_messages.append(masked_msg)
                    continue
                content = msg['content']
                if isinstance(content, str):
                    masked, found = presidio_mask(content)
                    masked_msg['content'] = masked
                    all_found.extend(_prefix(found, f'{loc}.content'))
                elif isinstance(content, list):
                    new_content: list[Any] = []
                    msg_found: list[str] = []
                    for b in content:
                        masked_b, found = mask_content_block(b)
                        new_content.append(masked_b)
                        msg_found.extend(found)
                    masked_msg['content'] = new_content
                    all_found.extend(_prefix(msg_found, f'{loc}.content'))
                new_messages.append(masked_msg)

            elif role == 'assistant':
                # Partial masking: only tool_use input blocks (may contain user-authored text
                # verbatim, e.g. new_string in Edit, content in Write).
                # Assistant prose (text blocks) is not masked — it's Claude's own output.
                content = msg.get('content')
                if not isinstance(content, list):
                    new_messages.append(msg)
                    continue
                new_content = []
                msg_found: list[str] = []
                changed = False
                for b in content:
                    if isinstance(b, dict) and b.get('type') == 'tool_use':
                        masked_b, found = mask_content_block(b)
                        new_content.append(masked_b)
                        msg_found.extend(found)
                        if found:  # real masking occurred — content actually changed
                            changed = True
                    else:
                        new_content.append(b)  # text block — pass through unchanged
                if changed:
                    new_messages.append({**msg, 'content': new_content})
                    all_found.extend(_prefix(msg_found, f'assistant[{i}].tool_use'))
                else:
                    new_messages.append(msg)

            else:
                # Unknown role — pass through unchanged
                new_messages.append(msg)

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
        elif self.path == '/api/metrics':
            self._metrics()
        elif self.path == '/api/meta':
            self._meta()
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
            'supported_languages': _supported_languages,
            'fallback_enabled': ENABLE_FALLBACK,
            'masking_level': MASKING_LEVEL,
            'log_level': LOG_LEVEL,
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
            'log_level': LOG_LEVEL,
        }).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()

    def _meta(self) -> None:
        body = json.dumps(_startup_meta).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _metrics(self) -> None:
        """GET /api/metrics — return live masking metrics for statusline integration."""
        with _masked_items_lock:
            masked_total = _masked_items_total
        uptime = time.time() - _server_start_time if _server_start_time > 0 else 0.0
        body = json.dumps({
            'masked_items_total': masked_total,
            'uptime_seconds': round(uptime, 1),
            'masking_level': MASKING_LEVEL,
            'log_level': LOG_LEVEL,
            'analyzer_ready': _presidio_ready,
        }).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except BrokenPipeError:
            pass

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
        global _masked_items_total
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
                if LOG_LEVEL == 'debug':
                    # Debug mode: log entity types + regex descriptions (PII metadata)
                    log.info('Masked request: %d item(s): %s', len(found), ', '.join(found))
                else:
                    # Info mode (default): log count only — do NOT log descriptions (metadata leak)
                    log.info('Masked request: %d sensitive item(s) found', len(found))
                # Increment global masked items counter (thread-safe)
                with _masked_items_lock:
                    _masked_items_total += len(found)
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
            resp = _get_http_session().request(
                method='HEAD',
                url=target,
                headers=headers,
                stream=False,
                verify=_SSL_VERIFY,
                timeout=(CONNECT_TIMEOUT, READ_TIMEOUT),
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
            with _get_http_session().request(
                method=self.command,
                url=target,
                headers=headers,
                data=body,
                stream=True,
                verify=_SSL_VERIFY,
                timeout=(CONNECT_TIMEOUT, READ_TIMEOUT),
                allow_redirects=False,
            ) as resp:
                # Exclude headers that change after requests decompresses the body:
                # content-encoding (decoded), content-length (recalculated below),
                # transfer-encoding / connection (hop-by-hop, not for client).
                _skip = ('transfer-encoding', 'connection', 'content-encoding', 'content-length')
                is_streaming = 'text/event-stream' in resp.headers.get('Content-Type', '')

                if is_streaming:
                    # SSE: status + headers must go out before the first chunk. After
                    # that the response is committed, so a mid-stream upstream error can
                    # only end the stream (handled below) — it cannot become a 502.
                    self.send_response(resp.status_code)
                    for key, val in resp.headers.items():
                        if key.lower() not in _skip:
                            self.send_header(key, val)
                    self.end_headers()
                    try:
                        for chunk in resp.iter_content(chunk_size=4096):
                            if chunk:
                                try:
                                    self.wfile.write(chunk)
                                    self.wfile.flush()
                                except (BrokenPipeError, ConnectionResetError):
                                    break  # client disconnected mid-stream
                    except _requests.exceptions.RequestException as exc:
                        # ANY upstream error AFTER the 200 + headers were sent: we cannot
                        # switch to 502 now. End the stream; client keeps partial output.
                        log.warning('Mid-stream upstream error; ending partial response: %s', exc)
                else:
                    # Buffer the full body FIRST. If reading it raises an upstream error,
                    # no status line has been emitted yet, so the outer handler still
                    # sends a clean 502 instead of corrupting a started 200 response.
                    content = resp.content  # fully buffered (already decompressed by requests)
                    self.send_response(resp.status_code)
                    for key, val in resp.headers.items():
                        if key.lower() not in _skip:
                            self.send_header(key, val)
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


def _build_server(args: Any) -> http.server.ThreadingHTTPServer:
    """Select a port and return a bound + listening ThreadingHTTPServer (does not serve yet).

    Port strategy: explicit args.port if free, else up to 30 random candidates from
    [PORT_MIN, PORT_MAX], else OS-assigned (bind 0). Each attempt is an atomic bind.
    """
    try:
        _port_min = int(os.environ.get('PII_PROXY_PORT_MIN', '20000'))
        _port_max = int(os.environ.get('PII_PROXY_PORT_MAX', '40000'))
    except (ValueError, TypeError):
        _port_min, _port_max = 20000, 40000
    if not (1024 <= _port_min < _port_max <= 65535):
        log.warning('Invalid port range [%d, %d]; falling back to [20000, 40000]', _port_min, _port_max)
        _port_min, _port_max = 20000, 40000

    server = None
    if args.port != 0:
        try:
            server = http.server.ThreadingHTTPServer(('127.0.0.1', args.port), PIIProxyHandler)
        except OSError:
            pass
    if server is None:
        _n = min(30, _port_max - _port_min + 1)
        for _p in random.sample(range(_port_min, _port_max + 1), _n):
            try:
                server = http.server.ThreadingHTTPServer(('127.0.0.1', _p), PIIProxyHandler)
                break
            except OSError:
                continue
        if server is None:
            server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), PIIProxyHandler)
    return server


def _run_worker(server: http.server.ThreadingHTTPServer, port_file: "Path | None" = None) -> None:
    """Serve requests until terminated. Used as the forked worker and in non-supervised mode.

    Installs its own SIGTERM/SIGINT handler (overriding any inherited supervisor handler in a
    forked child). When port_file is given (non-supervised path) it is unlinked on shutdown;
    in supervised mode the supervisor owns the port file and passes None.
    """
    global _server_start_time, _startup_meta
    _server_start_time = time.time()
    port = server.server_address[1]
    _raw_sid = os.environ.get('ICLAUDE_SESSION_ID', '')
    session_id = _raw_sid if (re.fullmatch(r'[0-9a-f]{12}', _raw_sid) or _raw_sid == 'shared') else 'default'
    _startup_meta = {
        'session_id': session_id,
        'pwd': os.getcwd(),
        'upstream_url': str(UPSTREAM_URL),
        'masking_level': MASKING_LEVEL,
        'log_level': LOG_LEVEL,
        'started_at': _server_start_time,
    }

    def _worker_shutdown(signum: int, _: Any) -> None:
        log.info('PII-proxy worker shutting down (signal %d)', signum)
        try:
            server.server_close()
        except Exception:
            pass
        if port_file is not None:
            port_file.unlink(missing_ok=True)
        os._exit(0)

    signal.signal(signal.SIGTERM, _worker_shutdown)
    signal.signal(signal.SIGINT, _worker_shutdown)

    if MASKING_LEVEL == 'standard':
        threading.Thread(target=init_presidio, daemon=True).start()

    server.serve_forever()


def _supervise(server: http.server.ThreadingHTTPServer, port_file: "Path") -> None:
    """Fork a worker to serve on the bound socket; re-fork it on unexpected death.

    The listening socket is bound once (by the caller) and inherited across forks, so the port is
    stable for the supervisor's lifetime. On SIGTERM/SIGINT the supervisor forwards the signal to the
    current worker and exits without respawning. A restart-storm cap prevents busy-looping on a
    worker that crashes immediately on startup.
    """
    global _supervisor_stop, _current_worker_pid

    def _sup_shutdown(signum: int, _: Any) -> None:
        global _supervisor_stop
        _supervisor_stop = True
        if _current_worker_pid:
            try:
                os.kill(_current_worker_pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    signal.signal(signal.SIGTERM, _sup_shutdown)
    signal.signal(signal.SIGINT, _sup_shutdown)

    restarts: list[float] = []
    while not _supervisor_stop:
        pid = os.fork()
        if pid == 0:
            # Child: serve on the inherited socket. _run_worker re-installs signal handlers,
            # replacing the supervisor's _sup_shutdown that this child inherited from the fork.
            _run_worker(server)   # blocks; on SIGTERM the worker calls os._exit
            os._exit(0)           # serve_forever returned unexpectedly
        _current_worker_pid = pid
        try:
            os.waitpid(pid, 0)
        except ChildProcessError:
            pass
        if _supervisor_stop:
            break
        now = time.time()
        restarts.append(now)
        restarts = [t for t in restarts if now - t <= _RESTART_WINDOW]
        if len(restarts) > _MAX_RESTARTS:
            log.error(
                'PII-proxy worker crash-looped (%d restarts in %.0fs); supervisor exiting',
                len(restarts), _RESTART_WINDOW,
            )
            break
        log.warning('PII-proxy worker died; respawning on the same port')
        time.sleep(0.2)

    log.info('PII-proxy supervisor shutting down')
    try:
        server.server_close()
    except Exception:
        pass
    port_file.unlink(missing_ok=True)
    sys.exit(0)


def main() -> None:
    parser = argparse.ArgumentParser(description='PII-Proxy Server')
    parser.add_argument('--port', type=int, default=DEFAULT_PORT)
    parser.add_argument('--log-dir', default=str(LOG_DIR))
    args = parser.parse_args()

    log_dir = Path(args.log_dir)
    sid = os.environ.get('ICLAUDE_SESSION_ID', 'default')
    setup_logging(log_dir, sid)

    server = _build_server(args)
    port = server.server_address[1]  # actual port assigned by OS

    # Per-session port file: named by ICLAUDE_SESSION_ID so concurrent sessions never collide.
    _raw_sid = os.environ.get('ICLAUDE_SESSION_ID', '')
    session_id = _raw_sid if (re.fullmatch(r'[0-9a-f]{12}', _raw_sid) or _raw_sid == 'shared') else 'default'
    port_file = log_dir / f'pii-proxy-{session_id}.port'
    port_file.write_text(str(port))

    log.info(
        'PII-proxy listening on 127.0.0.1:%d -> %s '
        '(masking_level=%s, connect_timeout=%.0fs, read_timeout=%.0fs, supervise=%s)',
        port, UPSTREAM_URL, MASKING_LEVEL, CONNECT_TIMEOUT, READ_TIMEOUT, SUPERVISE,
    )

    if SUPERVISE:
        _supervise(server, port_file)
    else:
        _run_worker(server, port_file)


if __name__ == '__main__':
    main()
