#!/bin/bash

#######################################
# iwiki MCP Registration Helper
# Description: Decides whether an iwiki MCP server is handed to Claude Code via
#              --mcp-config, and which tracked, secret-free config describes it:
#              mcp/iwiki-remote.json for a hosted Streamable HTTP server,
#              mcp/iwiki.json for the local stdio server (optionally rendered
#              with the code-graph overrides), or mcp/iwiki-dual.json when both
#              are usable at once — registered as two distinct servers,
#              "iwiki-local" and "iwiki-remote", so wiki_code_index/_search/
#              _context can run locally while every other wiki_* tool and
#              wiki_code_publish_* still reach the hosted server in the same
#              session. The IWIKI_* values are already exported by
#              lib/config/env-map.sh (de-prefixed from ICLAUDE_IWIKI_* in
#              .claude_config); this module only resolves the binary path,
#              evaluates the enable gate, and picks the config.
#######################################

# Absolute path to the tracked, secret-free MCP config file.
# Lives under the isolated Claude config dir (CLAUDE_CONFIG_DIR).
# If neither CLAUDE_CONFIG_DIR nor ISOLATED_CONFIG_DIR is set, the path resolves
# under `/` and won't exist, so iwiki_mcp_enabled silently returns 1 (intended -
# no hard failure).
iwiki_mcp_config_file() {
    printf '%s' "${CLAUDE_CONFIG_DIR:-${ISOLATED_CONFIG_DIR:-}}/mcp/iwiki.json"
}

# Absolute path to the tracked config for a hosted (Streamable HTTP) server.
# Remote mode talks to `iwiki-mcp serve --transport streamable-http` over
# `type: "http"`, so it needs no local binary and no local wiki base: the URL
# (which must end in the server's /mcp endpoint) plus a bearer token are the
# whole client contract. Embedding credentials and storage stay server-side.
iwiki_mcp_remote_config_file() {
    printf '%s' "${CLAUDE_CONFIG_DIR:-${ISOLATED_CONFIG_DIR:-}}/mcp/iwiki-remote.json"
}

# Absolute path to the tracked config that registers both transports at once,
# as "iwiki-local" and "iwiki-remote". Used only when both modes are usable;
# a single distinct file keeps single-mode registration (server name "iwiki")
# byte-identical to today.
iwiki_mcp_dual_config_file() {
    printf '%s' "${CLAUDE_CONFIG_DIR:-${ISOLATED_CONFIG_DIR:-}}/mcp/iwiki-dual.json"
}

# True when remote mode is both requested and usable: an explicit URL, a token
# to authenticate with, and the tracked remote config present. Setting the URL
# is the deliberate opt-in, so remote wins over a local install when local is
# not ALSO usable (see iwiki_mcp_launch_config for the dual case).
_iwiki_remote_selected() {
    [[ -n "${IWIKI_REMOTE_URL:-}" ]]                 || return 1
    [[ -n "${IWIKI_REMOTE_TOKEN:-}" ]]               || return 1
    [[ -f "$(iwiki_mcp_remote_config_file)" ]]       || return 1
    return 0
}

# True when local (stdio) mode is usable on its own: the binary resolves, the
# embeddings key is configured, and the tracked local config exists. Factored
# out of iwiki_mcp_enabled so dual-mode registration can check it independently
# of whether remote also wins the single-mode selection.
_iwiki_local_selected() {
    iwiki_resolve_command
    [[ -n "${IWIKI_COMMAND:-}" ]]            || return 1
    [[ -n "${IWIKI_LLM_KEY:-}" ]]            || return 1
    [[ -f "$(iwiki_mcp_config_file)" ]]      || return 1
    return 0
}

# Resolve the iwiki-mcp executable to an absolute path and export IWIKI_COMMAND.
# An explicit override is honored only when IWIKI_COMMAND is a NON-EMPTY value;
# an unset OR empty IWIKI_COMMAND is treated as absent and resolved from PATH via
# `command -v` (absolute path). This is intentional: env-map exports IWIKI_COMMAND
# only when ICLAUDE_IWIKI_COMMAND is non-empty, so an "empty override" never
# reaches here as an empty-but-set value.
iwiki_resolve_command() {
    # `|| true` keeps the assignment's exit status 0 so a bare call under
    # `set -e` never aborts when the binary is absent (an empty result then
    # leaves the enable gate to disable iwiki gracefully).
    IWIKI_COMMAND="${IWIKI_COMMAND:-$(command -v iwiki-mcp 2>/dev/null || true)}"
    export IWIKI_COMMAND
}

