"""Session search policy; no provider or credential mutation."""
class PolicyError(ValueError):
    """Controlled diagnostic containing no user-supplied values."""


MODES = frozenset({'inherit', 'native', 'framework', 'disabled'})


def resolve_mode(*, routed, native, routed_default, route_modes, selected_pair):
    if not isinstance(route_modes, dict) or any(
        not isinstance(k, str) or k.count(',') != 1 or not all(k.split(','))
        or v not in MODES for k, v in route_modes.items()
    ):
        raise PolicyError('Invalid search route map')
    mode = routed_default if routed else native
    if routed and route_modes:
        if not selected_pair or selected_pair.count(',') != 1:
            raise PolicyError('Search route map requires an exact provider,model pair')
        mode = route_modes.get(selected_pair, mode)
    if mode not in MODES:
        raise PolicyError('Invalid search mode')
    return mode


def selected_model(args, router_config):
    import os
    model = None
    for index, arg in enumerate(args):
        if arg == '--model':
            if index + 1 >= len(args):
                raise PolicyError('Missing model argument')
            model = args[index + 1]
        elif arg.startswith('--model='):
            model = arg.split('=', 1)[1]
    if model is None:
        model = os.environ.get('ANTHROPIC_MODEL')
    if not model and router_config:
        import json
        from pathlib import Path
        config = json.loads(Path(router_config).read_text())
        model = config.get('Router', {}).get('default')
    return model


def launch_arguments(mode, args, command):
    import json
    import os
    from pathlib import Path
    if mode == 'inherit':
        return []
    configs = [Path.cwd() / '.mcp.json']
    home_config = Path(os.environ.get('CLAUDE_CONFIG_DIR', str(Path.home() / '.claude')))
    configs.append(home_config / '.mcp.json')
    for user_file in (Path.home() / '.claude.json', home_config / '.claude.json'):
        if not user_file.is_file():
            continue
        user = json.loads(user_file.read_text())
        if 'framework-search' in user.get('mcpServers', {}):
            raise PolicyError('Reserved framework-search registration conflicts with managed search')
        project = user.get('projects', {}).get(str(Path.cwd()), {})
        if 'framework-search' in project.get('mcpServers', {}):
            raise PolicyError('Reserved project MCP registration conflicts with managed search')
    for path in configs:
        if path.is_file() and 'framework-search' in json.loads(path.read_text()).get('mcpServers', {}):
            raise PolicyError('Reserved framework-search registration conflicts with managed search')
    denied = []
    for index, arg in enumerate(args):
        if arg == '--strict-mcp-config':
            raise PolicyError('Managed search conflicts with strict MCP config')
        if arg in ('--settings', '--tools') or arg.startswith(('--settings=', '--tools=')):
            raise PolicyError('Managed search conflicts with tool or settings overrides')
        if arg in ('--disallowedTools', '--disallowed-tools'):
            if index + 1 == len(args):
                raise PolicyError('Missing disallowed tools value')
            for value in args[index + 1:]:
                if value.startswith('-'):
                    break
                denied += value.replace(',', ' ').split()
        if arg.startswith(('--disallowedTools=', '--disallowed-tools=')):
            denied += arg.split('=', 1)[1].replace(',', ' ').split()
        if arg == '--mcp-config' or arg.startswith('--mcp-config='):
            values = [arg.split('=', 1)[1]] if '=' in arg else args[index + 1:]
            for value in values:
                if value.startswith('-'):
                    break
                config = json.loads(value if value.lstrip().startswith('{') else Path(value).read_text())
                if 'framework-search' in config.get('mcpServers', {}):
                    raise PolicyError('Reserved framework-search MCP registration already exists')
    if mode == 'native':
        if any(x in ('WebSearch', '*') or x.startswith('WebSearch(') for x in denied):
            raise PolicyError('Native search conflicts with existing WebSearch denial')
        return []
    result = ['--disallowedTools', ','.join(dict.fromkeys([*denied, 'WebSearch']))]
    if mode == 'framework':
        config = {'mcpServers': {'framework-search': {'type': 'stdio', 'command': command,
                  'env': {'FRAMEWORK_WEBSEARCH_URL': '${FRAMEWORK_WEBSEARCH_URL}',
                          'FRAMEWORK_WEBSEARCH_TOKEN': '${FRAMEWORK_WEBSEARCH_TOKEN}'}}}}
        result += ['--mcp-config', json.dumps(config, separators=(',', ':'))]
    return result


def main():
    import json
    import os
    import re
    import sys
    from urllib.parse import urlsplit
    routed, microvm, router_config, *args = sys.argv[1:]
    try:
        route_modes = json.loads(os.environ.get('ICLAUDE_SEARCH_ROUTE_MODES', '{}'))
        pair = selected_model(args, router_config) if routed == 'true' and route_modes else None
        mode = resolve_mode(routed=routed == 'true', native=os.environ.get('ICLAUDE_SEARCH_MODE', 'inherit'),
                            routed_default=os.environ.get('ICLAUDE_ROUTER_SEARCH_MODE', 'inherit'),
                            route_modes=route_modes, selected_pair=pair)
        if mode != 'inherit' and microvm == 'true':
            raise PolicyError('Managed search is unsupported in microVM mode')
        command = os.environ.get('ICLAUDE_SEARCH_MCP_COMMAND', '')
        if mode == 'framework':
            if not os.path.isabs(command) or not os.access(command, os.X_OK):
                raise PolicyError('Search MCP command must be an absolute executable path')
            endpoint = os.environ.get('ICLAUDE_SEARCH_API_URL', '')
            url = urlsplit(endpoint)
            if url.scheme != 'https' or not url.hostname or url.username or url.password or url.query or url.fragment or url.path != '/v1/websearch':
                raise PolicyError('Search API must be an HTTPS /v1/websearch endpoint')
            key = os.environ.get('ICLAUDE_SEARCH_API_ENV_KEY', '')
            if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', key) or not os.environ.get(key):
                raise PolicyError('Search API token environment variable is missing')
        for arg in [mode, *launch_arguments(mode, args, command)]:
            sys.stdout.buffer.write(arg.encode() + b'\0')
    except PolicyError as error:
        print(str(error), file=sys.stderr)
        return 1
    except (ValueError, OSError, IndexError, TypeError, AttributeError):
        print('Invalid managed search configuration or conflicting launch arguments', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
