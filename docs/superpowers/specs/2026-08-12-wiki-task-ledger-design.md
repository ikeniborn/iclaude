# Design: wiki-task-ledger

**Date:** 2026-08-12
**Intent:** `docs/superpowers/intents/2026-08-12-wiki-task-ledger-intent.md`

## Acceptance (from intent)

Desired Outcomes carried verbatim:

- An open task exists as a `tasks/<topic>` page in the wiki with
  `status: in-progress`, and is listed in `tasks/index`.
- Subagent dispatch events and workflow gates (`/check-chain` stage verdicts,
  LoEn stage transitions) appear as entries in the task page's `## Log` section.
- A closed task disappears from `tasks/index` `## Open` and gains one line in
  `tasks/changelog`.
- `docs/TODO.md` no longer exists and is no longer referenced as a tracker by
  any skill, hook, or doc.

Done when: `docs/TODO.md` is deleted; `tasks/index` and `tasks/changelog` exist
and are populated from the migration; `check-chain` Step 6 and the LoEn hooks no
longer write to `docs/TODO.md`; `wiki_lint` is clean.

## 1. Architecture

The ledger is three wiki pages in the project's **primary** write domain. The
main agent is the only writer; it reaches the wiki through the iwiki MCP tools.

```
main agent ──wiki_read_page──►  tasks/<topic>   (State/Goal/Scope/Log/Subagents/Evidence/Decisions)
     │     ──wiki_update_page─►
     │
     ├────────────────────────►  tasks/index     (## Open — table of open topics)
     ├────────────────────────►  tasks/changelog (## YYYY-MM — closed topics, newest first)
     │
     └──(server unreachable)──►  docs/.wiki-pending.jsonl ──drain──► wiki on next successful wiki_status

subagents  ──wiki_search / wiki_read_page / wiki_related──► wiki (read-only)
           ──delta as text──► main agent

LoEn hooks ──► docs/loen/<topic>/ (loop.yaml, audit.html, attempts.jsonl) — never touch the wiki
```

**Domain selection.** `wiki_status` returns `write` as a list and `primary` as a
single domain. The ledger is written to `primary`. When `primary` is absent and
`write` holds exactly one domain, that domain is used; when `write` holds
several and `primary` is absent, the agent asks the user rather than guessing.

Three components, each with one responsibility:

- **Rule block in `CLAUDE.md`** — what to write, when, and who writes. The single
  source of ledger behavior.
- **`check-chain` Step 6** — switches from a Markdown table row to MCP calls.
  Nothing else in the skill changes.
- **One-shot migration script** — generates the Markdown for the migrated pages,
  then is deleted in the same commit as `docs/TODO.md`.

No new runtime code ships. LoEn loses `upsert_todo_row`; the repository loses
`docs/TODO.md`.

## 2. Page schema

### 2.1 `tasks/<topic>`

Frontmatter: `type: task`, `status: in-progress | blocked | done`,
`tags: [<topic>, workflow:chain | workflow:loen]`, `source: <primary changed path>`.

The seven `##` headings are a contract — `wiki_update_page` addresses a section by
heading, so headings are never renamed or reordered:

```markdown
## State
- Workflow: chain | loen
- Continuation: execute | full | n/a
- Stage: Intent ✓ | Spec – | Plan – | Result –
- Branch: dev-<topic>
- Opened: YYYY-MM-DD
- Closed:
- Model route: <semantic route>

## Goal
One to three sentences: what and why.

## Scope
- In: <paths>
- Out: <explicitly excluded>

## Log
- YYYY-MM-DD — <actor> — <event> — <evidence>

## Subagents
| Agent | Task | Route | Verdict |
|---|---|---|---|

## Evidence
- <command → result, artifact hash, PR link>

## Decisions
- <decision> — <reason>
```

`<actor>` is `main` for the main agent, otherwise the subagent type. `<event>` is
one of `open`, `gate`, `dispatch`, `return`, `blocked`, `close`.

### 2.2 `tasks/index`

One section, `## Open`:

```markdown
| Topic | Status | Workflow | Stage | Branch | Opened |
|---|---|---|---|---|---|
| [[tasks/<topic>]] | in-progress | chain | Intent ✓ | dev-<topic> | YYYY-MM-DD |
```

Closed topics are removed from the table. There is no `## Recently closed`
section — that would duplicate the changelog.

### 2.3 `tasks/changelog`

Month sections, newest month first, one line per closed topic:

```markdown
## 2026-08
- 2026-08-12 — [[tasks/wiki-task-ledger]] — chain/full — OK — PR #91
```

Month granularity is mechanical, not cosmetic: `wiki_update_page` rewrites a whole
section, so a close must rewrite only the current month instead of the entire
history.

## 3. Write points

Every write is `wiki_read_page` (fetch the current section) followed by
`wiki_update_page` (replace that section in full). Writes happen immediately at
each event; no buffering.

| Moment | What is written |
|---|---|
| **Open** — before the first code or artifact change | `wiki_list_pages`; if `tasks/<topic>` is absent, `wiki_write_page(status="in-progress")` with all seven sections; then a row in `tasks/index` `## Open` |
| **Gate** — `/check-chain <stage>` verdict, LoEn stage transition, model-route switch | a `## Log` line plus the affected `## State` fields |
| **Dispatch** — a subagent is launched | a `## Log` line plus a `## Subagents` row with `Verdict: –` |
| **Return** — a subagent finishes | a `## Log` line carrying the delta, and the `Verdict` cell filled in |
| **Blocked** | frontmatter `status: blocked` plus the reason in `## Log`; the row stays in `tasks/index` |
| **Close** — result `OK` | `## State` `Closed` and frontmatter `status: done` → remove the row from `tasks/index` → append a line to the current month in `tasks/changelog` → `wiki_lint` |

