# iclaude User-Space Symlink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `iclaude` create and maintain a user-space launcher like `icodex`, without requiring full paths or sudo for the normal isolated install flow.

**Architecture:** Add a focused `lib/symlink/symlink.sh` module for launcher directory resolution, isolated Claude Code layout detection, symlink creation/removal, and PATH profile setup. Wire the module into existing one-shot command branches without restructuring the Phase 15 parser. Keep legacy `/usr/local/bin` `--install` and `--uninstall` behavior unchanged.

**Tech Stack:** Bash, existing `print_*` logging helpers, existing `.nvm-isolated` layout, shell tests under `tests/`.

---

## File Structure

- Create: `lib/symlink/symlink.sh`
  - Owns user-space launcher behavior only.
  - Exports functions: `iclaude_link_dir`, `detect_iclaude_isolated_launcher`, `install_iclaude_symlink`, `ensure_iclaude_path_entry`, `uninstall_iclaude_symlink`, `install_iclaude_user_launcher`.
- Create: `tests/test_user_symlink.sh`
  - Unit-style shell tests with temporary `$HOME`, `$SCRIPT_DIR`, `$ISOLATED_NVM_DIR`, and `$ICLAUDE_LINK_DIR`.
- Modify: `iclaude.sh`
  - Sources `lib/symlink/symlink.sh`.
  - Calls `install_iclaude_user_launcher` after successful `--isolated-install`, `--isolated-update`, and `--install-from-lockfile`.
- Modify: `lib/core/remaining.sh`
  - Changes `create_symlink_only` and `uninstall_symlink_only` to delegate to user-space helpers.
  - Leaves `install_script` and `uninstall_script` legacy system path intact.
- Modify: `lib/command/usage.sh`, `README.md`, `docs/functions/CONFIGURATION.md`, `docs/functions/USE_CASES.md`
  - Removes `sudo` from symlink docs and documents `$ICLAUDE_LINK_DIR`.

---

### Task 1: Add Failing Symlink Module Tests

**Files:**
- Create: `tests/test_user_symlink.sh`

- [ ] **Step 1: Create test file**

Create `tests/test_user_symlink.sh` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass=0
fail=0

ok() {
    echo "PASS [$1]"
    pass=$((pass + 1))
}

not_ok() {
    echo "FAIL [$1]: $2"
    fail=$((fail + 1))
}

assert_eq() {
    local name="$1" want="$2" got="$3"
    if [[ "$want" == "$got" ]]; then
        ok "$name"
    else
        not_ok "$name" "want '$want', got '$got'"
    fi
}

assert_file() {
    local name="$1" path="$2"
    if [[ -e "$path" || -L "$path" ]]; then
        ok "$name"
    else
        not_ok "$name" "missing $path"
    fi
}

assert_symlink_target() {
    local name="$1" link="$2" target="$3"
    if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then
        ok "$name"
    else
        not_ok "$name" "link target is '$(readlink "$link" 2>/dev/null || echo missing)'"
    fi
}

new_fixture() {
    local root
    root="$(mktemp -d)"
    export HOME="$root/home"
    export SCRIPT_DIR="$root/repo"
    export ISOLATED_NVM_DIR="$SCRIPT_DIR/.nvm-isolated"
    export ICLAUDE_LINK_DIR=""
    export PATH="/usr/bin:/bin"
    export SHELL="/bin/bash"
    mkdir -p "$HOME" "$SCRIPT_DIR"
    printf '#!/usr/bin/env bash\necho iclaude test\n' > "$SCRIPT_DIR/iclaude.sh"
    chmod +x "$SCRIPT_DIR/iclaude.sh"
    printf '%s\n' "$root"
}

add_native_claude() {
    mkdir -p "$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin"
    printf '#!/usr/bin/env bash\necho claude native\n' > "$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
    chmod +x "$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
}

add_bin_claude() {
    mkdir -p "$ISOLATED_NVM_DIR/npm-global/bin"
    printf '#!/usr/bin/env bash\necho claude bin\n' > "$ISOLATED_NVM_DIR/npm-global/bin/claude"
    chmod +x "$ISOLATED_NVM_DIR/npm-global/bin/claude"
}

