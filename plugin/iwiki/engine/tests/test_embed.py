import httpx
import pytest
from iwiki_engine import embed as embed_mod
from iwiki_engine.embed import embed_texts, EmbedError
from iwiki_engine.config import Config


def _cfg():
    return Config(base_url="http://x", api_key="k", embed_model="m", dimensions=0,
                  chunk_size=512, chunk_overlap=64, summary_max=400, top_k=8,
                  score_threshold=0.2, graph_depth=2, include=[], exclude=[])


class _Resp:
    def __init__(self, data):
        self._data = data

    def raise_for_status(self):
        pass

    def json(self):
        return {"data": self._data}


def test_retries_transient_then_succeeds(monkeypatch):
    calls = {"n": 0}

    def fake_post(*a, **k):
        calls["n"] += 1
        if calls["n"] < 3:
            raise httpx.ConnectError("boom")
        return _Resp([{"index": 0, "embedding": [0.1, 0.2]}])

    monkeypatch.setattr(embed_mod.httpx, "post", fake_post)
    monkeypatch.setattr(embed_mod.time, "sleep", lambda s: None)
    assert embed_texts(_cfg(), ["hello"]) == [[0.1, 0.2]]
    assert calls["n"] == 3


def test_gives_up_after_max_attempts(monkeypatch):
    calls = {"n": 0}

    def fake_post(*a, **k):
        calls["n"] += 1
        raise httpx.ConnectError("down")

    monkeypatch.setattr(embed_mod.httpx, "post", fake_post)
    monkeypatch.setattr(embed_mod.time, "sleep", lambda s: None)
    with pytest.raises(EmbedError):
        embed_texts(_cfg(), ["hello"])
    assert calls["n"] == 3


def test_4xx_not_retried(monkeypatch):
    calls = {"n": 0}
    req = httpx.Request("POST", "http://x/embeddings")

    def fake_post(*a, **k):
        calls["n"] += 1
        resp = httpx.Response(400, request=req)
        raise httpx.HTTPStatusError("bad", request=req, response=resp)

    monkeypatch.setattr(embed_mod.httpx, "post", fake_post)
    monkeypatch.setattr(embed_mod.time, "sleep", lambda s: None)
    with pytest.raises(EmbedError):
        embed_texts(_cfg(), ["hello"])
    assert calls["n"] == 1
