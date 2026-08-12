---
review:
  intent_hash: 8de7f8980672a2a0
  last_run: 2026-08-12
  phases:
    structure:
      status: passed
    completeness:
      status: passed
    clarity:
      status: passed
    consistency:
      status: passed
    alignment:
      status: passed
  findings:
    - id: F-001
      phase: clarity
      severity: WARNING
      section: "Stop Rules"
      section_hash: 7e87ade89a1b1dbb
      fragment: "check-chain Step 6 and the LoEn hooks no longer write to `docs/TODO.md`"
      text: "Done when clause mixed an implementation act (\"are rewritten\") with the observable behavior (\"no longer write to docs/TODO.md\"). The observable part alone is sufficient; naming the act risks reading as \"code written\" rather than a result."
      fix: "Rephrase to the observable behavior only: \"check-chain Step 6 and the LoEn hooks no longer write to docs/TODO.md\"."
      verdict: fixed
      verdict_at: 2026-08-12
---

# Intent: wiki-task-ledger

**Date:** 2026-08-12
**Status:** approved

## Objective
`docs/TODO.md` duplicates the iwiki domain as a source of truth for task tracking.
There is no single place that tracks a topic's subagent dispatches and their
returns during execution, and no mandatory changelog at the wiki level. Move
task tracking (open tasks, in-progress log, subagent activity, closed-task
changelog) entirely into the project's bound iwiki domain, replacing
`docs/TODO.md`.

## Desired Outcomes
- An open task exists as a `tasks/<topic>` page in the wiki with
  `status: in-progress`, and is listed in `tasks/index`.
- Subagent dispatch events and workflow gates (`/check-chain` stage verdicts,
  LoEn stage transitions) appear as entries in the task page's `## Log` section.
- A closed task disappears from `tasks/index` `## Open` and gains one line in
  `tasks/changelog`.
- `docs/TODO.md` no longer exists and is no longer referenced as a tracker by
  any skill, hook, or doc.

## Health Metrics
- `/check-chain` continues to open/close a task at every gate without losing
  events (parity with current `docs/TODO.md` upsert behavior).
- Project Status Reports continue to be built from two reconciled sources —
  now `tasks/*` pages plus the domain's subject-matter pages — instead of
  `docs/TODO.md` plus the domain.
- The LoEn loop does not break when the iwiki server is unreachable: LoEn
  hooks keep writing their runtime artifacts under `docs/loen/<topic>/`
  independently of wiki availability.
- No log entry is lost under concurrent subagents — enforced by a single
  writer (main agent only) to the wiki.

## Strategic Context
- Interacts with: iwiki MCP server (external, its own git repo
  `iwiki-personal`), the `check-chain` skill (Step 6 TODO upsert), the LoEn
  plugin (Python hooks, no MCP access — `loen_artifacts.py`,
  `audit-writer.py`), `CLAUDE.md` / `AGENTS.md` of both `iclaude` and
  `icodex` (this intent scopes rollout to `iclaude` only; `icodex` follows
  later as a separate task).
- Priority trade-off: **trust** over speed and cost — no task or event may be
  silently lost due to a wiki channel failure.

## Constraints
### Steering (behavioral guidance)
- The main agent is the sole writer to the wiki
  (`wiki_write_page` / `wiki_update_page` / `wiki_delete_page`). Subagents are
  read-only against the wiki (`wiki_search`, `wiki_read_page`, `wiki_related`
  allowed) and return their delta as text for the main agent to append.
- `wiki_update_page` rewrites a whole `##` section — always `wiki_read_page`
  before writing; never assume partial merge.
- If the wiki server is unreachable, do not block work: mark the task
  `Tracking: unavailable` in the response, continue, and write the page once
  the server is reachable again.

### Hard (architectural enforcement)
- `docs/TODO.md` is not a source of truth and is deleted after migration.
- LoEn hooks get no MCP access; they write only to `docs/loen/<topic>/`.
  Mirroring loop state into `tasks/<topic>` is the main agent's job at stage
  boundaries, not the hooks'.
- Exactly one page per active task, `tasks/<topic>`, keyed by `<topic>`.

## Autonomy Zones
- Full autonomy (reversible, low risk): writing task open/close, appending
  `## Log` lines, running `wiki_lint` after close.
- Guarded (log + confidence threshold): `wiki_delete_page` for genuinely
  stale sources only, with the reason recorded in the log.
- Proposal-first (needs approval): one-time migration of the existing
  `docs/TODO.md` rows into the wiki, and the file's subsequent removal — show
  the migration plan before deleting the file.
- No autonomy (human only): changes to `CLAUDE.md` rules, the `check-chain`
  skill, or LoEn hooks outside the scope of this intent's implementation.

> These zones OVERRIDE subagent-driven-development's "continuous execution,
> don't pause" default. Any task touching proposal-first / no-go decisions
> is marked HUMAN CHECKPOINT in the plan.

## Stop Rules
- Halt if: `wiki_status` fails to resolve a domain for the project across more
  than one consecutive task (signals broken configuration, not a one-off
  blip).
- Escalate if: `wiki_lint` finds orphan or stale `tasks/*` pages after a
  close.
- Done when: `docs/TODO.md` is deleted; `tasks/index` and `tasks/changelog`
  exist and are populated from the migration; `check-chain` Step 6 and the
  LoEn hooks no longer write to `docs/TODO.md`; `wiki_lint` is clean.
