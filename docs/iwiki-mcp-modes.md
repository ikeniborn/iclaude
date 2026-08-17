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
over the local stdio server. The token is mapped only at runtime via env-map
(`ICLAUDE_IWIKI_REMOTE_TOKEN` → `IWIKI_REMOTE_TOKEN`), never written to any tracked
config file.

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

## Code graph and remote mode

`wiki_code_index` needs a local repository checkout on the server's disk. A hosted
Streamable HTTP server has no such checkout, so under remote mode it returns
`{"error":"source_unavailable", ...}`. The `iwiki-remote-scope.js` hook's emitted
instruction now says this explicitly: that error means the active MCP config must
switch from `mcp/iwiki-remote.json` to the local stdio one (`mcp/iwiki.json`, via
`IWIKI_COMMAND`/`IWIKI_BASE_DIR`) and the session restarted — not that `.iwiki.toml`
needs editing. `publish_mode = "mcp"` in `.iwiki.toml` still applies afterward, to push
the locally-built snapshot to the hosted server.
