#!/usr/bin/env bash
# Unit tests for the shared-asset symlink layer (lib/config/isolated.sh, S2 slice):
# link_shared_assets + its wiring into setup_claude_home.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WARNINGS=""
print_info()    { :; }
print_warning() { WARNINGS+="$*"$'\n'; }
print_error()   { :; }

source "$ROOT/lib/config/env-map.sh"
source "$ROOT/lib/config/isolated.sh"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }
assert_true() { if eval "$1"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$2]"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Fake store with a subset of managed entries (commands/, agents/ deliberately absent).
STORE="$TMP/store"
mkdir -p "$STORE/skills/demo" "$STORE/hooks" "$STORE/mcp" "$STORE/plugins" "$STORE/scripts"
echo "guidance" > "$STORE/CLAUDE.md"
echo '{}' > "$STORE/.credentials.json"
echo '{}' > "$STORE/router.json"

HOME_DIR="$TMP/home"
mkdir -p "$HOME_DIR"

# --- fresh home: links created for every existing store entry ---
link_shared_assets "$HOME_DIR" "$STORE"; rc=$?
assert_eq "$rc" "0" "link: exit 0 on fresh home"
for e in skills hooks mcp plugins scripts CLAUDE.md .credentials.json router.json; do
  assert_true '[[ -L "$HOME_DIR/'"$e"'" && "$(readlink "$HOME_DIR/'"$e"'")" == "$STORE/'"$e"'" ]]' "link: $e linked to store"
done

# --- absent store entries are skipped without error, no dangling link ---
assert_true '[[ ! -e "$HOME_DIR/commands" && ! -L "$HOME_DIR/commands" ]]' "link: absent commands skipped"
assert_true '[[ ! -e "$HOME_DIR/agents" && ! -L "$HOME_DIR/agents" ]]' "link: absent agents skipped"

# --- correct link untouched, idempotent second run ---
link_shared_assets "$HOME_DIR" "$STORE"
assert_eq "$(readlink "$HOME_DIR/skills")" "$STORE/skills" "link: idempotent rerun keeps target"

# --- wrong-target link repaired ---
rm "$HOME_DIR/hooks"; ln -s "$TMP/elsewhere" "$HOME_DIR/hooks"
link_shared_assets "$HOME_DIR" "$STORE"
assert_eq "$(readlink "$HOME_DIR/hooks")" "$STORE/hooks" "repair: wrong target relinked"

# --- materialized real dir replaced with link + warning (anti-de-share guard) ---
rm "$HOME_DIR/skills"; mkdir -p "$HOME_DIR/skills/local"
WARNINGS=""
link_shared_assets "$HOME_DIR" "$STORE"
assert_eq "$(readlink "$HOME_DIR/skills")" "$STORE/skills" "guard: materialized dir relinked"
assert_true '[[ -n "$WARNINGS" ]]' "guard: repair logged a warning"

# --- stale link to a removed store entry is pruned ---
ln -s "$STORE/commands" "$HOME_DIR/commands"
link_shared_assets "$HOME_DIR" "$STORE"
assert_true '[[ ! -L "$HOME_DIR/commands" ]]' "prune: stale link removed"

# --- late-appearing store entry gets linked on a later run ---
mkdir -p "$STORE/commands"
link_shared_assets "$HOME_DIR" "$STORE"
assert_eq "$(readlink "$HOME_DIR/commands")" "$STORE/commands" "late: new store entry linked"

# --- real path with a managed name but no store counterpart is left alone ---
mkdir -p "$HOME_DIR/agents"
link_shared_assets "$HOME_DIR" "$STORE"
assert_true '[[ -d "$HOME_DIR/agents" && ! -L "$HOME_DIR/agents" ]]' "safety: real dir without store counterpart untouched"
rm -rf "$HOME_DIR/agents"

# --- store is never mutated by the linking path ---
before="$(find "$STORE" | sort | sha256sum)"
link_shared_assets "$HOME_DIR" "$STORE"
assert_eq "$(find "$STORE" | sort | sha256sum)" "$before" "safety: store tree unchanged"

# --- integration: setup_claude_home links shared assets from ISOLATED_CONFIG_DIR ---
mkdir -p "$TMP/repoB"; git -C "$TMP/repoB" init -q
out="$(
  cd "$TMP/repoB" || exit 1
  ISOLATED_HOMES_DIR="$TMP/homes" ISOLATED_CONFIG_DIR="$STORE" setup_claude_home >/dev/null 2>&1 || exit 1
  readlink "$CLAUDE_CONFIG_DIR/skills"
)"
assert_eq "$out" "$STORE/skills" "integration: setup_claude_home wires links"

# --- shared mode: no links appear in the shared config dir ---
out="$(
  unset ICLAUDE_HOME_MODE
  ISOLATED_NVM_DIR="$TMP/nvm" setup_isolated_config >/dev/null 2>&1 || exit 1
  find "$TMP/nvm/.claude-isolated" -maxdepth 1 -type l | wc -l
)"
assert_eq "$out" "0" "shared: no symlinks created in shared dir"

echo "shared-asset-links: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
