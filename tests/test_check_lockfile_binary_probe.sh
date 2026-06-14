#!/bin/bash
# Function-level test for the check_lockfile_changes() version probe.
# Sources lib/lockfile/save.sh, stubs heavy deps, and asserts the bug case:
# binary is old while package.json (tracked) already matches the lockfile.
# Runs non-interactively (stdin from /dev/null) so a mismatch hits the warn-only branch.
set -u

ROOT="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1090
source "$ROOT/lib/lockfile/save.sh"

# Stubs (defined AFTER source so these definitions win).
compute_lockfile_hash() { echo "NEWHASH"; }
update_lockfile_hash()  { echo "UPDATE_HASH_CALLED"; }
install_from_lockfile() { echo "INSTALL_CALLED"; return 0; }
print_warning() { echo "WARN: $*"; }
print_info()    { echo "INFO: $*"; }
print_success() { echo "OK: $*"; }

pass=0; fail=0
assert_contains() { if grep -qF "$2" <<<"$1"; then echo "ok: $3"; pass=$((pass+1));
  else echo "FAIL: $3"; echo "--- output ---"; echo "$1"; echo "---"; fail=$((fail+1)); fi; }
assert_absent()   { if grep -qF "$2" <<<"$1"; then echo "FAIL: $3"; echo "--- output ---"; echo "$1"; echo "---"; fail=$((fail+1));
  else echo "ok: $3"; pass=$((pass+1)); fi; }

# setup_case <lockver> <pkgver> <binver>
setup_case() {
  local lockver="$1" pkgver="$2" binver="$3" dir pkgdir
  dir="$(mktemp -d)"
  ISOLATED_LOCKFILE="$dir/lockfile.json"
  printf '{"claudeCodeVersion":"%s"}\n' "$lockver" > "$ISOLATED_LOCKFILE"
  LOCKFILE_HASH_FILE="$dir/.last-lockfile-hash"
  echo "OLDHASH" > "$LOCKFILE_HASH_FILE"          # != NEWHASH → the "changed" gate passes
  ISOLATED_NVM_DIR="$dir/.nvm-isolated"
  pkgdir="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code"
  mkdir -p "$pkgdir"
  printf '{"version":"%s"}\n' "$pkgver" > "$pkgdir/package.json"   # tracked file — the trap
  mkdir -p "$ISOLATED_NVM_DIR/npm-global/bin"
  printf '#!/bin/bash\necho "%s (Claude Code)"\n' "$binver" \
    > "$ISOLATED_NVM_DIR/npm-global/bin/claude"
  chmod +x "$ISOLATED_NVM_DIR/npm-global/bin/claude"
}

# Case 1 (the bug): lockfile=9.9.9, package.json=9.9.9 (matches), real binary=1.0.0 (old).
#   OLD code reads package.json → "in sync" → NO warn  (this assertion FAILS pre-fix).
#   NEW code reads the binary   → mismatch  → warn.
setup_case "9.9.9" "9.9.9" "1.0.0"
out="$(check_lockfile_changes </dev/null 2>&1)"
assert_contains "$out" "Lockfile has changed" "old binary (pkg.json matches) reaches warn"
assert_absent  "$out" "INSTALL_CALLED"        "non-interactive mismatch does not auto-install"

# Case 2 (regression): everything 9.9.9 incl. the binary → no warn, hash refreshed.
setup_case "9.9.9" "9.9.9" "9.9.9"
out="$(check_lockfile_changes </dev/null 2>&1)"
assert_absent  "$out" "Lockfile has changed" "in-sync binary stays silent"
assert_contains "$out" "UPDATE_HASH_CALLED"   "in-sync refreshes the stored hash"

echo "---"; echo "pass=$pass fail=$fail"
[[ "$fail" -eq 0 ]]
