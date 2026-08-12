#!/usr/bin/env python3
"""One-shot generator for the docs/TODO.md -> wiki ledger migration.

Prints the Markdown body of every page the migration needs; the agent writes
them with wiki_write_page. Generates Markdown only: it has no MCP access.
Deleted together with docs/TODO.md once the migration is confirmed.
"""
import sys

COLUMNS = ["topic", "status", "intent", "spec", "plan",
           "result", "opened", "closed", "notes"]
ARCHIVE_SLUG = "reference/tasks/archive-todo-log"


def parse_rows(text):
    rows = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("|") or line.startswith("|---"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if cells[0] == "Topic":
            continue
        if len(cells) < len(COLUMNS):
            raise ValueError(
                f"row has {len(cells)} cells, expected at least {len(COLUMNS)}: {line[:60]}")
        # Notes carry unescaped '|' (e.g. "subagent|microvm"); keep the fixed
        # leading cells and rejoin the tail so no row is silently dropped.
        head = cells[:len(COLUMNS) - 1]
        notes = "|".join(cells[len(COLUMNS) - 1:])
        rows.append(dict(zip(COLUMNS, head + [notes])))
    return rows


def _field(label, value):
    return f"- {label}: {value}" if value else f"- {label}:"


def _truncate_word(text, limit=120):
    if len(text) <= limit:
        return text
    cut = text[:limit]
    idx = cut.rfind(" ")
    cut = (cut[:idx] if idx != -1 else cut).rstrip()
    return cut + "…"


def _sections(current_state, todo, subtasks, evidence, changelog):
    return "\n\n".join([
        "## Current State\n" + current_state,
        "## TODO\n" + todo,
        "## Subtasks\n" + subtasks,
        "## Evidence\n" + evidence,
        "## Changelog\n" + changelog,
    ]) + "\n"


def archive_page(rows):
    closed = [r for r in rows if r["status"] == "done"]
    table = ["| Topic | Opened | Closed | Result | Notes |", "|---|---|---|---|---|"]
    for r in closed:
        notes = _truncate_word(r["notes"].split(";")[0])
        table.append(f"| {r['topic']} | {r['opened']} | {r['closed']} | {r['result']} | {notes} |")
    archive_current_state = "\n".join([
        "Frozen archive of the retired docs/TODO.md rows. Closed work only; it",
        "records history and is never updated again.",
        "",
        "- Topic: archive-todo-log",
        "- Route: chain",
        "- Lifecycle: done",
        _field("Opened", closed[0]["opened"] if closed else ""),
        _field("Closed", closed[-1]["closed"] if closed else ""),
        "- Parent: main",
        "- Pending delivery: none",
    ])
    return _sections(
        archive_current_state,
        "Nothing outstanding: every row here closed before the ledger moved to\n"
        "the wiki.\n\n- [x] archived",
        "No delegated work is recorded for archived rows.\n\n"
        "| Subtask | Role | Route | Outcome |\n|---|---|---|---|",
        "The retired rows, condensed to topic, dates, verdict, and the first\n"
        "clause of their notes.\n\n" + "\n".join(table),
        "Single event: the archive itself.\n\n"
        "- 2026-08-12 — close — archived the retired docs/TODO.md rows — key:archive-todo-log-close",
    )


def topic_page(row):
    stages = [f"- [{'x' if row[k] == '✓' else ' '}] {k}" for k in
              ("intent", "spec", "plan")]
    topic_current_state = "\n".join([
        "Task migrated from the retired docs/TODO.md row; live state continues",
        "on this page.",
        "",
        f"- Topic: {row['topic']}",
        "- Route: chain",
        f"- Lifecycle: {row['status']}",
        _field("Opened", row["opened"]),
        _field("Closed", row["closed"]),
        "- Parent: main",
        "- Pending delivery: none",
    ])
    return _sections(
        topic_current_state,
        "Chain stages carried over from the migrated row.\n\n" + "\n".join(stages),
        "No delegated work was recorded before the migration.\n\n"
        "| Subtask | Role | Route | Outcome |\n|---|---|---|---|",
        "Full notes text from the migrated row.\n\n" + f"- {row['notes']}",
        "Single event: the migration itself.\n\n"
        f"- 2026-08-12 — open — migrated from docs/TODO.md — key:{row['topic']}-open-migration",
    )


def main(argv):
    path = argv[1] if len(argv) > 1 else "docs/TODO.md"
    text = sys.stdin.read() if path == "-" else open(path, encoding="utf-8").read()
    rows = parse_rows(text)
    print(f"=== {ARCHIVE_SLUG} ===")
    print(archive_page(rows))
    for row in rows:
        if row["status"] != "done":
            print(f"=== reference/tasks/{row['topic']} ===")
            print(topic_page(row))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
