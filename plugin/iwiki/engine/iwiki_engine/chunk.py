"""Split markdown on ## headings into sections, then into overlapping sub-chunks."""
from __future__ import annotations
import hashlib
import re
from dataclasses import dataclass

_H2 = re.compile(r"^##\s+(.*?)\s*$", re.MULTILINE)


@dataclass
class Chunk:
    file: str
    heading: str
    chunk: int           # sub-chunk index within the section (0-based)
    text: str            # heading + body (the text that gets embedded)
    hash: str            # sha256(heading + body)[:16]

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


def chunk_markdown(file: str, content: str, size: int, overlap: int) -> list[Chunk]:
    """Return chunks for one markdown file. Content before the first ## is ignored."""
    out: list[Chunk] = []
    matches = list(_H2.finditer(content))
    for i, m in enumerate(matches):
        heading = m.group(1).strip()
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(content)
        body = content[start:end].strip()
        section_text = f"## {heading}\n\n{body}".strip()
        words = section_text.split()
        for ci, piece in enumerate(_split_section(words, size, overlap)):
            text = " ".join(piece)
            out.append(Chunk(file=file, heading=heading, chunk=ci,
                             text=text, hash=_hash(f"{heading}\n{text}")))
    return out