add_legacy_cli() {
    mkdir -p "$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code"
    printf 'console.log("claude legacy")\n' > "$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
}

source "$REPO_ROOT/lib/core/logging.sh"
source "$REPO_ROOT/lib/symlink/symlink.sh"

root="$(new_fixture)"
add_native_claude
install_iclaude_symlink
assert_symlink_target "default-link-target" "$HOME/.local/bin/iclaude" "$SCRIPT_DIR/iclaude.sh"
rm -rf "$root"

root="$(new_fixture)"
add_native_claude
mkdir -p "$HOME/.local/bin" "$root/other"
ln -s "$root/other/iclaude.sh" "$HOME/.local/bin/iclaude"
install_iclaude_symlink
assert_symlink_target "repair-stale-symlink" "$HOME/.local/bin/iclaude" "$SCRIPT_DIR/iclaude.sh"
rm -rf "$root"

root="$(new_fixture)"
add_native_claude
mkdir -p "$HOME/.local/bin"
printf 'real file\n' > "$HOME/.local/bin/iclaude"
install_iclaude_symlink
assert_eq "non-symlink-left-untouched" "real file" "$(cat "$HOME/.local/bin/iclaude")"
rm -rf "$root"

root="$(new_fixture)"
add_native_claude
export ICLAUDE_LINK_DIR="~/custom-bin"
install_iclaude_symlink
assert_symlink_target "tilde-link-dir" "$HOME/custom-bin/iclaude" "$SCRIPT_DIR/iclaude.sh"
rm -rf "$root"

root="$(new_fixture)"
add_native_claude
ensure_iclaude_path_entry
ensure_iclaude_path_entry
assert_eq "bash-path-once" "1" "$(grep -c 'added by iclaude' "$HOME/.bashrc")"
rm -rf "$root"

root="$(new_fixture)"
add_native_claude
export SHELL="/bin/zsh"
ensure_iclaude_path_entry
ensure_iclaude_path_entry
assert_eq "zsh-path-once" "1" "$(grep -c 'added by iclaude' "$HOME/.zshrc")"
rm -rf "$root"

root="$(new_fixture)"
add_native_claude
export SHELL="/usr/bin/fish"
ensure_iclaude_path_entry
ensure_iclaude_path_entry
assert_eq "fish-path-once" "1" "$(grep -c 'added by iclaude' "$HOME/.config/fish/config.fish")"
rm -rf "$root"

root="$(new_fixture)"
add_native_claude
detect_iclaude_isolated_launcher
ok "detect-native-claude-exe"
rm -rf "$root"

root="$(new_fixture)"
add_bin_claude
detect_iclaude_isolated_launcher
ok "detect-npm-global-bin-claude"
rm -rf "$root"

root="$(new_fixture)"
add_legacy_cli
detect_iclaude_isolated_launcher
ok "detect-legacy-cli-js"
rm -rf "$root"

root="$(new_fixture)"
if detect_iclaude_isolated_launcher >/tmp/iclaude-symlink-missing.out 2>&1; then
    not_ok "missing-isolated-fails" "detect returned success"
else
    if grep -q -- "--isolated-install" /tmp/iclaude-symlink-missing.out; then
        ok "missing-isolated-fails"
    else
        not_ok "missing-isolated-fails" "missing instruction not printed"
    fi
fi
rm -rf "$root"

root="$(new_fixture)"
add_native_claude
install_iclaude_symlink
uninstall_iclaude_symlink
if [[ ! -e "$HOME/.local/bin/iclaude" && ! -L "$HOME/.local/bin/iclaude" ]]; then
    ok "uninstall-current-repo-link"
else
    not_ok "uninstall-current-repo-link" "link still exists"
fi
rm -rf "$root"

echo "=== Results: $pass passed, $fail failed ==="
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails before implementation**

```bash
bash tests/test_user_symlink.sh
```

Expected: FAIL before `lib/symlink/symlink.sh` exists or before required functions exist.

- [ ] **Step 3: Commit failing test**

```bash
git add tests/test_user_symlink.sh
git commit -m "test: cover iclaude user symlink behavior"
```

---

### Task 2: Implement `lib/symlink/symlink.sh`

**Files:**
- Create: `lib/symlink/symlink.sh`
- Test: `tests/test_user_symlink.sh`

