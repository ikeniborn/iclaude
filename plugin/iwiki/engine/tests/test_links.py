from iwiki_engine.links import parse_links


def test_ignores_fenced_code_block():
    md = (
        "See [[real-page]] for details.\n\n"
        "```bash\n"
        "if [[ $# -gt 0 ]]; then echo hi; fi\n"
        '[[ -d "$LIB_DIR/<name>" ]]\n'
        "```\n"
    )
    assert parse_links(md) == ["real-page"]


def test_ignores_inline_code():
    md = "Use `[[ -d x ]]` in bash, but link to [[guide]] here."
    assert parse_links(md) == ["guide"]


def test_alias_form_returns_target():
    assert parse_links("[[core|the core module]]") == ["core"]


def test_dedup_preserves_order():
    md = "[[a]] then [[b]] then [[a]] again, and [[c]]."
    assert parse_links(md) == ["a", "b", "c"]


def test_section_ref_target_kept_whole():
    assert parse_links("[[nvm#Claude Binary Detection]]") == ["nvm#Claude Binary Detection"]
