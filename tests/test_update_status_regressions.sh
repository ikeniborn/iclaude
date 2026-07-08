#!/usr/bin/env bash
set -u

ROOT="$(git rev-parse --show-toplevel)"

# shellcheck disable=SC1090
source "$ROOT/lib/nvm/setup.sh"
# shellcheck disable=SC1090
source "$ROOT/lib/nvm/repair.sh"
# shellcheck disable=SC1090
source "$ROOT/lib/config/status.sh"
# shellcheck disable=SC1090
source "$ROOT/lib/core/remaining.sh"

TMP_LIST="$(mktemp)"
trap 'xargs -r rm -rf < "$TMP_LIST"; rm -f "$TMP_LIST"' EXIT

pass=0
fail=0

ok() {
	echo "ok: $1"
	pass=$((pass + 1))
}

not_ok() {
	echo "FAIL: $1"
	echo "$2"
	fail=$((fail + 1))
}

assert_contains() {
	local haystack="$1" needle="$2" name="$3"
	if grep -qF "$needle" <<< "$haystack"; then
		ok "$name"
	else
		not_ok "$name" "missing: $needle"$'\n'"$haystack"
	fi
}

assert_absent() {
	local haystack="$1" needle="$2" name="$3"
	if grep -qF "$needle" <<< "$haystack"; then
		not_ok "$name" "unexpected: $needle"$'\n'"$haystack"
	else
		ok "$name"
	fi
}

print_warning() { echo "WARN: $*"; }
print_info() { echo "INFO: $*"; }
print_success() { echo "OK: $*"; }
print_error() { echo "ERROR: $*"; }

setup_node_dirs() {
	local dir
	dir="$(mktemp -d)"
	echo "$dir" >> "$TMP_LIST"
	ISOLATED_NVM_DIR="$dir/.nvm-isolated"
	ISOLATED_LOCKFILE="$dir/lockfile.json"
	mkdir -p "$ISOLATED_NVM_DIR/versions/node/v20.20.2/bin"
	mkdir -p "$ISOLATED_NVM_DIR/versions/node/v22.23.1/bin"
	mkdir -p "$ISOLATED_NVM_DIR/versions/node/v22.23.1/lib/node_modules/npm/bin"
	mkdir -p "$ISOLATED_NVM_DIR/versions/node/v22.23.1/lib/node_modules/corepack/dist"
	touch "$ISOLATED_NVM_DIR/versions/node/v22.23.1/lib/node_modules/npm/bin/npm-cli.js"
	touch "$ISOLATED_NVM_DIR/versions/node/v22.23.1/lib/node_modules/npm/bin/npx-cli.js"
	touch "$ISOLATED_NVM_DIR/versions/node/v22.23.1/lib/node_modules/corepack/dist/corepack.js"
	ln -s ../lib/node_modules/npm/bin/npm-cli.js "$ISOLATED_NVM_DIR/versions/node/v22.23.1/bin/npm"
	ln -s ../lib/node_modules/npm/bin/npx-cli.js "$ISOLATED_NVM_DIR/versions/node/v22.23.1/bin/npx"
	ln -s ../lib/node_modules/corepack/dist/corepack.js "$ISOLATED_NVM_DIR/versions/node/v22.23.1/bin/corepack"
	mkdir -p "$ISOLATED_NVM_DIR/npm-global/bin"
	mkdir -p "$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin"
	printf '{"version":"2.1.204"}\n' > "$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/package.json"
	touch "$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
	ln -s ../lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe "$ISOLATED_NVM_DIR/npm-global/bin/claude"
	printf '{"claudeCodeVersion":"2.1.204"}\n' > "$ISOLATED_LOCKFILE"
}

setup_node_dirs
selected="$(get_isolated_node_version_dir)"
if [[ "$selected" == "$ISOLATED_NVM_DIR/versions/node/v22.23.1" ]]; then
	ok "latest isolated Node dir selected deterministically"
else
	not_ok "latest isolated Node dir selected deterministically" "selected: ${selected:-<empty>}"
fi

out="$(check_isolated_status 2>&1)"
assert_contains "$out" "✓ npm" "status checks npm in latest Node dir"
assert_contains "$out" "✓ npx" "status checks npx in latest Node dir"
assert_contains "$out" "✓ corepack" "status checks corepack in latest Node dir"
assert_absent "$out" "Found 3 symlink issue(s)" "status does not warn about old Node dir symlinks"

rm -f "$ISOLATED_NVM_DIR/npm-global/bin/claude"
out="$(create_claude_symlink 2>&1)"
assert_contains "$out" "Created: claude symlink" "repair restores missing Claude symlink"
if [[ -L "$ISOLATED_NVM_DIR/npm-global/bin/claude" ]]; then
	ok "restored Claude symlink exists"
else
	not_ok "restored Claude symlink exists" "symlink missing"
fi

npm() {
	echo "npm-called: $*"
	return 0
}
out="$(run_claude_npm_install_with_progress "@anthropic-ai/claude-code@2.1.204" 2>&1)"
assert_contains "$out" "native binary package is large" "npm install helper warns about large native package"
assert_contains "$out" "npm-called: install -g @anthropic-ai/claude-code@2.1.204" "npm install helper delegates to npm install"

detect_nvm() { return 1; }
get_claude_version() { echo "2.1.204 (Claude Code)"; }
npm() {
	if [[ "$*" == "view @anthropic-ai/claude-code version" ]]; then
		echo "2.1.204"
		return 0
	fi
	return 1
}

out="$(check_update false 2>&1)"
assert_contains "$out" "You are running the latest version" "check-update treats version suffix as current"
assert_absent "$out" "An update is available" "check-update avoids suffix false positive"

echo "---"
echo "pass=$pass fail=$fail"
[[ "$fail" -eq 0 ]]
