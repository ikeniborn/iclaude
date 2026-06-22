from iwiki_engine.chunk import chunk_markdown


def test_splits_on_h2_headings():
    md = "intro ignored\n\n## First\nbody one\n\n## Second\nbody two\n"
    chunks = chunk_markdown("f.md", md, size=512, overlap=64)
    assert [c.heading for c in chunks] == ["First", "Second"]
    assert chunks[0].id == "f.md#First"


def test_content_before_first_heading_ignored():
    assert chunk_markdown("f.md", "preamble only, no headings", size=512, overlap=64) == []


def test_long_section_splits_with_overlap_and_indexes():
    body = " ".join(str(i) for i in range(20))
    chunks = chunk_markdown("f.md", f"## H\n{body}\n", size=8, overlap=2)
    assert len(chunks) > 1
    assert all(c.heading == "H" for c in chunks)
    assert [c.chunk for c in chunks] == list(range(len(chunks)))
