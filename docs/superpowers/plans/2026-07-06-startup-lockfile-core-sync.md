---
review:
  plan_hash: 980b34f3843ef7d0
  last_run: 2026-07-06
  phases:
    structure: { status: passed }
    coverage: { status: passed }
    dependencies: { status: passed }
    verifiability: { status: passed }
    consistency: { status: passed }
  findings: []
chain:
  intent: docs/superpowers/intents/2026-07-06-startup-lockfile-core-sync-intent.md
  spec: docs/superpowers/specs/2026-07-06-startup-lockfile-core-sync-design.md
---
# Startup Lockfile Core Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the startup lockfile prompt synchronize only Node.js and Claude Code, while preserving manual full lockfile restore including LSP.

**Architecture:** Add a focused internal `install_core_from_lockfile()` helper in `lib/lockfile/install.sh` that restores only `nodeVersion` and `claudeCodeVersion`. Change only the accepted-prompt branch in `check_lockfile_changes()` to call that helper and update the hash on success. Keep `install_from_lockfile()` as the public full restore path.

**Tech Stack:** Bash, existing lockfile modules, existing shell test style under `tests/`, `jq`, `bash -n`.

---

## File Structure

- Create: `tests/test_lockfile_core_sync.sh`
  - Function-level tests for startup prompt behavior and core/full restore boundaries.
  - Uses a pseudo-TTY through `script` when available so `check_lockfile_changes()` takes the interactive prompt branch.
- Modify: `lib/lockfile/install.sh`
  - Add `install_core_from_lockfile()` above `install_from_lockfile()`.
  - Keep existing full restore behavior unchanged.
- Modify: `lib/lockfile/save.sh`
  - Change accepted startup prompt branch to call `install_core_from_lockfile`.
  - Update prompt/help text to describe core isolated environment sync.

---

### Task 1: Add Failing Startup Core-Sync Tests

**Files:**
- Create: `tests/test_lockfile_core_sync.sh`

- [ ] **Step 1: Create the failing test file**

Create `tests/test_lockfile_core_sync.sh` with this content:

```bash
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

print_warning() { echo "WARN: $*"; }
print_info() { echo "INFO: $*"; }
print_success() { echo "OK: $*"; }
print_error() { echo "ERROR: $*"; }

setup_case() {
	local dir
	dir="$(mktemp -d)"
	echo "$dir" >> "$TMP_LIST"
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
		printf '%s\n' "$input" | script -q -e -c 'bash -c "source \"$0\"; check_lockfile_changes" "$1"' /dev/null "$ROOT/lib/lockfile/save.sh" 2>&1
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

assert_contains "$(declare -f install_from_lockfile)" "lspServers" "full restore still handles lspServers"
assert_contains "$(declare -f install_from_lockfile)" "lspPlugins" "full restore still handles lspPlugins"
if declare -F install_core_from_lockfile >/dev/null 2>&1; then
	core_body="$(declare -f install_core_from_lockfile)"
	assert_absent "$core_body" "lspServers" "core restore ignores lspServers"
	assert_absent "$core_body" "lspPlugins" "core restore ignores lspPlugins"
fi

echo "---"
echo "pass=$pass fail=$fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
bash tests/test_lockfile_core_sync.sh
```

Expected: FAIL because the current accepted prompt calls `install_from_lockfile` and does not mention core sync.

- [ ] **Step 3: Commit the failing test**

```bash
git add tests/test_lockfile_core_sync.sh
git commit -m "test: cover startup lockfile core sync"
```

---

### Task 2: Add Core-Only Lockfile Restore Helper

**Files:**
- Modify: `lib/lockfile/install.sh`
- Test: `tests/test_lockfile_core_sync.sh`

- [ ] **Step 1: Add `install_core_from_lockfile()`**

In `lib/lockfile/install.sh`, add this function above `install_from_lockfile()`:

