#!/usr/bin/env bash
# Validate the loen plugin manifest, marketplace registration, and the full
# stage-oriented durable-topic asset set (13 skills, 5 agents, 9 hook modules).
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

pj="plugin/loen/.claude-plugin/plugin.json"
mj=".claude-plugin/marketplace.json"
[[ -f "$pj" ]] || fail "missing $pj"

python3 - "$pj" "$mj" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
assert p.get("name") == "loen", f"plugin name != loen: {p.get('name')}"
assert p.get("version") == "1.0.0", f"plugin version must be 1.0.0, got {p.get('version')}"
for k in ("description", "author", "license"):
    assert p.get(k), f"plugin.json missing {k}"
m = json.load(open(sys.argv[2]))
entry = next((x for x in m.get("plugins", []) if x.get("name") == "loen"), None)
assert entry, "loen not registered in marketplace.json"
assert entry.get("source") == "./plugin/loen", f"bad source: {entry.get('source')}"
assert entry.get("version") == p["version"], (
    f"version mismatch: marketplace {entry.get('version')} != plugin {p['version']}")
print("OK plugin manifest + marketplace registration @ 1.0.0")
PY

# --- 13 skills ---
for s in loop-start loop-run loop-plan loop-act loop-check loop-reflect loop-status \
         loop-delivery loop-repair loop-autoresearch loop-review governance audit; do
  [[ -f "plugin/loen/skills/$s/SKILL.md" ]] || fail "missing skill $s"
done
[[ -e plugin/loen/skills/loop-goal ]] && fail "loop-goal not removed"

# --- 5 agents (read-only subagents; worker is the main session) ---
for a in explorer planner verifier reviewer researcher; do
  [[ -f "plugin/loen/agents/$a.md" ]] || fail "missing agent $a"
done

# --- shared library + 6 hooks ---
for h in loen_common loen_artifacts loen_capsules \
         loop-gate scope-guard tool-guard permission-guard evidence-gate audit-writer; do
  [[ -f "plugin/loen/hooks/$h.py" ]] || fail "missing hook module $h"
done
[[ -e plugin/loen/hooks/loop-guard.py ]] && fail "loop-guard.py not removed"

echo "PASS test_loen_plugin.sh"
