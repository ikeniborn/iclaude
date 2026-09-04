#!/usr/bin/env python3
"""Statusline cache segment: hit-rate % + read/write split rendering."""
import json
import os
import shutil
import subprocess

import pytest

SCRIPT = os.path.join(
    os.path.dirname(__file__), "..",
    ".claude-isolated", "scripts", "claude-statusline.sh",
)

pytestmark = pytest.mark.skipif(
    shutil.which("jq") is None or shutil.which("awk") is None,
    reason="statusline requires jq + awk",
)


def _run(session_json):
    env = dict(os.environ, ICLAUDE_SL_NO_CACHE="1")  # bypass the 3s render cache
    return subprocess.run(
        ["bash", SCRIPT],
        input=json.dumps(session_json),
        capture_output=True, text=True, env=env, timeout=15,
    ).stdout


def test_segment_shows_hitrate_and_split():
    # read=900, creation=50, input=50 -> hit-rate = 900/1000 = 90%
    out = _run({
        "context_window": {
            "total_input_tokens": 1000, "total_output_tokens": 100,
            "context_window_size": 200000, "used_percentage": 5,
            "current_usage": {
                "cache_read_input_tokens": 900,
                "cache_creation_input_tokens": 50,
                "input_tokens": 50,
            },
        },
        "model": {"display_name": "Opus 4.8"},
        "cost": {"total_cost_usd": 0.1},
        "session_id": "test", "transcript_path": "",
        "workspace": {"project_dir": "/tmp"},
    })
    assert "📦 90% · R900/W50" in out


def test_segment_hidden_when_no_cache():
    out = _run({
        "context_window": {
            "total_input_tokens": 0, "total_output_tokens": 0,
            "context_window_size": 200000, "used_percentage": 0,
            "current_usage": {
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
                "input_tokens": 0,
            },
        },
        "model": {"display_name": "Opus 4.8"},
        "cost": {"total_cost_usd": 0},
        "session_id": "test", "transcript_path": "",
        "workspace": {"project_dir": "/tmp"},
    })
    assert "📦" not in out
