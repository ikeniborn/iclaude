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
