---
chain:
  intent: docs/superpowers/intents/2026-08-12-wiki-task-ledger-intent.md
  intent_hash: 744c651c66a47cc1
review:
  spec_hash: 0384e7aa1a96164b
  last_run: 2026-08-12
  phases:
    structure:
      status: passed
    coverage:
      status: passed
    clarity:
      status: passed
    consistency:
      status: passed
  findings:
    - id: F-003
      phase: clarity
      severity: WARNING
      section: "6. Migration"
      section_hash: f8c6c6bee7da07f1
      fragment: "reference/tasks/archive-todo-log"
      text: "The archive slug names a single month, but the rows it carries close across 2026-06 (3) and 2026-07 (11). A reader searching by tag sees a page that claims narrower coverage than it holds."
      fix: "Rename the archive page to a month-neutral slug, e.g. reference/tasks/archive-todo-log."
      verdict: fixed
      verdict_at: 2026-08-12
---

# Design: wiki-task-ledger

**Date:** 2026-08-12
**Intent:** `docs/superpowers/intents/2026-08-12-wiki-task-ledger-intent.md`
**Shared standard:** `devops/concept/wiki-task-ledger` (adopted by `icodex`)

## Acceptance (from intent)

Desired Outcomes carried verbatim:

- An open task exists as a `reference/tasks/<topic>` page in the project's
  primary write domain, with lifecycle `in-progress` recorded in the page body.
- Project status for any topic is answerable by searching pages tagged `task`,
  with no central mutable index page to maintain.
- Subagent dispatch events, their returns, and workflow gates (`/check-chain`
  stage verdicts, LoEn stage transitions) appear as entries in the page's
  `Changelog` section, each carrying an idempotency key so a replay never
  duplicates an entry.
- A task reaches `done` only after its final evidence is recorded, every queued
  event is delivered, and `wiki_lint` reports no new finding for the task page;
  until then it stays `completion-pending`.
- `docs/TODO.md` no longer exists and is no longer referenced as a tracker by
  any skill, hook, or doc; its retired rows survive as one verified archive
  page.

Done when: `docs/TODO.md` is deleted and its rows survive as one archive page;
`check-chain` Step 6 and the LoEn hooks no longer write to `docs/TODO.md`; every
open topic has a `reference/tasks/<topic>` page discoverable by tag search;
`wiki_lint` reports no new task-page finding. Orphan entries for
`reference/tasks/*` are expected: refusing a central index is what leaves task
pages unreachable by link.

## 1. Architecture

The ledger is one page per topic in the project's **primary** write domain.
There is no index page and no changelog page: per-topic pages are the only task
state, and status is derived by searching pages tagged `task`.

```
parent agent ──wiki_read_page──►  reference/tasks/<topic>
     │       ──wiki_update_page─►    (Current State / TODO / Subtasks / Evidence / Changelog)
     │
     ├──wiki_search(tags=[task])──►  project status, derived — nothing central to maintain
     │
     └──(server unreachable)──────►  spool file outside the repo ──replay──► wiki at next checkpoint

subagents  ──wiki_search / wiki_read_page / wiki_related──► wiki (read-only)
           ──structured evidence──► parent agent

LoEn hooks ──► docs/loen/<topic>/ (loop.yaml, audit.html, attempts.jsonl) — never touch the wiki
```

**Domain selection.** `wiki_status` returns `write` as a list and `primary` as a
single domain. The ledger is written to `primary` (currently `iclaude`, with
`devops` also writable for shared standards). When `primary` is absent and
`write` holds exactly one domain, that domain is used; when `write` holds
several and `primary` is absent, the agent asks rather than guessing.

Three components, each with one responsibility:

- **Rule block in `CLAUDE.md`** — what to write, when, and who writes. The single
  source of ledger behavior for this repository.
- **`check-chain` Step 6** — switches from a Markdown table row to MCP calls.
  Nothing else in the skill changes.
- **One-shot migration script** — generates the Markdown for the archive page,
  then is deleted in the same commit as `docs/TODO.md`.

No new runtime code ships. LoEn loses `upsert_todo_row`; the repository loses
`docs/TODO.md`.

## 2. Page schema

Frontmatter is passed as `wiki_write_page` parameters, never inline in the
`markdown` argument — an inline block is duplicated by the server and becomes
indexable text before the first `##`, which `wiki_lint` reports as a blocking
`pre_h2_text` finding.

- `type: reference` and `status: stable` — the iwiki vocabulary defines neither a
  `task` type nor live lifecycle statuses; a `status: draft` write is rejected as
  `unknown_status`. Live lifecycle lives in the page body.
- `tags: [task, <topic>, workflow:<direct|chain|loen>]` — the `task` tag is what
  makes status derivable by search.

Five `##` sections, each present exactly once, in this order. Headings are a
contract: `wiki_update_page` addresses a section by heading, so they are never
renamed or reordered. Headings deeper than `##` are forbidden, and each section
opens with a lead paragraph of at most 250 characters followed by a blank line
before any list or table — otherwise `wiki_lint` reports `long_lead`.

