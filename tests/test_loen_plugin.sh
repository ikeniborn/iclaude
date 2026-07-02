#!/usr/bin/env bash
# Validate the loen plugin manifest + marketplace registration.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $1" >&2; exit 1; }

pj="plugin/loen/.claude-plugin/plugin.json"
mj=".claude-plugin/marketplace.json"

[[ -f "$pj" ]] || fail "missing $pj"

python3 - "$pj" "$mj" <<'PY'
import json, sys
pj, mj = sys.argv[1], sys.argv[2]
p = json.load(open(pj))
assert p.get("name") == "loen", f"plugin name != loen: {p.get('name')}"
assert p.get("version"), "plugin.json missing version"
for k in ("description", "author", "license"):
    assert p.get(k), f"plugin.json missing {k}"
m = json.load(open(mj))
entry = next((x for x in m.get("plugins", []) if x.get("name") == "loen"), None)
assert entry, "loen not registered in marketplace.json"
assert entry.get("source") == "./plugin/loen", f"bad source: {entry.get('source')}"
assert entry.get("version") == p["version"], (
    f"version mismatch: marketplace {entry.get('version')} != plugin {p['version']}")
print("OK plugin manifest + marketplace registration")
PY
echo "PASS test_loen_plugin.sh"
