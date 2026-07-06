---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-01-iwiki-mcp-user-scope-design.md
review:
  spec_hash: ff63ddc066677423
  last_run: 2026-07-01
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings: []
---

# iwiki MCP Server — User-Scope Integration via Tracked `.mcp.json`

**Date:** 2026-07-01
**Status:** Design (approved for planning)
**Topic:** `iwiki-mcp-user-scope`

## Goal

Register the `iwiki` MCP server for iclaude in a **version-controlled, secret-free** way,
sourcing all `IWIKI_*` values from the single source of truth (`.claude_config`,
`ICLAUDE_IWIKI_*`) instead of hard-coding them. The server binary is resolved to an
absolute path at launch (never a relative path).

## Background / Findings

The current setup registers the server manually in
`.nvm-isolated/.claude-isolated/.claude.json` (top-level `mcpServers.iwiki`) with the LLM
key and base URL **hard-coded and duplicated** from `.claude_config`. Investigation established:

1. **Claude Code ignores `mcpServers` in `settings.json`.** MCP servers are read only from
   `.mcp.json`, user-scope `.claude.json`, or the `--mcp-config <file>` flag. The
   `"mcpServers": {}` key currently in `settings.json` is dead config.
2. **`${VAR}` / `${VAR:-default}` expansion works in `.mcp.json`-format files** (including
   files passed via `--mcp-config`), expanding from the parent `claude` process environment.
   It does **not** work in `settings.json` or `.claude.json`.
3. **stdio MCP servers do not reliably inherit the parent environment** — Claude Code passes a
   sanitized subset, which is why the current `.claude.json` block lists env vars explicitly.
   Therefore values must be passed through an explicit `env` block (with `${VAR}` expansion),
   not left to inheritance.
4. **`.claude.json` is Claude Code runtime state** (identity, per-project absolute paths,
   usage counters, `oauthAccount`) — gitignored and rewritten every session. It must not be
   committed and is not a hand-maintained config surface.
5. **iclaude already exports `IWIKI_*`** from `.claude_config` via the env-map layer
   (`lib/config/env-map.sh` de-prefixes `ICLAUDE_IWIKI_X` → exports `IWIKI_X`). Nothing
   currently connects those exports to the MCP server.