```bash
#######################################
# Install core isolated environment from lockfile
# Installs only Node.js and Claude Code for startup lockfile sync.
# Returns:
#   0 - success
#   1 - error
#######################################
install_core_from_lockfile() {
	if [[ ! -f "$ISOLATED_LOCKFILE" ]]; then
		print_error "Lockfile not found: $ISOLATED_LOCKFILE"
		echo ""
		echo "Create lockfile first with: iclaude --isolated-install"
		return 1
	fi

	print_info "Installing core isolated environment from lockfile..."
	echo ""

	local node_version
	local claude_version
	node_version=$(grep -oP '"nodeVersion":\s*"\K[^"]+' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "22")
	claude_version=$(grep -oP '"claudeCodeVersion":\s*"\K[^"]+' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "")

	print_info "Node.js version from lockfile: $node_version"
	if [[ -n "$claude_version" ]] && [[ "$claude_version" != "unknown" ]]; then
		print_info "Claude Code version from lockfile: $claude_version"
	fi
	echo ""

	if [[ ! -s "$ISOLATED_NVM_DIR/nvm.sh" ]]; then
		install_isolated_nvm || return 1
	fi

	setup_isolated_nvm
	source "$NVM_DIR/nvm.sh"

	node_version=$(echo "$node_version" | sed 's/^v//')

	if ! nvm install "$node_version" || ! nvm use "$node_version"; then
		print_warning "nvm could not download Node.js; trying the node-TLS fallback..."
		echo ""
		local major="${node_version%%.*}"
		if fetch_node_via_node_tls "$major"; then
			local newdir
			newdir="$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d -name "v${major}.*" 2>/dev/null | LC_ALL=C sort | tail -1)"
			[[ -n "$newdir" ]] && { nvm use "$(basename "$newdir")" &>/dev/null || export PATH="$newdir/bin:$PATH"; }
		else
			print_error "Failed to install Node.js $node_version"
			return 1
		fi
	fi

	if [[ -n "$claude_version" ]] && [[ "$claude_version" != "unknown" ]]; then
		npm install -g "@anthropic-ai/claude-code@$claude_version"
	else
		npm install -g "@anthropic-ai/claude-code"
	fi

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install Claude Code"
		return 1
	fi

	print_success "Core isolated environment installed from lockfile"
	echo ""
	return 0
}
```

- [ ] **Step 2: Run focused test**

```bash
bash tests/test_lockfile_core_sync.sh
```

Expected: still FAIL in accepted-prompt cases because `check_lockfile_changes()` still calls `install_from_lockfile`.

- [ ] **Step 3: Run syntax checks**

```bash
bash -n lib/lockfile/install.sh
bash -n tests/test_lockfile_core_sync.sh
```

Expected: no output and exit 0 for both commands.

- [ ] **Step 4: Commit helper**

```bash
git add lib/lockfile/install.sh tests/test_lockfile_core_sync.sh
git commit -m "feat: add core lockfile restore helper"
```

---

### Task 3: Wire Startup Prompt to Core Restore

**Files:**
- Modify: `lib/lockfile/save.sh`
- Test: `tests/test_lockfile_core_sync.sh`

- [ ] **Step 1: Change prompt text and accepted branch**

In `check_lockfile_changes()` in `lib/lockfile/save.sh`, replace the current prompt and accepted branch:

```bash
	read -p "  Run --install-from-lockfile now to update environment? [y/N]: " run_install
	echo ""

	if [[ "$run_install" =~ ^[Yy]$ ]]; then
		print_info "Running: install_from_lockfile..."
		echo ""
		if install_from_lockfile; then
			update_lockfile_hash
			print_success "Environment updated from lockfile"
		else
			print_warning "install_from_lockfile failed — check errors above"
		fi
		echo ""
	else
		print_info "Skipped. Run './iclaude.sh --install-from-lockfile' manually when ready."
		echo ""
	fi
```

with this code:

```bash
	read -p "  Update core isolated environment from lockfile now? [y/N]: " run_install
	echo ""

	if [[ "$run_install" =~ ^[Yy]$ ]]; then
		if [[ $(type -t install_core_from_lockfile) != function ]]; then
			print_warning "Core lockfile sync is unavailable — check installation modules"
			echo ""
			return 0
		fi

		print_info "Running: install_core_from_lockfile..."
		echo ""
		if install_core_from_lockfile; then
			update_lockfile_hash
			print_success "Core isolated environment updated from lockfile"
		else
			print_warning "install_core_from_lockfile failed — check errors above"
		fi
		echo ""
	else
		print_info "Skipped. Run './iclaude.sh --install-from-lockfile' manually for a full restore when ready."
		echo ""
	fi
```

