---
chain:
  intent: docs/superpowers/intents/2026-08-12-wiki-task-ledger-intent.md
  intent_hash: bd8fae72ce0c2ceb
  spec: docs/superpowers/specs/2026-08-12-wiki-task-ledger-design.md
  spec_hash: ec4af6056521ae6c
---

# Wiki Task Ledger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `docs/TODO.md` with a wiki-only per-topic task ledger that follows the shared standard `devops/concept/wiki-task-ledger`.

**Architecture:** Task state moves to one wiki page per topic (`reference/tasks/<topic>`) in the project's primary write domain, written only by the parent agent through iwiki MCP tools. No index page and no changelog page: status is derived by searching pages tagged `task`. Behavior lives in rules (`CLAUDE.md`, the `check-chain` skill), not in new runtime code; the only code shipped is a one-shot migration script that is deleted with the tracker it migrates.

**Tech Stack:** Markdown rules and skills, Python 3 (LoEn hooks + one-shot migration script), pytest-style standalone test files, iwiki MCP server.

## Global Constraints

Exact values copied from the spec. Every task's requirements implicitly include this section.

- Page slug: `reference/tasks/<topic>`; `<topic>` is the canonical lowercase-kebab-case slug.
- Frontmatter is passed as `wiki_write_page` parameters, **never** inline in the `markdown` argument — an inline block is duplicated by the server and becomes text before the first `##`, which `wiki_lint` reports as a blocking `pre_h2_text` finding.
- Frontmatter values: `type: reference`, `status: stable`, `tags: [task, <topic>, workflow:<direct|chain|loen>]`. The iwiki vocabulary defines no `task` type and no live lifecycle statuses; `status: draft` is rejected as `unknown_status`.
- Exactly five `##` sections, each once, in order: `Current State`, `TODO`, `Subtasks`, `Evidence`, `Changelog`.
- Headings deeper than `##` are forbidden. Each section opens with a lead paragraph of at most 250 characters, then a blank line before any list or table — otherwise `wiki_lint` reports `long_lead`.
- Lifecycle values (in the page body, not frontmatter): `in-progress`, `blocked`, `completion-pending`, `done`.
- Changelog event kinds: `open`, `route`, `dispatch`, `return`, `scope`, `decision`, `blocker`, `verification`, `close`. Tool calls are not events.
- Every changelog event carries an idempotency key derived from topic, event kind, and a hash of the redacted evidence. An event whose key is already on the page is not appended again.
- Single writer: only the parent agent calls `wiki_write_page` / `wiki_update_page` / `wiki_delete_page`. Subagents are read-only against the wiki.
- Spool path on an outage: `$CLAUDE_CONFIG_DIR/state/iwiki-task-spool/<project>/<topic>.json`, redacted evidence only, outside the repository.
- Fail-closed completion: a task with undelivered events stays `completion-pending`; `done` requires final evidence, full delivery, and `wiki_lint` reporting no new finding for the page.
- No central mutable index page and no separate changelog page.
- Target domain is `wiki_status.primary`.

**Repository paths.** `CLAUDE.md` and the `check-chain` skill live in the isolated config tree:

- `.nvm-isolated/.claude-isolated/CLAUDE.md`
- `.nvm-isolated/.claude-isolated/skills/check-chain/SKILL.md`

---

## File Structure

| File | Responsibility |
|---|---|
| `.nvm-isolated/.claude-isolated/CLAUDE.md` | The ledger rule: what to write, when, who writes. Sections `Task Log`, `Task Topic`, `Project Status Reports`. |
| `.nvm-isolated/.claude-isolated/skills/check-chain/SKILL.md` | Step 6 records the gate on the topic page instead of upserting a table row. |
| `plugin/loen/hooks/loen_artifacts.py` | Loop artifacts only. Loses the TODO-row API entirely. |
| `plugin/loen/hooks/audit-writer.py` | Renders `audit.html` only. |
| `plugin/loen/skills/loop-reflect/SKILL.md`, `plugin/loen/skills/audit/SKILL.md` | Terminal loop steps stop naming the tracker. |
| `tests/test_loen_artifacts.py`, `tests/test_loen_audit_writer.py` | Guarantee the tracker API is gone and never recreated. |
| `scripts/migrate_todo_to_wiki.py` | One-shot Markdown generator for the migration. Deleted with `docs/TODO.md`. |
| `tests/test_migrate_todo_to_wiki.py` | Pins the generator's output shape. Deleted with the script. |
| `docs/TODO.md` | Deleted. |

