#!/usr/bin/env bash
# Exercise launcher branches with recording executables and synthetic credentials.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" LIB_DIR="$ROOT/lib"
export ISOLATED_CONFIG_DIR="$TMP/store" CLAUDE_CONFIG_DIR="$TMP/store" ISOLATED_NVM_DIR="$TMP/nvm"
mkdir -p "$HOME" "$TMP/project" "$TMP/store/mcp" "$TMP/nvm/versions/node"
cd "$TMP/project"
cp "$ROOT/.claude-isolated/mcp/iwiki"*.json "$TMP/store/mcp/"
printf '%s' '{"mcpServers":{"user-tool":{"command":"/bin/true"}}}' > user.json
source "$LIB_DIR/launcher/launch.sh"
source "$LIB_DIR/iwiki/mcp.sh"
source "$LIB_DIR/search/search.sh"
print_info() { :; }; print_warning() { :; }; print_error() { echo "$*" >&2; }
cleanup_stale_session_env() { :; }
detect_router() { return 0; }
get_router_path() { printf '%s' "$TMP/record"; }
detect_nvm() { return 0; }
get_nvm_claude_path() { printf '%s' "$TMP/record"; }
get_cli_version() { echo unknown; }
detect_pii_proxy() { return 0; }
start_ccr_server() { echo ccr >> "$CAPTURE.services"; export ANTHROPIC_BASE_URL=http://ccr.invalid; }
stop_ccr_server() { :; }
start_pii_proxy_server() { echo pii >> "$CAPTURE.services"; export ANTHROPIC_BASE_URL=http://pii.invalid; }
stop_pii_proxy_server() { :; }
cat > "$TMP/record" <<'REC'
#!/usr/bin/env bash
if [[ "${1:-}" == -v ]]; then echo mock; exit; fi
printf '%s\0' "$@" > "$CAPTURE"
printf '%s\0' "${FRAMEWORK_WEBSEARCH_TOKEN:-}" "${ANTHROPIC_API_KEY:-}" "${ANTHROPIC_BASE_URL:-}" > "$CAPTURE.context"
REC
chmod +x "$TMP/record"
export IWIKI_COMMAND=/bin/true IWIKI_REMOTE_URL=https://example.invalid/mcp IWIKI_REMOTE_TOKEN=synthetic-wiki
unset IWIKI_LLM_KEY IWIKI_CODE_GRAPH_MCP_TOKEN IWIKI_CODE_GRAPH_MCP_URL
export ANTHROPIC_API_KEY=synthetic-provider ICLAUDE_SEARCH_MCP_COMMAND="$TMP/record"
export ICLAUDE_SEARCH_API_URL=https://example.invalid/v1/websearch
export ICLAUDE_SEARCH_API_ENV_KEY=SEARCH_FIXTURE_TOKEN SEARCH_FIXTURE_TOKEN=synthetic-search
for path in native solo combined pii; do
    for mode in inherit native disabled framework; do
        export CAPTURE="$TMP/$path-$mode"
        export USE_ROUTER_FLAG=false USE_PII_PROXY_FLAG=false
        [[ "$path" != solo && "$path" != combined ]] || export USE_ROUTER_FLAG=true
        [[ "$path" != pii && "$path" != combined ]] || export USE_PII_PROXY_FLAG=true
        export ICLAUDE_SEARCH_MODE="$mode" ICLAUDE_ROUTER_SEARCH_MODE="$mode"
        (launch_claude false --print 'prompt with spaces' --mcp-config "$TMP/project/user.json") >/dev/null
        python3 - "$CAPTURE" "$path" "$mode" "$TMP" <<'PY'
import json, pathlib, sys
capture, path, mode, root = sys.argv[1:]
args = pathlib.Path(capture).read_bytes().decode().rstrip('\0').split('\0')
assert (args[0] == 'code') == (path == 'solo'), args
assert args[-4:] == ['--print', 'prompt with spaces', '--mcp-config', root + '/project/user.json'], args
assert root + '/store/mcp/iwiki-remote.json' in args, args
assert ('--disallowedTools' in args) == (mode in ('disabled', 'framework')), args
configs = [args[i + 1] for i, a in enumerate(args[:-1]) if a == '--mcp-config']
managed = [json.loads(c) for c in configs if c.startswith('{')]
assert bool(managed) == (mode == 'framework'), args
if managed:
    assert list(managed[0]['mcpServers']) == ['framework-search']
assert 'synthetic-search' not in str(args)
context = pathlib.Path(capture + '.context').read_bytes().decode().split('\0')
assert context[0] == ('synthetic-search' if mode == 'framework' else '')
assert context[1] == 'synthetic-provider'
if path in ('pii', 'combined'):
    assert context[2] == 'http://pii.invalid'
services = pathlib.Path(capture + '.services')
assert services.exists() == (path in ('pii', 'combined'))
if services.exists():
    assert services.read_text().splitlines() == (['ccr', 'pii'] if path == 'combined' else ['pii'])
PY
    done
done
[[ $(cat user.json) == '{"mcpServers":{"user-tool":{"command":"/bin/true"}}}' ]]
echo 'search-launch: 16 native/CCR/PII combinations passed'
