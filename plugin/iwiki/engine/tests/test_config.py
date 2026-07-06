import pytest
from iwiki_engine.config import Config, ConfigError


def test_missing_config_names_env_vars(monkeypatch):
    monkeypatch.delenv("IWIKI_LLM_BASE_URL", raising=False)
    monkeypatch.delenv("IWIKI_LLM_KEY", raising=False)
    with pytest.raises(ConfigError) as ei:
        Config.load()
    msg = str(ei.value)
    assert "IWIKI_LLM_BASE_URL" in msg
    assert "IWIKI_LLM_KEY" in msg
    assert "environment variable" in msg.lower()


def test_summary_max_default_and_override(monkeypatch):
    monkeypatch.setenv("IWIKI_LLM_BASE_URL", "https://x/v1")
    monkeypatch.setenv("IWIKI_LLM_KEY", "k")
    monkeypatch.delenv("IWIKI_SUMMARY_MAX_CHARS", raising=False)
    assert Config.load().summary_max == 400
    monkeypatch.setenv("IWIKI_SUMMARY_MAX_CHARS", "250")
    assert Config.load().summary_max == 250
