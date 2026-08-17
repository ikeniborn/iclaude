#!/usr/bin/env bash
# Unit tests for lib/iwiki/mcp.sh:
#   iwiki_mcp_config_file, iwiki_resolve_command, iwiki_mcp_enabled,
#   iwiki_mcp_launch_config (single local, single remote, and dual mode).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/iwiki/mcp.sh"

PASS=0; FAIL=0
assert_eq(){ if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }

TD=$(mktemp -d)
# Fake iwiki-mcp on an absolute PATH entry so `command -v` yields an absolute path.
mkdir -p "$TD/bin"; printf '#!/bin/sh\n' > "$TD/bin/iwiki-mcp"; chmod +x "$TD/bin/iwiki-mcp"

# iwiki_resolve_command: resolves via PATH to the absolute binary path.
assert_eq "$(PATH="$TD/bin:$PATH"; unset IWIKI_COMMAND; iwiki_resolve_command; printf '%s' "$IWIKI_COMMAND")" \
  "$TD/bin/iwiki-mcp" "resolve via PATH -> absolute"

# iwiki_resolve_command: an explicit override wins over PATH resolution.
assert_eq "$(PATH="$TD/bin:$PATH"; IWIKI_COMMAND=/custom/iwiki-mcp; iwiki_resolve_command; printf '%s' "$IWIKI_COMMAND")" \
  "/custom/iwiki-mcp" "override respected"

# iwiki_mcp_config_file: path is <config dir>/mcp/iwiki.json.
assert_eq "$(CLAUDE_CONFIG_DIR=/x/.claude-isolated iwiki_mcp_config_file)" \
  "/x/.claude-isolated/mcp/iwiki.json" "config file path"

# Prepare a config dir with the tracked file present.
mkdir -p "$TD/.claude-isolated/mcp"; printf '{}' > "$TD/.claude-isolated/mcp/iwiki.json"

# iwiki_mcp_enabled: YES when binary + LLM key + config file all present.
assert_eq "$(PATH="$TD/bin:$PATH"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; IWIKI_LLM_KEY=sk-x; unset IWIKI_COMMAND; iwiki_mcp_enabled && echo YES || echo NO)" \
  "YES" "enabled when all set"

# iwiki_mcp_enabled: NO without an LLM key.
assert_eq "$(PATH="$TD/bin:$PATH"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; unset IWIKI_LLM_KEY IWIKI_COMMAND; iwiki_mcp_enabled && echo YES || echo NO)" \
  "NO" "disabled without LLM key"

# iwiki_mcp_enabled: NO when the binary is not resolvable.
assert_eq "$(PATH="/nonexistent"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; IWIKI_LLM_KEY=sk-x; unset IWIKI_COMMAND; iwiki_mcp_enabled && echo YES || echo NO)" \
  "NO" "disabled without binary"

# iwiki_mcp_enabled: NO when the tracked config file is missing.
assert_eq "$(PATH="$TD/bin:$PATH"; CLAUDE_CONFIG_DIR="$TD/nowhere"; IWIKI_LLM_KEY=sk-x; unset IWIKI_COMMAND; iwiki_mcp_enabled && echo YES || echo NO)" \
  "NO" "disabled without config file"

# ---------------------------------------------------------------------------
# iwiki_mcp_launch_config: code-graph vars are forwarded only when configured.
# ---------------------------------------------------------------------------
CFG="$TD/.claude-isolated/mcp/iwiki.json"
printf '%s\n' '{' '  "mcpServers": {' '    "iwiki": {' '      "env": {' \
  '        "IWIKI_TOP_K": "${IWIKI_TOP_K:-8}"' '      }' '    }' '  }' '}' > "$CFG"

# No code-graph var set: the tracked file is used verbatim, nothing is rendered.
assert_eq "$(CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; unset "${_IWIKI_CODE_GRAPH_VARS[@]}"; iwiki_mcp_launch_config)" \
  "$CFG" "launch config: tracked file without code-graph vars"
assert_eq "$([[ -e "${CFG%.json}.runtime.json" ]] && echo YES || echo NO)" \
  "NO" "launch config: no runtime file rendered"

# An empty value is treated as unset: the server rejects an empty code-graph
# value, so it must never reach the rendered config.
assert_eq "$(CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; IWIKI_CODE_GRAPH_ENABLED=""; iwiki_mcp_launch_config)" \
  "$CFG" "launch config: empty var does not trigger a render"

