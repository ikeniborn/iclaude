#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
j="$repo_root/plugin/loen/hooks/hooks.json"
[[ -f "$j" ]] || { echo "FAIL: no hooks.json" >&2; exit 1; }
python3 - "$j" <<'PY' || { echo "FAIL: hooks.json wiring incorrect" >&2; exit 1; }
import json, sys
d = json.load(open(sys.argv[1]))["hooks"]
pre = d["PreToolUse"][0]["hooks"]
cmds = " ".join(h["command"] for h in pre)
for want in ("loop-gate", "scope-guard", "tool-guard", "permission-guard"):
    assert want in cmds, f"PreToolUse missing {want}"
assert "Stop" in d and any("evidence-gate" in h["command"] for g in d["Stop"] for h in g["hooks"])
assert "PostToolUse" in d and any("audit-writer" in h["command"] for g in d["PostToolUse"] for h in g["hooks"])
print("wiring OK")
PY
[[ -f "$repo_root/plugin/loen/hooks/loop-guard.py" ]] && { echo "FAIL: loop-guard.py still present" >&2; exit 1; }
echo "PASS test_loen_hooks_wiring.sh"
