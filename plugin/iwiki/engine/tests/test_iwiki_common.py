import contextlib
import io
import os
import sys

# iwiki_common lives in the plugin's hooks/ dir, not the engine package.
_HOOKS = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "hooks"))
sys.path.insert(0, _HOOKS)
import iwiki_common  # noqa: E402


def test_read_session_warns_on_corrupt_file(tmp_path, monkeypatch):
    state = tmp_path / "iwiki-session.json"
    state.write_text("{not valid json", encoding="utf-8")
    monkeypatch.setattr(iwiki_common, "session_path", lambda: str(state))
    err = io.StringIO()
    with contextlib.redirect_stderr(err):
        out = iwiki_common.read_session()
    # fail-soft preserved: defaults returned
    assert out["session_id"] == ""
    assert out["count"] == 0
    # no longer silent
    assert "iwiki" in err.getvalue().lower()


def test_read_session_silent_when_absent(tmp_path, monkeypatch):
    missing = tmp_path / "nope.json"
    monkeypatch.setattr(iwiki_common, "session_path", lambda: str(missing))
    err = io.StringIO()
    with contextlib.redirect_stderr(err):
        out = iwiki_common.read_session()
    assert out["session_id"] == ""
    assert err.getvalue() == ""   # absent state is normal — stay quiet
