#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1] Syntax check: lib/core/init.sh"
bash -n "$SCRIPT_DIR/lib/core/init.sh"
echo "✓ lib/core/init.sh syntax OK"

echo "[2] LAUNCH_DIR captured in init_environment()"
# Source init.sh in a subshell from a known directory, verify LAUNCH_DIR is set
(
  cd /tmp
  # Minimal stubs so init_environment() doesn't error
  SCRIPT_DIR="$SCRIPT_DIR"
  source "$SCRIPT_DIR/lib/core/init.sh"
  init_environment
  [[ "$LAUNCH_DIR" == "/tmp" ]] || { echo "FAIL: LAUNCH_DIR='$LAUNCH_DIR', expected '/tmp'"; exit 1; }
  [[ "$LAT_ENABLED" == "false" ]] || { echo "FAIL: LAT_ENABLED not false"; exit 1; }
  [[ -z "$LAT_BIN" ]] || { echo "FAIL: LAT_BIN not empty"; exit 1; }
  [[ -z "$LAT_PROJECT_ROOT" ]] || { echo "FAIL: LAT_PROJECT_ROOT not empty"; exit 1; }
)
echo "✓ lat vars initialized correctly"
echo "All Task 1 tests PASSED"

echo "[3] detect_lat() returns 1 when lat binary missing"
(
  SCRIPT_DIR="$SCRIPT_DIR"
  source "$SCRIPT_DIR/lib/core/init.sh"
  init_environment
  NPM_CONFIG_PREFIX="/nonexistent"
  source "$SCRIPT_DIR/lib/lat/detect.sh"
  detect_lat && { echo "FAIL: should return 1"; exit 1; } || true
)
echo "✓ detect_lat() returns 1 for missing binary"

echo "[4] detect_lat_project() returns 1 when lat.md/ missing"
(
  SCRIPT_DIR="$SCRIPT_DIR"
  source "$SCRIPT_DIR/lib/core/init.sh"
  init_environment
  LAUNCH_DIR="/tmp"  # no lat.md/ there
  source "$SCRIPT_DIR/lib/lat/detect.sh"
  detect_lat_project && { echo "FAIL: should return 1"; exit 1; } || true
)
echo "✓ detect_lat_project() returns 1 for missing lat.md/"

echo "[5] detect_lat_project() returns 0 when lat.md/ exists"
(
  SCRIPT_DIR="$SCRIPT_DIR"
  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir/lat.md"
  source "$SCRIPT_DIR/lib/core/init.sh"
  LAUNCH_DIR="$tmpdir"
  source "$SCRIPT_DIR/lib/lat/detect.sh"
  detect_lat_project || { echo "FAIL: should return 0"; rm -rf "$tmpdir"; exit 1; }
  rm -rf "$tmpdir"
)
echo "✓ detect_lat_project() returns 0 when lat.md/ present"

echo "[6] inject_lat_mcp() writes mcpServers.lat to settings.json"
(
  SCRIPT_DIR="$SCRIPT_DIR"
  tmpdir=$(mktemp -d)
  # Minimal settings.json
  echo '{"permissions": {}}' > "$tmpdir/settings.json"
  source "$SCRIPT_DIR/lib/core/init.sh"
  init_environment
  CLAUDE_CONFIG_DIR="$tmpdir"
  LAT_BIN="/usr/local/bin/lat"
  LAUNCH_DIR="/home/user/myproject"
  source "$SCRIPT_DIR/lib/lat/mcp.sh"
  inject_lat_mcp
  # Verify mcpServers.lat.command and cwd
  python3 -c "
import json, sys
with open('$tmpdir/settings.json') as f:
    s = json.load(f)
assert 'mcpServers' in s, 'mcpServers missing'
assert 'lat' in s['mcpServers'], 'lat server missing'
lat = s['mcpServers']['lat']
assert lat['command'] == '/usr/local/bin/lat', f'wrong command: {lat[\"command\"]}'
assert lat['cwd'] == '/home/user/myproject', f'wrong cwd: {lat[\"cwd\"]}'
assert lat['args'] == ['mcp'], f'wrong args: {lat[\"args\"]}'
assert lat['type'] == 'stdio', f'wrong type: {lat[\"type\"]}'
print('JSON structure OK')
"
  rm -rf "$tmpdir"
)
echo "✓ inject_lat_mcp() writes correct settings.json"

echo "[7] inject_lat_mcp() is idempotent (safe to call twice)"
(
  SCRIPT_DIR="$SCRIPT_DIR"
  tmpdir=$(mktemp -d)
  echo '{"permissions": {}}' > "$tmpdir/settings.json"
  source "$SCRIPT_DIR/lib/core/init.sh"
  init_environment
  CLAUDE_CONFIG_DIR="$tmpdir"
  LAT_BIN="/usr/local/bin/lat"
  LAUNCH_DIR="/home/user/myproject"
  source "$SCRIPT_DIR/lib/lat/mcp.sh"
  inject_lat_mcp
  inject_lat_mcp
  python3 -c "
import json
with open('$tmpdir/settings.json') as f:
    s = json.load(f)
assert len([k for k in s['mcpServers']]) == 1, 'duplicate entries'
print('Idempotent OK')
"
  rm -rf "$tmpdir"
)
echo "✓ inject_lat_mcp() idempotent"
