---
review:
  intent_hash: bd8fae72ce0c2ceb
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
      section_hash: 1998e6563b7088e0
      fragment: "check-chain Step 6 and the LoEn hooks no longer write to `docs/TODO.md`"
      text: "Done when clause mixed an implementation act (\"are rewritten\") with the observable behavior (\"no longer write to docs/TODO.md\"). The observable part alone is sufficient; naming the act risks reading as \"code written\" rather than a result."
      fix: "Rephrase to the observable behavior only: \"check-chain Step 6 and the LoEn hooks no longer write to docs/TODO.md\"."
      verdict: fixed
      verdict_at: 2026-08-12
    - id: F-002
      phase: clarity
      severity: WARNING
      section: "Constraints"
      section_hash: 8c1ff0a2a4be3a6c
      fragment: "Mirroring loop state into the task page is the parent agent's job at material stage boundaries"
      text: "\"material stage boundaries\" carries no criterion, so an agent can read it as every LoEn stage or only terminal ones. The shared standard uses the same wording, so the criterion belongs in the design, not in a divergent intent."
      fix: "Leave the intent wording aligned with the shared standard and enumerate the qualifying boundaries in the design's LoEn section."
      verdict: accepted
      verdict_at: 2026-08-12
---

# Intent: wiki-task-ledger

**Date:** 2026-08-12
**Status:** approved

## Objective
`docs/TODO.md` duplicates the iwiki domain as a source of truth for task
tracking. There is no single place that tracks a topic's subagent dispatches and
their returns during execution, and no mandatory lifecycle record at the wiki
level. Move task tracking entirely into the project's bound iwiki domain,
replacing `docs/TODO.md`, and align `iclaude` with the cross-agent standard
`devops/concept/wiki-task-ledger`, which `icodex` already adopted: every task —
direct, chain, or loop-workflow, including small fixes and read-only analysis —
gets one authoritative page.

## Desired Outcomes
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

## Health Metrics
- `/check-chain` continues to record a task's stage at every gate without losing
  events (parity with current `docs/TODO.md` upsert behavior).
- Project Status Reports continue to be built from two reconciled sources — now
  task pages plus the domain's subject-matter pages — instead of `docs/TODO.md`
  plus the domain.
- The LoEn loop does not break when the iwiki server is unreachable: LoEn hooks
  keep writing their runtime artifacts under `docs/loen/<topic>/` independently
  of wiki availability.
- No log entry is lost under concurrent subagents — enforced by a single writer
  (parent agent only) to the wiki.
- `iclaude` task pages stay readable by an `icodex` agent under the shared
  standard: same slug namespace, same required sections, same lifecycle values.

## Strategic Context
- Interacts with: iwiki MCP server (external, its own git repo
  `iwiki-personal`), the shared standard page
  `devops/concept/wiki-task-ledger` and the `icodex` agents that follow it, the
  `check-chain` skill (Step 6 TODO upsert), the LoEn plugin (Python hooks, no
  MCP access — `loen_artifacts.py`, `audit-writer.py`), `CLAUDE.md` /
  `AGENTS.md` of both `iclaude` and `icodex` (this intent scopes rollout to
  `iclaude` only; `icodex` adopts separately).
- Priority trade-off: **trust** over speed and cost — no task or event may be
  silently lost due to a wiki channel failure.

## Constraints
### Steering (behavioral guidance)
- The parent agent is the sole writer to the wiki
  (`wiki_write_page` / `wiki_update_page` / `wiki_delete_page`). Subagents are
  read-only against the wiki (`wiki_search`, `wiki_read_page`, `wiki_related`
  allowed) and return structured evidence — subtask id, role, outcome, changed
  paths, checks, blockers, proposed changelog text — for the parent to record.
- `wiki_update_page` rewrites a whole `##` section — always `wiki_read_page`
  before writing; never assume partial merge.
- If the wiki server is unreachable, execution continues, but completion does
  not: the task stays `completion-pending` until its queued events are
  delivered.

### Hard (architectural enforcement)
- `docs/TODO.md` is not a source of truth and is deleted after migration.
- LoEn hooks get no MCP access; they write only to `docs/loen/<topic>/`.
  Mirroring loop state into the task page is the parent agent's job at material
  stage boundaries, not the hooks'.
- Exactly one page per task, `reference/tasks/<topic>`, keyed by `<topic>`.
- No central mutable index page and no separate changelog page: per-topic pages
  are the only task state.
- Queued events live outside the repository, carry redacted evidence only, and
  are deleted only after durable wiki state is confirmed.
- Divergence from `devops/concept/wiki-task-ledger` is not introduced silently:
  any `iclaude`-specific deviation is recorded on that shared page.

## Autonomy Zones
- Full autonomy (reversible, low risk): opening a task page, appending
  `Changelog` entries, recording dispatches and returns, running `wiki_lint`.
- Guarded (log + confidence threshold): `wiki_delete_page` for genuinely stale
  sources only, with the reason recorded in the page's `Changelog`.
- Proposal-first (needs approval): the one-time archive migration of
  `docs/TODO.md` and the file's subsequent removal; reconciliation of
  conflicting durable state.
- No autonomy (human only): changes to `CLAUDE.md` rules, the `check-chain`
  skill, or LoEn hooks outside the scope of this intent's implementation;
  changing the shared standard page on behalf of other projects.

> These zones OVERRIDE subagent-driven-development's "continuous execution,
> don't pause" default. Any task touching proposal-first / no-go decisions
> is marked HUMAN CHECKPOINT in the plan.

## Stop Rules
- Halt if: `wiki_status` fails to resolve a domain for the project across more
  than one consecutive task (signals broken configuration, not a one-off blip).
- Halt if: durable wiki state conflicts with queued state — reconcile
  proposal-first rather than overwriting either side.
- Escalate if: `wiki_lint` reports a new finding for a task page after a close.
- Done when: `docs/TODO.md` is deleted and its rows survive as one archive page;
  `check-chain` Step 6 and the LoEn hooks no longer write to `docs/TODO.md`;
  every open topic has a `reference/tasks/<topic>` page discoverable by tag
  search; `wiki_lint` is clean.
