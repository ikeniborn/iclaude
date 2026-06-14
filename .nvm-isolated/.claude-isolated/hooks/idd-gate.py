#!/usr/bin/env python3
"""
PreToolUse hook — IDD→SDD phase gate.

Перехватывает вызовы инструмента Skill и блокирует переход к следующему
этапу цепи IDD→SDD, пока upstream-артефакт не прошёл валидацию
(нет открытых CRITICAL, все фазы passed, хеш тела совпадает).

Роль хука — ТОЛЬКО gate (block/allow); он никогда не валидирует. Валидацию
выполняет /check-* в субагенте, вердикты собираются в основной сессии.
Коммуникация — через frontmatter review:/result_check:.

Exit codes:
  0 — разрешить (Skill выполняется)
  2 — заблокировать (Skill не выполняется, Claude получает stderr)

Fail-open: любое внутреннее исключение → exit 0. Баг в гейте НЕ должен
ломать каждый вызов Skill. Это противоположность block-secrets.py (fail-closed).
"""

import sys
import json
import os
import glob

DOCS_ROOT = "docs/superpowers"

# Единственный тюнинг строгости: какие severity блокируют переход.
BLOCK_ON = {"CRITICAL"}

# skill (суффикс после последнего ':') → правило гейта:
#   dir      — поддиректория docs/superpowers/
#   glob     — шаблон файла-артефакта
#   block    — имя блока state во frontmatter ('review' | 'result_check')
#   hash_key — поле с хешем тела внутри блока
#   fix      — команда-валидатор для сообщения о блокировке
GATE_MAP = {
    "brainstorming": {
        "dir": "intents", "glob": "*-intent.md",
        "block": "review", "hash_key": "intent_hash", "fix": "/check-intent",
    },
    "writing-plans": {
        "dir": "specs", "glob": "*-design.md",
        "block": "review", "hash_key": "spec_hash", "fix": "/check-spec",
    },
    "executing-plans": {
        "dir": "plans", "glob": "*-plan.md",
        "block": "review", "hash_key": "plan_hash", "fix": "/check-plan",
    },
    "subagent-driven-development": {
        "dir": "plans", "glob": "*-plan.md",
        "block": "review", "hash_key": "plan_hash", "fix": "/check-plan",
    },
    "finishing-a-development-branch": {
        "dir": "plans", "glob": "*-plan.md",
        "block": "result_check", "hash_key": "plan_hash", "fix": "/check-result",
    },
}


def normalize_skill(name):
    """Суффикс после последнего ':' ('superpowers:writing-plans' → 'writing-plans')."""
    return name.rsplit(":", 1)[-1].strip()


def resolve_candidate(rule):
    """Самый недавно изменённый файл, совпавший с glob в upstream-директории.
    None, если совпадений нет — escape hatch: hotfix без IDD-доков проходит."""
    pattern = os.path.join(DOCS_ROOT, rule["dir"], rule["glob"])
    matches = glob.glob(pattern)
    if not matches:
        return None
    return max(matches, key=os.path.getmtime)


def evaluate_gate(path, rule):
    """Возвращает None, если гейт ОТКРЫТ (allow), либо строку-причину BLOCK.
    Заглушка: реальный предикат добавляется в Tasks 3–4."""
    return None


def main():
    try:
        data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)  # битый stdin → fail-open

    if data.get("tool_name") != "Skill":
        sys.exit(0)

    skill = normalize_skill(data.get("tool_input", {}).get("skill", ""))
    rule = GATE_MAP.get(skill)
    if rule is None:
        sys.exit(0)  # скилл не гейтируется

    try:
        candidate = resolve_candidate(rule)
        if candidate is None:
            sys.exit(0)  # нет артефакта → escape
        reason = evaluate_gate(candidate, rule)
    except Exception as exc:  # fail-open на любой внутренней ошибке
        print("idd-gate: внутренняя ошибка, пропускаю (fail-open): %s" % exc,
              file=sys.stderr)
        sys.exit(0)

    if reason is None:
        sys.exit(0)

    sys.stderr.write(
        "🚧 IDD gate: %s has not passed validation.\n"
        "Reason: %s\n"
        "Action: dispatch a subagent to run %s on %s (clean-context\n"
        "check-runner protocol), collect verdicts in the main session, "
        "resolve the CRITICAL\n"
        "findings, then retry the skill invocation.\n"
        % (candidate, reason, rule["fix"], candidate)
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