The page template below is indented rather than fenced on purpose: a fenced block
starting at column 0 would make the example's `##` lines indistinguishable from
this document's own sections for any tool that splits on `^##`, including this
chain's own section-hash algorithm.

    ## Current State
    Topic, route, lifecycle, and ownership as of the last recorded event.

    - Topic: <topic>
    - Route: direct | chain | loen
    - Lifecycle: in-progress | blocked | completion-pending | done
    - Opened: YYYY-MM-DD
    - Closed:
    - Parent: main
    - Pending delivery: none | <count> queued events

    ## TODO
    Workflow-specific stages for this task; chain stages are not imposed on
    direct or loop work.

    - [x] intent — /check-chain intent OK
    - [ ] spec

    ## Subtasks
    Parent-recorded dispatch and return state for delegated work.

    | Subtask | Role | Route | Outcome |
    |---|---|---|---|

    ## Evidence
    Redacted paths, hashes, exit status, and check counts.

    - <command> → <exit status / count>
    - <artifact> → <hash>

    ## Changelog
    Ordered material lifecycle events, append-only.

    - YYYY-MM-DD — <kind> — <summary> — key:<idempotency key>

**Lifecycle** values: `in-progress`, `blocked`, `completion-pending`, `done`.

**Event kinds** in `Changelog`: `open`, `route`, `dispatch`, `return`, `scope`,
`decision`, `blocker`, `verification`, `close`. Tool calls are not events.

**Idempotency key** — `sha256(topic \n kind \n canonical redacted evidence)`
truncated to 12 characters. The timestamp, the actor, and the human-readable
summary must not enter the key, or a replay of the same fact would produce a
second entry. An event whose key already appears on the page is not appended
again, which is what makes spool replay safe. Past entries are append-only;
rewriting one is proposal-first and only to repair malformed or secret-bearing
content.

## 3. Write points

Every write is `wiki_read_page` (fetch the current section) followed by
`wiki_update_page` (replace that section in full). Writes happen immediately at
each event; no buffering while the server is reachable.

| Moment | What is written |
|---|---|
| **Open** — after bounded discovery, before any task-specific analysis or implementation | `wiki_list_pages`; if `reference/tasks/<topic>` is absent, `wiki_write_page` with all five sections and lifecycle `in-progress`; `Changelog` gets the `open` event |
| **Route** — workflow or model route decided or changed | `route` event; `Current State` `Route` updated |
| **Gate** — `/check-chain <stage>` verdict, LoEn stage transition | `verification` event; the `TODO` stage checked off |
| **Dispatch** — a subagent is launched | `dispatch` event, recorded *before* delegation; a `Subtasks` row with `Outcome: pending` |
| **Return** — a subagent finishes | `return` event from its structured evidence; the `Outcome` cell filled; `Evidence` extended |
| **Blocked** | `blocker` event; lifecycle `blocked` |
| **Close** | final evidence recorded → queued events drained → `wiki_lint` → lifecycle `done` and `Closed` set, with the `close` event appended |

**Close is fail-closed.** A task with undelivered events stays
`completion-pending`; `done` requires final evidence recorded, every queued event
delivered, and `wiki_lint` reporting no new finding for the page. An interrupted
close therefore never reads as a completed task.

**Subagent contract.** Subagents never mutate wiki state and never create their
own task pages. They return: subtask id, role, outcome, changed paths, checks,
blockers, and proposed changelog text. The parent serializes those returns onto
the one topic page — this is what keeps concurrent subagents from losing each
other's history under a section-replacing API.

## 4. Failure handling

The only failure mode worth handling is an unreachable or misconfigured MCP
server — observed twice while designing this task, when `write` was a string
instead of a list and every call failed.

Execution continues during an outage; durable completion does not.

1. The parent writes the event atomically to a spool file outside the
   repository: `$CLAUDE_CONFIG_DIR/state/iwiki-task-spool/<project>/<topic>.json`
   (the `icodex` standard names the same path under `$CODEX_HOME`). The spool
   holds ordered events and idempotency keys, and redacted evidence only — never
   raw command output, environment values, tokens, or credentials.
2. The response to the user states `Tracking: unavailable`.
3. The task's lifecycle becomes `completion-pending` and cannot reach `done`.
4. At the next successful checkpoint, events replay in order; a key already on
   the page counts as delivered. Queued data is deleted only after durable wiki
   state is confirmed.

The spool is a delivery queue, never the authoritative project status. Conflict
between durable and queued state halts work for proposal-first reconciliation
rather than either side overwriting the other. A queue surviving more than one
consecutive task fires the intent's `Halt` rule: the configuration is broken and
gets fixed rather than accumulating backlog.

## 5. LoEn integration

LoEn hooks keep writing `docs/loen/<topic>/` exactly as today. `upsert_todo_row`
is removed outright rather than repointed: `loop.yaml` already carries `status`
and `current_stage`, and `audit.html` is rendered alongside, so no information is
lost. This also removes a frequency mismatch: `audit-writer.py` runs on every
`PostToolUse` of an active loop, a rate no MCP-backed ledger should absorb.

