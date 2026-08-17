#!/usr/bin/env bash
# tests/test-idd-gate.sh — тесты IDD→SDD chain gate (hooks/chain-gate.py).
# Запускать из корня проекта iclaude: ./tests/test-idd-gate.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/.nvm-isolated/.claude-isolated/hooks/chain-gate.py"
PASS=0; FAIL=0
pass(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
fail(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }

# Канонический хеш тела — ТОТ ЖЕ пайплайн, что у валидаторов и хука.
bodyhash(){ awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$1" | sha256sum | cut -c1-16; }

SID_A='sess-A'; SID_B='sess-B'

# write_json file content [sid] ; edit_json tool file [sid]  (sid defaults to SID_A)
write_json(){ printf '{"session_id":"%s","tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' "${3:-$SID_A}" "$1" "$2"; }
edit_json(){  printf '{"session_id":"%s","tool_name":"%s","tool_input":{"file_path":"%s"}}' "${3:-$SID_A}" "$1" "$2"; }

# seed_owner root relpath sid — record ownership in the temp-root ledger.
seed_owner(){
  python3 - "$1/state/idd-sessions.json" "$1/$2" "$3" <<'PY'
import json, os, sys, time
ledger, artifact, sid = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(os.path.dirname(ledger), exist_ok=True)
data = {}
if os.path.exists(ledger):
    try:
        with open(ledger) as f: data = json.load(f)
    except Exception: data = {}
data[os.path.abspath(artifact)] = {"session": sid, "ts": int(time.time())}
with open(ledger, "w") as f: json.dump(data, f)
PY
}

# Запускает хук в указанном project-root с изолированным ledger; печатает exit code.
run(){ ( cd "$1" && printf '%s' "$2" | CLAUDE_CONFIG_DIR="$1" python3 "$HOOK" >/dev/null 2>&1; echo $? ); }

assert_exit(){ # label cwd json expected
  local got; got=$(run "$2" "$3")
  if [[ "$got" == "$4" ]]; then pass "$1"; else fail "$1 (exit=$got, ожидался $4)"; fi
}

# ── fixtures ────────────────────────────────────────────────────────────
# Хеш считается с PLACEHOLDER в frontmatter, затем подставляется sed'ом:
# тело (всё после 2-го '---') не меняется, поэтому хеш остаётся валидным.
# Каждый mk_* регистрирует владение артефактом за $SID_A в ledger temp-root.

mk_spec_passed(){ # root → валидная пройденная спека (writing-plans → allow)
  local d="$1/docs/superpowers/specs"; mkdir -p "$d"
  local f="$d/2026-06-14-fix-design.md"
  cat > "$f" <<'EOF'
---
review:
  spec_hash: PLACEHOLDER
  last_run: 2026-06-14
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  findings:
    - { id: F-001, severity: WARNING, verdict: open }
chain:
  intent: null
---

# Design: fix

Body content for hashing.
EOF
  sed -i "s/PLACEHOLDER/$(bodyhash "$f")/" "$f"
  seed_owner "$1" "docs/superpowers/specs/2026-06-14-fix-design.md" "$SID_A"
}

mk_spec_noreview_at(){ # root relpath → unvalidated spec at root/relpath
  local f="$1/$2"; mkdir -p "$(dirname "$f")"
  cat > "$f" <<'EOF'
---
chain:
  intent: null
---

# Design: old

Body content for hashing.
EOF
  seed_owner "$1" "$2" "$SID_A"
}

mk_spec_noreview(){ # root → спека без review-блока (→ block)
  local d="$1/docs/superpowers/specs"; mkdir -p "$d"
  cat > "$d/2026-06-14-fix-design.md" <<'EOF'
---
chain:
  intent: null
---

# Design: fix

Body content for hashing.
EOF
  seed_owner "$1" "docs/superpowers/specs/2026-06-14-fix-design.md" "$SID_A"
}

mk_plan_result(){ # root verdict → план с result_check (печатает путь)
  local d="$1/docs/superpowers/plans"; mkdir -p "$d"
  local f="$d/2026-06-14-fix-plan.md"
  cat > "$f" <<EOF
---
result_check:
  verdict: $2
  plan_hash: PLACEHOLDER
  last_run: 2026-06-14
---

# Plan: fix

Plan body content.
EOF
  sed -i "s/PLACEHOLDER/$(bodyhash "$f")/" "$f"
  seed_owner "$1" "docs/superpowers/plans/2026-06-14-fix-plan.md" "$SID_A"
  echo "$f"
}

mk_intent_result(){ # root verdict → интент с result_check (execute-маршрут; печатает путь)
  local d="$1/docs/superpowers/intents"; mkdir -p "$d"
  local f="$d/2026-06-14-fix-intent.md"
  cat > "$f" <<EOF
---
result_check:
  verdict: $2
  intent_hash: PLACEHOLDER
  last_run: 2026-06-14
---

# Intent: fix

Intent body content.
EOF
  sed -i "s/PLACEHOLDER/$(bodyhash "$f")/" "$f"
  seed_owner "$1" "docs/superpowers/intents/2026-06-14-fix-intent.md" "$SID_A"
  echo "$f"
}

mk_intent_noresult(){ # root → интент без result_check (→ block)
  local d="$1/docs/superpowers/intents"; mkdir -p "$d"
  cat > "$d/2026-06-14-fix-intent.md" <<'EOF'
---
review:
  intent_hash: unused
---

# Intent: fix

Intent body content.
EOF
  seed_owner "$1" "docs/superpowers/intents/2026-06-14-fix-intent.md" "$SID_A"
}

mk_plan_noresult(){ # root → план без result_check (→ block)
  local d="$1/docs/superpowers/plans"; mkdir -p "$d"
  cat > "$d/2026-06-14-fix-plan.md" <<'EOF'
---
chain:
  intent: null
---

# Plan: fix

Plan body content.
EOF
  seed_owner "$1" "docs/superpowers/plans/2026-06-14-fix-plan.md" "$SID_A"
}

mk_plan_cmd_noreview(){ # root → unvalidated plan whose name does NOT end in -plan.md
  local d="$1/docs/superpowers/plans"; mkdir -p "$d"
  cat > "$d/2026-06-14-fix-command.md" <<'EOF'
---
chain:
  intent: null
---

# Plan: fix

Plan body content.
EOF
  seed_owner "$1" "docs/superpowers/plans/2026-06-14-fix-command.md" "$SID_A"
}

mk_plan_passed(){ # root → plan with a passing review block (plan→impl → allow)
  local d="$1/docs/superpowers/plans"; mkdir -p "$d"
  local f="$d/2026-06-14-fix-plan.md"
  cat > "$f" <<'EOF'
---
review:
  plan_hash: PLACEHOLDER
  last_run: 2026-06-14
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  findings: []
---

# Plan: fix

Plan body content.
EOF
  sed -i "s/PLACEHOLDER/$(bodyhash "$f")/" "$f"
  seed_owner "$1" "docs/superpowers/plans/2026-06-14-fix-plan.md" "$SID_A"
}

SKILL_WP='{"session_id":"sess-A","tool_name":"Skill","tool_input":{"skill":"writing-plans"}}'
SKILL_WP_NS='{"session_id":"sess-A","tool_name":"Skill","tool_input":{"skill":"superpowers:writing-plans"}}'
SKILL_FIN='{"session_id":"sess-A","tool_name":"Skill","tool_input":{"skill":"finishing-a-development-branch"}}'
SKILL_EP='{"session_id":"sess-A","tool_name":"Skill","tool_input":{"skill":"executing-plans"}}'

echo "idd-gate: escape & non-gated"
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/specs"
assert_exit "не-гейтируемый скилл → 0" "$T" '{"tool_name":"Skill","tool_input":{"skill":"systematic-debugging"}}' 0
assert_exit "пустая specs/ → 0 (escape)"  "$T" "$SKILL_WP" 0
assert_exit "битый stdin → 0 (fail-open)" "$T" 'garbage{'   0
assert_exit "tool_input: null → 0 (fail-open)" "$T" '{"tool_name":"Skill","tool_input":null}' 0
rm -rf "$T"

echo "idd-gate: review-предикат"
T=$(mktemp -d); mk_spec_passed "$T"
F="$T/docs/superpowers/specs/2026-06-14-fix-design.md"
assert_exit "passed-спека → 0"            "$T" "$SKILL_WP"    0
assert_exit "namespaced имя → 0 (как bare)" "$T" "$SKILL_WP_NS" 0
mk_spec_noreview "$T"
assert_exit "нет review: → 2"             "$T" "$SKILL_WP" 2
mk_spec_passed "$T"
sed -i 's/spec_hash: .*/spec_hash: 0000000000000000/' "$F"
assert_exit "stale hash → 2"              "$T" "$SKILL_WP" 2
mk_spec_passed "$T"
sed -i 's/coverage:    { status: passed }/coverage:    { status: in_progress }/' "$F"
assert_exit "фаза in_progress → 2"        "$T" "$SKILL_WP" 2
mk_spec_passed "$T"
sed -i 's/severity: WARNING/severity: CRITICAL/' "$F"
assert_exit "открытый CRITICAL → 2"       "$T" "$SKILL_WP" 2
rm -rf "$T"

echo "idd-gate: result_check-предикат"
T=$(mktemp -d); P=$(mk_plan_result "$T" OK)
assert_exit "result_check OK → 0"         "$T" "$SKILL_FIN" 0
sed -i 's/verdict: OK/verdict: needs_work/' "$P"
assert_exit "needs_work → 2"              "$T" "$SKILL_FIN" 2
mk_plan_noresult "$T"
assert_exit "нет result_check → 2"        "$T" "$SKILL_FIN" 2
P=$(mk_plan_result "$T" OK)
printf '\nextra line\n' >> "$P"
assert_exit "hash drift (тело изменено) → 2" "$T" "$SKILL_FIN" 2
rm -rf "$T"

echo "idd-gate: result_check на интенте (execute-маршрут)"
# Плана нет: гейт финиша ветки опирается на интент.
T=$(mktemp -d); I=$(mk_intent_result "$T" OK)
assert_exit "intent result_check OK → 0"      "$T" "$SKILL_FIN" 0
sed -i 's/verdict: OK/verdict: needs_work/' "$I"
assert_exit "intent needs_work → 2"           "$T" "$SKILL_FIN" 2
rm -rf "$T"

T=$(mktemp -d); mk_intent_noresult "$T"
assert_exit "intent без result_check → 2"     "$T" "$SKILL_FIN" 2
rm -rf "$T"

T=$(mktemp -d); I=$(mk_intent_result "$T" OK)
printf '\nextra line\n' >> "$I"
assert_exit "intent hash drift → 2"           "$T" "$SKILL_FIN" 2
rm -rf "$T"

# План есть — он и решает, интент не подменяет его вердикт.
T=$(mktemp -d); mk_plan_noresult "$T"; mk_intent_result "$T" OK >/dev/null
assert_exit "план важнее интента → 2"         "$T" "$SKILL_FIN" 2
rm -rf "$T"

echo "idd-gate: plan glob fix (*.md)"
T=$(mktemp -d); mk_plan_cmd_noreview "$T"
assert_exit "*-command.md plan resolves → 2" "$T" "$SKILL_EP" 2
rm -rf "$T"

echo "idd-gate: spec→plan write trigger"
PLAN_AT="docs/superpowers/plans/2026-06-15-new.md"
NOCHAIN="---\nchain:\n  intent: null\n---\n\n# Plan\n\nbody"

# chain.spec → validated spec → 0
T=$(mktemp -d); mk_spec_passed "$T"
C="---\nchain:\n  spec: docs/superpowers/specs/2026-06-14-fix-design.md\n---\n\n# Plan\n\nbody"
assert_exit "chain.spec → passed spec → 0" "$T" "$(write_json "$T/$PLAN_AT" "$C")" 0
rm -rf "$T"

# chain.spec → unvalidated spec, even though a NEWER validated spec exists → 2
# (proves chain.spec beats the newest-spec fallback)
T=$(mktemp -d)
mk_spec_noreview_at "$T" "docs/superpowers/specs/2026-06-10-old-design.md"
touch -d '1 hour ago' "$T/docs/superpowers/specs/2026-06-10-old-design.md"
mk_spec_passed "$T"   # 2026-06-14-fix-design.md is newer
C="---\nchain:\n  spec: docs/superpowers/specs/2026-06-10-old-design.md\n---\n\n# Plan\n\nbody"
assert_exit "chain.spec → unvalidated spec → 2" "$T" "$(write_json "$T/$PLAN_AT" "$C")" 2
rm -rf "$T"

# no chain.spec, newest spec validated → 0
T=$(mktemp -d); mk_spec_passed "$T"
assert_exit "fallback newest spec passed → 0" "$T" "$(write_json "$T/$PLAN_AT" "$NOCHAIN")" 0
rm -rf "$T"

# no chain.spec, newest spec unvalidated → 2
T=$(mktemp -d); mk_spec_noreview "$T"
assert_exit "fallback newest spec unvalidated → 2" "$T" "$(write_json "$T/$PLAN_AT" "$NOCHAIN")" 2
rm -rf "$T"

echo "idd-gate: plan→impl write trigger"
PLAN_F="docs/superpowers/plans/2026-06-14-fix-plan.md"

# code edit + fresh unvalidated plan → 2
T=$(mktemp -d); mk_plan_noresult "$T"   # chain-only plan, no review block, fresh
assert_exit "Edit code + fresh unvalidated plan → 2" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 2

# Write to a code path is also plan→impl (not mistaken for plan creation) → 2
assert_exit "Write code + fresh unvalidated plan → 2" "$T" "$(write_json "$T/src/x.py" "print(1)")" 2

# non-transition: editing the plan itself (checkbox tick) is never gated → 0
assert_exit "Edit existing plan (checkbox) → 0" "$T" "$(edit_json Edit "$T/$PLAN_F")" 0

# non-transition: editing a spec is never gated by plan→impl → 0
assert_exit "Edit spec → 0" "$T" "$(edit_json Edit "$T/docs/superpowers/specs/x-design.md")" 0
rm -rf "$T"

# code edit + STALE unvalidated plan → 0 (recency window passed)
T=$(mktemp -d); mk_plan_noresult "$T"
touch -d '3 hours ago' "$T/$PLAN_F"
assert_exit "Edit code + stale unvalidated plan → 0" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"

# code edit + validated plan → 0
T=$(mktemp -d); mk_plan_passed "$T"
assert_exit "Edit code + validated plan → 0" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"

# code edit + no plan at all → 0 (escape)
T=$(mktemp -d)
assert_exit "Edit code + no plan → 0" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"

# fail-open: a forced internal exception → 0 (spec acceptance #7).
# The newest plan candidate is a DIRECTORY named *.md → resolve_candidate picks it
# (glob matches dirs), fresh() passes, then evaluate_gate → read_frontmatter →
# open(<dir>) raises IsADirectoryError → caught by main's `except Exception` →
# exit 0. The gate must NEVER block on an internal bug.
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/plans/2026-06-14-dir-plan.md"
seed_owner "$T" "docs/superpowers/plans/2026-06-14-dir-plan.md" "$SID_A"
assert_exit "forced exception (dir candidate) → 0 (fail-open)" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"

echo "idd-gate: session scoping"

# Session B edits code; a FRESH unvalidated plan owned by Session A exists.
# Session B created nothing IDD-related → must NOT be blocked.
T=$(mktemp -d); mk_plan_noresult "$T"   # plan owned by SID_A, fresh, unvalidated
assert_exit "cross-session: B edits code, A owns plan → 0" "$T" "$(edit_json Edit "$T/lib/foo.sh" "$SID_B")" 0
# Owner-is-gated invariant (made explicit, mirroring the cross-session case): the
# SAME session that owns the unvalidated plan IS blocked editing code.
assert_exit "same-session: A edits code, A owns plan → 2" "$T" "$(edit_json Edit "$T/lib/foo.sh" "$SID_A")" 2
rm -rf "$T"

# No session_id in payload → cannot scope → escape (fail-open).
T=$(mktemp -d); mk_plan_noresult "$T"
assert_exit "no session_id → 0" "$T" '{"tool_name":"Edit","tool_input":{"file_path":"'"$T"'/lib/foo.sh"}}' 0
rm -rf "$T"

# Corrupt ledger → load_ledger returns {} → owns-nothing → escape.
T=$(mktemp -d); mk_plan_noresult "$T"
mkdir -p "$T/state"; printf 'garbage{' > "$T/state/idd-sessions.json"
assert_exit "corrupt ledger → 0 (fail-open)" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"

# Claim: a session that owns NO plan invokes executing-plans. The claim stamps
# the newest plan into its ownership, so the unvalidated plan still gates it.
T=$(mktemp -d); mk_plan_noresult "$T"   # plan owned by SID_A, unvalidated
EP_B='{"session_id":"sess-B","tool_name":"Skill","tool_input":{"skill":"executing-plans"}}'
assert_exit "claim: EP by non-owner B → 2" "$T" "$EP_B" 2
rm -rf "$T"

T=$(mktemp -d); mk_plan_noresult "$T"
SDD_B='{"session_id":"sess-B","tool_name":"Skill","tool_input":{"skill":"subagent-driven-development"}}'
assert_exit "claim: subagent-driven by non-owner B → 2" "$T" "$SDD_B" 2
rm -rf "$T"

# Claim + VALIDATED newest plan → allow. Proves claim records ownership for a
# non-owner session AND that a passing review then opens the gate.
T=$(mktemp -d); mk_plan_passed "$T"
EP_B='{"session_id":"sess-B","tool_name":"Skill","tool_input":{"skill":"executing-plans"}}'
assert_exit "claim: EP by non-owner B, validated plan → 0" "$T" "$EP_B" 0
rm -rf "$T"

echo "idd-gate: ledger prune"
# Stale ownership entry (8 days old) is pruned on load → owns-nothing → escape.
T=$(mktemp -d); mk_plan_noresult "$T"
python3 - "$T/state/idd-sessions.json" "$T/docs/superpowers/plans/2026-06-14-fix-plan.md" <<'PY'
import json, os, sys, time
ledger, art = sys.argv[1], sys.argv[2]
data = {os.path.abspath(art): {"session": "sess-A", "ts": int(time.time()) - 8*24*3600}}
with open(ledger, "w") as f: json.dump(data, f)
PY
assert_exit "stale ownership pruned → 0" "$T" "$(edit_json Edit "$T/lib/foo.sh")" 0
rm -rf "$T"

echo "─────────────────────────────"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
