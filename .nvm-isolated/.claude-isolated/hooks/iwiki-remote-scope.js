#!/usr/bin/env node
// iwiki — SessionStart hook: remote-scope preflight instruction
//
// Under a hosted (Streamable HTTP) iwiki MCP server, the bearer token's own
// grants remain the authorization ceiling, but the agent must still apply the
// current project's `.iwiki.toml` scope via `wiki_bind` before any
// task-specific wiki call — otherwise whatever scope the token defaults to
// governs instead of the project's own read/write/primary intent.
//
// Local stdio mode does not need this: the server resolves the project
// binding itself from `.iwiki.toml` (see lib/iwiki/mcp.sh), so this hook
// emits nothing when IWIKI_REMOTE_URL is unset. Since SessionStart context is
// regenerated fresh every session (nothing is written to a tracked file),
// idempotency and stdio-removal are automatic — the same env check runs once
// per launch and either emits the block or emits nothing.

if (!process.env.IWIKI_REMOTE_URL) {
  process.stdout.write('OK');
  process.exit(0);
}

// IWIKI_COMMAND is exported by lib/iwiki/mcp.sh's iwiki_resolve_command as a
// side effect of the launch-time enable gate, so by the time this hook runs
// (spawned as a child of that same launch) it is present in the environment
// whenever local mode is also usable. Together with IWIKI_LLM_KEY this
// mirrors _iwiki_local_selected's conditions closely enough to tell the
// agent whether it is looking at a dual (mcp/iwiki-dual.json) or a
// remote-only registration — see lib/iwiki/mcp.sh.
const dualActive = Boolean(process.env.IWIKI_COMMAND && process.env.IWIKI_LLM_KEY);

process.stdout.write(
  '## Remote iwiki project scope\n\n' +
  'Before the first wiki call, load `read`, `write`, `primary`, and — when present — ' +
  '`[specifications].mode` from the project-root `.iwiki.toml`. Normalize domain ' +
  'names before passing them to `wiki_bind`; never pass TOML text, paths, ' +
  '`iwiki_id`, tokens, or other credentials. Call `wiki_bind` with the full ' +
  'normalized `read`, `write`, and `primary` values from `.iwiki.toml`, and pass ' +
  '`[specifications].mode` as `specification_mode`, before `wiki_status`, ' +
  '`wiki_search`, task-ledger, or any other wiki call.\n\n' +
  'Do not infer, broaden, or replace that scope with a project name, primary ' +
  'domain, or current session scope. `wiki_search` also takes a `scope` ' +
  'parameter: leave it at its `project` default, because `scope="all"` ignores ' +
  'the bound `read` list. On a missing or invalid TOML scope, or a ' +
  'rejected bind such as 403, show a brief reason, do not make mutating wiki ' +
  'calls, and retain task lifecycle `completion-pending`. The remote server\'s ' +
  'token grants remain the absolute authorization limit.\n\n' +

  'The binding is session-scoped, keyed by `mcp-session-id`, and expires after ' +
  '1800 idle seconds, so a reconnect or a restarted server drops it silently. ' +
  '`wiki_status`, `wiki_bind`, `wiki_code_status`, `wiki_code_search`, ' +
  '`wiki_code_context`, and `wiki_code_publish_begin` report `binding_source`: ' +
  '`session` means your bind chose the scope, `token_default` means the server ' +
  'fell back to the token\'s own grants. Seeing `token_default` after you bound ' +
  'means the selection was lost — re-bind before trusting the answer. This ' +
  'matters most for the three domain-free code reads, which target ' +
  '`binding.primary` rather than a named domain and otherwise report another ' +
  'domain\'s snapshot as `state: "ready"`, `fresh: true`; under the fallback they ' +
  'also append `binding_defaulted` to `warnings`, and a server configured with ' +
  '`[code_graph] require_session_binding = true` refuses them with ' +
  '`binding_not_selected`. A primary replaced by the write-scope intersection ' +
  'appears as `primary_substituted: true` beside `requested_primary` — report ' +
  'that as a binding error rather than working in the substituted scope.\n\n' +
  'Specification (Given-When-Then) policy is resolved server-side, but this ' +
  'transport carries the project tier: the `[specifications] mode` you passed as ' +
  '`wiki_bind(specification_mode=…)` is gated by the server\'s own ' +
  '`allow_project_mode` switch and a tighten-only guard. Still take each domain\'s ' +
  'effective mode from the `specifications` block of `wiki_status`, never from the ' +
  'project file: precedence is hosted exact override, the carried project mode, ' +
  'hosted default, then the built-in `optional`, so a `[specifications] mode` in ' +
  '`.iwiki.toml` counts only when the answer reports `source: project` — a refused ' +
  'value comes back as `project_mode_suppressed: true`, and a hosted override wins ' +
  'over it outright. If the bind rejects `specification_mode`, the parameter is ' +
  'absent, or `wiki_status` reports a looser mode than the project file asked for, ' +
  'report the mismatch, make no mutating specification call, and retain task ' +
  'lifecycle `completion-pending`; ordinary Wiki work stays available.\n\n' +
  (dualActive
    ? 'This session has both transports registered: `wiki_code_index`, ' +
      '`wiki_code_search`, and `wiki_code_context` run on the `iwiki-local` ' +
      'server (it has the repository checkout); every other wiki tool, ' +
      'including `wiki_code_publish_begin`/`_batch`/`_finalize`, runs on ' +
      '`iwiki-remote` as usual. No config switch is needed for either. The ' +
      '`specification_mode` argument belongs to the hosted bind only — the ' +
      '`iwiki-local` server reads `.iwiki.toml` itself and rejects a client ' +
      'binding override with `project_config_manual_edit_required`. ' +
      'Trust code results only when `wiki_code_status` reports `state: ' +
      '"ready"` and `fresh: true`; otherwise fall back to repository search. ' +
      'A code read served by `iwiki-remote` never returns file source — ' +
      '`include_source=true` yields graph context plus `source_unavailable`.'
    : '`wiki_code_index` is unavailable under this hosted-only mode — it needs a ' +
      'local repository checkout on the server\'s disk, which a remote HTTP ' +
      'server does not have, so it returns `source_unavailable`. That error ' +
      'means the active MCP server config must switch to the local stdio one ' +
      '(`mcp/iwiki.json`, via `IWIKI_COMMAND`/`IWIKI_BASE_DIR`) or add it ' +
      'alongside this one (`mcp/iwiki-dual.json`) and the session restarted — ' +
      'not that `.iwiki.toml` needs editing. `wiki_code_status`, ' +
      '`wiki_code_search`, and `wiki_code_context` still answer here from the ' +
      'published snapshot; trust them only at `state: "ready"` with `fresh: ' +
      'true`, and expect no file source — `include_source=true` yields graph ' +
      'context plus `source_unavailable`.')
);
