---
review:
  intent_hash: c8d088abafde6458
  last_run: 2026-08-17
  phases:
    structure: {status: passed, findings: []}
    completeness: {status: passed, findings: []}
    clarity: {status: passed, findings: []}
    consistency: {status: passed, findings: []}
    alignment: {status: passed, findings: []}
result_check:
  verdict: OK
  intent_hash: c8d088abafde6458
  last_run: 2026-08-17
---

# Intent: iwiki-dual-mcp-registration

**Date:** 2026-08-17
**Status:** approved

## Objective
iclaude currently registers exactly one iwiki MCP server per session (`lib/iwiki/mcp.sh`'s
`iwiki_mcp_enabled` / `_iwiki_remote_selected` picks remote over local exclusively). This
breaks the code-graph workflow: `wiki_code_index` needs a local repository checkout, so it
always returns `source_unavailable` under remote (hosted HTTP) mode; `wiki_code_publish_*`
needs a hosted authenticated transit, so it returns `unsupported_storage` under local
(stdio) mode. Build a code graph locally, then publish it to a hosted server — that
sequence is currently impossible within one session. Support running the code-graph build
and its MCP publication at the same time, now.

## Desired Outcomes
- In a session with both local (`IWIKI_COMMAND`/`IWIKI_LLM_KEY`) and remote
  (`IWIKI_REMOTE_URL`/`IWIKI_REMOTE_TOKEN`) configured, `wiki_code_index` no longer fails
  with `source_unavailable` — it builds the graph locally.
- In the same session, `wiki_code_publish_begin`/`_batch`/`_finalize` successfully push the
  built snapshot to the hosted server.
- Existing content tools (`wiki_search`, `wiki_read_page`, task-ledger writes, etc.)
  continue to route through remote/primary as before — no regression.
- Sessions with only local or only remote configured behave exactly as they do today
  (single-server, unchanged).

## Health Metrics
- `lib/iwiki/mcp.sh` enable gate: single-server sessions (local-only or remote-only)
  behave identically to today; `tests/test_iwiki_mcp.sh` stays green with its existing
  single-mode assertions unchanged.
- `hooks/iwiki-remote-scope.js`: remote-only sessions still get the same preflight
  instruction as today; `tests/test_iwiki_remote_scope.sh` does not regress.
- Existing task-ledger workflow (`wiki_bind` → `wiki_status` → mutating calls) keeps its
  current mechanics for content — only code-graph tools move to a different server.
- No secret (`IWIKI_REMOTE_TOKEN`, `IWIKI_LLM_KEY`, etc.) ever lands in a tracked config
  file when splicing the two JSON configs into one.

## Strategic Context
- Interacts with: `lib/launcher/launch.sh` (native exec / PII-proxy / combined router
  branches — the microVM path is already uncovered by `--mcp-config` and stays that way),
  `.claude_config` / `.claude_config.example`, tracked `mcp/iwiki.json` +
  `mcp/iwiki-remote.json`, `hooks/iwiki-remote-scope.js`,
  `tests/test_iwiki_mcp.sh` + `tests/test_iwiki_remote_scope.sh`, the user's global
  `CLAUDE.md` iwiki Project Binding rule, any skill that references `mcp__iwiki__*` tool
  names directly.
- Priority trade-off: **trust** — not breaking today's single-mode (local-only /
  remote-only) sessions outweighs shipping the dual mode faster.

## Constraints
### Steering (behavioral guidance)
- Renaming the server must not change single-mode session behavior (local-only,
  remote-only) — they see the same server, the same tool names as today, unless their
  config actually becomes dual.
- Dual mode is a transparent splice of the two existing JSON configs into one rendered
  file at launch, not a hand-rewrite of either tracked file.
- The agent-facing hook instruction must explicitly route: content tools → remote/primary,
  code-graph tools (`wiki_code_index`/`wiki_code_search`/`wiki_code_context`) → local.

### Hard (architectural enforcement)
- Secrets (`IWIKI_REMOTE_TOKEN`, `IWIKI_LLM_KEY`, `IWIKI_DB_PASSWORD`, etc.) never land in
  a tracked git file — only `${VAR}` placeholders, as today.
- The microVM launch path is not touched (already not covered by `--mcp-config`).
- No change to the `.iwiki.toml` schema (the `[code_graph]` table stays as-is, per-project).

## Autonomy Zones
- Full autonomy (reversible, low risk): `lib/iwiki/mcp.sh`, `mcp/iwiki.json`,
  `mcp/iwiki-remote.json`, `lib/launcher/launch.sh`, `tests/test_iwiki_mcp.sh`,
  `tests/test_iwiki_remote_scope.sh`, `hooks/iwiki-remote-scope.js`,
  `docs/iwiki-mcp-modes.md`.
- Guarded (log + confidence threshold): updates to `.claude_config.example` (variable
  documentation).
- Proposal-first (needs approval): any edit to a skill that references `mcp__iwiki__*` by
  name, if any are found.
- No autonomy (human only): the user's global `CLAUDE.md` outside this repo — not a
  project file, never edited by this task.

> These zones OVERRIDE subagent-driven-development's "continuous execution,
> don't pause" default. Any task touching proposal-first / no-go decisions
> is marked HUMAN CHECKPOINT in the plan.

## Stop Rules
- Halt if: renaming the server is found to break a single-mode session (local-only or
  remote-only).
- Escalate if: solving this turns out to require changing the `.iwiki.toml` schema.
- Done when: in a dual session (local + remote both configured), `wiki_code_index`
  builds the graph without `source_unavailable`, `wiki_code_publish_*` pushes the
  snapshot to the hosted server in the same session, both existing test files stay
  green, and single-mode sessions show no regression (verified manually / by test).
