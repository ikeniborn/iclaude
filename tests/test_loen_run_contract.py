#!/usr/bin/env python3
"""Unit tests for loen_artifacts.validate_run_contract + plan_body_hash."""
import importlib.util, os
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    p = os.path.join(REPO, "plugin", "loen", "hooks", name + ".py")
    s = importlib.util.spec_from_file_location(name, p)
    m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m


def _delivery_loop(a, plan):
    return {"run": {"plan_approved": True, "plan_hash": a.plan_body_hash(plan)},
            "mode": "delivery", "mutable_scope": ["src/**"],
            "quality_gates": ["pytest"], "budget": {"max_iterations": 3},
            "rollback_policy": "git revert", "stop_conditions": [],
            "context_sources": []}


def test_plan_hash_excludes_frontmatter():
    a = load("loen_artifacts")
    body = "# Plan\n\nstep 1\n"
    with_fm = "---\nreview: {}\n---\n" + body
    assert a.plan_body_hash(with_fm) == a.plan_body_hash(body)


def test_contract_rejects_unapproved():
    a = load("loen_artifacts")
    plan = "# Plan\nstep\n"
    loop = _delivery_loop(a, plan)
    loop["run"]["plan_approved"] = False
    ok, errs = a.validate_run_contract(loop, plan)
    assert not ok and any("plan_approved" in e for e in errs)


def test_contract_rejects_hash_mismatch():
    a = load("loen_artifacts")
    plan = "# Plan\nstep\n"
    loop = _delivery_loop(a, plan)
    loop["run"]["plan_hash"] = "deadbeefdeadbeef"
    ok, errs = a.validate_run_contract(loop, plan)
    assert not ok and any("plan_hash" in e for e in errs)


def test_contract_accepts_valid_delivery():
    a = load("loen_artifacts")
    plan = "# Plan\nstep\n"
    ok, errs = a.validate_run_contract(_delivery_loop(a, plan), plan)
    assert ok, errs


def test_contract_budget_string_ok():
    # loop.yaml parser yields budget values as strings; contract must coerce.
    a = load("loen_artifacts")
    plan = "# Plan\nstep\n"
    loop = _delivery_loop(a, plan)
    loop["budget"] = {"max_iterations": "3"}
    ok, errs = a.validate_run_contract(loop, plan)
    assert ok, errs


def test_contract_research_needs_target():
    a = load("loen_artifacts")
    plan = "# Plan\nstep\n"
    loop = _delivery_loop(a, plan)
    loop["mode"] = "research"; loop["quality_gates"] = ["eval"]
    ok, _ = a.validate_run_contract(loop, plan); assert not ok
    loop["stop_conditions"] = ["reach target: accuracy > 0.9"]
    ok, errs = a.validate_run_contract(loop, plan); assert ok, errs


def test_contract_review_needs_scope():
    a = load("loen_artifacts")
    plan = "# Plan\nstep\n"
    loop = _delivery_loop(a, plan)
    loop["mode"] = "review"
    ok, _ = a.validate_run_contract(loop, plan); assert not ok
    loop["context_sources"] = ["PR #42"]
    ok, errs = a.validate_run_contract(loop, plan); assert ok, errs


if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f): f(); print("ok", n)
    print("PASS test_loen_run_contract.py")
