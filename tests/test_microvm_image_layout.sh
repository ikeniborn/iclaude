#!/usr/bin/env bash
# Unit tests for S4: the microVM nvm image is now populated from two host trees —
# the nvm tree and the relocated shared store — while the guest layout stays
# /mnt/nvm/.claude-isolated.
#
# The exclude arrays are extracted from lib/sandbox/install.sh rather than copied,
# so the test tracks the source. The passes run into a plain directory: the ext4
# image, loop mount and sudo add nothing to the layout being asserted.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/lib/sandbox/install.sh"

PASS=0; FAIL=0
assert_true() { if eval "$1"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$2]"; fi; }
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }

if ! command -v rsync &>/dev/null; then
  echo "microvm-image-layout: SKIP (rsync not installed)"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- pull the two exclude lists out of _create_microvm_nvm_image ---
eval "$(awk '/^\tlocal _nvm_excludes=\(/,/^\t\)/' "$SRC" | sed 's/^\tlocal //')"
eval "$(awk '/^\tlocal _store_excludes=\(/,/^\t\)/' "$SRC" | sed 's/^\tlocal //')"
assert_true '[[ "${#_nvm_excludes[@]}" -gt 0 ]]' "extract: nvm exclude list found"
assert_true '[[ "${#_store_excludes[@]}" -gt 0 ]]' "extract: store exclude list found"
assert_true '[[ ! "${_store_excludes[*]}" == *".claude-isolated/"* ]]' \
  "extract: store patterns are relative to the store root, not prefixed"

# --- build host sources: an nvm tree and a store that is NOT inside it ---
NVM="$TMP/.nvm-isolated"
STORE="$TMP/.claude-isolated"
mkdir -p "$NVM/npm-global/bin" "$NVM/versions/node/v22/bin" "$NVM/versions/node/v22/include" "$NVM/.npm"
echo 'claude' > "$NVM/npm-global/bin/claude"
echo 'node' > "$NVM/versions/node/v22/bin/node"
echo 'header' > "$NVM/versions/node/v22/include/node.h"
echo 'npm cache' > "$NVM/.npm/cache-entry"
mkdir -p "$STORE/skills/demo" "$STORE/hooks" "$STORE/bin" "$STORE/projects/p1" \
         "$STORE/pii-proxy-venv/lib" "$STORE/file-history" "$STORE/ssh" "$STORE/session-env" \
         "$STORE/microvm-snapshots" "$STORE/backups"
echo '{"model":"opus"}' > "$STORE/settings.json"
echo 'SKILL' > "$STORE/skills/demo/SKILL.md"
echo 'hook' > "$STORE/hooks/h.py"
head -c 2048 /dev/zero > "$STORE/bin/nvm.img"
echo 'transcript' > "$STORE/projects/p1/session.jsonl"
echo 'venv' > "$STORE/pii-proxy-venv/lib/pyvenv.cfg"
echo 'history' > "$STORE/file-history/entry"
echo 'private-key' > "$STORE/ssh/microvm"
echo 'env' > "$STORE/session-env/sess"
echo 'snap' > "$STORE/microvm-snapshots/s1"
echo 'backup' > "$STORE/backups/b1"

# --- run the two passes in the order the source uses them ---
IMG="$TMP/image-root"; mkdir -p "$IMG"
rsync -aq --delete "${_nvm_excludes[@]}" "$NVM/" "$IMG/" \
  || { echo "FAIL [rsync: nvm pass]"; FAIL=$((FAIL+1)); }
rsync -aq --delete "${_store_excludes[@]}" "$STORE/" "$IMG/.claude-isolated/" \
  || { echo "FAIL [rsync: store pass]"; FAIL=$((FAIL+1)); }

# --- guest layout: the store lands where the guest expects it ---
assert_true '[[ -d "$IMG/.claude-isolated" ]]' "guest: .claude-isolated present at the image root"
assert_eq "$(cat "$IMG/.claude-isolated/settings.json")" '{"model":"opus"}' "guest: settings.json copied"
assert_eq "$(cat "$IMG/.claude-isolated/skills/demo/SKILL.md")" "SKILL" "guest: skills copied"
assert_eq "$(cat "$IMG/.claude-isolated/hooks/h.py")" "hook" "guest: hooks copied"

# --- nvm tree still complete, and its own excludes still applied ---
assert_eq "$(cat "$IMG/npm-global/bin/claude")" "claude" "nvm: claude binary copied"
assert_eq "$(cat "$IMG/versions/node/v22/bin/node")" "node" "nvm: node binary copied"
assert_true '[[ ! -e "$IMG/versions/node/v22/include" ]]' "nvm: node headers excluded"
assert_true '[[ ! -e "$IMG/.npm" ]]' "nvm: npm cache excluded"

# --- host-specific store dirs stay out of the image ---
for d in bin projects pii-proxy-venv file-history ssh session-env microvm-snapshots backups; do
  assert_true '[[ ! -e "$IMG/.claude-isolated/'"$d"'" ]]' "store: $d excluded"
done

# --- ordering: the nvm pass runs --delete against the image root, so a store pass
#     placed before it would be wiped. Assert the source keeps the store pass second.
nvm_line=$(grep -n '"\$nvm_src/" "\$mnt_tmp/"' "$SRC" | head -1 | cut -d: -f1)
store_line=$(grep -n '"\$store_src/" "\$mnt_tmp/\.claude-isolated/"' "$SRC" | head -1 | cut -d: -f1)
assert_true '[[ -n "$nvm_line" && -n "$store_line" && "$store_line" -gt "$nvm_line" ]]' \
  "ordering: the store pass follows the nvm pass in the source"

# --- rebuilding over an existing image root is stable ---
rsync -aq --delete "${_nvm_excludes[@]}" "$NVM/" "$IMG/" >/dev/null 2>&1
rsync -aq --delete "${_store_excludes[@]}" "$STORE/" "$IMG/.claude-isolated/" >/dev/null 2>&1
assert_eq "$(cat "$IMG/.claude-isolated/settings.json")" '{"model":"opus"}' "rebuild: store survives a second build"
assert_eq "$(cat "$IMG/npm-global/bin/claude")" "claude" "rebuild: nvm tree survives a second build"

# --- the guest config bootstrap still reads the frozen guest path ---
assert_true 'grep -q "/mnt/nvm/.claude-isolated" "$ROOT/lib/sandbox/microvm.sh"' \
  "guest contract: microvm.sh still reads /mnt/nvm/.claude-isolated"

echo "microvm-image-layout: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
