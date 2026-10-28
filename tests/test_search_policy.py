import importlib.util
from pathlib import Path
import pytest

path = Path(__file__).parents[1] / 'lib/search/policy.py'
spec = importlib.util.spec_from_file_location('search_policy', path)
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


def test_route_override_cancels_default():
    assert policy.resolve_mode(routed=True, native='native', routed_default='framework',
                              route_modes={'framework,qwen': 'inherit'}, selected_pair='framework,qwen') == 'inherit'


def test_native_setting_is_independent():
    assert policy.resolve_mode(routed=False, native='native', routed_default='framework',
                              route_modes={}, selected_pair=None) == 'native'


def test_unresolved_route_map_fails():
    with pytest.raises(ValueError):
        policy.resolve_mode(routed=True, native='inherit', routed_default='framework',
                            route_modes={'framework,qwen': 'native'}, selected_pair=None)


def test_explicit_model_precedes_environment(monkeypatch):
    monkeypatch.setenv('ANTHROPIC_MODEL', 'other,model')
    assert policy.selected_model(['--model', 'framework,qwen'], None) == 'framework,qwen'


@pytest.mark.parametrize('mode', ['inherit', 'native', 'framework', 'disabled'])
def test_mode_matrix(mode):
    for routed in (False, True):
        assert policy.resolve_mode(routed=routed, native=mode, routed_default=mode,
                                  route_modes={}, selected_pair=None) == mode


@pytest.mark.parametrize('value', ['bad', '', 'FRAMEWORK'])
def test_invalid_mode_rejected(value):
    with pytest.raises(ValueError):
        policy.resolve_mode(routed=False, native=value, routed_default='inherit',
                            route_modes={}, selected_pair=None)


def test_framework_config_contains_names_only():
    args = policy.launch_arguments('framework', [], '/path with spaces/search')
    assert args[:2] == ['--disallowedTools', 'WebSearch']
    assert '${FRAMEWORK_WEBSEARCH_TOKEN}' in args[3]


def test_native_preserves_denial():
    with pytest.raises(ValueError):
        policy.launch_arguments('native', ['--disallowedTools', 'WebSearch'], '')


def test_inherit_ignores_managed_conflicts():
    assert policy.launch_arguments('inherit', ['--strict-mcp-config'], '') == []


@pytest.mark.parametrize('args', [
    ['--disallowedTools=WebSearch'], ['--disallowed-tools=WebSearch'],
])
def test_native_equal_form_denial_is_preserved(args):
    with pytest.raises(ValueError):
        policy.launch_arguments('native', args, '')


def test_native_variadic_denial_rejected():
    with pytest.raises(ValueError):
        policy.launch_arguments('native', ['--disallowedTools', 'Bash', 'WebSearch'], '')


@pytest.fixture(autouse=True)
def isolated_configs(tmp_path, monkeypatch):
    monkeypatch.setenv('HOME', str(tmp_path))
    monkeypatch.setenv('CLAUDE_CONFIG_DIR', str(tmp_path / 'config'))
    monkeypatch.chdir(tmp_path)


def test_actionable_safe_diagnostic(monkeypatch, capsys):
    monkeypatch.setenv('ICLAUDE_SEARCH_MODE', 'framework')
    monkeypatch.setenv('ICLAUDE_SEARCH_MCP_COMMAND', 'secret-marker-relative-command')
    monkeypatch.setattr('sys.argv', ['policy.py', 'false', 'false', ''])
    assert policy.main() == 1
    message = capsys.readouterr().err
    assert 'absolute executable path' in message
    assert 'secret-marker' not in message


@pytest.mark.parametrize('location', ['project', 'config', 'user', 'user-project'])
def test_persistent_reserved_registration_rejected(location, tmp_path):
    import json
    server = {'mcpServers': {'framework-search': {'command': '/bin/true'}}}
    targets = {'project': tmp_path / '.mcp.json', 'config': tmp_path / 'config/.mcp.json',
               'user': tmp_path / '.claude.json', 'user-project': tmp_path / '.claude.json'}
    target = targets[location]
    target.parent.mkdir(parents=True, exist_ok=True)
    content = {'projects': {str(tmp_path): server}} if location == 'user-project' else server
    target.write_text(json.dumps(content))
    with pytest.raises(ValueError, match='registration conflicts'):
        policy.launch_arguments('disabled', [], '')


