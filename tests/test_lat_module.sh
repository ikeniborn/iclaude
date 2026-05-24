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
