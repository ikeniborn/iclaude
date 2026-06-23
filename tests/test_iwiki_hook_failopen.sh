#!/usr/bin/env bash
# Verify the iwiki plugin hook commands fail OPEN when the hook script is
# missing or crashes, while preserving an intentional exit-2 block and any
# stdout-based decision. Exercises the REAL command strings in hooks.json.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_JSON="$REPO_ROOT/plugin/iwiki/hooks/hooks.json"
OUT="$(mktemp)"
fail=0

# Print the hook command whose string contains the given script basename.
get_cmd() {
  python3 - "$HOOKS_JSON" "$1" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
needle = sys.argv[2]
for event in data.get("hooks", {}).values():
    for group in event:
        for h in group.get("hooks", []):
            cmd = h.get("command", "")
            if needle in cmd:
                print(cmd)
                sys.exit(0)
sys.exit(1)
PY
}

# Run a command string with CLAUDE_PLUGIN_ROOT=$2 and stdin=$3; stdout -> $OUT.
run_cmd() {
  CLAUDE_PLUGIN_ROOT="$2" sh -c "$1" <<<"$3" >"$OUT" 2>/dev/null
}

assert_exit() {
  if [ "$3" = "$2" ]; then
    echo "PASS: $1 (exit $3)"
  else
    echo "FAIL: $1 — want exit $2, got $3"; fail=1
  fi
}

CMD="$(get_cmd iwiki-validate.py)" || { echo "FAIL: no validate command in hooks.json"; exit 1; }
PAYLOAD='{"tool_name":"Write","tool_input":{"file_path":"docs/wiki/x.md","content":"# T\n\n## A\n"}}'

# 1) Missing script -> allow (exit 0). Core regression for the reported bug.
EMPTY="$(mktemp -d)"; mkdir -p "$EMPTY/hooks"
run_cmd "$CMD" "$EMPTY" "$PAYLOAD"; assert_exit "missing script -> allow" 0 "$?"

# 2) Present script that exits 2 (real block) -> exit 2 preserved.
BLOCK="$(mktemp -d)"; mkdir -p "$BLOCK/hooks"
cat > "$BLOCK/hooks/iwiki-validate.py" <<'PY'
import sys
sys.exit(2)
PY
run_cmd "$CMD" "$BLOCK" "$PAYLOAD"; assert_exit "present + exit 2 -> block" 2 "$?"

# 3) Present script that crashes (exit 1) -> allow (exit 0).
CRASH="$(mktemp -d)"; mkdir -p "$CRASH/hooks"
cat > "$CRASH/hooks/iwiki-validate.py" <<'PY'
import sys
sys.exit(1)
PY
run_cmd "$CMD" "$CRASH" "$PAYLOAD"; assert_exit "present + crash -> allow" 0 "$?"

# 4) Present script that prints stdout JSON and exits 0 -> allow + stdout kept.
OKDIR="$(mktemp -d)"; mkdir -p "$OKDIR/hooks"
cat > "$OKDIR/hooks/iwiki-validate.py" <<'PY'
print('{"decision":"block"}')
PY
run_cmd "$CMD" "$OKDIR" "$PAYLOAD"; assert_exit "present + stdout json -> allow" 0 "$?"
if grep -q '"decision":"block"' "$OUT"; then
  echo "PASS: stdout passed through"
else
  echo "FAIL: stdout not passed through"; fail=1
fi

# 5) Every one of the five hook commands carries the guard.
for s in iwiki-bootstrap.py iwiki-recall.py iwiki-validate.py iwiki-reindex.py iwiki-sync.py; do
  c="$(get_cmd "$s")" || { echo "FAIL: no command for $s"; fail=1; continue; }
  case "$c" in
    *'[ -f '*' ] || exit 0'*) echo "PASS: $s guarded" ;;
    *) echo "FAIL: $s not guarded: $c"; fail=1 ;;
  esac
done

rm -rf "$EMPTY" "$BLOCK" "$CRASH" "$OKDIR" "$OUT"
if [ "$fail" = 0 ]; then echo "ALL PASS"; exit 0; else echo "SOME FAILED"; exit 1; fi
