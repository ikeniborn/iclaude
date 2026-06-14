#!/usr/bin/env bash
# tests/test-idd-gate.sh — тесты IDD→SDD gate (hooks/idd-gate.py).
# Запускать из корня проекта iclaude: ./tests/test-idd-gate.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/.nvm-isolated/.claude-isolated/hooks/idd-gate.py"
PASS=0; FAIL=0
pass(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
fail(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }

# Канонический хеш тела — ТОТ ЖЕ пайплайн, что у валидаторов и хука.
bodyhash(){ awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$1" | sha256sum | cut -c1-16; }

# Запускает хук в указанном project-root, печатает exit code.
run(){ ( cd "$1" && printf '%s' "$2" | python3 "$HOOK" >/dev/null 2>&1; echo $? ); }

assert_exit(){ # label cwd json expected
  local got; got=$(run "$2" "$3")
  if [[ "$got" == "$4" ]]; then pass "$1"; else fail "$1 (exit=$got, ожидался $4)"; fi
}

# ── fixtures ────────────────────────────────────────────────────────────
# Хеш считается с PLACEHOLDER в frontmatter, затем подставляется sed'ом:
# тело (всё после 2-го '---') не меняется, поэтому хеш остаётся валидным.

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
  echo "$f"
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
}

SKILL_WP='{"tool_name":"Skill","tool_input":{"skill":"writing-plans"}}'
SKILL_WP_NS='{"tool_name":"Skill","tool_input":{"skill":"superpowers:writing-plans"}}'
SKILL_FIN='{"tool_name":"Skill","tool_input":{"skill":"finishing-a-development-branch"}}'

echo "idd-gate: escape & non-gated"
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/specs"
assert_exit "не-гейтируемый скилл → 0" "$T" '{"tool_name":"Skill","tool_input":{"skill":"systematic-debugging"}}' 0
assert_exit "пустая specs/ → 0 (escape)"  "$T" "$SKILL_WP" 0
assert_exit "битый stdin → 0 (fail-open)" "$T" 'garbage{'   0
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

echo "─────────────────────────────"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
