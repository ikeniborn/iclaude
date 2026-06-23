"""Split markdown on ## headings into sections, then into overlapping sub-chunks.

Each content section's sub-chunks are prefixed with the page title, the authored
``## Overview`` summary, the section heading, and the section lead, so every vector
carries whole-article + whole-section context. The first ``## Overview`` section is
the summary source and is itself excluded from the index.
"""
from __future__ import annotations
import hashlib
import os
import re
from dataclasses import dataclass

_H1 = re.compile(r"^#\s+(.*?)\s*$", re.MULTILINE)
_H2 = re.compile(r"^##\s+(.*?)\s*$", re.MULTILINE)

OVERVIEW_HEADING = "overview"   # reserved first section; its body is the article summary
LEAD_MAX = 250                  # section lead (= section summary) char cap


@dataclass
class Chunk:
    file: str
    heading: str
    chunk: int           # sub-chunk index within the section (0-based)
    text: str            # prefix + body slice (the text that gets embedded)
    hash: str            # sha256(text)[:16]

    @property
    def id(self) -> str:
        return f"{self.file}#{self.heading}"


def _hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def _split_section(words: list[str], size: int, overlap: int) -> list[list[str]]:
    if len(words) <= size:
        return [words]
    step = max(1, size - overlap)
    return [words[i:i + size] for i in range(0, len(words), step) if words[i:i + size]]


def _page_title(content: str, file: str) -> str:
    """First ``# H1`` before the first ``##``; fallback to a humanized basename."""
    h2 = _H2.search(content)
    head = content[:h2.start()] if h2 else content
    m = _H1.search(head)
    if m and m.group(1).strip():
        return m.group(1).strip()
    stem = os.path.splitext(os.path.basename(file))[0]
    return stem.replace("-", " ").replace("_", " ").strip()


def _lead(body: str) -> str:
    """First paragraph of a section body (up to the first blank line), capped."""
    para: list[str] = []
    for ln in body.splitlines():
        if not ln.strip():
            if para:
                break
            continue
        para.append(ln.strip())
    return " ".join(para)[:LEAD_MAX]


def _sections(content: str) -> list[tuple[str, str]]:
    """[(heading, body), ...] split on ``##``. Pre-``##`` content is ignored."""
    out: list[tuple[str, str]] = []
    ms = list(_H2.finditer(content))
    for i, m in enumerate(ms):
        start = m.end()
        end = ms[i + 1].start() if i + 1 < len(ms) else len(content)
        out.append((m.group(1).strip(), content[start:end].strip()))
    return out


def chunk_markdown(file: str, content: str, size: int, overlap: int,
                   summary_max: int = 400) -> list[Chunk]:
    """Return chunks for one markdown file.

    The first ``## Overview`` section (case-insensitive) is the article-summary
    source and is NOT itself indexed; every other section's sub-chunks are prefixed
    with title + article summary + heading + lead, then word-split with overlap.
    """
    out: list[Chunk] = []
    title = _page_title(content, file)
    secs = _sections(content)
    article_summary = ""
    if secs and secs[0][0].lower() == OVERVIEW_HEADING:
        article_summary = " ".join(secs[0][1].split())[:summary_max]
        secs = secs[1:]                       # exclude Overview from the index
    for heading, body in secs:
        lead = _lead(body)
        prefix = "\n".join(
            ln for ln in (f"# {title}", article_summary, f"## {heading}", lead) if ln
        )
        for ci, piece in enumerate(_split_section(body.split(), size, overlap)):
            text = prefix + "\n\n" + " ".join(piece)
            out.append(Chunk(file=file, heading=heading, chunk=ci,
                             text=text, hash=_hash(text)))
    return out