---

### Task 1: Remove the TODO ledger from LoEn

The LoEn hook writes a tracker row on every `PostToolUse` of an active loop. That row is redundant — `loop.yaml` already carries `status` and `current_stage`, and `audit.html` is rendered next to it — and its write rate is one no MCP-backed ledger should absorb.

**Files:**
- Modify: `plugin/loen/hooks/loen_artifacts.py:1-10` (module docstring), `:173-222` (the whole `# --- TODO.md row ---` block)
- Modify: `plugin/loen/hooks/audit-writer.py:1-3` (docstring), `:31` (the call)
- Modify: `plugin/loen/skills/loop-reflect/SKILL.md:27-38` (terminal bash block)
- Modify: `plugin/loen/skills/audit/SKILL.md:33`
- Modify: `plugin/loen/.claude-plugin/plugin.json` (version)
- Test: `tests/test_loen_artifacts.py`, `tests/test_loen_audit_writer.py`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `loen_artifacts` no longer exports `upsert_todo_row`. Later tasks rely on no LoEn code path writing `docs/TODO.md`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_loen_artifacts.py`, before the `if __name__ == "__main__":` block:

```python
def test_todo_ledger_api_is_gone():
    a = load("loen_artifacts")
    assert not hasattr(a, "upsert_todo_row"), "LoEn must not own a task ledger API"
    src = pathlib.Path(__file__).resolve().parents[1] / "plugin/loen/hooks/loen_artifacts.py"
    assert "docs/TODO.md" not in src.read_text(encoding="utf-8")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tests/test_loen_artifacts.py`
Expected: FAIL with `AssertionError: LoEn must not own a task ledger API`

- [ ] **Step 3: Delete the two obsolete upsert tests**

In `tests/test_loen_artifacts.py`, delete `test_upsert_todo_preserves_foreign_row` and `test_upsert_todo_idempotent` in full (they start at the `def test_upsert_todo_preserves_foreign_row():` line and end just before `def test_append_attempt():`).

- [ ] **Step 4: Remove the TODO block from `loen_artifacts.py`**

Delete everything from the line `# --- TODO.md row ---...` through the end of `upsert_todo_row` (up to but excluding `# --- attempts log ---...`). That removes `_TODO_HEADER`, `_TODO_SEP`, `_LOEN_NOTE`, `_row_cells`, and `upsert_todo_row`.

In the module docstring, change:

```python
run-contract validation, the regenerated audit report, the docs/TODO.md row,
```

to:

```python
run-contract validation, the regenerated audit report,
```

- [ ] **Step 5: Run test to verify it passes**

Run: `python3 tests/test_loen_artifacts.py`
Expected: PASS, `ok test_todo_ledger_api_is_gone` in the output

- [ ] **Step 6: Update the audit-writer hook and its test**

In `plugin/loen/hooks/audit-writer.py`, change the docstring:

```python
"""PostToolUse audit-writer: regenerate the topic's audit.html.
Side-effecting only — never blocks (always exit 0)."""
```

and delete the line:

```python
    _a.upsert_todo_row(topic, stage, verdict, today)
```

The `verdict` local becomes unused — delete its assignment too:

```python
    verdict = "–"
```

In `tests/test_loen_audit_writer.py`, rename `test_writes_audit_and_todo` to `test_writes_audit` and drop its last two lines (`todo = ...` and `assert "| t |" in todo`). Leave `test_no_loop_is_noop` and `test_finished_loop_is_noop` untouched — their `assert not ... exists()` lines become the permanent guarantee that the hook never recreates the tracker.

- [ ] **Step 7: Run the LoEn suites**

Run: `python3 tests/test_loen_artifacts.py && python3 tests/test_loen_audit_writer.py`
Expected: both print `ok ...` lines and exit 0

- [ ] **Step 8: Drop the tracker from the LoEn skills**

In `plugin/loen/skills/loop-reflect/SKILL.md`, replace the terminal bash block's body so it renders the report only:

````markdown
     Because the PostToolUse `audit-writer` goes inert on `status != active`, finalize the
     report explicitly on this terminal:

     ```bash
     python3 - "$TOPIC" "$PLUGIN" <<'PY'
     import sys, os; sys.path.insert(0, os.path.join(sys.argv[2], "hooks"))
     import loen_artifacts as a
     a.render_audit(sys.argv[1], "docs/loen")          # audit.html verdict: Done
     PY
     ```
