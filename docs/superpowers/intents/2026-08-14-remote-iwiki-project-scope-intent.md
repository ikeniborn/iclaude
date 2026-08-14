---
review:
  intent_hash: b64809290c5bf624
  last_run: 2026-08-14
  phases:
    structure: {status: passed, findings: []}
    completeness: {status: passed, findings: []}
    clarity: {status: passed, findings: []}
    consistency: {status: passed, findings: []}
    alignment: {status: passed, findings: []}
---

# Intent: remote-iwiki-project-scope

**Date:** 2026-08-14
**Status:** approved

## Objective
Under `IWIKI_REMOTE_URL` (Streamable HTTP iwiki MCP), the agent must apply the current
project's `.iwiki.toml` scope via `wiki_bind` before any task-specific wiki call. Without
this, the session's default bearer-token scope (broader or narrower than the project's
intended `read`/`write`/`primary`) governs wiki access instead, and cross-domain access
must not be narrowed to just the primary domain. Reference: iclaude has no such
preflight surface today; a live `wiki_status` in this session returned `primary: aioperator`
instead of the project's own scope, confirming the gap. icodex already ships this behavior
(`lib/iwiki/iwiki.sh: ensure_iwiki_remote_scope_instructions`) and is the port source.

## Desired Outcomes
- When `IWIKI_REMOTE_URL` is set, a SessionStart hook emits a managed region with the
  preflight instruction into `additionalContext`.
- When running stdio (or `IWIKI_REMOTE_URL` unset), the region is absent / not emitted.
- `write = ["iclaude", "devops"]` in `.iwiki.toml` causes the agent to call `wiki_bind`
  with the full TOML scope before the first `wiki_status` / `wiki_search` / task-ledger /
  any other wiki call, enabling writes to `devops` without a manual bind.
- A token without a grant on `devops` yields a 403 from the server, with no heuristic
  fallback and no mutating call attempted.
- A config with only `primary` set behaves exactly as before (no regression).
- A repeated bind within the same session restores the full TOML scope (never narrows to
  the current session scope, project basename, or primary domain alone).

## Health Metrics
- Local stdio wiring (`iwiki_mcp_enabled`, `iwiki_mcp_launch_config`, server-local
  `.iwiki.toml` binding) is unchanged.
- `tests/test_iwiki_mcp.sh` and the full Bash test suite stay green.
- Secrets (`IWIKI_REMOTE_TOKEN`, LLM/DB keys) never reach `config.toml`, `settings.json`,
  the generated instruction text, logs, or error output.
- A normal (non-remote) launch produces no new output or overhead in `additionalContext`.

## Strategic Context
- Interacts with: `lib/iwiki/mcp.sh` (remote/stdio selection), `lib/launcher/launch.sh`
  (MCP server registration), `.claude-isolated/settings.json` (SessionStart hooks), a new
  `hooks/iwiki-remote-scope.js`, the iwiki MCP server (bearer-token grants), and the
  project-root `.iwiki.toml`.
- Priority trade-off: trust over speed/cost — fail closed on missing/invalid scope or a
  403, never broaden scope heuristically.

## Constraints
### Steering (behavioral guidance)
- Normalize domain names before passing them to `wiki_bind`.
- `write` supports both a string and an array; every scope value from TOML is preserved.
- On a missing/invalid `.iwiki.toml`, never substitute the project basename, the primary
  domain, or the current session scope.

### Hard (architectural enforcement)
- Do not modify the iwiki-mcp server.
- The server and its bearer-token grants remain the absolute authorization ceiling; never
  bypass them.
- Never send the server the TOML text, file paths, `iwiki_id`, tokens, or other
  credentials.
- Secrets flow only through `bearer_token_env_var`; never literal in config, logs, or
  error output.
- On invalid scope or a rejected bind (including 403), no mutating wiki call is made and
  lifecycle stays `completion-pending`.

## Autonomy Zones
- Full autonomy (reversible, low risk): rendering/removing the managed region via the
  hook (deterministic, idempotent, visible as a tracked-file diff).
- Guarded (log + confidence threshold): extending the test suite
  (`tests/test_iwiki_mcp.sh` plus a new hook test).
- Proposal-first (needs approval): changing the managed instruction's wording/format
  beyond the icodex-ported text, if that becomes necessary.
- No autonomy (human only): the iwiki-mcp server itself, bearer-token grant policy.

> These zones OVERRIDE subagent-driven-development's "continuous execution,
> don't pause" default. Any task touching proposal-first / no-go decisions
> is marked HUMAN CHECKPOINT in the plan.

## Stop Rules
- Halt if: delivering this requires modifying the iwiki-mcp server.
- Escalate if: the SessionStart hook cannot read `IWIKI_REMOTE_URL` at hook-invocation
  time (architectural blocker).
- Done when: the full Bash test suite passes; `write = ["iclaude", "devops"]` produces an
  automatic bind that allows writing to `devops`; a token without a `devops` grant yields a
  403 with no fallback and no write; a config with only `primary` is unchanged in
  behavior; a repeated bind restores the full TOML scope; the remote managed instruction
  is idempotent and disappears under stdio.
