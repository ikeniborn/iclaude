#!/usr/bin/env bash
set -u

ROOT="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1090
source "$ROOT/lib/lockfile/save.sh"
# shellcheck disable=SC1090
source "$ROOT/lib/lockfile/install.sh"

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

assert_file_contains() {
	local path="$1" needle="$2" name="$3"
	if [[ -f "$path" ]] && grep -qF "$needle" "$path"; then
		ok "$name"
	else
		not_ok "$name" "file $path did not contain $needle"
	fi
}

assert_file_not_contains() {
	local path="$1" needle="$2" name="$3"
	if [[ -f "$path" ]] && grep -qF "$needle" "$path"; then
		not_ok "$name" "file $path contained $needle"
	else
		ok "$name"
	fi
}

real_install_function_body() {
	local name="$1"
	awk -v name="$name" '
		$0 ~ "^" name "\\(\\)[[:space:]]*\\{" {
			found = 1
		}
		found && $0 ~ "^[[:alpha:]_][[:alnum:]_]*\\(\\)[[:space:]]*\\{" && $0 !~ "^" name "\\(\\)[[:space:]]*\\{" {
			exit
		}
		found {
			print
		}
	' "$ROOT/lib/lockfile/install.sh"
}

print_warning() { echo "WARN: $*"; }
print_info() { echo "INFO: $*"; }
print_success() { echo "OK: $*"; }
print_error() { echo "ERROR: $*"; }

setup_case() {
	local dir
	dir="$(mktemp -d)"
	echo "$dir" >> "$TMP_LIST"
	CASE_DIR="$dir"
	ISOLATED_LOCKFILE="$dir/lockfile.json"
	cat > "$ISOLATED_LOCKFILE" <<'JSON'
{
  "nodeVersion": "22.23.1",
  "claudeCodeVersion": "2.1.201",
  "lspServers": {"pyright": "1.1.408"},
  "lspPlugins": {"pyright-lsp@claude-plugins-official": "1.0.0"}
}
JSON
	LOCKFILE_HASH_FILE="$dir/.last-lockfile-hash"
	echo "OLDHASH" > "$LOCKFILE_HASH_FILE"
	ISOLATED_NVM_DIR="$dir/.nvm-isolated"
	mkdir -p "$ISOLATED_NVM_DIR/npm-global/bin"
	printf '#!/bin/bash\necho "1.0.0 (Claude Code)"\n' > "$ISOLATED_NVM_DIR/npm-global/bin/claude"
	chmod +x "$ISOLATED_NVM_DIR/npm-global/bin/claude"
	CALL_LOG="$dir/calls.log"
	: > "$CALL_LOG"
}

setup_case
mkdir -p "$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code"
mkdir -p "$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/.claude-code-stale"
touch "$ISOLATED_NVM_DIR/npm-global/bin/.claude-stale"
cleanup_rc=0
cleanup_out="$(cleanup_claude_npm_install_artifacts 2>&1)" || cleanup_rc=$?
if [[ "$cleanup_rc" -eq 0 ]]; then
	ok "claude npm cleanup helper exits successfully"
else
	not_ok "claude npm cleanup helper exits successfully" "$cleanup_out"
fi
if [[ -d "$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code" ]]; then
	ok "claude npm cleanup keeps installed package"
else
	not_ok "claude npm cleanup keeps installed package" "installed package was removed"
fi
if [[ ! -e "$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/.claude-code-stale" ]]; then
	ok "claude npm cleanup removes stale package temp dir"
else
	not_ok "claude npm cleanup removes stale package temp dir" "stale temp dir remains"
fi
if [[ ! -e "$ISOLATED_NVM_DIR/npm-global/bin/.claude-stale" ]]; then
	ok "claude npm cleanup removes stale temp binary"
else
	not_ok "claude npm cleanup removes stale temp binary" "stale temp binary remains"
fi

compute_lockfile_hash() { echo "NEWHASH"; }
update_lockfile_hash() {
	echo "NEWHASH" > "$LOCKFILE_HASH_FILE"
	echo "update_lockfile_hash" >> "$CALL_LOG"
}

install_core_from_lockfile() {
	echo "install_core_from_lockfile" >> "$CALL_LOG"
	return "${CORE_RETURN:-0}"
}

install_from_lockfile() {
	echo "install_from_lockfile" >> "$CALL_LOG"
	return 0
}

