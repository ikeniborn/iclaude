"""Configuration from environment. Halts (stop rule) when API config is missing."""
from __future__ import annotations
import os
from dataclasses import dataclass


class ConfigError(RuntimeError):
    """Raised when required API configuration is absent (intent stop rule)."""


def _load_scope(filename: str, env_var: str) -> list[str]:
    """Glob patterns from a comma-separated env var plus a gitignore-style file."""
    pats = [p.strip() for p in os.environ.get(env_var, "").split(",") if p.strip()]
    if os.path.exists(filename):
        with open(filename, encoding="utf-8") as fh:
            pats += [ln.strip() for ln in fh if ln.strip() and not ln.startswith("#")]
    return pats


@dataclass(frozen=True)
class Config:
    base_url: str
    api_key: str
    embed_model: str
    dimensions: int
    chunk_size: int
    chunk_overlap: int
    top_k: int
    score_threshold: float
    graph_depth: int
    include: list[str]        # glob patterns; empty = include everything
    exclude: list[str]        # glob patterns applied after include

    @staticmethod
    def load() -> "Config":
        getenv = os.environ.get
        url_var, key_var = "IWIKI_LLM_BASE_URL", "IWIKI_LLM_KEY"
        base_url = getenv(url_var, "").strip()
        api_key = getenv(key_var, "").strip()
        if not base_url or not api_key:
            raise ConfigError(
                f"{url_var} and {key_var} must be set as environment variables "
                "(e.g. exported from .claude_config). Halting."
            )
        if base_url.endswith("/"):
            base_url = base_url[:-1]
        return Config(
            base_url=base_url,
            api_key=api_key,
            embed_model=getenv("IWIKI_EMBED_MODEL", "text-embedding-3-small"),
            dimensions=int(getenv("IWIKI_EMBED_DIMENSIONS", "1536")),
            chunk_size=int(getenv("IWIKI_CHUNK_SIZE", "512")),
            chunk_overlap=int(getenv("IWIKI_CHUNK_OVERLAP", "64")),
            top_k=int(getenv("IWIKI_TOP_K", "8")),
            score_threshold=float(getenv("IWIKI_SCORE_THRESHOLD", "0.2")),
            graph_depth=int(getenv("IWIKI_GRAPH_DEPTH", "2")),
            include=_load_scope(".iwikiinclude", "IWIKI_INCLUDE"),
            exclude=_load_scope(".iwikiexclude", "IWIKI_EXCLUDE"),
        )
