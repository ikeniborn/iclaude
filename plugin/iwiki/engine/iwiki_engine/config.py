"""Configuration from environment. Halts (stop rule) when API config is missing."""
from __future__ import annotations
import os
from dataclasses import dataclass

from pathspec import PathSpec


class ConfigError(RuntimeError):
    """Raised when required API configuration is absent (intent stop rule)."""


def _load_ignore(filename: str) -> PathSpec | None:
    """Compile a gitignore-style ignore file into a PathSpec.

    Read relative to the engine's working directory (the project root it runs in).
    Real gitignore semantics via the 'gitignore' style: '/' anchoring, '!'
    negation, '**', trailing-slash directories, and basename matching. Absent
    file or no patterns -> None (index the whole project)."""
    if not os.path.exists(filename):
        return None
    with open(filename, encoding="utf-8") as fh:
        spec = PathSpec.from_lines("gitignore", fh)
    # Comment/blank-only lines compile to no-op patterns (include is None);
    # treat a file with no real patterns as "no ignore" to skip the filter pass.
    return spec if any(p.include is not None for p in spec.patterns) else None


@dataclass(frozen=True)
class Config:
    base_url: str
    api_key: str
    embed_model: str
    dimensions: int
    chunk_size: int
    chunk_overlap: int
    summary_max: int
    top_k: int
    score_threshold: float
    graph_depth: int
    ignore: PathSpec | None   # gitignore-style ignore (.iwikiignore); None = index all

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
            summary_max=int(getenv("IWIKI_SUMMARY_MAX_CHARS", "400")),
            top_k=int(getenv("IWIKI_TOP_K", "8")),
            score_threshold=float(getenv("IWIKI_SCORE_THRESHOLD", "0.2")),
            graph_depth=int(getenv("IWIKI_GRAPH_DEPTH", "2")),
            ignore=_load_ignore(".iwikiignore"),
        )
