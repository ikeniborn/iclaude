#!/bin/bash
# lat MCP wrapper — resolves project dir from $LAUNCH_DIR at runtime.
# Installed by inject_lat_mcp() in lib/lat/mcp.sh.
# LAUNCH_DIR and ISOLATED_NVM_DIR are exported by iclaude; Claude Code inherits
# them and passes to MCP subprocess env.

# Set up PATH: source NVM for Node 20+ (lat.md requires RegExp 'v' flag), add npm-global/bin.
# This replaces the env.PATH injection in settings.json — keeps settings.json portable.
if [[ -n "$ISOLATED_NVM_DIR" ]]; then
    export NVM_DIR="$ISOLATED_NVM_DIR/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
    export PATH="$ISOLATED_NVM_DIR/npm-global/bin:$PATH"
fi

exec_dir="${LAUNCH_DIR:-$PWD}"
lat_bin="$(dirname "$0")/../../npm-global/bin/lat"
[[ -x "$lat_bin" ]] || lat_bin="$(command -v lat 2>/dev/null)"
cd "$exec_dir" && exec "$lat_bin" mcp "$@"