- [ ] **Step 2: Update non-interactive guidance text**

In the non-interactive branch in `check_lockfile_changes()`, replace:

```bash
		print_info "Non-interactive mode: skipping prompt. Run './iclaude.sh --install-from-lockfile' to update."
```

with:

```bash
		print_info "Non-interactive mode: skipping prompt. Run interactively for core sync, or './iclaude.sh --install-from-lockfile' for a full restore."
```

- [ ] **Step 3: Run focused tests**

```bash
bash tests/test_lockfile_core_sync.sh
```

Expected: all assertions pass, with final line `fail=0`.

- [ ] **Step 4: Run existing lockfile probe regression**

```bash
bash tests/test_check_lockfile_binary_probe.sh
```

Expected: all assertions pass, with final line `fail=0`.

- [ ] **Step 5: Run syntax checks**

```bash
bash -n lib/lockfile/install.sh
bash -n lib/lockfile/save.sh
bash -n tests/test_lockfile_core_sync.sh
```

Expected: no output and exit 0 for each command.

- [ ] **Step 6: Commit startup wiring**

```bash
git add lib/lockfile/save.sh tests/test_lockfile_core_sync.sh
git commit -m "fix: use core lockfile sync for startup prompt"
```

---

### Task 4: Final Verification and Chain Result Prep

**Files:**
- Verify: `lib/lockfile/install.sh`
- Verify: `lib/lockfile/save.sh`
- Verify: `tests/test_lockfile_core_sync.sh`
- Verify: `tests/test_check_lockfile_binary_probe.sh`

- [ ] **Step 1: Run focused verification**

```bash
bash tests/test_lockfile_core_sync.sh
bash tests/test_check_lockfile_binary_probe.sh
```

Expected:
- `tests/test_lockfile_core_sync.sh` ends with `fail=0`.
- `tests/test_check_lockfile_binary_probe.sh` ends with `fail=0`.

- [ ] **Step 2: Run syntax verification**

```bash
bash -n iclaude.sh
bash -n lib/lockfile/install.sh
bash -n lib/lockfile/save.sh
bash -n tests/test_lockfile_core_sync.sh
bash -n tests/test_check_lockfile_binary_probe.sh
```

Expected: no output and exit 0 for each command.

- [ ] **Step 3: Verify implementation boundaries by static inspection**

Run:

```bash
grep -n "install_core_from_lockfile" lib/lockfile/install.sh lib/lockfile/save.sh
grep -n "lspServers\\|lspPlugins" lib/lockfile/install.sh
```

Expected:
- `install_core_from_lockfile` appears in `lib/lockfile/install.sh` and the accepted-prompt branch of `lib/lockfile/save.sh`.
- `lspServers` and `lspPlugins` remain inside `install_from_lockfile`.
- `install_core_from_lockfile` does not contain `lspServers` or `lspPlugins`.

- [ ] **Step 4: Commit final verification note only if files changed**

If Step 3 reveals no changes needed, do not create an empty commit. If a verification fix is needed, commit only the changed files:

```bash
git add lib/lockfile/install.sh lib/lockfile/save.sh tests/test_lockfile_core_sync.sh
git commit -m "test: verify lockfile core sync boundaries"
```

Expected: commit is created only when a real fix was made.

---

## Self-Review

- Spec coverage: Requirements 1-8 are covered by Tasks 1 and 3; Requirement 9 is covered by Task 1 static assertions and Task 4 boundary inspection; Requirement 10 is covered by no schema changes and tests using existing fields.
- Placeholder scan: no placeholder markers or deferred-work phrases are present.
- Type/signature consistency: the plan uses one new function name, `install_core_from_lockfile`, consistently across tests, implementation, and startup wiring.
