from iwiki_engine.store import Record, quantize
from iwiki_engine.search import search


def _rec(id, vec):
    scale, q = quantize(vec)
    return Record(id=id, file=id.split("#")[0], heading="H", chunk=0,
                  hash="h", dim=len(vec), scale=scale, q=q)


def test_threshold_filters_low_scores():
    recs = [_rec("a.md#A", [1.0, 0.0]), _rec("b.md#B", [0.0, 1.0])]
    out = search([1.0, 0.0], recs, top_k=10, threshold=0.5)
    assert [d["id"] for d in out] == ["a.md#A"]   # B is orthogonal → filtered


def test_top_k_limits_and_orders_by_score():
    recs = [_rec("a.md#A", [1.0, 0.0]),
            _rec("b.md#B", [0.9, 0.1]),
            _rec("c.md#C", [0.8, 0.2])]
    out = search([1.0, 0.0], recs, top_k=2, threshold=0.0)
    assert [d["id"] for d in out] == ["a.md#A", "b.md#B"]
