import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

FIXTURE = """# Task Log

One row per chain topic.

| Topic | Status | Intent | Spec | Plan | Result | Opened | Closed | Notes |
|---|---|---|---|---|---|---|---|---|
| alpha | done | n/a | ✓ | ✓ | OK | 2026-06-01 | 2026-06-05 | shipped via PR #1 |
| beta | in-progress | ✓ | ✓ | – | – | 2026-07-02 | | halfway, spec validated |
"""


def test_parse_rows_splits_cells():
    import migrate_todo_to_wiki as m
    rows = m.parse_rows(FIXTURE)
    assert len(rows) == 2
    assert rows[0]["topic"] == "alpha"
    assert rows[0]["closed"] == "2026-06-05"
    assert rows[1]["status"] == "in-progress"
    assert rows[1]["closed"] == ""


def test_notes_may_contain_pipes():
    import migrate_todo_to_wiki as m
    extra = ("| gamma | done | ✓ | ✓ | ✓ | OK | 2026-07-01 | 2026-07-03 "
             "| opt-in key: subagent|microvm |\n")
    rows = m.parse_rows(FIXTURE + extra)
    assert len(rows) == 3, "a pipe inside Notes must not drop the row"
    assert rows[2]["notes"] == "opt-in key: subagent|microvm"


def test_short_row_fails_loud():
    import migrate_todo_to_wiki as m
    broken = FIXTURE + "| delta | done | ✓ |\n"
    try:
        m.parse_rows(broken)
    except ValueError as exc:
        assert "expected at least" in str(exc)
    else:
        raise AssertionError("a malformed row must raise, not vanish")


def test_archive_page_holds_only_closed_rows():
    import migrate_todo_to_wiki as m
    page = m.archive_page(m.parse_rows(FIXTURE))
    assert "| alpha |" in page
    assert "beta" not in page
    assert page.count("\n## ") == 4, "five sections, four after the first"
    assert page.startswith("## Current State")


def test_topic_page_has_the_five_sections_in_order():
    import migrate_todo_to_wiki as m
    page = m.topic_page(m.parse_rows(FIXTURE)[1])
    heads = [ln for ln in page.splitlines() if ln.startswith("## ")]
    assert heads == ["## Current State", "## TODO", "## Subtasks",
                     "## Evidence", "## Changelog"]
    assert "Lifecycle: in-progress" in page
    assert "migrated from docs/TODO.md" in page


def test_no_heading_is_deeper_than_h2():
    import migrate_todo_to_wiki as m
    rows = m.parse_rows(FIXTURE)
    for page in (m.archive_page(rows), m.topic_page(rows[1])):
        assert "\n### " not in page


def test_every_section_lead_is_at_most_250_chars():
    import migrate_todo_to_wiki as m
    rows = m.parse_rows(FIXTURE)
    for page in (m.archive_page(rows), m.topic_page(rows[1])):
        # Prepend "\n" so the leading "## Current State" heading is also a
        # split boundary; without it, [1:] silently drops the first section
        # (the page starts with "## " at position 0, not "\n## ").
        for block in ("\n" + page).split("\n## ")[1:]:
            lead = block.split("\n\n")[0].split("\n", 1)[1]
            assert len(lead) <= 250, lead


def test_archive_table_truncates_long_notes_on_word_boundary():
    import migrate_todo_to_wiki as m
    clause = " ".join(f"word{i}" for i in range(40))  # well over 120 chars
    assert len(clause) > 120
    extra = (f"| epsilon | done | ✓ | ✓ | ✓ | OK | 2026-07-05 | 2026-07-06 "
             f"| {clause} |\n")
    rows = m.parse_rows(FIXTURE + extra)
    page = m.archive_page(rows)
    line = next(ln for ln in page.splitlines() if ln.startswith("| epsilon |"))
    cell = line.strip("|").split("|")[-1].strip()
    assert cell.endswith("…"), cell
    prefix = cell[:-1]
    assert prefix == prefix.rstrip(), "no trailing space before the ellipsis"
    assert clause.startswith(prefix), "truncated text must be a prefix of the original"
    boundary = clause[len(prefix)]
    assert boundary == " ", "cut must land on a word boundary"


def test_archive_table_leaves_short_notes_unchanged():
    import migrate_todo_to_wiki as m
    clause = "short note under the limit"
    assert len(clause) <= 120
    extra = (f"| zeta | done | ✓ | ✓ | ✓ | OK | 2026-07-05 | 2026-07-06 "
             f"| {clause} |\n")
    rows = m.parse_rows(FIXTURE + extra)
    page = m.archive_page(rows)
    line = next(ln for ln in page.splitlines() if ln.startswith("| zeta |"))
    cell = line.strip("|").split("|")[-1].strip()
    assert cell == clause
    assert "…" not in cell


def test_topic_page_empty_closed_has_no_trailing_space():
    import migrate_todo_to_wiki as m
    row = m.parse_rows(FIXTURE)[1]  # beta, closed == ""
    page = m.topic_page(row)
    lines = page.splitlines()
    assert "- Closed:" in lines
    assert "- Closed: " not in lines


def test_cli_prints_every_page():
    out = subprocess.run(
        [sys.executable, str(ROOT / "scripts/migrate_todo_to_wiki.py"), "-"],
        input=FIXTURE, capture_output=True, text=True, check=True).stdout
    assert "=== reference/tasks/archive-todo-log ===" in out
    assert "=== reference/tasks/beta ===" in out


if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f):
            f()
            print("ok", n)