````

In `plugin/loen/skills/audit/SKILL.md:33`, change `non-empty. On `OK`: regenerate `audit.html` and mark the `docs/TODO.md` row` to `non-empty. On `OK`: regenerate `audit.html`.` and delete the now-dangling remainder of that sentence on the following line.

- [ ] **Step 9: Bump the plugin version**

In `plugin/loen/.claude-plugin/plugin.json`, change `"version": "1.0.0"` to `"version": "1.1.0"`. Then run the repository's version-sync test to find every file that must agree:

Run: `ls tests/ | grep -i version`
Then run the version-sync test it names.
Expected: exit 0 after the marketplace entry is updated to `1.1.0`

- [ ] **Step 10: Verify no LoEn path names the tracker**

Run: `grep -rn "docs/TODO.md\|upsert_todo_row" plugin/loen/ tests/`
Expected: no output

- [ ] **Step 11: Commit**

```bash
git add plugin/loen tests/test_loen_artifacts.py tests/test_loen_audit_writer.py
git commit -m "refactor(loen): drop the docs/TODO.md row from the loop hooks"
```

---

### Task 2: Point check-chain Step 6 at the wiki

Step 6 currently upserts a Markdown table row. It becomes the gate's write to the topic page.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/check-chain/SKILL.md:83`, `:127-133`, `:350`, `:354-355`, `:361`
- Test: none — the skill is instructional Markdown; verification is by `grep`

**Interfaces:**
- Consumes: the page schema and event kinds from Global Constraints.
- Produces: the phrase "Step 6 — wiki task page" that Task 3's `CLAUDE.md` rule refers to.

- [ ] **Step 1: Rewrite Step 6**

Replace the whole `### Step 6 — TODO.md upsert` section (heading plus its body) with:

```markdown
### Step 6 — wiki task page

After the verdict, record the gate on the topic's wiki page
`reference/tasks/<topic>` in the domain reported by `wiki_status.primary` (see the
Task Log convention in `CLAUDE.md`). If the page is absent, create it with
`wiki_write_page` and the five required sections; otherwise `wiki_read_page` the
section you are about to change, then `wiki_update_page` it in full.

- Append one `verification` event to `Changelog`: `- <today> — verification — <stage> <verdict> — key:<key>`, where `<key>` is derived from topic, event kind, and a hash of the recorded evidence. Skip the append when that key is already present.
- Tick the stage's line in `TODO`.
- On `result` `OK`: set `Current State` `Lifecycle: done` and `Closed: <today>`, and append the `close` event — but only after every queued event is delivered and `wiki_lint` reports no new finding for the page. Otherwise set `Lifecycle: completion-pending`.
- If the MCP server is unreachable, append the event to the spool at `$CLAUDE_CONFIG_DIR/state/iwiki-task-spool/<project>/<topic>.json`, report `Tracking: unavailable`, and continue — the stage verdict itself is never blocked by the wiki channel.
```

- [ ] **Step 2: Fix the four remaining references**

- Line 83: `Step 4 (verdict) and Step 6 (TODO upsert).` → `Step 4 (verdict) and Step 6 (wiki task page).`
- Line 350: `(findings → verdicts → frontmatter → TODO cell)` → `(findings → verdicts → frontmatter → wiki task page)`
- Lines 354-355: `leave the TODO`/`Result` cell `–` (not `done`)` → `leave the page's `Lifecycle` at `completion-pending` (not `done`)`
- Line 361: `frontmatter, TODO cell, footer` → `frontmatter, wiki task page, footer`

Leave the three `- Placeholders: `TODO`, `TBD`, `???`, `FIXME`` checklist lines untouched — that `TODO` is a placeholder token, not the tracker.

- [ ] **Step 3: Verify**

Run: `grep -n "docs/TODO.md\|TODO cell\|TODO upsert" .nvm-isolated/.claude-isolated/skills/check-chain/SKILL.md`
Expected: no output

Run: `grep -c "Placeholders: \`TODO\`" .nvm-isolated/.claude-isolated/skills/check-chain/SKILL.md`
Expected: `3`

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/check-chain/SKILL.md
git commit -m "feat(check-chain): record gates on the wiki task page"
```

---

### Task 3: Replace the Task Log rule in CLAUDE.md

The rule is the single source of ledger behavior. It also widens the scope: under the shared standard every task gets a page, including direct work.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/CLAUDE.md:58-80` (the `## Task Log (docs/TODO.md)` section), `:87` (Task Topic surface), `:341-354` (Project Status Reports)
- Test: none — instructional Markdown; verification is by `grep`

