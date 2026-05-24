#!/bin/bash
# lat.md MCP integration module
# Provides: inject_lat_mcp(), cleanup_lat_project_artifacts()

#######################################
# Inject lat MCP server + hooks into isolated settings.json.
# Called on each launch when LAT_ENABLED=true.
# Idempotent — overwrites existing lat entry.
# Returns: 0 on success, 1 on failure
#######################################
inject_lat_mcp() {
    local settings_file="${CLAUDE_CONFIG_DIR}/settings.json"

    if [[ ! -f "$settings_file" ]]; then
        print_warning "settings.json not found at $settings_file — skipping lat MCP inject"
        return 1
    fi

    # Resolve isolated node bin dir — lat.md requires Node 20+ (uses RegExp 'v' flag)
    # Pass explicitly so MCP subprocess inherits the right PATH regardless of how Claude Code spawns it.
    local node_bin node_dir lat_wrapper
    node_bin="$(command -v node 2>/dev/null)"
    node_dir="$(dirname "$node_bin" 2>/dev/null)"
    lat_wrapper="${CLAUDE_CONFIG_DIR}/scripts/lat-mcp-wrapper.sh"

    if ! python3 - "$settings_file" "$LAT_BIN" "$lat_wrapper" "${node_dir:-}" << 'PYEOF'
import json, sys, os
settings_path, lat_bin, lat_wrapper, node_dir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(settings_path) as f:
    s = json.load(f)

# Build explicit PATH for MCP subprocess: isolated node first, then system fallback.
# lat.md requires Node 20+; without this, Claude Code may spawn with system Node 18.
npm_bin_dir = os.path.dirname(lat_bin)
path_parts = [p for p in [node_dir, npm_bin_dir, '/usr/local/bin', '/usr/bin', '/bin'] if p]
mcp_env = {'PATH': ':'.join(dict.fromkeys(path_parts))}  # deduplicate, preserve order

# Use wrapper script instead of lat binary directly.
# Wrapper cd's to $LAUNCH_DIR (inherited from iclaude's env) at spawn time, so lat
# always operates on the current project's lat.md — not the project from last inject.
cmd = lat_wrapper if os.path.isfile(lat_wrapper) else lat_bin
s.setdefault('mcpServers', {})['lat'] = {
    'type': 'stdio',
    'command': cmd,
    'env': mcp_env,
}

# Hooks: inject lat workflow reminders
# Conditional: only runs when project has lat.md/ (no noise in non-lat projects)
hook_submit = {'type': 'command', 'command': f'[[ -d "$LAUNCH_DIR/lat.md" ]] && "{lat_bin}" hook claude UserPromptSubmit || true'}
hook_stop   = {'type': 'command', 'command': f'[[ -d "$LAUNCH_DIR/lat.md" ]] && "{lat_bin}" hook claude Stop || true'}

hooks = s.setdefault('hooks', {})

# UserPromptSubmit
submit_hooks = hooks.setdefault('UserPromptSubmit', [])
submit_group = next((g for g in submit_hooks if any(
    'hook claude UserPromptSubmit' in h.get('command', '') for h in g.get('hooks', [])
)), None)
if submit_group is None:
    submit_hooks.append({'hooks': [hook_submit]})
else:
    submit_group['hooks'] = [hook_submit]

# Stop
stop_hooks = hooks.setdefault('Stop', [])
stop_group = next((g for g in stop_hooks if any(
    'hook claude Stop' in h.get('command', '') for h in g.get('hooks', [])
)), None)
if stop_group is None:
    stop_hooks.append({'hooks': [hook_stop]})
else:
    stop_group['hooks'] = [hook_stop]

with open(settings_path, 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
PYEOF
    then
        print_warning "Failed to inject lat MCP config into settings.json"
        return 1
    fi
    return 0
}

#######################################
# Remove per-project lat artifacts that iclaude manages centrally.
# Called after --lat-init to keep project dirs clean:
#   - .claude/skills/lat-md/  (skill lives in iclaude isolated dir)
#   - .mcp.json               (MCP registered via iclaude inject_lat_mcp)
#   - lat hooks from .claude/settings.json
# Arguments:
#   $1 - project dir (default: $LAUNCH_DIR)
# Returns: 0 always
#######################################
cleanup_lat_project_artifacts() {
    local project_dir="${1:-${LAUNCH_DIR}}"

    # Remove skill — already in iclaude isolated skills
    local skill_dir="${project_dir}/.claude/skills/lat-md"
    if [[ -d "$skill_dir" ]]; then
        rm -rf "$skill_dir"
        print_info "Removed per-project lat-md skill (lives in iclaude isolated)"
    fi

    # Remove .mcp.json — MCP handled by iclaude inject_lat_mcp
    local mcp_json="${project_dir}/.mcp.json"
    if [[ -f "$mcp_json" ]]; then
        rm -f "$mcp_json"
        print_info "Removed .mcp.json (MCP handled by iclaude)"
    fi

    # Strip lat hooks from .claude/settings.json
    local proj_settings="${project_dir}/.claude/settings.json"
    if [[ -f "$proj_settings" ]]; then
        python3 - "$proj_settings" << 'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    s = json.load(f)
hooks = s.get('hooks', {})
# Remove UserPromptSubmit groups that contain lat hook
for event in ('UserPromptSubmit', 'Stop'):
    groups = hooks.get(event, [])
    filtered = [g for g in groups if not any(
        'hook claude' in h.get('command', '') for h in g.get('hooks', [])
    )]
    if filtered:
        hooks[event] = filtered
    elif event in hooks:
        del hooks[event]
if not hooks:
    s.pop('hooks', None)
if not s:
    import os; os.remove(path)
else:
    with open(path, 'w') as f:
        json.dump(s, f, indent=2); f.write('\n')
PYEOF
        # If file now empty/gone, say so
        if [[ ! -f "$proj_settings" ]]; then
            print_info "Removed empty .claude/settings.json (hooks stripped)"
        else
            print_info "Stripped lat hooks from .claude/settings.json"
        fi
    fi

    return 0
}
