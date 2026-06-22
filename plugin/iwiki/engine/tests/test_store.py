from iwiki_engine.store import quantize, dequantize, cosine


def test_quantize_dequantize_roundtrip():
    vec = [0.1, -0.5, 0.9, -1.0, 0.0]
    scale, q = quantize(vec)
    out = dequantize(scale, q)
    assert all(abs(a - b) <= scale for a, b in zip(vec, out))


def test_quantize_zero_vector():
    scale, q = quantize([0.0, 0.0, 0.0])
    assert q == [0, 0, 0]
    assert scale == 1.0


def test_cosine_identical_is_one():
    assert abs(cosine([1.0, 2.0, 3.0], [1.0, 2.0, 3.0]) - 1.0) < 1e-9


def test_cosine_zero_vector_is_zero():
    assert cosine([0.0, 0.0], [1.0, 1.0]) == 0.0
