#!/bin/bash
# Tests for the iwiki engine entrypoint: IWIKI_ENGINE_DIR resolver, env-map
# wiring, install preflight, and skill regression. No bats — plain asserts.
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fails=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; fails=$((fails+1)); }
assert_eq() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1 (got '$2', want '$3')"; }
assert_contains() { case "$2" in *"$3"*) pass "$1";; *) fail "$1 (missing '$3')";; esac; }
assert_not_contains() { case "$2" in *"$3"*) fail "$1 (found '$3')";; *) pass "$1";; esac; }

# ---- Task 1: resolver ----
make_engine() { mkdir -p "$1"; printf '[project]\nname="x"\n' > "$1/pyproject.toml"; }

test_resolver_prefers_in_repo() {
    local t; t="$(mktemp -d)"
    make_engine "$t/plugin/iwiki/engine"
    ( set -e
      SCRIPT_DIR="$t"; CLAUDE_CONFIG_DIR="$t/nope"
      source "$REPO/lib/iwiki/detect.sh"
      unset IWIKI_ENGINE_DIR
      iwiki_export_engine_dir
      [[ "$IWIKI_ENGINE_DIR" == "$t/plugin/iwiki/engine" ]] )
    assert_eq "resolver prefers in-repo engine" "$?" "0"
    rm -rf "$t"
}

test_resolver_falls_back_to_newest_cache() {
    local t; t="$(mktemp -d)"
    make_engine "$t/cfg/plugins/cache/iclaude/iwiki/0.6.3/engine"
    make_engine "$t/cfg/plugins/cache/iclaude/iwiki/0.6.4/engine"
    local got
    got="$(
      SCRIPT_DIR="$t/no-repo"; CLAUDE_CONFIG_DIR="$t/cfg"
      source "$REPO/lib/iwiki/detect.sh"
      unset IWIKI_ENGINE_DIR
      iwiki_export_engine_dir
      echo "$IWIKI_ENGINE_DIR" )"
    assert_eq "resolver picks newest cached engine" \
      "$got" "$t/cfg/plugins/cache/iclaude/iwiki/0.6.4/engine"
    rm -rf "$t"
}

# ---- Task 1: env-map wiring ----
test_envmap_exports_engine_dir() {
    local t; t="$(mktemp -d)"
    make_engine "$t/plugin/iwiki/engine"
    local got
    got="$(
      SCRIPT_DIR="$t"; CLAUDE_CONFIG_DIR="$t/nope"; CREDENTIALS_FILE="$t/nofile"
      source "$REPO/lib/iwiki/detect.sh"
      source "$REPO/lib/config/env-map.sh"
      unset IWIKI_ENGINE_DIR
      source_iclaude_config
      echo "$IWIKI_ENGINE_DIR" )"
    assert_eq "source_iclaude_config exports IWIKI_ENGINE_DIR (no config file)" \
      "$got" "$t/plugin/iwiki/engine"
    rm -rf "$t"
}

test_resolver_prefers_in_repo
test_resolver_falls_back_to_newest_cache
test_envmap_exports_engine_dir

echo "----"
[[ "$fails" -eq 0 ]] && { echo "ALL PASS"; exit 0; } || { echo "$fails FAILED"; exit 1; }
