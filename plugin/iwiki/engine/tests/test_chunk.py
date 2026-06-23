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


PAGE = (
    "# Proxy Management\n\n"
    "## Overview\n"
    "iclaude routes Claude Code via an HTTPS proxy with OAuth refresh.\n\n"
    "## TLS Handling\n"
    "The proxy terminates TLS using a local CA.\n\n"
    "## OAuth Refresh\n"
    "Tokens refresh before expiry.\n"
)


def test_overview_section_is_not_indexed():
    chunks = chunk_markdown("proxy.md", PAGE, size=512, overlap=64)
    assert "Overview" not in {c.heading for c in chunks}
    assert {c.heading for c in chunks} == {"TLS Handling", "OAuth Refresh"}


def test_prefix_carries_title_overview_and_lead():
    chunks = chunk_markdown("proxy.md", PAGE, size=512, overlap=64)
    tls = next(c for c in chunks if c.heading == "TLS Handling")
    assert tls.text.startswith("# Proxy Management\n")
    assert "iclaude routes Claude Code via an HTTPS proxy" in tls.text  # article summary
    assert "## TLS Handling" in tls.text                                # heading
    assert "The proxy terminates TLS using a local CA." in tls.text     # lead


def test_prefix_on_every_subchunk_of_a_split_section():
    body = " ".join(str(i) for i in range(40))
    md = f"# T\n\n## Overview\nsumm of all.\n\n## Big\n{body}\n"
    chunks = chunk_markdown("f.md", md, size=8, overlap=2)
    big = [c for c in chunks if c.heading == "Big"]
    assert len(big) > 1
    assert all(c.text.startswith("# T\n") for c in big)
    assert all("summ of all." in c.text for c in big)   # article summary in every piece
    assert all("## Big" in c.text for c in big)          # section heading in every piece


def test_title_falls_back_to_humanized_basename():
    md = "## Overview\nsumm.\n\n## A\nbody.\n"   # no H1
    chunks = chunk_markdown("my-page.md", md, size=512, overlap=64)
    assert chunks[0].text.startswith("# my page\n")


def test_no_overview_yields_no_summary_line():
    md = "# T\n\n## A\nbody alpha.\n"
    chunks = chunk_markdown("f.md", md, size=512, overlap=64)
    # prefix is title + heading + lead only; no blank summary line injected
    assert chunks[0].text.startswith("# T\n## A\nbody alpha.\n\n")


def test_hash_changes_when_overview_changes():
    a = chunk_markdown("f.md", "# T\n\n## Overview\nsumm one.\n\n## A\nbody.\n",
                       size=512, overlap=64)
    b = chunk_markdown("f.md", "# T\n\n## Overview\nsumm two.\n\n## A\nbody.\n",
                       size=512, overlap=64)
    assert a[0].hash != b[0].hash