**Interfaces:**
- Consumes: "Step 6 — wiki task page" from Task 2.
- Produces: the rule that Task 4's migration and Task 5's deletion depend on.

- [ ] **Step 1: Replace the Task Log section**

Replace everything from `## Task Log (docs/TODO.md)` up to (not including) `## Task Topic` with:

```markdown
## Task Log (iwiki, MANDATORY)

**Every task — direct, chain, or LoEn, including small fixes and read-only analysis — is tracked as one wiki page in the project's primary write domain: opened before the first change, updated at every material event, closed only when delivery is confirmed.** This follows the shared standard `devops/concept/wiki-task-ledger`. There is no in-repo task file.

- **Preconditions.** Call `wiki_status`. Write to `primary`. If no domain is bound, `wiki_bind(read=[<domain>], write=[<domain>])`. If the server is unreachable, say `Tracking: unavailable`, spool the events, continue working — but the task cannot reach `done`.
- **One page per topic**, slug `reference/tasks/<topic>`, frontmatter passed as tool parameters only: `type: reference`, `status: stable`, `tags: [task, <topic>, workflow:<direct|chain|loen>]`. Never put frontmatter inline in `markdown` — the server duplicates it and `wiki_lint` blocks on `pre_h2_text`.
- **No index page, no changelog page.** Project status is derived with `wiki_search(tags=["task"])`.
- **Five `##` sections, each once, never renamed or reordered**: `Current State`, `TODO`, `Subtasks`, `Evidence`, `Changelog`. No `###`. Each section opens with a lead of at most 250 characters, then a blank line.
- **Lifecycle** in the body: `in-progress`, `blocked`, `completion-pending`, `done`.
- **Single writer.** Only the parent agent writes. Subagents are read-only against the wiki (`wiki_search`, `wiki_read_page`, `wiki_related`) and return structured evidence — subtask id, role, outcome, changed paths, checks, blockers, proposed changelog text — which the parent records. Hooks never reach MCP; loop hooks write `docs/loen/<topic>/` and the parent mirrors loop state at material stage boundaries.
- **Write points.** `open` before the first change; `route` when the workflow or model route is decided; `verification` at each `/check-chain` verdict or loop-check; `dispatch` before delegating and `return` when the subagent answers; `blocker` when blocked; `close` at the end. Tool calls are not events.
- **Idempotency.** Every `Changelog` entry carries `key:<hash of topic + kind + redacted evidence>`. An entry whose key is present is not appended again — this is what makes spool replay safe. Entries are append-only; rewriting one is proposal-first and only to repair malformed or secret-bearing content.
- **Close is fail-closed.** `done` requires final evidence recorded, every spooled event delivered, and `wiki_lint` reporting no new finding for the page. Until then the task stays `completion-pending`.
- **Divergence** from the shared standard is recorded on `devops/concept/wiki-task-ledger` before it is implemented.
```

- [ ] **Step 2: Update the Task Topic surface**

At line 87, change:

```markdown
  - `docs/TODO.md` `Topic`;
```

to:

```markdown
  - the wiki task page slug `reference/tasks/<topic>`;
```

- [ ] **Step 3: Update Project Status Reports**

In the `## Project Status Reports` section, replace the opening sentence and the "Read both first" bullet with:

```markdown
**When the user asks for project status, progress, or "what's the state of X", build the answer from two sources together — never one alone: the project's task pages (what is being worked on) and the project's subject-matter wiki pages (what is documented as true).**

- **Read both first.** `wiki_status`; then `wiki_search(tags=["task"])` for the task pages, and `wiki_search`/`wiki_read_page` for the topic's subject-matter pages. If iwiki is unavailable, say so — there is no in-repo fallback.
```

In the discrepancy bullets, replace each `docs/TODO.md` reference with the task page: a topic whose page says `done` but whose subject-matter page is missing or stale; a documented feature with no task page; a page claiming a passed stage while the subject-matter page still describes the old behavior. Replace the closing line `state "TODO and wiki agree" explicitly` with `state "task pages and documentation agree" explicitly`. In the age signal, replace the `in-progress` row wording with task pages whose `Current State` `Opened` is more than 14 days old and whose lifecycle is not `done`.

- [ ] **Step 4: Verify**

Run: `grep -n "docs/TODO.md" .nvm-isolated/.claude-isolated/CLAUDE.md`
Expected: no output

