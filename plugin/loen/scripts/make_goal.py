#!/usr/bin/env python3
"""loen /goal string generator (deterministic).

Usage: make_goal.py [path/to/loop.yaml]
Default path: docs/loen/current/loop.yaml (the active run).

Prints ONE ready-to-paste, evidence-first /goal line assembled only
from contract fields — no LLM, no inference. Refuses (exit 1, nothing
on stdout) contracts that would fail `loen:audit plan`: missing or
unreadable file, unknown mode, empty quality_gates, empty
mutable_scope, research mode without a `target: <name> <op> <number>`
stop condition, missing mode budget. Line-oriented YAML reading
mirrors hooks/loop-guard.py — stdlib only, no PyYAML."""
import re
import sys
from typing import NoReturn

DEFAULT_PATH = "docs/loen/current/loop.yaml"
LIST_KEYS = ("quality_gates", "mutable_scope", "protected_scope",
             "stop_conditions")
TARGET = re.compile(
    r"^target:\s*([\w.-]+)\s*(>=|<=)\s*(-?\d+(?:\.\d+)?)\s*$")
EVIDENCE = "Claude prints each command's output summary as evidence"


def fail(msg) -> NoReturn:
    sys.stderr.write("make_goal: " + msg + "\n")
    sys.exit(1)


def scalar(rest):
    """Value of 'key: <rest>' with a trailing comment stripped."""
    return rest.split("#", 1)[0].strip().strip('"').strip("'")


def inline_list(s):
    """Parse 'key: [a, b]' -> [a, b]; None if not an inline flow
    list. Tolerates a trailing comment (the shipped template has
    them on every empty-list line)."""
    m = re.match(r"^[\w-]+:\s*\[([^\]]*)\]\s*(?:#.*)?$", s)
    if m is None:
        return None
    body = m.group(1).strip()
    if not body:
        return []
    return [x.strip().strip('"').strip("'")
            for x in body.split(",") if x.strip()]


def parse(path):
    """Line-oriented read of the contract fields this generator
    needs: mode, the four list keys, and the budget block."""
    lists = {k: [] for k in LIST_KEYS}
    mode = ""
    budget = {}
    cur = None            # list collecting block-style '- item' lines
    in_budget = False
    try:
        f = open(path, encoding="utf-8")
    except OSError as e:
        fail(f"cannot read {path}: {e.strerror}")
    with f:
        for line in f:
            s = line.rstrip("\n")
            top = re.match(r"^([\w-]+):(.*)$", s)
            if top:
                key, rest = top.group(1), top.group(2)
                cur, in_budget = None, key == "budget"
                if key in lists:
                    inline = inline_list(s)
                    if inline is None:
                        cur = lists[key]   # block list on next lines
                    else:
                        lists[key].extend(inline)
                elif key == "mode":
                    mode = scalar(rest)
                continue
            if in_budget:
                m = re.match(r"^\s+([\w-]+):\s*(.*)$", s)
                if m:
                    budget[m.group(1)] = scalar(m.group(2))
                continue
            m = re.match(r"^\s*-\s*(.+?)\s*$", s)
            if m and cur is not None:
                cur.append(m.group(1).strip().strip('"').strip("'"))
    return mode, lists, budget


def budget_int(budget, key):
    v = budget.get(key, "")
    if not re.fullmatch(r"\d+", v):
        fail(f"budget.{key} missing or not an integer")
    return int(v)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PATH
    mode, lists, budget = parse(path)
    if mode not in ("delivery", "repair", "research"):
        fail(f"unsupported mode: {mode!r}")
    if not lists["quality_gates"]:
        fail("quality_gates is empty — contract is not audit-plan ready")
    if not lists["mutable_scope"]:
        fail("mutable_scope is empty — contract is not audit-plan ready")

    clauses = []
    if mode == "research":
        target = None
        for item in lists["stop_conditions"]:
            m = TARGET.match(item)
            if m:
                target = m
                break
        if target is None:
            fail("research contract lacks a "
                 "'target: <name> <op> <number>' stop condition")
        name, op, num = target.groups()
        clauses.append(
            f"the printed eval summary shows {name} {op} {num}")
    clauses += [f"{g} exits 0" for g in lists["quality_gates"]]
    clauses.append(EVIDENCE)

    parts = [" and ".join(clauses),
             "change only " + ", ".join(lists["mutable_scope"])]
    if lists["protected_scope"]:
        parts.append(
            "do not modify " + ", ".join(lists["protected_scope"]))
    if mode == "research":
        n = budget_int(budget, "max_experiments")
        parts.append(f"stop after {n} experiments "
                     f"and report the best kept state")
    else:
        n = budget_int(budget, "max_iterations")
        parts.append(f"stop after {n} failed attempts "
                     f"and report the blocker")
    print("/goal " + "; ".join(parts))


if __name__ == "__main__":
    main()