# A configured var: a runtime file is rendered with the placeholder spliced in.
RENDERED="$(CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; IWIKI_CODE_GRAPH_ENABLED=false; IWIKI_CODE_GRAPH_MAX_FILES=100; iwiki_mcp_launch_config)"
assert_eq "$RENDERED" "${CFG%.json}.runtime.json" "launch config: renders a runtime file"
assert_eq "$(python3 -m json.tool "$RENDERED" >/dev/null 2>&1 && echo OK || echo BAD)" \
  "OK" "launch config: rendered file is valid JSON"
assert_eq "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["mcpServers"]["iwiki"]["env"]["IWIKI_CODE_GRAPH_ENABLED"])' "$RENDERED")" \
  '${IWIKI_CODE_GRAPH_ENABLED}' "launch config: placeholder, not the literal value"
assert_eq "$(python3 -c 'import json,sys; e=json.load(open(sys.argv[1]))["mcpServers"]["iwiki"]["env"]; print(",".join(sorted(e)))' "$RENDERED")" \
  "IWIKI_CODE_GRAPH_ENABLED,IWIKI_CODE_GRAPH_MAX_FILES,IWIKI_TOP_K" "launch config: only configured vars are added"

# A tracked file with no `env` object cannot be spliced: fall back to it and
# leave no half-rendered sibling behind.
printf '%s' '{"mcpServers":{"iwiki":{"type":"stdio"}}}' > "$TD/.claude-isolated/mcp/noenv.json"
assert_eq "$(CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; iwiki_mcp_config_file(){ printf '%s' "$TD/.claude-isolated/mcp/noenv.json"; }; IWIKI_CODE_GRAPH_ENABLED=true; iwiki_mcp_launch_config)" \
  "$TD/.claude-isolated/mcp/noenv.json" "launch config: falls back when there is no env object"
assert_eq "$([[ -e "$TD/.claude-isolated/mcp/noenv.runtime.json" ]] && echo YES || echo NO)" \
  "NO" "launch config: no leftover render after a failed splice"

# A render from an earlier launch is removed once the vars are gone, so a stale
# file is never mistaken for the active config.
touch "${CFG%.json}.runtime.json"
assert_eq "$(CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; unset "${_IWIKI_CODE_GRAPH_VARS[@]}"; iwiki_mcp_launch_config)" \
  "$CFG" "launch config: tracked file after the vars are unset"
assert_eq "$([[ -e "${CFG%.json}.runtime.json" ]] && echo YES || echo NO)" \
  "NO" "launch config: stale render removed"

# ---------------------------------------------------------------------------
# Remote (hosted Streamable HTTP) mode: URL + token, no local binary needed.
# ---------------------------------------------------------------------------
RCFG="$TD/.claude-isolated/mcp/iwiki-remote.json"
printf '%s' '{"mcpServers":{"iwiki":{"type":"http","url":"${IWIKI_REMOTE_URL}"}}}' > "$RCFG"

# Enabled with neither an iwiki-mcp binary nor an embeddings key: a hosted
# server keeps both server-side.
assert_eq "$(PATH="/nonexistent"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; unset IWIKI_LLM_KEY IWIKI_COMMAND; IWIKI_REMOTE_URL=https://w.example/mcp; IWIKI_REMOTE_TOKEN=t; iwiki_mcp_enabled && echo YES || echo NO)" \
  "YES" "remote: enabled without binary or LLM key"

# A URL without a token is not usable, so remote stays off.
assert_eq "$(PATH="/nonexistent"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; unset IWIKI_LLM_KEY IWIKI_COMMAND IWIKI_REMOTE_TOKEN; IWIKI_REMOTE_URL=https://w.example/mcp; iwiki_mcp_enabled && echo YES || echo NO)" \
  "NO" "remote: disabled without a token"

# Remote is the deliberate opt-in, so it wins when local is NOT also usable
# (no binary here: IWIKI_COMMAND stays unset and PATH offers no iwiki-mcp).
assert_eq "$(PATH="/nonexistent"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; unset IWIKI_LLM_KEY IWIKI_COMMAND; IWIKI_REMOTE_URL=https://w.example/mcp; IWIKI_REMOTE_TOKEN=t; iwiki_mcp_launch_config)" \
  "$RCFG" "remote: selected when local is not usable"

# Remote never renders the code-graph sibling: a hosted server owns that cache.
assert_eq "$(PATH="/nonexistent"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; unset IWIKI_LLM_KEY IWIKI_COMMAND; IWIKI_REMOTE_URL=https://w.example/mcp; IWIKI_REMOTE_TOKEN=t; IWIKI_CODE_GRAPH_ENABLED=true; iwiki_mcp_launch_config)" \
  "$RCFG" "remote: no code-graph render"