**Close ordering is fixed**: page → index → changelog → lint. An interruption
mid-sequence leaves a state that `wiki_lint` and the next run can detect and
repair (a `done` page still listed under `## Open`). The reverse order would
publish a changelog line for a task still recorded as open.

## 4. Failure handling

The only failure mode worth handling is an unreachable or misconfigured MCP
server — observed twice while designing this task, when `write` was a string
instead of a list and every call failed.

One reaction for all calls:

1. The event is appended as one JSON line to `docs/.wiki-pending.jsonl`
   (`{"ts", "topic", "target", "section", "payload"}`).
2. The response to the user states `Tracking: unavailable`.
3. Work continues — the wiki channel never blocks the task.
4. On the next successful `wiki_status`, the queue is drained in order and the
   file is truncated.

`docs/.wiki-pending.jsonl` is gitignored: it is a local buffer, not a project
artifact.

No separate branches are specified for "page not found" (that is the Open path)
or "section conflict" (impossible with a single writer). If the queue survives
more than one consecutive task, the intent's `Halt` stop rule fires: the
configuration is broken and gets fixed rather than accumulating backlog.

## 5. LoEn integration

LoEn hooks keep writing `docs/loen/<topic>/` exactly as today. `upsert_todo_row`
is removed outright rather than repointed: `loop.yaml` already carries `status`
and `current_stage`, and `audit.html` is rendered alongside, so no information is
lost. Mirroring loop state into `tasks/<topic>` is the main agent's job at stage
boundaries, under the **Gate** row of §3.

This also removes a frequency mismatch: `audit-writer.py` runs on every
`PostToolUse` of an active loop, a rate no MCP-backed ledger should absorb.

## 6. Migration

`scripts/migrate_todo_to_wiki.py` generates Markdown only — it has no MCP access.
The agent writes the generated output through `wiki_write_page`.

- 14 `done` rows → grouped by their `Closed` date into `## 2026-07` (11) and
  `## 2026-06` (3) sections of `tasks/changelog`. The `Notes` column is condensed
  to verdict plus PR/commit.
- 3 `in-progress` rows (`iwiki-mcp-user-scope`, `result-only-html-report`,
  `wiki-task-ledger`) → one `tasks/<topic>` page each: `## State` from the
  Intent/Spec/Plan/Opened cells, a single `## Log` line
  `migrated from docs/TODO.md`, and the full `Notes` text under `## Evidence`.
- `tasks/index` `## Open` is then written with those three rows.
- The script is deleted in the same commit that deletes `docs/TODO.md`.

Deleting `docs/TODO.md` is a **proposal-first** action per the intent: the
generated Markdown is shown to the user before the file is removed.

## 7. Affected artifacts

| File | Change |
|---|---|
| `CLAUDE.md` | `Task Log (docs/TODO.md)` → `Task Log (iwiki)`; in `Task Topic`, the controlled surface `docs/TODO.md` `Topic` → slug `tasks/<topic>`; `Project Status Reports` reconciles `tasks/*` against the domain's subject-matter pages |
| `skills/check-chain/SKILL.md` | Step 6 becomes MCP calls; "TODO cell" / "TODO upsert" wording in the run modes and stage profiles follows |
| `plugin/loen/hooks/loen_artifacts.py` | drop `upsert_todo_row`, `_TODO_HEADER`, `_TODO_SEP`, `_LOEN_NOTE`, `_row_cells`; fix the module docstring |
| `plugin/loen/hooks/audit-writer.py` | drop the call and the docstring mention |
| `plugin/loen/skills/loop-reflect/SKILL.md` | drop `upsert_todo_row` from the terminal bash block |
| `plugin/loen/skills/audit/SKILL.md` | drop "mark the `docs/TODO.md` row" |
| `tests/test_loen_artifacts.py` | remove the two upsert tests (foreign-row guard, idempotency) |
| `tests/test_loen_audit_writer.py` | keep `not exists` assertions as a permanent guarantee; drop the assertion that reads the file's contents |
| `.gitignore` | add `docs/.wiki-pending.jsonl` |
| `plugin/loen/.claude-plugin/plugin.json` | bump `1.0.0` → `1.1.0`, with marketplace version-sync |
| `docs/TODO.md` | deleted |
| `scripts/migrate_todo_to_wiki.py` | added, then deleted with the migration commit |

## 8. Verification

Automated:

| Check | Command |
|---|---|
| LoEn suites green after the removal | `python3 -m pytest tests/test_loen_artifacts.py tests/test_loen_audit_writer.py` |
| The hook never creates the tracker | `not exists` assertion in `tests/test_loen_audit_writer.py` |
| No artifact references the tracker | `grep -rn "docs/TODO.md" CLAUDE.md skills/ plugin/ tests/` → empty |
| Plugin/marketplace versions agree | the existing version-sync test |

Manual, because ledger behavior lives in rules rather than code:

- `wiki_list_pages <primary>` lists `tasks/index`, `tasks/changelog`, and the
  three migrated topic pages.
- `wiki_lint` is clean — no broken `[[refs]]`, no orphan or stale pages.
- `wiki_read_page tasks/changelog` shows the 14 migrated lines under `## 2026-07`
  and `## 2026-06`.
