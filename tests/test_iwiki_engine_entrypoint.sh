#!/bin/bash
# Tests for the iwiki engine entrypoint: IWIKI_ENGINE_DIR resolver, env-map
# wiring, install preflight, and skill regression. No bats — plain asserts.
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO
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

# ---- Task 2: install preflight ----
# Resolve uv the same way install does.
_uv() { [[ -x "${UV_BIN:-}" ]] && { echo "$UV_BIN"; return; }; command -v uv; }

# Stub the iclaude UI helpers to echo so we can assert on output.
_with_stubs() {
    print_info() { echo "INFO: $*"; }
    print_warning() { echo "WARN: $*"; }
    print_success() { echo "OK: $*"; }
    print_error() { echo "ERR: $*"; }
    source "$REPO/lib/iwiki/detect.sh"
    source "$REPO/lib/iwiki/install.sh"
}

test_postsync_params_present() {
    local uv; uv="$(_uv)"
    [[ -z "$uv" || ! -f "$REPO/plugin/iwiki/engine/.venv/pyvenv.cfg" ]] && { echo "SKIP: postsync(params present) — no uv/synced engine"; return; }
    local out
    out="$( cd "$(mktemp -d)" && SCRIPT_DIR="$REPO" \
            IWIKI_LLM_BASE_URL="http://x/v1" IWIKI_LLM_KEY="k" \
            bash -c "$(declare -f); _with_stubs; _iwiki_postsync_check '$REPO/plugin/iwiki/engine' '$uv'" 2>&1 )"
    assert_contains "postsync prints engine health OK" "$out" "OK:"
    assert_not_contains "postsync: no param warning when set" "$out" "params missing"
    assert_contains "postsync prints resolved engine dir" "$out" "plugin/iwiki/engine"
}

test_postsync_params_missing() {
    local uv; uv="$(_uv)"
    [[ -z "$uv" || ! -f "$REPO/plugin/iwiki/engine/.venv/pyvenv.cfg" ]] && { echo "SKIP: postsync(params missing) — no uv/synced engine"; return; }
    local out
    out="$( cd "$(mktemp -d)" && SCRIPT_DIR="$REPO" \
            bash -c "$(declare -f); _with_stubs; \
                     unset IWIKI_LLM_BASE_URL IWIKI_LLM_KEY; \
                     _iwiki_postsync_check '$REPO/plugin/iwiki/engine' '$uv'; echo RC=\$?" 2>&1 )"
    assert_contains "postsync warns params missing" "$out" "params missing"
    assert_contains "postsync names ICLAUDE_IWIKI_LLM_BASE_URL" "$out" "ICLAUDE_IWIKI_LLM_BASE_URL"
    assert_contains "postsync names ICLAUDE_IWIKI_LLM_KEY" "$out" "ICLAUDE_IWIKI_LLM_KEY"
    assert_contains "postsync stays non-fatal (RC=0)" "$out" "RC=0"
}

# ---- Task 3: skill regression ----
test_skills_canonical_block() {
    local s f body
    for s in iwiki-init iwiki-ingest iwiki-query iwiki-lint; do
        f="$REPO/plugin/iwiki/skills/$s/SKILL.md"
        body="$(cat "$f")"
        assert_not_contains "$s: no 'command -v iwiki_engine'" "$body" "command -v iwiki_engine"
        assert_not_contains "$s: no 'iwiki_engine --help'"     "$body" "iwiki_engine --help"
        assert_contains     "$s: reads IWIKI_ENGINE_DIR"       "$body" "IWIKI_ENGINE_DIR"
        assert_contains     "$s: has fail-loud line"           "$body" "engine not found — run ./iclaude.sh --install-iwiki"
    done
}

test_resolver_prefers_in_repo
test_resolver_falls_back_to_newest_cache
test_envmap_exports_engine_dir
test_postsync_params_present
test_postsync_params_missing
test_skills_canonical_block

echo "----"
[[ "$fails" -eq 0 ]] && { echo "ALL PASS"; exit 0; } || { echo "$fails FAILED"; exit 1; }
