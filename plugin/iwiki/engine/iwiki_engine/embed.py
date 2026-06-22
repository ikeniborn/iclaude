"""OpenAI-compatible embeddings client. Batches inputs; respects HTTPS_PROXY.

Transient backend failures (timeouts, connection errors, HTTP 5xx) are retried
with bounded exponential backoff before surfacing as EmbedError.
"""
from __future__ import annotations
import time
import httpx
from .config import Config

_MAX_ATTEMPTS = 3
_BACKOFF_BASE = 0.5  # seconds; doubled each retry


class EmbedError(RuntimeError):
    """Raised when the embedding backend is unreachable or errors (stop rule)."""


def _is_transient(exc: httpx.HTTPError) -> bool:
    """Timeouts, connection/transport failures, and HTTP 5xx are worth retrying."""
    if isinstance(exc, httpx.HTTPStatusError):
        return exc.response.status_code >= 500
    return isinstance(exc, httpx.TransportError)


def embed_texts(cfg: Config, texts: list[str]) -> list[list[float]]:
    """Return one float vector per input text. Raises EmbedError on failure."""
    if not texts:
        return []
    url = f"{cfg.base_url}/embeddings"
    payload: dict = {"model": cfg.embed_model, "input": texts}
    if cfg.dimensions:
        payload["dimensions"] = cfg.dimensions
    headers = {"Authorization": f"Bearer {cfg.api_key}"}
    last: httpx.HTTPError | None = None
    for attempt in range(_MAX_ATTEMPTS):
        try:
            resp = httpx.post(url, json=payload, headers=headers, timeout=60.0)
            resp.raise_for_status()
            data = resp.json().get("data", [])
            return [row["embedding"] for row in sorted(data, key=lambda r: r["index"])]
        except httpx.HTTPError as e:
            last = e
            if attempt + 1 < _MAX_ATTEMPTS and _is_transient(e):
                time.sleep(_BACKOFF_BASE * (2 ** attempt))
                continue
            break
    raise EmbedError(f"embedding backend unreachable: {last}") from last
