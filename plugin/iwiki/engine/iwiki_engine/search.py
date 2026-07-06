"""Cosine search over the index: top-k above a threshold."""
from __future__ import annotations
from .store import Record, dequantize, cosine


def search(query_vec: list[float], recs: list[Record], top_k: int,
           threshold: float) -> list[dict]:
    scored = []
    for r in recs:
        score = cosine(query_vec, dequantize(r.scale, r.q))
        if score >= threshold:
            scored.append({"id": r.id, "file": r.file, "heading": r.heading,
                           "chunk": r.chunk, "score": round(score, 4)})
    scored.sort(key=lambda d: d["score"], reverse=True)
    return scored[:top_k]