def test_variadic_mcp_checks_every_config(tmp_path):
    import json
    clean = tmp_path / 'clean.json'
    clean.write_text('{"mcpServers":{"unrelated":{"command":"true"}}}')
    conflict = json.dumps({'mcpServers': {'framework-search': {}}})
    with pytest.raises(ValueError, match='already exists'):
        policy.launch_arguments('framework', ['--mcp-config', str(clean), conflict], '/bin/true')


def test_variadic_denials_are_merged():
    assert policy.launch_arguments('disabled', ['--disallowedTools', 'Bash', 'Read', '--print'], '') == [
        '--disallowedTools', 'Bash,Read,WebSearch']


def test_model_precedence_and_fallback(tmp_path, monkeypatch):
    config = tmp_path / 'router.json'
    config.write_text('{"Router":{"default":"framework,qwen"}}')
    monkeypatch.delenv('ANTHROPIC_MODEL', raising=False)
    assert policy.selected_model([], config) == 'framework,qwen'
    monkeypatch.setenv('ANTHROPIC_MODEL', 'other,model')
    assert policy.selected_model([], config) == 'other,model'
    assert policy.selected_model(['--model=explicit,model'], config) == 'explicit,model'


@pytest.mark.parametrize('endpoint', ['http://example.invalid/v1/websearch',
    'https://user:secret@example.invalid/v1/websearch', 'https://example.invalid/v1/websearch?secret=1',
    'https://example.invalid/v1/websearch#secret', 'https://example.invalid/other'])
def test_framework_endpoint_is_closed(endpoint, monkeypatch, capsys):
    monkeypatch.setenv('ICLAUDE_SEARCH_MODE', 'framework')
    monkeypatch.setenv('ICLAUDE_SEARCH_MCP_COMMAND', '/bin/true')
    monkeypatch.setenv('ICLAUDE_SEARCH_API_URL', endpoint)
    monkeypatch.setattr('sys.argv', ['policy.py', 'false', 'false', ''])
    assert policy.main() == 1
    message = capsys.readouterr().err
    assert 'HTTPS /v1/websearch endpoint' in message
    assert endpoint not in message


def test_missing_token_is_actionable(monkeypatch, capsys):
    monkeypatch.setenv('ICLAUDE_SEARCH_MODE', 'framework')
    monkeypatch.setenv('ICLAUDE_SEARCH_MCP_COMMAND', '/bin/true')
    monkeypatch.setenv('ICLAUDE_SEARCH_API_URL', 'https://example.invalid/v1/websearch')
    monkeypatch.setenv('ICLAUDE_SEARCH_API_ENV_KEY', 'UNSET_SEARCH_FIXTURE')
    monkeypatch.delenv('UNSET_SEARCH_FIXTURE', raising=False)
    monkeypatch.setattr('sys.argv', ['policy.py', 'false', 'false', ''])
    assert policy.main() == 1
    assert 'token environment variable is missing' in capsys.readouterr().err


def test_malformed_json_diagnostic_does_not_echo_input(monkeypatch, capsys):
    monkeypatch.setenv('ICLAUDE_SEARCH_MODE', 'disabled')
    monkeypatch.setenv('ICLAUDE_SEARCH_ROUTE_MODES', 'synthetic-secret-invalid-json')
    monkeypatch.setattr('sys.argv', ['policy.py', 'false', 'false', ''])
    assert policy.main() == 1
    assert 'synthetic-secret' not in capsys.readouterr().err


@pytest.mark.parametrize('route_modes', [[], {'framework': 'framework'},
    {'framework,': 'framework'}, {'framework,qwen,extra': 'native'}, {'framework,qwen': 'invalid'}])
def test_malformed_route_maps_rejected(route_modes):
    with pytest.raises(ValueError):
        policy.resolve_mode(routed=True, native='inherit', routed_default='inherit',
                            route_modes=route_modes, selected_pair='framework,qwen')


def test_alias_without_provider_cannot_resolve_route_map():
    with pytest.raises(ValueError, match='exact provider,model pair'):
        policy.resolve_mode(routed=True, native='inherit', routed_default='inherit',
                            route_modes={'framework,qwen': 'framework'}, selected_pair='qwen')


def test_active_user_store_reserved_registration(tmp_path, monkeypatch):
    active = tmp_path / 'active'
    active.mkdir()
    monkeypatch.setenv('CLAUDE_CONFIG_DIR', str(active))
    (active / '.claude.json').write_text('{"mcpServers":{"framework-search":{}}}')
    with pytest.raises(ValueError):
        policy.launch_arguments('disabled', [], '')
