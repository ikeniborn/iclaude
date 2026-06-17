"""OpenAI-compatible embeddings client. Batches inputs; respects HTTPS_PROXY."""
from __future__ import annotations
import httpx
from .config import Config


class EmbedError(RuntimeError):
    """Raised when the embedding backend is unreachable or errors (stop rule)."""


def embed_texts(cfg: Config, texts: list[str]) -> list[list[float]]:
    """Return one float vector per input text. Raises EmbedError on failure."""
    if not texts:
        return []
    url = f"{cfg.base_url}/embeddings"
    payload: dict = {"model": cfg.embed_model, "input": texts}
    if cfg.dimensions:
        payload["dimensions"] = cfg.dimensions
    headers = {"Authorization": f"Bearer {cfg.api_key}"}
    try:
        resp = httpx.post(url, json=payload, headers=headers, timeout=60.0)
        resp.raise_for_status()
    except httpx.HTTPError as e:
        raise EmbedError(f"embedding backend unreachable: {e}") from e
    data = resp.json().get("data", [])
    return [row["embedding"] for row in sorted(data, key=lambda r: r["index"])]