**Material stage boundaries** — the intent's wording, enumerated here, per
finding F-002. The parent mirrors loop state into the task page at exactly these
points, and at no others:

- loop start (plan approved, `loop.yaml` armed) → `open` or `route` event
- each `loop-check` verdict → `verification` event
- each `loop-reflect` decision of `fix`, `revert`, or `handoff` → `decision` or
  `blocker` event
- terminal `7_result.md` or `handoff.md` → `close` event

Per-iteration act steps and hook-rendered `audit.html` refreshes are not
mirrored.

## 6. Migration

`scripts/migrate_todo_to_wiki.py` generates Markdown only — it has no MCP access.
The agent writes the generated output through `wiki_write_page`.

- The 14 `done` rows become one archive page,
  `reference/tasks/archive-todo-log`, tagged `task`, lifecycle `done`.
  It carries the retired rows as a table under `Evidence`, condensed to topic,
  dates, verdict, and PR/commit. One page, not fourteen: closed history needs to
  survive, not to be individually addressable.
- The 3 `in-progress` rows (`iwiki-mcp-user-scope`, `result-only-html-report`,
  `wiki-task-ledger`) become `reference/tasks/<topic>` pages: `Current State`
  from the Intent/Spec/Plan/Opened cells, one `Changelog` entry
  `migrated from docs/TODO.md`, the full `Notes` text under `Evidence`.
- The script is deleted in the same commit that deletes `docs/TODO.md`.

Deleting `docs/TODO.md` is **proposal-first** per the intent: the generated
Markdown is shown to the user before the file is removed.

## 7. Affected artifacts

| File | Change |
|---|---|
| `CLAUDE.md` | `Task Log (docs/TODO.md)` → `Task Log (iwiki)`, covering direct work too; in `Task Topic`, the controlled surface `docs/TODO.md` `Topic` → slug `reference/tasks/<topic>`; `Project Status Reports` derives status by tag search and reconciles it against the domain's subject-matter pages |
| `skills/check-chain/SKILL.md` | Step 6 becomes MCP calls against the topic page; "TODO cell" / "TODO upsert" wording in the run modes and stage profiles follows |
| `plugin/loen/hooks/loen_artifacts.py` | drop `upsert_todo_row`, `_TODO_HEADER`, `_TODO_SEP`, `_LOEN_NOTE`, `_row_cells`; fix the module docstring |
| `plugin/loen/hooks/audit-writer.py` | drop the call and the docstring mention |
| `plugin/loen/skills/loop-reflect/SKILL.md` | drop `upsert_todo_row` from the terminal bash block |
| `plugin/loen/skills/audit/SKILL.md` | drop "mark the `docs/TODO.md` row" |
| `tests/test_loen_artifacts.py` | remove the two upsert tests (foreign-row guard, idempotency) |
| `tests/test_loen_audit_writer.py` | keep the `not exists` assertions as a permanent guarantee; drop the assertion that reads the file's contents |
| `plugin/loen/.claude-plugin/plugin.json` | bump `1.0.0` → `1.1.0`, with marketplace version-sync |
| `docs/TODO.md` | deleted |
| `scripts/migrate_todo_to_wiki.py` | added, then deleted with the migration commit |

`.gitignore` needs no entry: the spool lives outside the repository.

## 8. Verification

Automated:

| Check | Command |
|---|---|
| LoEn suites green after the removal | `python3 -m pytest tests/test_loen_artifacts.py tests/test_loen_audit_writer.py` |
| The hook never creates the tracker | `not exists` assertion in `tests/test_loen_audit_writer.py` |
| No artifact references the tracker | `grep -rn "docs/TODO.md" CLAUDE.md skills/ plugin/ tests/` → empty |
| Plugin/marketplace versions agree | the existing version-sync test |

Manual, because ledger behavior lives in rules rather than code:

- `wiki_search(tags=["task"])` returns the three migrated topic pages plus the
  archive page — status is derivable without an index.
- `wiki_lint` reports no new task-page finding: no `pre_h2_text`, no `long_lead`
  on task pages, no broken refs, nothing stale. Orphan entries for
  `reference/tasks/*` are expected, not defects — refusing a central index is
  what makes task pages unreachable by link, and status comes from tag search
  instead. This wording matches the shared standard's own completion criterion.
- A simulated outage leaves the task `completion-pending`, and a replay after
  recovery adds no duplicate `Changelog` entry (idempotency keys hold).

## 9. Divergence from the shared standard

None. Where this design is more specific than
`devops/concept/wiki-task-ledger` — the enumerated material stage boundaries in
§5, the `$CLAUDE_CONFIG_DIR` spool path in §4, the migration shape in §6 — it
specifies `iclaude` mechanics under the standard rather than departing from it.
Any future deviation is recorded on the shared page before it is implemented,
per the intent's hard constraint.
