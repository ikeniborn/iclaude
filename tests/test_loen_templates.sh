#!/usr/bin/env bash
# The loop.yaml template must parse as YAML and carry the required contract keys.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

tpl="plugin/loen/skills/loop-delivery/assets/loop.template.yaml"
[[ -f "$tpl" ]] || fail "missing $tpl"

python3 - "$tpl" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
required = ["name","mode","objective","context_sources","mutable_scope","protected_scope",
           "quality_gates","metrics","budget","stop_conditions","handoff_conditions",
           "rollback_policy","logging"]
missing = [k for k in required if k not in d]
assert not missing, f"loop.template.yaml missing keys: {missing}"
assert isinstance(d["mutable_scope"], list) and isinstance(d["protected_scope"], list)
assert isinstance(d["budget"], dict) and "max_iterations" in d["budget"]
print("OK loop.template.yaml schema")
PY
echo "PASS test_loen_templates.sh"