6. **`iwiki-mcp` reads these env vars** — cross-checked against the `iwiki-mcp` README "Env
   reference" table, the `iwiki-mcp` wiki domain (`installation.md`, `indexing.md`,
   `base-binding.md`), and the loader `iwiki_mcp/engine/config.py`:
   - **Required (halt if unset):** `IWIKI_LLM_BASE_URL`, `IWIKI_LLM_KEY`; plus `IWIKI_BASE_DIR`
     (base dir — or the `base` key in a project's `.iwiki.toml`).
   - **Optional (documented defaults):** `IWIKI_EMBED_MODEL` (`text-embedding-3-small`),
     `IWIKI_EMBED_DIMENSIONS` (`1536`), `IWIKI_CHUNK_SIZE` (`512`), `IWIKI_CHUNK_OVERLAP` (`64`),
     `IWIKI_SUMMARY_MAX_CHARS` (`400`), `IWIKI_TOP_K` (`8`), `IWIKI_SCORE_THRESHOLD` (`0.2`),
     `IWIKI_GRAPH_DEPTH` (`2`).
   - **`IWIKI_PROJECT_DIR`** (defaults to process cwd; also the `--project` flag): omitted for
     Claude Code, which starts the server with `cwd` at the project root, so `.iwiki.toml` is
     resolved automatically. Per-project read/write/base binding lives in `.iwiki.toml`, not env.

## Approach

A tracked, secret-free `.mcp.json`-format file declares the `iwiki` server using `${IWIKI_*}`
placeholders. iclaude exports the `IWIKI_*` values (from `.claude_config`) plus a launch-time
resolved `IWIKI_COMMAND`, then passes the file to Claude Code via `--mcp-config`. Claude Code
expands the placeholders from the process environment when it spawns the server.

Because `iwiki` is the only MCP server, the merge-vs-replace ambiguity of `--mcp-config` is
immaterial: the server loads from the passed file regardless.

## Architecture

```
.claude_config (ICLAUDE_IWIKI_*, gitignored, secrets)
        │  source + de-prefix (lib/config/env-map.sh)
        ▼
process env: IWIKI_BASE_DIR, IWIKI_LLM_KEY, … (in iclaude.sh / launch.sh)
        │
        │  launch.sh: IWIKI_COMMAND="${IWIKI_COMMAND:-$(command -v iwiki-mcp)}"; export
        │             append  --mcp-config <mcp/iwiki.json>  to claude_cmd_arr
        ▼
claude … --mcp-config .../mcp/iwiki.json
        │  Claude Code expands ${IWIKI_*} / ${IWIKI_COMMAND} from process env
        ▼
iwiki-mcp (stdio child) receives real IWIKI_* values in its env block
```

## Components

### 1. Tracked MCP config file — `.nvm-isolated/.claude-isolated/mcp/iwiki.json`

Secret-free; contains only `${…}` placeholders. The variable set is verified against the
`iwiki-mcp` README "Env reference" table and the loader `iwiki_mcp/engine/config.py`. All 11
`IWIKI_*` vars the server reads are passed (3 required + 8 optional); `IWIKI_PROJECT_DIR` is
intentionally omitted so the server resolves the current project cwd (Claude Code launches the
server with `cwd` at the project root, per the README).

**Required vars use plain `${VAR}`** — if unset the server halts with a clear hint
(`ConfigError` for the LLM pair, `BaseError` for the base), which is the desired loud failure.

**Optional vars use `${VAR:-<default>}` with the README/config.py default** — because
`config.py` reads them via `int(getenv("IWIKI_X", "<default>"))`, where the default applies
**only when the var is absent**. An empty string (which is what `${IWIKI_X}` expands to when the
var is unset in the process env) would reach `int("")` and crash. `${VAR:-<default>}` maps
unset/empty to the documented default, never to an empty string.

```json
{
  "mcpServers": {
    "iwiki": {
      "type": "stdio",
      "command": "${IWIKI_COMMAND}",
      "args": [],
      "env": {
        "IWIKI_BASE_DIR":          "${IWIKI_BASE_DIR}",
        "IWIKI_LLM_BASE_URL":      "${IWIKI_LLM_BASE_URL}",
        "IWIKI_LLM_KEY":           "${IWIKI_LLM_KEY}",
        "IWIKI_EMBED_MODEL":       "${IWIKI_EMBED_MODEL:-text-embedding-3-small}",
        "IWIKI_EMBED_DIMENSIONS":  "${IWIKI_EMBED_DIMENSIONS:-1536}",
        "IWIKI_CHUNK_SIZE":        "${IWIKI_CHUNK_SIZE:-512}",
        "IWIKI_CHUNK_OVERLAP":     "${IWIKI_CHUNK_OVERLAP:-64}",
        "IWIKI_SUMMARY_MAX_CHARS": "${IWIKI_SUMMARY_MAX_CHARS:-400}",
        "IWIKI_TOP_K":             "${IWIKI_TOP_K:-8}",
        "IWIKI_SCORE_THRESHOLD":   "${IWIKI_SCORE_THRESHOLD:-0.2}",
        "IWIKI_GRAPH_DEPTH":       "${IWIKI_GRAPH_DEPTH:-2}"
      }
    }
  }
}
```

Note: `IWIKI_EMBED_DIMENSIONS` must match the embedding model; this user runs `ollama-bge-m3`
at `1024`, set in `.claude_config`. The `:-1536` fallback only applies if the user blanks the
var, in which case behavior is identical to the server's own default — no crash either way.

### 2. Binary resolution — `IWIKI_COMMAND`

Resolved at launch to an absolute path:

```bash
IWIKI_COMMAND="${IWIKI_COMMAND:-$(command -v iwiki-mcp 2>/dev/null)}"
export IWIKI_COMMAND
```

- `command -v iwiki-mcp` returns the absolute path from `PATH` (e.g.
  `/home/altuser/.local/bin/iwiki-mcp`) — absolute, never relative, and portable across machines.
- An explicit override is honored: if `.claude_config` sets `ICLAUDE_IWIKI_COMMAND`, env-map
  exports `IWIKI_COMMAND` and the `${IWIKI_COMMAND:-…}` default is skipped.
- If resolution yields empty (binary not installed) → the server is not registered (guard below).

### 3. Launch wiring — `lib/launcher/launch.sh` (native path)

A small helper (new `lib/iwiki/mcp.sh`, sourced like other `lib/` modules) resolves
`IWIKI_COMMAND` and decides whether to register. In `launch.sh`, immediately after
`claude_cmd_arr` is built (the `read -ra claude_cmd_arr <<< "$claude_cmd"` line), conditionally
append the flag:

```bash
if iwiki_mcp_enabled; then          # IWIKI_COMMAND non-empty AND IWIKI_LLM_KEY non-empty AND file exists
    export IWIKI_COMMAND
    claude_cmd_arr+=( --mcp-config "$IWIKI_MCP_CONFIG_FILE" )
fi
```

The appended flag is carried into both launch branches that use `claude_cmd_arr` (the PII-proxy
branch and the standard `exec` branch), so native, PII-proxy, and combined router modes all get it.

### 4. Config surface — `.claude_config` / `.claude_config.example`

Add to the existing iwiki block:

```
ICLAUDE_IWIKI_BASE_DIR="/home/altuser/Документы/Project/iwiki-personal"
# Optional binary override (default: resolved via `command -v iwiki-mcp`):
# ICLAUDE_IWIKI_COMMAND=
```

env-map de-prefixes `ICLAUDE_IWIKI_BASE_DIR` → exports `IWIKI_BASE_DIR`. The example file gets
the same entries (commented, with guidance) under the existing iwiki section.

### 5. Cleanup

- Remove the manual `mcpServers.iwiki` block from `.claude.json` (one-time). Keep the file
  itself — Claude owns it. After removal the key returns to `{}`.
- Remove the dead `"mcpServers": {}` key from `settings.json` (tracked; Claude Code ignores it).

### 6. `.gitignore`

The new file lives under the blanket-ignored `.nvm-isolated/.claude-isolated/*`. Un-ignore it,
consistent with the existing `commands/` / `skills/` / `agents/` un-ignores:

```
!.nvm-isolated/.claude-isolated/mcp/
!.nvm-isolated/.claude-isolated/mcp/**
```

## Data Flow (launch → server)

1. `iclaude.sh` Phase 0 sources `.claude_config`, env-map exports `IWIKI_BASE_DIR`,
   `IWIKI_LLM_KEY`, … into the process environment.
2. `launch.sh` resolves and exports `IWIKI_COMMAND`, and if iwiki is enabled appends
   `--mcp-config <mcp/iwiki.json>` to `claude_cmd_arr`.
3. `claude` is exec'd; when it starts the `iwiki` stdio server it expands `${IWIKI_COMMAND}`
   and each `${IWIKI_*}` in the file from its own environment.
4. `iwiki-mcp` launches with the real values in its env block; `IWIKI_PROJECT_DIR` is unset so
   it uses the current project cwd.

## Edge Cases & Risks

- **Tuning vars as empty strings — resolved.** Verified against `iwiki_mcp/engine/config.py`:
  optional vars are parsed with `int(getenv("IWIKI_X", "<default>"))` / `float(...)`, so an
  empty string reaches `int("")` and crashes. env-map exports `IWIKI_X` only when non-empty, so
  an absent/blank config entry leaves the var unset and `${IWIKI_X}` would expand to `""`. The
  design therefore uses `${IWIKI_X:-<README default>}` for every optional var, mapping
  unset/empty to the documented default. Required vars (`IWIKI_LLM_*`, `IWIKI_BASE_DIR`) stay
  plain so a missing value fails loudly with the server's own hint.
- **`--mcp-config` merge semantics are buggy/version-dependent.** Since `iwiki` is the only
  server this is immaterial today. Documented consequence: future MCP servers should be added
  to the tracked `mcp/iwiki.json` (or a sibling tracked file also passed via `--mcp-config`),
  not to `.claude.json`.
- **Binary not installed.** `command -v iwiki-mcp` empty → `iwiki_mcp_enabled` false → flag
  omitted, launch proceeds without the server (no hard failure).

## Out of Scope

- **microVM launch path.** `iwiki-mcp` lives on the host (`~/.local/bin`), not inside the
  Firecracker guest, so `--mcp-config` is not wired into the guest exec path. Documented as a
  known limitation.
- The iwiki **plugin** (`iclaude/iwiki`) — unrelated; only the standalone MCP server is in scope.
- Installing/updating the `iwiki-mcp` uv tool itself.

## Testing / Verification

1. `bash -n lib/launcher/launch.sh lib/iwiki/mcp.sh` — syntax clean.
2. Secret check: `grep -R "IWIKI_LLM_KEY" mcp/iwiki.json` shows only `${IWIKI_LLM_KEY}` — no
   literal key in the tracked file.
3. Launch iclaude in a project → `/mcp` lists `iwiki` as connected; an `mcp__iwiki__*` tool call
   succeeds (proves real key/URL reached the server via expansion).
4. Unset-binary case: with `iwiki-mcp` off `PATH`, iclaude launches without error and without the
   server.
5. `git status` confirms `mcp/iwiki.json` is tracked and `.claude.json` remains ignored.
```
