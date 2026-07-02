#!/usr/bin/env bash
# Boot must survive a missing VERSION file: init_environment falls back to "dev".
# Regression: `cat VERSION | tr` inside $() under `set -euo pipefail` killed the
# whole script (silent exit 1) before the fallback line could run.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# SCRIPT_DIR points at an empty dir (no VERSION file), same strict mode as iclaude.sh.
out="$(bash -c '
  set -euo pipefail
  source "$1/lib/core/init.sh"
  SCRIPT_DIR="$2"
  init_environment
  echo "version=$ICLAUDE_VERSION"
' _ "$repo_root" "$tmp")" || {
  echo "FAIL: init_environment died with missing VERSION (exit $?)" >&2
  exit 1
}

[[ "$out" == *"version=dev"* ]] || {
  echo "FAIL: expected fallback version=dev, got: $out" >&2
  exit 1
}
echo "PASS test_version_fallback.sh"
