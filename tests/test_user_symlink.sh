#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass=0
fail=0

RED=""
GREEN=""
YELLOW=""
BLUE=""
NC=""

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
    export FIXTURE_ROOT="$root"
    export HOME="$root/home"
    export SCRIPT_DIR="$root/repo"
    export ISOLATED_NVM_DIR="$SCRIPT_DIR/.nvm-isolated"
    export ICLAUDE_LINK_DIR=""
    export PATH="/usr/bin:/bin"
    export SHELL="/bin/bash"
    mkdir -p "$HOME" "$SCRIPT_DIR"
    printf '#!/usr/bin/env bash\necho iclaude test\n' > "$SCRIPT_DIR/iclaude.sh"
    chmod +x "$SCRIPT_DIR/iclaude.sh"
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

new_fixture
root="$FIXTURE_ROOT"
add_native_claude
install_iclaude_symlink
assert_symlink_target "default-link-target" "$HOME/.local/bin/iclaude" "$SCRIPT_DIR/iclaude.sh"
rm -rf "$root"

new_fixture
root="$FIXTURE_ROOT"
add_native_claude
mkdir -p "$HOME/.local/bin" "$root/other"
ln -s "$root/other/iclaude.sh" "$HOME/.local/bin/iclaude"
install_iclaude_symlink
assert_symlink_target "repair-stale-symlink" "$HOME/.local/bin/iclaude" "$SCRIPT_DIR/iclaude.sh"
rm -rf "$root"

new_fixture
root="$FIXTURE_ROOT"
add_native_claude
mkdir -p "$HOME/.local/bin"
printf 'real file\n' > "$HOME/.local/bin/iclaude"
install_iclaude_symlink
assert_eq "non-symlink-left-untouched" "real file" "$(cat "$HOME/.local/bin/iclaude")"
rm -rf "$root"

new_fixture
root="$FIXTURE_ROOT"
add_native_claude
export ICLAUDE_LINK_DIR="~/custom-bin"
install_iclaude_symlink
assert_symlink_target "tilde-link-dir" "$HOME/custom-bin/iclaude" "$SCRIPT_DIR/iclaude.sh"
rm -rf "$root"

new_fixture
root="$FIXTURE_ROOT"
add_native_claude
ensure_iclaude_path_entry
ensure_iclaude_path_entry
assert_eq "bash-path-once" "1" "$(grep -c 'added by iclaude' "$HOME/.bashrc")"
rm -rf "$root"

new_fixture
root="$FIXTURE_ROOT"
add_native_claude
export SHELL="/bin/zsh"
ensure_iclaude_path_entry
ensure_iclaude_path_entry
assert_eq "zsh-path-once" "1" "$(grep -c 'added by iclaude' "$HOME/.zshrc")"
rm -rf "$root"

new_fixture
root="$FIXTURE_ROOT"
add_native_claude
export SHELL="/usr/bin/fish"
ensure_iclaude_path_entry
ensure_iclaude_path_entry
assert_eq "fish-path-once" "1" "$(grep -c 'added by iclaude' "$HOME/.config/fish/config.fish")"
rm -rf "$root"

new_fixture
root="$FIXTURE_ROOT"
add_native_claude
detect_iclaude_isolated_launcher
ok "detect-native-claude-exe"
rm -rf "$root"

new_fixture
root="$FIXTURE_ROOT"
add_bin_claude
detect_iclaude_isolated_launcher
ok "detect-npm-global-bin-claude"
rm -rf "$root"

new_fixture
root="$FIXTURE_ROOT"
add_legacy_cli
detect_iclaude_isolated_launcher
ok "detect-legacy-cli-js"
rm -rf "$root"

new_fixture
root="$FIXTURE_ROOT"
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

new_fixture
root="$FIXTURE_ROOT"
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