Run: `grep -c "reference/tasks/<topic>" .nvm-isolated/.claude-isolated/CLAUDE.md`
Expected: at least `3`

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/CLAUDE.md
git commit -m "feat(rules): replace the docs/TODO.md task log with the wiki ledger"
```

---

### Task 4: Generate the migration Markdown

The script only generates Markdown — it has no MCP access. The parent agent writes the output to the wiki. **HUMAN CHECKPOINT:** the generated Markdown is shown to the user before Task 5 deletes anything (proposal-first per the intent).

**Files:**
- Create: `scripts/migrate_todo_to_wiki.py`
- Test: `tests/test_migrate_todo_to_wiki.py`
- Read-only input: `docs/TODO.md`

**Interfaces:**
- Consumes: the page schema from Global Constraints.
- Produces: `parse_rows(text) -> list[dict]` with keys `topic, status, intent, spec, plan, result, opened, closed, notes`; `archive_page(rows) -> str`; `topic_page(row) -> str`. Task 5 relies on the script existing at `scripts/migrate_todo_to_wiki.py`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_migrate_todo_to_wiki.py`:

```python
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
        for block in page.split("\n## ")[1:]:
            lead = block.split("\n\n")[0].split("\n", 1)[1]
            assert len(lead) <= 250, lead


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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tests/test_migrate_todo_to_wiki.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'migrate_todo_to_wiki'`

- [ ] **Step 3: Write the generator**

Create `scripts/migrate_todo_to_wiki.py`:

```python
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
        notes = r["notes"].split(";")[0][:120]
        table.append(f"| {r['topic']} | {r['opened']} | {r['closed']} | {r['result']} | {notes} |")
    return _sections(
        "Frozen archive of the retired docs/TODO.md rows. Closed work only; it\n"
        "records history and is never updated again.\n\n"
        "- Topic: archive-todo-log\n"
        "- Route: chain\n"
        "- Lifecycle: done\n"
        f"- Opened: {closed[0]['opened'] if closed else ''}\n"
        f"- Closed: {closed[-1]['closed'] if closed else ''}\n"
        "- Parent: main\n"
        "- Pending delivery: none",
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
    return _sections(
        "Task migrated from the retired docs/TODO.md row; live state continues\n"
        "on this page.\n\n"
        f"- Topic: {row['topic']}\n"
        "- Route: chain\n"
        f"- Lifecycle: {row['status']}\n"
        f"- Opened: {row['opened']}\n"
        f"- Closed: {row['closed']}\n"
        "- Parent: main\n"
        "- Pending delivery: none",
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tests/test_migrate_todo_to_wiki.py`
Expected: eight `ok test_...` lines, exit 0

- [ ] **Step 5: Generate the real migration output and check nothing was dropped**

Run: `python3 scripts/migrate_todo_to_wiki.py docs/TODO.md`
Expected: one archive page carrying the 14 closed rows, then three topic pages — `iwiki-mcp-user-scope`, `result-only-html-report`, `wiki-task-ledger`

Then confirm every table row survived the parse:

```bash
python3 - <<'PY'
import pathlib, sys
sys.path.insert(0, "scripts")
import migrate_todo_to_wiki as m
text = pathlib.Path("docs/TODO.md").read_text(encoding="utf-8")
raw = [l for l in (x.strip() for x in text.splitlines())
       if l.startswith("|") and not l.startswith("|---") and not l.startswith("| Topic")]
rows = m.parse_rows(text)
print(f"table rows: {len(raw)}  parsed: {len(rows)}")
assert len(raw) == len(rows), "a row was dropped during the parse"
done = [r for r in rows if r["status"] == "done"]
print(f"closed: {len(done)}  open: {len(rows) - len(done)}")
PY
```

Expected: `table rows: 17  parsed: 17`, then `closed: 14  open: 3`

- [ ] **Step 6: HUMAN CHECKPOINT — show the output and get approval**

Show the generated Markdown to the user. Do not write to the wiki and do not delete anything until they approve. This is the intent's proposal-first zone.

- [ ] **Step 7: Write the pages to the wiki**

For each generated page, in the domain from `wiki_status.primary`:

```text
wiki_write_page(domain=<primary>, slug=<slug>, markdown=<body>,
                type="reference", status="stable",
                tags=["task", "<topic>", "workflow:chain"],
                description="<one line>")
```