- [ ] **Step 1: Create symlink module**

Create `lib/symlink/symlink.sh` with this content:

```bash
#!/usr/bin/env bash
# User-space launcher symlink management for iclaude.

iclaude_link_dir() {
    local dir="${ICLAUDE_LINK_DIR:-$HOME/.local/bin}"
    dir="${dir/#\~\//$HOME/}"
    printf '%s\n' "$dir"
}

_iclaude_realpath() {
    if command -v readlink >/dev/null 2>&1; then
        readlink -f "$1"
    else
        local base name
        base="$(dirname "$1")"
        name="$(basename "$1")"
        (cd "$base" && printf '%s/%s\n' "$PWD" "$name")
    fi
}

detect_iclaude_isolated_launcher() {
    local prefix="$ISOLATED_NVM_DIR/npm-global"
    local pkg="$prefix/lib/node_modules/@anthropic-ai/claude-code"
    local bin_link="$prefix/bin/claude"
    local native_bin="$pkg/bin/claude.exe"
    local legacy_cli="$pkg/cli.js"

    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found"
        echo ""
        echo "Run: ./iclaude.sh --isolated-install"
        return 1
    fi

    if [[ -x "$bin_link" || -L "$bin_link" ]]; then
        print_success "Claude Code launcher found: $bin_link"
        return 0
    fi

    if [[ -x "$native_bin" ]]; then
        print_success "Claude Code native binary found: $native_bin"
        return 0
    fi

    if [[ -f "$legacy_cli" ]]; then
        print_success "Claude Code legacy CLI found: $legacy_cli"
        return 0
    fi

    print_error "Claude Code not found in isolated environment"
    echo ""
    echo "Checked:"
    echo "  $bin_link"
    echo "  $native_bin"
    echo "  $legacy_cli"
    echo ""
    echo "Run: ./iclaude.sh --repair-isolated"
    echo "Or reinstall: ./iclaude.sh --isolated-install"
    return 1
}

install_iclaude_symlink() {
    local dir target link target_real link_real
    dir="$(iclaude_link_dir)"
    target="$SCRIPT_DIR/iclaude.sh"
    link="$dir/iclaude"

    mkdir -p "$dir" || {
        print_error "Cannot create launcher directory: $dir"
        return 1
    }

    target_real="$(_iclaude_realpath "$target")"

    if [[ -L "$link" ]]; then
        link_real="$(_iclaude_realpath "$link" 2>/dev/null || true)"
        if [[ "$link_real" == "$target_real" ]]; then
            print_info "iclaude symlink already up to date: $link"
        else
            ln -sf "$target" "$link"
            print_info "repaired iclaude symlink: $link -> $target"
        fi
    elif [[ -e "$link" ]]; then
        print_warning "$link exists and is not an iclaude symlink; left untouched"
        return 0
    else
        ln -s "$target" "$link"
        print_info "created iclaude symlink: $link -> $target"
    fi

    return 0
}

ensure_iclaude_path_entry() {
    local dir marker profile line shell_name
    dir="$(iclaude_link_dir)"

    case ":$PATH:" in
        *":$dir:"*) return 0 ;;
    esac

    marker="# added by iclaude (PATH for the iclaude launcher)"
    shell_name="$(basename "${SHELL:-}")"

    case "$shell_name" in
        fish)
            profile="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
            line="fish_add_path \"$dir\""
            ;;
        zsh)
            profile="$HOME/.zshrc"
            line="export PATH=\"$dir:\$PATH\""
            ;;
        bash)
            profile="$HOME/.bashrc"
            line="export PATH=\"$dir:\$PATH\""
            ;;
        *)
            print_warning "$dir is not on your PATH; add it manually to run 'iclaude' directly"
            return 0
            ;;
    esac

    if [[ -f "$profile" ]] && grep -qF "$dir" "$profile" 2>/dev/null; then
        return 0
    fi

    mkdir -p "$(dirname "$profile")" || {
        print_warning "Cannot create $(dirname "$profile"); add $dir to PATH manually"
        return 0
    }

    printf '\n%s\n%s\n' "$marker" "$line" >> "$profile" || {
        print_warning "Cannot write $profile; add $dir to PATH manually"
        return 0
    }

    print_info "added $dir to PATH in $profile; restart your shell or source the profile"
    return 0
}

uninstall_iclaude_symlink() {
    local dir target link target_real link_real
    dir="$(iclaude_link_dir)"
    target="$SCRIPT_DIR/iclaude.sh"
    link="$dir/iclaude"

    if [[ ! -e "$link" && ! -L "$link" ]]; then
        print_info "Symlink not found at: $link"
        return 0
    fi

    if [[ ! -L "$link" ]]; then
        print_warning "$link exists and is not a symlink; left untouched"
        return 0
    fi

    target_real="$(_iclaude_realpath "$target")"
    link_real="$(_iclaude_realpath "$link" 2>/dev/null || true)"

    if [[ "$link_real" != "$target_real" ]]; then
        print_warning "$link points elsewhere; left untouched"
        echo "  Current: $link_real"
        echo "  Expected: $target_real"
        return 0
    fi

    rm -f "$link"
    print_success "Removed iclaude symlink: $link"
    return 0
}

install_iclaude_user_launcher() {
    detect_iclaude_isolated_launcher || return 1
    install_iclaude_symlink || return 1
    ensure_iclaude_path_entry
    return 0
}
```

