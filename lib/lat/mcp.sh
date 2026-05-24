#!/bin/bash
# lat.md MCP integration module
# Provides: inject_lat_mcp()

#######################################
# Inject lat MCP server into settings.json.
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

    if ! python3 - "$settings_file" "$LAT_BIN" "$LAUNCH_DIR" << 'PYEOF'
import json, sys
settings_path, lat_bin, launch_dir = sys.argv[1], sys.argv[2], sys.argv[3]
with open(settings_path) as f:
    s = json.load(f)
s.setdefault('mcpServers', {})['lat'] = {
    'type': 'stdio',
    'command': lat_bin,
    'args': ['mcp'],
    'cwd': launch_dir
}
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
