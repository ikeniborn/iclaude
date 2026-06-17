"""Parse [[target]] / [[target|alias]] wiki-links from markdown."""
from __future__ import annotations
import re

_LINK = re.compile(r"\[\[([^\]|]+)(?:\|[^\]]*)?\]\]")


def parse_links(content: str) -> list[str]:
    """Return the target part of every [[...]] link, de-duplicated, order-preserving."""
    seen: dict[str, None] = {}
    for m in _LINK.finditer(content):
        seen.setdefault(m.group(1).strip(), None)
    return list(seen)