- [ ] **Step 2: Run symlink tests**

```bash
bash tests/test_user_symlink.sh
```

Expected: all tests PASS.

- [ ] **Step 3: Run syntax check**

```bash
bash -n lib/symlink/symlink.sh
bash -n tests/test_user_symlink.sh
```

Expected: no output, exit 0.

- [ ] **Step 4: Commit module**

```bash
git add lib/symlink/symlink.sh tests/test_user_symlink.sh
git commit -m "feat: add user-space iclaude symlink module"
```

---

### Task 3: Wire Symlink Helpers Into Existing Commands

**Files:**
- Modify: `iclaude.sh`
- Modify: `lib/core/remaining.sh`
- Test: `tests/test_user_symlink.sh`

- [ ] **Step 1: Source the new module**

In `iclaude.sh`, after the NVM module block and before lockfile modules, add:

```bash
#######################################
# Load Symlink modules
#######################################
if [[ -d "$LIB_DIR/symlink" ]]; then
    source "${LIB_DIR}/symlink/symlink.sh"
fi
```

- [ ] **Step 2: Wire install/update command branches**

In `iclaude.sh`, update these branches:

```bash
            --isolated-install)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --isolated-install"
                    echo ""
                    echo "The --system flag skips isolated environment, but --isolated-install"
                    echo "is specifically for installing isolated environment."
                    exit 1
                fi
                install_isolated_nvm && \
                    install_isolated_nodejs && \
                    install_isolated_claude && \
                    install_iclaude_user_launcher
                exit $?
                ;;
```

```bash
            --install-from-lockfile)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-from-lockfile"
                    echo ""
                    echo "The --system flag skips isolated environment, but --install-from-lockfile"
                    echo "is specifically for installing isolated environment from lockfile."
                    exit 1
                fi
                install_from_lockfile && install_iclaude_user_launcher
                exit $?
                ;;
```

```bash
            --isolated-update)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --isolated-update"
                    echo ""
                    echo "The --system flag skips isolated environment, but --isolated-update"
                    echo "is specifically for updating Claude Code in isolated environment."
                    exit 1
                fi
                update_isolated_claude && install_iclaude_user_launcher
                exit $?
                ;;
```

- [ ] **Step 3: Delegate `--create-symlink` and `--uninstall-symlink`**

In `lib/core/remaining.sh`, replace the body of `create_symlink_only` with:

```bash
create_symlink_only() {
    echo ""
    print_info "Creating user-space iclaude launcher..."
    echo ""

    if ! declare -F install_iclaude_user_launcher &>/dev/null; then
        print_error "Symlink module is not loaded"
        return 1
    fi

    install_iclaude_user_launcher
}
```

Replace the body of `uninstall_symlink_only` with:

```bash
uninstall_symlink_only() {
    echo ""
    print_info "Removing user-space iclaude launcher..."
    echo ""

    if ! declare -F uninstall_iclaude_symlink &>/dev/null; then
        print_error "Symlink module is not loaded"
        return 1
    fi

    uninstall_iclaude_symlink
}
```

