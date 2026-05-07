#!/usr/bin/env bash
# Apply iclaude portability patches to vendored graphifyy.
# Idempotent — skips files already patched (marker comment ICLAUDE-PATCHED-v1).
# Best-effort — degrades gracefully if patch fails (warns, continues).

set -uo pipefail

MARKER="ICLAUDE-PATCHED-v1"

# Resolve graphify package dir (override via env for tests)
if [[ -n "${GRAPHIFY_PKG_OVERRIDE:-}" ]]; then
    GRAPHIFY_PKG="$GRAPHIFY_PKG_OVERRIDE"
else
    GRAPHIFY_PKG="${ISOLATED_NVM_DIR:-}/.claude-isolated/graphify/graphifyy/lib/python3.12/site-packages/graphify"
fi

PATCHES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patches"

if [[ ! -d "$GRAPHIFY_PKG" ]]; then
    echo "apply_patches: graphifyy not installed at $GRAPHIFY_PKG (skip)" >&2
    exit 0
fi

if [[ ! -d "$PATCHES_DIR" ]]; then
    echo "apply_patches: patches dir not found: $PATCHES_DIR (skip)" >&2
    exit 0
fi

applied=0
skipped=0
failed=0

for patch_file in "$PATCHES_DIR"/*.patch; do
    [[ -f "$patch_file" ]] || continue

    target_file=$(grep -m1 '^+++ b/' "$patch_file" | sed 's|^+++ b/||')
    if [[ -z "$target_file" ]]; then
        echo "apply_patches: cannot parse target from $(basename "$patch_file")" >&2
        ((failed++))
        continue
    fi

    target_path="$GRAPHIFY_PKG/$target_file"
    if [[ ! -f "$target_path" ]]; then
        echo "apply_patches: target missing: $target_path (skip)" >&2
        ((skipped++))
        continue
    fi

    if grep -q "$MARKER" "$target_path" 2>/dev/null; then
        ((skipped++))
        continue
    fi

    if ! patch -p1 --dry-run -d "$GRAPHIFY_PKG" < "$patch_file" >/dev/null 2>&1; then
        echo "apply_patches: dry-run failed for $(basename "$patch_file") (graphifyy upstream may have changed)" >&2
        ((failed++))
        continue
    fi

    if patch -p1 -d "$GRAPHIFY_PKG" < "$patch_file" >/dev/null 2>&1; then
        echo "apply_patches: applied $(basename "$patch_file")"
        ((applied++))
    else
        echo "apply_patches: failed to apply $(basename "$patch_file")" >&2
        ((failed++))
    fi
done

echo "apply_patches: applied=$applied skipped=$skipped failed=$failed"
exit 0
