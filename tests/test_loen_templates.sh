#!/usr/bin/env bash
# All durable templates exist and carry their required section headings + sentinels.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
t="$repo_root/plugin/loen/assets/templates"
fail(){ echo "FAIL: $1" >&2; exit 1; }
for f in 1_goal 2_context 3_plan 4_act 5_check 6_reflect 7_result; do
  [[ -f "$t/$f.md" ]] || fail "missing $f.md"
done
for f in loop.yaml handoff.md audit.html; do [[ -f "$t/$f" ]] || fail "missing $f"; done
grep -q "## User Request" "$t/1_goal.md" || fail "1_goal missing User Request"
grep -q "## Success Criteria" "$t/1_goal.md" || fail "1_goal missing Success Criteria"
grep -q "## Facts" "$t/2_context.md" || fail "2_context missing Facts"
grep -q "## Steps" "$t/3_plan.md" || fail "3_plan missing Steps"
grep -q "## Checks" "$t/3_plan.md" || fail "3_plan missing Checks"
grep -q "## Changed Paths" "$t/4_act.md" || fail "4_act missing Changed Paths"
grep -q "## Result" "$t/5_check.md" || fail "5_check missing Result"
grep -q "PASS" "$t/5_check.md" || fail "5_check missing PASS sentinel"
grep -q "## Decision" "$t/6_reflect.md" || fail "6_reflect missing Decision"
grep -q "## Outcome" "$t/7_result.md" || fail "7_result missing Outcome"
grep -q "Done" "$t/7_result.md" || fail "7_result missing Done sentinel"
grep -q "^topic:" "$t/loop.yaml" || fail "loop.yaml missing topic"
grep -q "^status:" "$t/loop.yaml" || fail "loop.yaml missing status"
grep -q "^run:" "$t/loop.yaml" || fail "loop.yaml missing run block"
echo "PASS test_loen_templates.sh"