Frontmatter goes in the parameters only — never inline in `markdown`. Do not pass `source`: `docs/TODO.md` is about to be deleted, and an ignored path is rejected outright.

- [ ] **Step 8: Verify the wiki state**

Run `wiki_search(tags=["task"])`.
Expected: four pages — the archive plus the three open topics.

Run `wiki_lint(domain=<primary>)`.
Expected: no `pre_h2_text`, no `long_lead` on the new pages, no broken refs, no new orphans.

- [ ] **Step 9: Commit**

```bash
git add scripts/migrate_todo_to_wiki.py tests/test_migrate_todo_to_wiki.py
git commit -m "feat(migration): generate wiki ledger pages from docs/TODO.md"
```

---

### Task 5: Delete the tracker and the migration scaffolding

**Files:**
- Delete: `docs/TODO.md`, `scripts/migrate_todo_to_wiki.py`, `tests/test_migrate_todo_to_wiki.py`

**Interfaces:**
- Consumes: the wiki pages written in Task 4; the rule and skill changes from Tasks 1-3.
- Produces: the repository's final state — no in-repo tracker.

- [ ] **Step 1: Confirm nothing still reads the tracker**

Run: `grep -rn "docs/TODO.md" --include="*.md" --include="*.py" --include="*.json" . | grep -v "^./docs/superpowers/" | grep -v "^./.git"`
Expected: only `./scripts/migrate_todo_to_wiki.py` and `./tests/test_migrate_todo_to_wiki.py` (both deleted in the next step). Chain artifacts under `docs/superpowers/` legitimately reference the retired path as history.

- [ ] **Step 2: Delete the files**

```bash
git rm docs/TODO.md scripts/migrate_todo_to_wiki.py tests/test_migrate_todo_to_wiki.py
```

- [ ] **Step 3: Run the full LoEn suites once more**

Run: `python3 tests/test_loen_artifacts.py && python3 tests/test_loen_audit_writer.py`
Expected: all `ok ...`, exit 0 — the hooks never needed the file

- [ ] **Step 4: Verify the tracker is gone**

Run: `test -e docs/TODO.md && echo PRESENT || echo GONE`
Expected: `GONE`

Run: `grep -rn "docs/TODO.md" .nvm-isolated/.claude-isolated/CLAUDE.md .nvm-isolated/.claude-isolated/skills/ plugin/ tests/`
Expected: no output

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(ledger): retire docs/TODO.md in favour of the wiki task ledger"
```

---

## Self-Review

**Spec coverage.** §1 Architecture → Tasks 2-4 (rule, skill, pages). §2 Page schema → Task 4 generator plus the Global Constraints every task inherits. §3 Write points → Task 3 Step 1 (rule) and Task 2 Step 1 (gate). §4 Failure handling → Task 3 Step 1 (spool, fail-closed) and Task 2 Step 1 (unreachable server). §5 LoEn integration → Task 1. §6 Migration → Task 4. §7 Affected artifacts → every file in the table appears in a task. §8 Verification → the verify steps in Tasks 1, 2, 3, 5 and the wiki checks in Task 4 Step 8. §9 Divergence → Task 3 Step 1's closing bullet.

**Placeholder scan.** No "TBD", no "implement later", no "add error handling". Every code step carries the actual code. `TODO` appears only as the tracker's filename, as the page's section name, and as the placeholder token in check-chain's own checklists — Task 2 Step 2 explicitly says which of those to leave alone.

**Type consistency.** `parse_rows` / `archive_page` / `topic_page` are declared in Task 4's Interfaces block and used with those exact names in the test (Step 1), the implementation (Step 3), and the CLI (Step 5). `ARCHIVE_SLUG` matches the `reference/tasks/archive-todo-log` used in the test assertion and in Task 4 Step 8's expectation. `upsert_todo_row` appears only where it is being removed.

**Code executed, not just written.** Task 4's script and test were extracted from this plan and run against the real `docs/TODO.md` before the plan was committed. The first run exposed a silent data-loss bug: `loen-verifier-microvm` carries an unescaped `|` inside Notes (`verifier_isolation: subagent|microvm`), so a strict nine-cell check dropped the row without a word. `parse_rows` now rejoins the tail into Notes and raises on a genuinely short row; `test_notes_may_contain_pipes` and `test_short_row_fails_loud` pin both halves. Verified output: `table rows: 17  parsed: 17`, `closed: 14  open: 3`.

One spec item deliberately carries no task: `.gitignore`. §7 states it needs no entry because the spool lives outside the repository.