# Without the tracked remote config, remote cannot be selected.
rm -f "$RCFG"
assert_eq "$(CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; unset "${_IWIKI_CODE_GRAPH_VARS[@]}"; IWIKI_REMOTE_URL=https://w.example/mcp; IWIKI_REMOTE_TOKEN=t; iwiki_mcp_launch_config)" \
  "$CFG" "remote: falls back to local without the remote config"

# ---------------------------------------------------------------------------
# Dual mode: both local and remote usable -> register both as distinct servers.
# ---------------------------------------------------------------------------
# The single-mode remote config keeps its key "iwiki" (existence is all that
# matters to _iwiki_remote_selected/dual's fallback check below); only the
# dual tracked file uses the distinct "iwiki-local"/"iwiki-remote" names.
printf '%s' '{"mcpServers":{"iwiki":{"type":"http","url":"${IWIKI_REMOTE_URL}"}}}' > "$RCFG"
DCFG="$TD/.claude-isolated/mcp/iwiki-dual.json"
printf '%s\n' '{' '  "mcpServers": {' '    "iwiki-local": {' '      "env": {' \
  '        "IWIKI_TOP_K": "${IWIKI_TOP_K:-8}"' '      }' '    },' \
  '    "iwiki-remote": {' '      "url": "${IWIKI_REMOTE_URL}"' '    }' '  }' '}' > "$DCFG"

# Both configured, dual tracked file present: enabled, and the dual file wins
# over either single config.
assert_eq "$(PATH="$TD/bin:$PATH"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; IWIKI_LLM_KEY=sk-x; unset IWIKI_COMMAND; IWIKI_REMOTE_URL=https://w.example/mcp; IWIKI_REMOTE_TOKEN=t; iwiki_mcp_enabled && echo YES || echo NO)" \
  "YES" "dual: enabled when both are usable"
assert_eq "$(PATH="$TD/bin:$PATH"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; IWIKI_LLM_KEY=sk-x; unset IWIKI_COMMAND; IWIKI_REMOTE_URL=https://w.example/mcp; IWIKI_REMOTE_TOKEN=t; unset "${_IWIKI_CODE_GRAPH_VARS[@]}"; iwiki_mcp_launch_config)" \
  "$DCFG" "dual: selected over either single config"

# Dual code-graph render: splices only into the local entry's "env" object,
# not the remote entry (which has none).
RENDERED_D="$(PATH="$TD/bin:$PATH"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; IWIKI_LLM_KEY=sk-x; unset IWIKI_COMMAND; IWIKI_REMOTE_URL=https://w.example/mcp; IWIKI_REMOTE_TOKEN=t; IWIKI_CODE_GRAPH_ENABLED=false; iwiki_mcp_launch_config)"
assert_eq "$RENDERED_D" "${DCFG%.json}.runtime.json" "dual: renders a runtime file"
assert_eq "$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))["mcpServers"]; print(",".join(sorted(d)))' "$RENDERED_D")" \
  "iwiki-local,iwiki-remote" "dual: both server names present"
assert_eq "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["mcpServers"]["iwiki-local"]["env"]["IWIKI_CODE_GRAPH_ENABLED"])' "$RENDERED_D")" \
  '${IWIKI_CODE_GRAPH_ENABLED}' "dual: code-graph placeholder spliced into iwiki-local only"
assert_eq "$(python3 -c 'import json,sys; print("IWIKI_CODE_GRAPH_ENABLED" in json.load(open(sys.argv[1]))["mcpServers"]["iwiki-remote"])' "$RENDERED_D")" \
  "False" "dual: no code-graph key on iwiki-remote"

# Without the tracked dual config, remote (the deliberate opt-in) is selected
# as a single server instead — no dual registration is attempted.
rm -f "$DCFG" "${DCFG%.json}.runtime.json"
assert_eq "$(PATH="$TD/bin:$PATH"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; IWIKI_LLM_KEY=sk-x; unset IWIKI_COMMAND; IWIKI_REMOTE_URL=https://w.example/mcp; IWIKI_REMOTE_TOKEN=t; unset "${_IWIKI_CODE_GRAPH_VARS[@]}"; iwiki_mcp_launch_config)" \
  "$RCFG" "dual: falls back to remote without the dual config"

rm -rf "$TD"
echo "iwiki-mcp: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