run_interactive_check() {
	local input="$1"
	if command -v script >/dev/null 2>&1; then
		local driver="$CASE_DIR/driver.sh"
		{
			printf '#!/usr/bin/env bash\n'
			printf 'set -u\n'
			printf 'ROOT=%q\n' "$ROOT"
			printf 'ISOLATED_LOCKFILE=%q\n' "$ISOLATED_LOCKFILE"
			printf 'LOCKFILE_HASH_FILE=%q\n' "$LOCKFILE_HASH_FILE"
			printf 'ISOLATED_NVM_DIR=%q\n' "$ISOLATED_NVM_DIR"
			printf 'CALL_LOG=%q\n' "$CALL_LOG"
			printf 'CORE_RETURN=%q\n' "${CORE_RETURN:-0}"
			cat <<'DRIVER'
# shellcheck disable=SC1090
source "$ROOT/lib/lockfile/save.sh"

compute_lockfile_hash() { echo "NEWHASH"; }
update_lockfile_hash() {
	echo "NEWHASH" > "$LOCKFILE_HASH_FILE"
	echo "update_lockfile_hash" >> "$CALL_LOG"
}

install_core_from_lockfile() {
	echo "install_core_from_lockfile" >> "$CALL_LOG"
	return "$CORE_RETURN"
}

install_from_lockfile() {
	echo "install_from_lockfile" >> "$CALL_LOG"
	return 0
}

print_warning() { echo "WARN: $*"; }
print_info() { echo "INFO: $*"; }
print_success() { echo "OK: $*"; }
print_error() { echo "ERROR: $*"; }

check_lockfile_changes
DRIVER
		} > "$driver"
		chmod +x "$driver"
		printf '%s\n' "$input" | script -q -e -c "bash $(printf '%q' "$driver")" /dev/null 2>&1
	else
		echo "SKIP: script command unavailable"
		return 77
	fi
}

setup_case
CORE_RETURN=0
out="$(run_interactive_check "y")"
if [[ $? -eq 77 ]]; then
	echo "$out"
	echo "---"
	echo "pass=$pass fail=$fail"
	exit 0
fi
assert_contains "$out" "core isolated environment" "accepted prompt describes core sync"
assert_file_contains "$CALL_LOG" "install_core_from_lockfile" "accepted prompt calls core restore"
assert_file_not_contains "$CALL_LOG" "install_from_lockfile" "accepted prompt does not call full restore"
assert_file_contains "$CALL_LOG" "update_lockfile_hash" "successful core sync updates hash"
assert_file_contains "$LOCKFILE_HASH_FILE" "NEWHASH" "stored hash changed after success"

setup_case
CORE_RETURN=1
out="$(run_interactive_check "y")"
assert_file_contains "$CALL_LOG" "install_core_from_lockfile" "failure still calls core restore"
assert_file_not_contains "$CALL_LOG" "install_from_lockfile" "failure does not fall back to full restore"
assert_file_not_contains "$CALL_LOG" "update_lockfile_hash" "failure does not update hash"
assert_file_contains "$LOCKFILE_HASH_FILE" "OLDHASH" "stored hash unchanged after failure"

setup_case
CORE_RETURN=0
out="$(run_interactive_check "n")"
assert_file_not_contains "$CALL_LOG" "install_core_from_lockfile" "decline does not call core restore"
assert_file_not_contains "$CALL_LOG" "install_from_lockfile" "decline does not call full restore"
assert_file_contains "$LOCKFILE_HASH_FILE" "OLDHASH" "decline leaves hash unchanged"

setup_case
out="$(check_lockfile_changes </dev/null 2>&1)"
assert_contains "$out" "Non-interactive mode" "non-interactive warning remains"
assert_file_not_contains "$CALL_LOG" "install_core_from_lockfile" "non-interactive does not call core restore"
assert_file_not_contains "$CALL_LOG" "install_from_lockfile" "non-interactive does not call full restore"
assert_file_not_contains "$CALL_LOG" "update_lockfile_hash" "non-interactive does not update hash"
assert_file_contains "$LOCKFILE_HASH_FILE" "OLDHASH" "non-interactive leaves hash unchanged"

full_body="$(real_install_function_body install_from_lockfile)"
assert_contains "$full_body" "lspServers" "full restore still handles lspServers"
assert_contains "$full_body" "lspPlugins" "full restore still handles lspPlugins"
core_body="$(real_install_function_body install_core_from_lockfile)"
assert_contains "$core_body" "install_core_from_lockfile()" "core restore function exists"
assert_absent "$core_body" "lspServers" "core restore ignores lspServers"
assert_absent "$core_body" "lspPlugins" "core restore ignores lspPlugins"

echo "---"
echo "pass=$pass fail=$fail"
[[ "$fail" -eq 0 ]]
