from iwiki_engine.validate import validate_page


def _types(content):
    return {f["type"] for f in validate_page(content)}


CLEAN = (
    "# T\n\n## Overview\nsummary of all sections.\n\n"
    "## A\nlead alpha.\n\n## B\nlead beta.\n"
)


def test_clean_page_has_no_findings():
    assert validate_page(CLEAN) == []


def test_deep_heading_is_blocking():
    fs = [f for f in validate_page("## Overview\ns.\n\n## A\nx.\n\n### too deep\n")
          if f["type"] == "deep_heading"]
    assert fs and fs[0]["severity"] == "block"


def test_pre_h2_text_is_blocking():
    fs = [f for f in validate_page("# T\n\nstray prose\n\n## Overview\ns.\n\n## A\nx.\n")
          if f["type"] == "pre_h2_text"]
    assert fs and fs[0]["severity"] == "block"


def test_single_h1_before_h2_is_allowed():
    assert "pre_h2_text" not in _types(CLEAN)


def test_missing_overview_is_advisory():
    fs = [f for f in validate_page("# T\n\n## A\nlead.\n") if f["type"] == "missing_overview"]
    assert fs and fs[0]["severity"] == "advisory"


def test_missing_lead_is_advisory():
    fs = [f for f in validate_page("## Overview\ns.\n\n## A\n\n## B\nlead.\n")
          if f["type"] == "missing_lead"]
    assert fs and fs[0]["severity"] == "advisory"


def test_long_lead_is_advisory():
    long = "x " * 200  # > 250 chars
    fs = [f for f in validate_page(f"## Overview\ns.\n\n## A\n{long}\n")
          if f["type"] == "long_lead"]
    assert fs and fs[0]["severity"] == "advisory"
