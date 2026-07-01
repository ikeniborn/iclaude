#!/bin/bash

#######################################
# iwiki MCP Registration Helper
# Description: Resolves the iwiki-mcp binary to an absolute path and decides
#              whether the tracked, secret-free mcp/iwiki.json should be handed
#              to Claude Code via --mcp-config. The IWIKI_* values are already
#              exported by lib/config/env-map.sh (de-prefixed from
#              ICLAUDE_IWIKI_* in .claude_config); this module only resolves the
#              binary path and evaluates the enable gate.
#######################################

# Absolute path to the tracked, secret-free MCP config file.
# Lives under the isolated Claude config dir (CLAUDE_CONFIG_DIR).
iwiki_mcp_config_file() {
    printf '%s' "${CLAUDE_CONFIG_DIR:-${ISOLATED_CONFIG_DIR:-}}/mcp/iwiki.json"
}

# Resolve the iwiki-mcp executable to an absolute path and export IWIKI_COMMAND.
# Honors an explicit override (ICLAUDE_IWIKI_COMMAND -> IWIKI_COMMAND via
# env-map); otherwise resolves it from PATH with `command -v` (absolute path).
iwiki_resolve_command() {
    IWIKI_COMMAND="${IWIKI_COMMAND:-$(command -v iwiki-mcp 2>/dev/null)}"
    export IWIKI_COMMAND
}

# Return 0 (enabled) only when the iwiki MCP server should be registered:
#   - the binary resolved (IWIKI_COMMAND non-empty), AND
#   - iwiki is configured (IWIKI_LLM_KEY non-empty), AND
#   - the tracked config file exists.
# Returns 1 otherwise, so launch proceeds without the server (no hard failure).
iwiki_mcp_enabled() {
    iwiki_resolve_command
    [[ -n "${IWIKI_COMMAND:-}" ]]            || return 1
    [[ -n "${IWIKI_LLM_KEY:-}" ]]            || return 1
    [[ -f "$(iwiki_mcp_config_file)" ]]      || return 1
    return 0
}
