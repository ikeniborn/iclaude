#!/usr/bin/env python3
"""Unit tests for loen_common — the shared hook foundation."""
import importlib.util, os, tempfile, pathlib

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(REPO, "plugin", "loen", "hooks", "loen_common.py")


def load():
    spec = importlib.util.spec_from_file_location("loen_common", MOD)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def test_mode_default_and_env():
    c = load()
    os.environ.pop("LOEN_MODE", None); assert c.mode() == "enforce"
    os.environ["LOEN_MODE"] = "off"; assert c.mode() == "off" and c.is_off()
    os.environ["LOEN_MODE"] = "bogus"; assert c.mode() == "enforce"
    os.environ.pop("LOEN_MODE", None)


def test_slug():
    c = load()
    assert c.validate_topic_slug("fix-parser-1")
    assert not c.validate_topic_slug("Fix_Parser")
    assert not c.validate_topic_slug("-bad")


def test_topic_from_path():
    c = load()
    assert c.topic_from_path("docs/loen/my-topic/4_act.md") == "my-topic"
    assert c.topic_from_path("src/app.py") is None


def test_parse_loop_yaml_nested_and_lists():
    c = load()
    y = c.parse_loop_yaml(
        "topic: t\nstatus: active\n"
        "mutable_scope:\n  - src/**\n  - tests/**\n"
        "stages:\n  act: {roles: [worker]}\n"
        "permissions:\n  network: {mode: off, allowlist: []}\n")
    assert y["topic"] == "t" and y["status"] == "active"
    assert y["mutable_scope"] == ["src/**", "tests/**"]
    assert y["stages"]["act"]["roles"] == ["worker"]
    assert y["permissions"]["network"]["mode"] == "off"


def test_block_or_nudge_modes():
    c = load()
    os.environ["LOEN_MODE"] = "enforce"; assert c.block_or_nudge("x") == 2
    os.environ["LOEN_MODE"] = "advisory"; assert c.block_or_nudge("x") == 0
    os.environ["LOEN_MODE"] = "off"; assert c.block_or_nudge("x") == 0
    os.environ.pop("LOEN_MODE", None)


def test_current_topic_via_pointer():
    c = load()
    d = tempfile.mkdtemp(); cwd = os.getcwd()
    try:
        os.chdir(d); os.environ["LOEN_ARTIFACT_ROOT"] = "docs/loen"
        pathlib.Path("docs/loen/t1").mkdir(parents=True)
        pathlib.Path("docs/loen/current").write_text("t1\n")
        assert c.current_topic() == "t1"
    finally:
        os.chdir(cwd); os.environ.pop("LOEN_ARTIFACT_ROOT", None)


def test_tool_class():
    c = load()
    assert c.tool_class("Write") == "edit" and c.tool_class("Bash") == "shell"
    assert c.tool_class("Grep") == "search" and c.tool_class("Read") == "read"


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn(); print(f"ok {name}")
    print("PASS test_loen_common.py")
