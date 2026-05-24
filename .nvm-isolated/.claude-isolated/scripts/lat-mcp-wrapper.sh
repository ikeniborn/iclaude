#!/bin/bash
# lat MCP wrapper — resolves project dir from $LAUNCH_DIR at runtime.
# Installed by inject_lat_mcp() in lib/lat/mcp.sh.
# LAUNCH_DIR is exported by iclaude before Claude Code launches; Claude Code
# inherits it and passes it to MCP subprocess env.
exec_dir="${LAUNCH_DIR:-$PWD}"
lat_bin="$(dirname "$0")/../../../npm-global/bin/lat"
[[ -x "$lat_bin" ]] || lat_bin="$(command -v lat 2>/dev/null)"
cd "$exec_dir" && exec "$lat_bin" mcp "$@"
