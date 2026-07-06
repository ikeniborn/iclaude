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

rm -rf "$TD"
echo "iwiki-mcp: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
