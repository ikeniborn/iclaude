"""JSONL index: load/save, int8 quantize/dequantize, per-chunk records."""
from __future__ import annotations
import json
import math
import os
from dataclasses import dataclass, asdict


@dataclass
class Record:
    id: str
    file: str
    heading: str
    chunk: int
    hash: str
    dim: int
    scale: float
    q: list[int]         # int8 quantized vector


def quantize(vec: list[float]) -> tuple[float, list[int]]:
    peak = max((abs(x) for x in vec), default=0.0)
    if peak == 0.0:
        return 1.0, [0] * len(vec)
    scale = peak / 127.0
    return scale, [max(-127, min(127, round(x / scale))) for x in vec]


def dequantize(scale: float, q: list[int]) -> list[float]:
    return [v * scale for v in q]


def make_record(c, vec: list[float]) -> Record:
    scale, q = quantize(vec)
    return Record(id=c.id, file=c.file, heading=c.heading, chunk=c.chunk,
                  hash=c.hash, dim=len(vec), scale=scale, q=q)


def load_index(path: str) -> list[Record]:
    if not os.path.exists(path):
        return []
    recs: list[Record] = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                recs.append(Record(**json.loads(line)))
    return recs


def save_index(path: str, recs: list[Record]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        for r in recs:
            fh.write(json.dumps(asdict(r), ensure_ascii=False) + "\n")


def index_bytes(path: str) -> int:
    return os.path.getsize(path) if os.path.exists(path) else 0


def cosine(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    return dot / (na * nb) if na and nb else 0.0