- [ ] **Step 4: Add static wiring checks to symlink test**

Append this block before the final results line in `tests/test_user_symlink.sh`:

```bash
for expected in \
    "source \"\${LIB_DIR}/symlink/symlink.sh\"" \
    "install_isolated_claude &&" \
    "install_from_lockfile && install_iclaude_user_launcher" \
    "update_isolated_claude && install_iclaude_user_launcher" \
    "create_symlink_only()" \
    "uninstall_symlink_only()"; do
    if grep -qF "$expected" "$REPO_ROOT/iclaude.sh" "$REPO_ROOT/lib/core/remaining.sh"; then
        ok "static-wiring-$expected"
    else
        not_ok "static-wiring-$expected" "missing expected wiring"
    fi
done
```

- [ ] **Step 5: Run tests and syntax checks**

```bash
bash tests/test_user_symlink.sh
bash -n iclaude.sh
bash -n lib/core/remaining.sh
bash -n lib/symlink/symlink.sh
```

Expected: all tests PASS; syntax checks produce no output and exit 0.

- [ ] **Step 6: Commit wiring**

```bash
git add iclaude.sh lib/core/remaining.sh tests/test_user_symlink.sh
git commit -m "feat: wire iclaude user symlink commands"
```

---

### Task 4: Update User-Facing Documentation

**Files:**
- Modify: `lib/command/usage.sh`
- Modify: `README.md`
- Modify: `docs/functions/CONFIGURATION.md`
- Modify: `docs/functions/USE_CASES.md`

- [ ] **Step 1: Update usage text**

In `lib/command/usage.sh`, update symlink examples:

```text
  # Create user-space launcher to use 'iclaude' from anywhere
  ./iclaude.sh --create-symlink

  # Use a custom launcher directory
  ICLAUDE_LINK_DIR=~/bin ./iclaude.sh --create-symlink

  # Remove user-space launcher only (keeps isolated environment)
  iclaude --uninstall-symlink
```

Also change the option descriptions:

```text
  --create-symlink                  Create user-space iclaude launcher (default: ~/.local/bin)
  --uninstall-symlink               Remove user-space iclaude launcher only
```

- [ ] **Step 2: Update README isolated environment section**

In `README.md`, change the `--create-symlink` row to:

```markdown
| `--create-symlink` | Создать пользовательский симлинк `iclaude` (`~/.local/bin`, override: `ICLAUDE_LINK_DIR`) |
```

Add this note below the isolated command table:

```markdown
`--isolated-install`, `--isolated-update`, and `--install-from-lockfile` create or repair the user launcher automatically. The default launcher path is `~/.local/bin/iclaude`; set `ICLAUDE_LINK_DIR` to use another directory. Existing non-symlink files are left untouched.
```

- [ ] **Step 3: Update configuration docs**

In `docs/functions/CONFIGURATION.md`, change the rows to:

```markdown
| `--create-symlink` | Создание пользовательского симлинка | ❌ | isolated env |
| `--uninstall-symlink` | Удаление пользовательского симлинка | ❌ | - |
```

- [ ] **Step 4: Update use cases**

In `docs/functions/USE_CASES.md`, replace `sudo ./iclaude.sh --create-symlink` with:

```bash
./iclaude.sh --create-symlink
```

Replace `sudo iclaude --uninstall-symlink` with:

```bash
iclaude --uninstall-symlink
```

Replace `/usr/local/bin/iclaude` checks with:

```bash
ls -la ~/.local/bin/iclaude
```

- [ ] **Step 5: Verify docs no longer advertise sudo for user symlink**

```bash
grep -RIn "sudo .*--create-symlink\|sudo .*--uninstall-symlink\|/usr/local/bin/iclaude" README.md docs/functions lib/command/usage.sh
```

Expected: no output for user-space symlink docs. Mentions in legacy `--install` docs may remain only when they explicitly describe system installation.

- [ ] **Step 6: Commit docs**

```bash
git add lib/command/usage.sh README.md docs/functions/CONFIGURATION.md docs/functions/USE_CASES.md
git commit -m "docs: document user-space iclaude launcher"
```

