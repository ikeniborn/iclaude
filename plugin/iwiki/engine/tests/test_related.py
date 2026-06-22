from iwiki_engine.store import Record, quantize
from iwiki_engine.related import related, _graph_neighbours


def _rec(id, file, vec):
    scale, q = quantize(vec)
    return Record(id=id, file=file, heading=id.split("#")[-1], chunk=0,
                  hash="h", dim=len(vec), scale=scale, q=q)


def test_vector_neighbours_ranked_and_self_excluded():
    recs = [
        _rec("a.md#A", "a.md", [1.0, 0.0]),
        _rec("b.md#B", "b.md", [0.9, 0.1]),   # close to A
        _rec("c.md#C", "c.md", [0.0, 1.0]),   # orthogonal to A
    ]
    out = related("a.md#A", recs, top_k=2, graph_depth=2)
    ids = [d["id"] for d in out["vector"]]
    assert ids[0] == "b.md#B"
    assert "a.md#A" not in ids


def test_graph_skips_unreadable_path(tmp_path):
    # A path that exists but cannot be read as a file (a directory) must be
    # skipped by the BFS, not raise IsADirectoryError.
    d = tmp_path / "weird.md"
    d.mkdir()
    assert _graph_neighbours(str(d), depth=1) == []
