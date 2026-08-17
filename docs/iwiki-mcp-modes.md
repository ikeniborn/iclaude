# iwiki MCP modes

## Local stdio

iclaude registers `iwiki-mcp` as a local stdio MCP server at launch from the tracked,
secret-free `.nvm-isolated/.claude-isolated/mcp/iwiki.json` (see `lib/iwiki/mcp.sh`). The
server resolves the project's own read/write/primary binding server-side from the
project-root `.iwiki.toml` — no client-side preflight is needed or run.

```bash
./iclaude.sh
```

## Hosted streamable HTTP (external MCP client)

For an already hosted iwiki server, set these in `.claude_config` (see the `IWIKI MCP
SERVER` section of `.claude_config.example`):

```text
ICLAUDE_IWIKI_REMOTE_URL="https://iwiki.example.com/mcp"
ICLAUDE_IWIKI_REMOTE_TOKEN="<bearer-token>"
```

When `IWIKI_REMOTE_URL` is set, `lib/iwiki/mcp.sh` selects the remote registration
(`mcp/iwiki-remote.json`, type `http`, `Authorization: Bearer ${IWIKI_REMOTE_TOKEN}`)
over the local stdio server — unless local is *also* usable, in which case both are
registered at once (see [Dual mode](#dual-mode-local--remote-at-once) below). The token
is mapped only at runtime via env-map (`ICLAUDE_IWIKI_REMOTE_TOKEN` → `IWIKI_REMOTE_TOKEN`),
never written to any tracked config file.

The hosted server resolves wiki identity and its own read/write grants from the bearer
token — that grant remains the absolute authorization ceiling. But the client project can
still request a narrower or differently-scoped view via its own `.iwiki.toml`: `read`,
`write` (string or array), and `primary`. In this mode iclaude also runs a SessionStart
hook, `hooks/iwiki-remote-scope.js`, that emits a short instruction into
`additionalContext` at every session start where `IWIKI_REMOTE_URL` is set:

Before its first wiki call, the agent reads only `read`, `write`, and `primary` from the
project-root `.iwiki.toml`, normalizes the domain names, then calls `wiki_bind` with that
complete scope — before `wiki_status`, `wiki_search`, task-ledger, or any other wiki call.
It never sends the server TOML text, file paths, `iwiki_id`, or credentials. A missing or
invalid scope, or a rejected bind such as HTTP 403, fails closed: no heuristic fallback
and no mutating wiki call is made, and the task-ledger lifecycle stays
`completion-pending`.

The hook checks only whether `IWIKI_REMOTE_URL` is set in the environment — it writes
nothing to disk, so the instruction disappears on its own the moment a session starts
under local stdio (no `IWIKI_REMOTE_URL`).

Local stdio does not run this preflight — its project binding is resolved entirely
server-side from `.iwiki.toml`, as described above.

## Dual mode (local + remote at once)

`wiki_code_index` needs a local repository checkout on the server's disk, so it always
returns `source_unavailable` under remote-only mode; `wiki_code_publish_begin`/`_batch`/
`_finalize` need a hosted authenticated transit, so they always return
`unsupported_storage` under local-only mode. Building a code graph locally and then
publishing it needs both in the same session.

When both local (`IWIKI_COMMAND` resolvable, `IWIKI_LLM_KEY` set) and remote
(`IWIKI_REMOTE_URL` + `IWIKI_REMOTE_TOKEN`) are usable, `lib/iwiki/mcp.sh` registers the
tracked `.nvm-isolated/.claude-isolated/mcp/iwiki-dual.json` instead of either single
config. It declares two distinct servers in one `--mcp-config`:

- `iwiki-local` — the same stdio registration as single-local mode, so
  `wiki_code_index`, `wiki_code_search`, and `wiki_code_context` run against this
  project's own checkout. Optional `IWIKI_CODE_GRAPH_*` overrides still splice into its
  `env` object exactly as in single-local mode.
- `iwiki-remote` — the same hosted HTTP registration as single-remote mode, for every
  other wiki tool, including `wiki_code_publish_begin`/`_batch`/`_finalize`.

Single-local-only and single-remote-only sessions are unaffected: they keep registering
under the plain server name `iwiki` from `mcp/iwiki.json` / `mcp/iwiki-remote.json`, byte
for byte as before. Dual mode is a distinct third tracked file, never a rename of either.

`hooks/iwiki-remote-scope.js` detects this at session start (via `IWIKI_COMMAND` and
`IWIKI_LLM_KEY` also being present alongside `IWIKI_REMOTE_URL`) and tells the agent to
route code-graph tools to `iwiki-local` and everything else to `iwiki-remote` — no config
switch needed. Under remote-only mode it still tells the agent that `source_unavailable`
means switching (or adding) the local config, not editing `.iwiki.toml`.