---

### Task 5: Final Verification and Regression Matrix

**Files:**
- Read: `docs/superpowers/specs/2026-07-04-iclaude-user-symlink-design.md`
- Read: `docs/superpowers/intents/2026-07-04-iclaude-user-symlink-intent.md`
- May modify only if a verification defect is found.

- [ ] **Step 1: Run shell syntax checks**

```bash
find . -path './.git' -prune -o -path './.nvm-isolated' -prune -o -name '*.sh' -type f -print0 | xargs -0 -n1 bash -n
```

Expected: no output, exit 0.

- [ ] **Step 2: Run focused symlink tests**

```bash
bash tests/test_user_symlink.sh
```

Expected: all tests PASS.

- [ ] **Step 3: Run existing launcher regression test**

```bash
bash tests/test-suppress-npx-fallback.sh
```

Expected: all tests PASS.

- [ ] **Step 4: Run config/env regression tests that exercise launch wiring**

```bash
bash tests/test_env_map.sh
bash tests/test_config_migration.sh
bash tests/test_persistent_toggles.sh
```

Expected: all tests PASS.

- [ ] **Step 5: Run integrated feature smoke tests that are local and deterministic**

```bash
bash tests/test_ccr_integration.sh
bash tests/test_pii_integration.sh
bash tests/test_chrome-detection.sh
bash tests/test_statusline_context_window.sh
bash tests/test_project_id_unit.sh
```

Expected: all tests PASS. If a test requires a service that is not available, record the exact skip/failure reason in the final result and verify the unchanged module source with `bash -n`.

- [ ] **Step 6: Run symlink launch smoke test without touching real `~/.local/bin`**

```bash
tmp_home="$(mktemp -d)"
tmp_bin="$(mktemp -d)"
ICLAUDE_LINK_DIR="$tmp_bin" HOME="$tmp_home" ./iclaude.sh --create-symlink
PATH="$tmp_bin:$PATH" HOME="$tmp_home" iclaude --help >/tmp/iclaude-symlink-help.out
grep -q "ISOLATED ENVIRONMENT" /tmp/iclaude-symlink-help.out
rm -rf "$tmp_home" "$tmp_bin"
```

Expected: `iclaude --help` runs through the symlink and prints help text.

- [ ] **Step 7: Verify no-regression matrix**

Record this checklist in the result summary:

```text
Direct launch: bash -n iclaude.sh PASS
Symlink launch: temporary ICLAUDE_LINK_DIR smoke PASS
NVM install/repair: symlink tests + unchanged repair tests PASS
Lockfile install: static wiring PASS
Config isolation: env/config tests PASS
Router: CCR integration test PASS
PII proxy: PII integration test PASS
Statusline: statusline context test PASS
LSP: module syntax PASS
oh-my-posh: module syntax PASS
GSD: module syntax PASS
Sandbox/microVM: module syntax PASS
OAuth: launch module syntax PASS
Chrome: chrome detection test PASS
Command dispatch: static wiring + help smoke PASS
```

- [ ] **Step 8: Commit verification fixes if needed**

If verification reveals a defect, fix it surgically and commit:

```bash
git add lib/symlink/symlink.sh tests/test_user_symlink.sh iclaude.sh lib/core/remaining.sh lib/command/usage.sh README.md docs/functions/CONFIGURATION.md docs/functions/USE_CASES.md
git commit -m "fix: complete iclaude user symlink verification"
```

If no defects are found, do not create an empty commit.

---

## Self-Review

Spec coverage:
- Requirements 1-8 map to Tasks 1-3.
- Requirement 9 maps to Task 3 and Task 4 legacy boundary.
- Requirement 10 maps to Task 5 regression matrix.
- Documentation requirements map to Task 4.
- Non-goals are preserved: parser is not refactored, `/usr/local/bin` legacy support stays, `.nvm-isolated` content changes only through existing install/update/repair flows, integrated modules are not behavior-changed.

Placeholder scan:
- No unresolved placeholders.
- Every code-changing task includes exact file path, exact snippet, command, expected result, and commit command.

Type/signature consistency:
- The functions introduced in Task 2 are the same functions wired in Task 3.
- Test names use the same helper names and environment variables as the implementation.
