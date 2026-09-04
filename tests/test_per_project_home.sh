#!/usr/bin/env bash
# Unit tests for per-project home resolution (lib/config/isolated.sh, S1 slice):
# resolve_project_root, resolve_claude_home_id, setup_claude_home, and the
# ICLAUDE_HOME_MODE dispatch inside setup_isolated_config.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Stub print_* so the module has no hard dependency on lib/core/logging.sh.
print_info()    { :; }
print_warning() { :; }
print_error()   { :; }

source "$ROOT/lib/config/env-map.sh"
source "$ROOT/lib/config/isolated.sh"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }
assert_match() { if [[ "$1" =~ $2 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: '$1' !~ /$2/"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- resolve_project_root ---

# Inside a git repo → git toplevel, even from a subdirectory.
mkdir -p "$TMP/repoA/sub"
git -C "$TMP/repoA" init -q
top_phys="$(cd "$TMP/repoA" && pwd -P)"
assert_eq "$(cd "$TMP/repoA/sub" && resolve_project_root)" "$top_phys" "root: git toplevel from subdir"

# Outside git → physical working directory.
mkdir -p "$TMP/plaindir"
plain_phys="$(cd "$TMP/plaindir" && pwd -P)"
assert_eq "$(cd "$TMP/plaindir" && resolve_project_root)" "$plain_phys" "root: non-git falls back to pwd -P"

# --- resolve_claude_home_id ---

# Format: sanitized basename + '-' + 12 hex chars of sha256(path).
id_a="$(resolve_claude_home_id "$top_phys")"
assert_match "$id_a" '^repoa-[0-9a-f]{12}$' "id: format basename-12hex, lowercased"

# Deterministic: same path → same id.
assert_eq "$(resolve_claude_home_id "$top_phys")" "$id_a" "id: deterministic"

# Different paths (same basename) → different ids.
mkdir -p "$TMP/other/repoA"
id_b="$(resolve_claude_home_id "$(cd "$TMP/other/repoA" && pwd -P)")"
[[ "$id_a" != "$id_b" ]] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL [id: distinct paths distinct ids]"; }

# Sanitization: chars outside [a-z0-9._-] collapse to '-'.
mkdir -p "$TMP/My Repo!"
assert_match "$(resolve_claude_home_id "$(cd "$TMP/My Repo!" && pwd -P)")" '^my-repo-[0-9a-f]{12}$' "id: sanitized basename"

# Known-vector check: hash suffix equals sha256 of the path string.
want_hash="$(printf '%s' "$top_phys" | sha256sum | cut -c1-12)"
assert_eq "${id_a##*-}" "$want_hash" "id: hash is sha256(path)[0:12]"

# --- setup_claude_home ---

# Creates the home + marker, exports CLAUDE_CONFIG_DIR.
out="$(
  cd "$TMP/repoA" || exit 1
  ISOLATED_HOMES_DIR="$TMP/homes" setup_claude_home >/dev/null 2>&1 || exit 1
  printf '%s' "$CLAUDE_CONFIG_DIR"
)"
assert_eq "$out" "$TMP/homes/$id_a" "home: CLAUDE_CONFIG_DIR exported to home"
[[ -d "$TMP/homes/$id_a" ]] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL [home: dir created]"; }
marker="$TMP/homes/$id_a/home.json"
[[ -f "$marker" ]] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL [home: marker exists]"; }
assert_eq "$(jq -r '.project_root' "$marker" 2>/dev/null)" "$top_phys" "home: marker records project root"
assert_eq "$(jq -r '.schema' "$marker" 2>/dev/null)" "1" "home: marker schema version"
assert_match "$(jq -r '.created' "$marker" 2>/dev/null)" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "home: marker created timestamp"

# Idempotent: second call keeps the marker byte-identical.
before="$(cat "$marker")"
( cd "$TMP/repoA" && ISOLATED_HOMES_DIR="$TMP/homes" setup_claude_home >/dev/null 2>&1 )
assert_eq "$(cat "$marker")" "$before" "home: second call preserves marker"

# --- setup_isolated_config dispatch ---

# Default (mode unset) → per-project home (S5 flip).
out="$(
  cd "$TMP/repoA" || exit 1
  unset ICLAUDE_HOME_MODE
  ISOLATED_NVM_DIR="$TMP/nvm" ISOLATED_HOMES_DIR="$TMP/homes2" setup_isolated_config >/dev/null 2>&1 || exit 1
  printf '%s' "$CLAUDE_CONFIG_DIR"
)"
assert_eq "$out" "$TMP/homes2/$id_a" "dispatch: default per-project (S5 flip)"

# mode=shared → shared dir. The shared store comes from ISOLATED_CONFIG_DIR, not
# from a path derived under ISOLATED_NVM_DIR.
out="$(
  export ICLAUDE_HOME_MODE=shared
  ISOLATED_NVM_DIR="$TMP/nvm" ISOLATED_CONFIG_DIR="$TMP/shared-store" \
    ISOLATED_HOMES_DIR="$TMP/homes2" setup_isolated_config >/dev/null 2>&1 || exit 1
  printf '%s' "$CLAUDE_CONFIG_DIR"
)"
assert_eq "$out" "$TMP/shared-store" "dispatch: explicit shared"

# mode=per-project → per-project home.
out="$(
  cd "$TMP/repoA" || exit 1
  export ICLAUDE_HOME_MODE=per-project
  ISOLATED_NVM_DIR="$TMP/nvm" ISOLATED_HOMES_DIR="$TMP/homes2" setup_isolated_config >/dev/null 2>&1 || exit 1
  printf '%s' "$CLAUDE_CONFIG_DIR"
)"
assert_eq "$out" "$TMP/homes2/$id_a" "dispatch: per-project mode"

# Unknown mode → warn, fall back to shared, still succeed.
out="$(
  export ICLAUDE_HOME_MODE=bogus
  ISOLATED_NVM_DIR="$TMP/nvm" ISOLATED_CONFIG_DIR="$TMP/shared-store" \
    ISOLATED_HOMES_DIR="$TMP/homes2" setup_isolated_config >/dev/null 2>&1 || exit 1
  printf '%s' "$CLAUDE_CONFIG_DIR"
)"
assert_eq "$out" "$TMP/shared-store" "dispatch: unknown mode falls back to shared"

# --- env-map: ICLAUDE_HOME_MODE is native, never de-prefixed ---

out="$(bash -c '
  print_info(){ :; }; print_warning(){ :; }; print_error(){ :; }
  source "'"$ROOT"'/lib/config/env-map.sh"
  export ICLAUDE_HOME_MODE=per-project
  apply_iclaude_env_map
  if [[ -n ${HOME_MODE+x} ]]; then printf "%s" "$HOME_MODE"; else printf "<unset>"; fi
')"
assert_eq "$out" "<unset>" "env-map: not de-prefixed to HOME_MODE"

out="$(bash -c '
  print_info(){ :; }; print_warning(){ :; }; print_error(){ :; }
  source "'"$ROOT"'/lib/config/env-map.sh"
  export ICLAUDE_HOME_MODE=per-project
  apply_iclaude_env_map
  printf "%s" "${ICLAUDE_HOME_MODE:-<unset>}"
')"
assert_eq "$out" "per-project" "env-map: native name kept verbatim"

echo "per-project-home: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
