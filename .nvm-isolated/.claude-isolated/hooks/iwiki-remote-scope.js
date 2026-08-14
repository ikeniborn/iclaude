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

process.stdout.write(
  '## Remote iwiki project scope\n\n' +
  'Before the first wiki call, load only `read`, `write`, and `primary` from the ' +
  'project-root `.iwiki.toml`. Normalize domain names before passing them to ' +
  '`wiki_bind`; never pass TOML text, paths, `iwiki_id`, tokens, or other ' +
  'credentials. Call `wiki_bind` with the full normalized `read`, `write`, and ' +
  '`primary` values from `.iwiki.toml` before `wiki_status`, `wiki_search`, ' +
  'task-ledger, or any other wiki call.\n\n' +
  'Do not infer, broaden, or replace that scope with a project name, primary ' +
  'domain, or current session scope. On a missing or invalid TOML scope, or a ' +
  'rejected bind such as 403, show a brief reason, do not make mutating wiki ' +
  'calls, and retain task lifecycle `completion-pending`. The remote server\'s ' +
  'token grants remain the absolute authorization limit.'
);
