#!/usr/bin/env bash
# Unit tests for lib/iwiki/mcp.sh:
#   iwiki_mcp_config_file, iwiki_resolve_command, iwiki_mcp_enabled.
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

# Remote is the deliberate opt-in, so it wins over a usable local install.
assert_eq "$(PATH="$TD/bin:$PATH"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; IWIKI_LLM_KEY=sk-x; unset IWIKI_COMMAND; IWIKI_REMOTE_URL=https://w.example/mcp; IWIKI_REMOTE_TOKEN=t; iwiki_mcp_launch_config)" \
  "$RCFG" "remote: selected over the local config"

# Remote never renders the code-graph sibling: a hosted server owns that cache.
assert_eq "$(CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; IWIKI_REMOTE_URL=https://w.example/mcp; IWIKI_REMOTE_TOKEN=t; IWIKI_CODE_GRAPH_ENABLED=true; iwiki_mcp_launch_config)" \
  "$RCFG" "remote: no code-graph render"

# Without the tracked remote config, remote cannot be selected.
rm -f "$RCFG"
assert_eq "$(CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; unset "${_IWIKI_CODE_GRAPH_VARS[@]}"; IWIKI_REMOTE_URL=https://w.example/mcp; IWIKI_REMOTE_TOKEN=t; iwiki_mcp_launch_config)" \
  "$CFG" "remote: falls back to local without the remote config"

rm -rf "$TD"
echo "iwiki-mcp: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
