---
name: task-ledger
description: Use when starting, updating, delegating, completing, or reporting a direct, chain, or LoEn project task that needs authoritative iwiki lifecycle state.
---

# Task Ledger

Track every direct, chain, and LoEn task, including read-only work. The parent agent is the sole writer; task state lives on iwiki, never in a repository ledger.

## Required flow

1. Call `wiki_status`; bind the project domain for read/write when present.
2. Resolve one English lowercase-kebab-case topic; stop on conflicting controlled topics.
3. Read or create `reference/tasks/<topic>` with `type: reference`, `status: stable`, and tag `task`.
4. Load durable event keys, then replay pending spool events in order; acknowledge only after confirmed page replay.
5. Keep exactly `## Current State`, `## TODO`, `## Subtasks`, `## Evidence`, and `## Changelog`. Each starts with a <=250-character lead paragraph and blank line; use no heading deeper than `##`.
6. Parent records material events. Before delegation record `dispatch`; subagents never write wiki and return subtask ID, role, outcome, changed paths, checks, blockers, and proposed changelog text. Record `return` before the next transition.
7. On MCP failure, enqueue redacted events with `scripts/task_spool.py` and use `completion-pending`.
8. Set `done` only after final evidence, successful wiki write, empty spool, and `wiki_lint` without a new task-page finding.

If iwiki is connected but the project domain is absent, the task page cannot be read or created. Parent may continue with redacted spool events, report durable status unavailable, and retain `completion-pending`; completion remains fail-closed until a bound domain permits replay, wiki write, and lint. This differs from the normal bound-domain flow above.

## State and events

Lifecycle: `in-progress`, `blocked`, `completion-pending`, `done`. Material event kinds: `open`, `route`, `dispatch`, `return`, `decision`, `blocker`, `verification`, `gate`, `close`; append them chronologically, not every tool call.

`Current State` records topic, route, lifecycle, opened, closed (when done), parent, and pending-delivery. `TODO` is workflow-specific and must not impose chain stages on direct or LoEn work.

Input schema is exactly `{kind, occurred_at, actor, summary, evidence}`; persisted event schema adds canonical `evidence_hash` and `event_id`. Evidence is `{paths, checks, hashes}`. Paths are repository-relative; checks contain only name, passed/failed status, and integer exit code; hashes are lowercase hex. Never record credentials, environment values, auth files, or raw command output.

Idempotency key: SHA-256 of topic, kind, and canonical redacted evidence hash, truncated to 16 hex characters. Exclude timestamp, actor, and summary. Page replay happens outside helper: skip page keys already durable, then acknowledge confirmed events.

## History segments and domain journal

Keep complete task history in linked history segments. The task page `Changelog` is a small manifest that links to the first and bounded active segment; it does not repeat past events. Each segment is `reference/task-history/<topic>-<sequence>`, carries up to 20 events, and links to its successor after rollover. A new event rewrites only the bounded active segment. On replay, the parent traverses history segments, loads their durable event IDs, then appends only missing events. Closing a topic leaves every segment reachable from the task page and preserves its full event history.

The domain changelog is `reference/domain-changelog`. It contains curated domain-level changes such as standards, releases, migrations, and cross-task decisions, with links to affected task pages. Do not add routine task events there and do not use it as a task index.

An `orphans` entry for `reference/tasks/*` is an expected task-page orphan advisory: status discovery enumerates task pages with `wiki_list_pages` rather than following an inbound central index. It does not block closure unless `wiki_lint` reports another finding for that task page.

## Helper

`scripts/task_spool.py` is the only executable surface. It stores redacted events under `$CLAUDE_CONFIG_DIR/state/iwiki-task-spool/<project>/<topic>.json`:

```bash
printf '%s' "$event_json" | python3 scripts/task_spool.py enqueue --config-dir "$CLAUDE_CONFIG_DIR" --project <project> --topic <topic>
python3 scripts/task_spool.py list --config-dir "$CLAUDE_CONFIG_DIR" --project <project> --topic <topic>
python3 scripts/task_spool.py ack --config-dir "$CLAUDE_CONFIG_DIR" --project <project> --topic <topic> --event-id <id>
```

`enqueue` is idempotent on the event ID, `list` never mutates the queue, and `ack` removes exactly one confirmed event and deletes the queue file once empty.

## Boundaries and reporting

`task_spool.py` is dependency-free local storage only and must never call MCP; never modify iwiki-mcp, call `wiki_sync`, or create a subagent task page. Threat model: the launcher-created per-user `CLAUDE_CONFIG_DIR` is trusted even when mode 0775; helper-managed `state/iwiki-task-spool/<project>` dirs are owner-only 0700 and unsafe preexisting managed components are rejected, preventing cross-user mutation. It is a redaction backstop: reject controls, secret assignments, authentication/credential paths, `.env` paths, symlinks, and non-regular spool targets before writing. Status reports enumerate task pages with `wiki_list_pages(domain)` filtered to the `reference/tasks/` prefix, read relevant pages, report lifecycle/TODO/pending delivery/lint findings, and list `in-progress` tasks older than 14 days. If iwiki is unavailable, say durable status is unavailable; spool evidence is non-authoritative.