# Return 0 (enabled) when the iwiki MCP server should be registered, in either
# of two modes (see _iwiki_local_selected / _iwiki_remote_selected for the
# exact conditions of each). Returns 1 when neither is usable, so launch
# proceeds without the server (no hard failure).
iwiki_mcp_enabled() {
    _iwiki_local_selected && return 0
    _iwiki_remote_selected && return 0
    return 1
}

# Code-graph variables the iwiki-mcp server reads. They are NOT part of the
# tracked config: iwiki-mcp applies them AFTER the project's `.iwiki.toml`
# [code_graph] table, so a placeholder with a baked-in default would override
# every project's own setting. Claude Code passes an unresolved `${VAR:-}` as a
# set-but-empty value, and the server rejects an empty value for each of these,
# so they can only be forwarded when actually configured.
_IWIKI_CODE_GRAPH_VARS=(
    IWIKI_CODE_GRAPH_ENABLED IWIKI_CODE_GRAPH_AUTO_REBUILD
    IWIKI_CODE_GRAPH_MAX_FILE_BYTES IWIKI_CODE_GRAPH_MAX_FILES
    IWIKI_CODE_GRAPH_MCP_URL IWIKI_CODE_GRAPH_MCP_TOKEN
)

# Emit one JSON `"NAME": "${NAME}",` line per code-graph var that is set to a
# non-empty value. Empty output means "nothing to add" — the caller then uses
# the tracked config unchanged and `.iwiki.toml` stays authoritative.
_iwiki_code_graph_env_lines() {
    local var
    for var in "${_IWIKI_CODE_GRAPH_VARS[@]}"; do
        [[ -n "${!var:-}" ]] && printf '        "%s": "${%s}",\n' "$var" "$var"
    done
    return 0
}

# Render $1 (a tracked config with exactly one "env" object, the local
# server's) into $2 (its *.runtime.json sibling), splicing configured
# code-graph vars into that env object. Prints $2 on a successful render, or
# $1 unchanged when no vars are configured or the splice fails (no `env`
# object to splice into) — iwiki still starts, only without the code-graph
# overrides. Always leaves at most one of the two present on disk, so a stale
# render from an earlier launch is never mistaken for the active config.
_iwiki_render_code_graph() {
    local tracked="$1" runtime="$2" lines
    lines="$(_iwiki_code_graph_env_lines)"
    if [[ -z "$lines" ]]; then
        rm -f "$runtime" 2>/dev/null || true
        printf '%s' "$tracked"
        return 0
    fi
    if awk -v ins="$lines" '
        { print }
        /"env"[[:space:]]*:[[:space:]]*\{/ && !spliced { printf "%s", ins; spliced = 1 }
        END { if (!spliced) exit 3 }
    ' "$tracked" > "$runtime" 2>/dev/null; then
        printf '%s' "$runtime"
    else
        rm -f "$runtime" 2>/dev/null || true
        printf '%s' "$tracked"
    fi
}

# Print the config path to hand to `--mcp-config`.
# Dual mode (both local and remote usable, and mcp/iwiki-dual.json present)
# registers both transports at once under distinct names, "iwiki-local" and
# "iwiki-remote", so wiki_code_index/_search/_context can run locally while
# wiki_code_publish_* and every other wiki_* tool still reach the hosted
# server. Otherwise remote wins when usable (the deliberate opt-in), else
# local. In remote-only mode the code-graph render does not apply, because a
# hosted server owns its own storage and code-graph cache; local-only and dual
# mode both render code-graph overrides into the local server's `env` object
# via _iwiki_render_code_graph (the dual tracked file's remote entry has no
# `env` key, so the splice only ever touches the local one).
iwiki_mcp_launch_config() {
    local tracked runtime

    if _iwiki_local_selected && _iwiki_remote_selected && [[ -f "$(iwiki_mcp_dual_config_file)" ]]; then
        tracked="$(iwiki_mcp_dual_config_file)"
        runtime="${tracked%.json}.runtime.json"
        _iwiki_render_code_graph "$tracked" "$runtime"
        return 0
    fi

    if _iwiki_remote_selected; then
        iwiki_mcp_remote_config_file
        return 0
    fi

    tracked="$(iwiki_mcp_config_file)"
    runtime="${tracked%.json}.runtime.json"
    _iwiki_render_code_graph "$tracked" "$runtime"
}
