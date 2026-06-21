#!/usr/bin/env bash
# L1 — unit test for the Langfuse-capture launcher helper `_should_start_proxy`
# and the widened `_init_project_id` activation.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

_extract() {
    awk -v fn="$1" '
        $0 ~ "^"fn"\\(\\)" { in_fn=1 }
        in_fn { print }
        in_fn && /^}/ { in_fn=0 }
    ' "$ROOT/lib/launcher/launch.sh"
}
eval "$(_extract _derive_project_id)"
eval "$(_extract _init_project_id)"
eval "$(_extract _should_start_proxy)"
eval "$(_extract _proxy_masking_default)"
eval "$(_extract _should_capture)"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' want '$2'"; fi; }

# _should_start_proxy <use_pii_proxy> <use_langfuse_capture> -> rc 0 (start) / 1 (no)
_should_start_proxy "true"  "false"; assert_eq "$?" "0" "pii only → start"
_should_start_proxy "false" "true";  assert_eq "$?" "0" "capture only → start"
_should_start_proxy "true"  "true";  assert_eq "$?" "0" "both → start"
_should_start_proxy "false" "false"; assert_eq "$?" "1" "neither → no start"

# _proxy_masking_default <use_pii_proxy> <current_level> -> echoes level to force ('off') or empty
assert_eq "$(_proxy_masking_default "false" "")"        "off" "capture-only → default off"
assert_eq "$(_proxy_masking_default "true"  "")"        ""    "pii-proxy on → no forced level"
assert_eq "$(_proxy_masking_default "false" "secrets")" ""    "explicit level honored"

# _should_capture <USE_LANGFUSE_CAPTURE> <use_router> -> rc 0 (capture) / 1 (no). R6: router mode suppresses capture.
_should_capture "true"  "false"; assert_eq "$?" "0" "capture on, not router → capture"
_should_capture "true"  "true";  assert_eq "$?" "1" "capture on but router → suppressed (no double traces)"
_should_capture "false" "false"; assert_eq "$?" "1" "capture off → no capture"
_should_capture "false" "true";  assert_eq "$?" "1" "capture off + router → no capture"

# _init_project_id widened: capture mode exports the id even when not routing.
EXP=$(_derive_project_id "$ROOT")
out=$( cd "$ROOT" && unset ICLAUDE_PROJECT_ID; _init_project_id "false" "true"; bash -c 'printf "%s" "${ICLAUDE_PROJECT_ID:-}"' )
assert_eq "$out" "$EXP" "init exports id in capture mode (router=false, capture=true)"
out=$( cd "$ROOT" && unset ICLAUDE_PROJECT_ID; _init_project_id "false" "false"; bash -c 'printf "%s" "${ICLAUDE_PROJECT_ID:-}"' )
assert_eq "$out" "" "init no-op when neither router nor capture"

# Invariant guard (F-002): the forced-masking export must precede every proxy fork in
# source order, so a capture-only session always forks with the level already resolved.
LAUNCH="$ROOT/lib/launcher/launch.sh"
_export_line=$(grep -n 'export PII_PROXY_MASKING_LEVEL="\$_mdef"' "$LAUNCH" | head -1 | cut -d: -f1)
# Match real invocations (call with a quoted arg), not the function def or comments.
_first_fork=$(grep -nE 'start_pii_proxy_server "' "$LAUNCH" | head -1 | cut -d: -f1)
if [[ -n "$_export_line" && -n "$_first_fork" && "$_export_line" -lt "$_first_fork" ]]; then
    PASS=$((PASS+1))
else
    FAIL=$((FAIL+1)); echo "FAIL [masking export precedes first proxy fork]: export@${_export_line:-none} fork@${_first_fork:-none}"
fi

echo "L1 langfuse-launch: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
