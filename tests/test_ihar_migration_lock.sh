#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
print_info() { :; }
print_warning() { :; }
print_error() { :; }
source "$ROOT/lib/config/isolated.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
home="$tmp/homes/project-123"
mkdir -p "$(dirname "$home")"

acquire_claude_home_lifecycle_lock "$home"
if flock -x -n "$home.ihar-lifecycle.lock" true 2>/dev/null; then
  echo "FAIL: migration exclusive lock entered during Claude lifecycle"
  exit 1
fi
eval "exec ${ICLAUDE_HOME_LIFECYCLE_FD}>&-"
unset ICLAUDE_HOME_LIFECYCLE_FD
flock -x -n "$home.ihar-lifecycle.lock" true
echo "PASS: Claude holds the shared migration lock for its lifecycle"

project="$tmp/project"
homes="$tmp/integration-homes"
mkdir -p "$project" "$homes"
project_root="$(cd "$project" && pwd -P)"
project_home="$homes/$(resolve_claude_home_id "$project_root")"
exec {exclusive_fd}>"$project_home.ihar-lifecycle.lock"
flock -x "$exclusive_fd"
if (cd "$project" && ICLAUDE_HOME_LOCK_TIMEOUT=0 ISOLATED_HOMES_DIR="$homes" \
    setup_claude_home >/dev/null 2>&1); then
  echo "FAIL: setup_claude_home bypassed the migration lock"
  exit 1
fi
[[ ! -d "$project_home" ]]
if (cd "$project" && ICLAUDE_HOME_LOCK_TIMEOUT=0 ISOLATED_HOMES_DIR="$homes" \
    ISOLATED_CONFIG_DIR="$tmp/shared" setup_isolated_config >/dev/null 2>&1); then
  echo "FAIL: dispatcher fell back to shared config during migration"
  exit 1
fi
[[ ! -d "$tmp/shared" ]]
exec {exclusive_fd}>&-
echo "PASS: Claude setup refuses an active migration"
