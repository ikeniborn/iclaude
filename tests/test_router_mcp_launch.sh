#!/usr/bin/env bash
# Exercise the real solo-router launch with a recording CCR executable.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
source "$ROOT/lib/launcher/launch.sh"
source "$ROOT/lib/iwiki/mcp.sh"
print_info() { :; }
print_warning() { :; }
print_error() { echo "$*" >&2; }
cleanup_stale_session_env() { :; }
detect_router() { return 0; }
get_router_path() { printf '%s' "$TMP/ccr"; }
mkdir -p "$TMP/store/mcp" "$TMP/nvm"
cp "$ROOT/.claude-isolated/mcp/iwiki"*.json "$TMP/store/mcp/"
cat > "$TMP/ccr" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == -v ]]; then echo 'mock CCR'; exit 0; fi
printf '%s\0' "$@" > "$CAPTURE"
printf '%s' "${IWIKI_COMMAND:-}" > "$CAPTURE.command"
SH
chmod +x "$TMP/ccr"
export USE_ROUTER_FLAG=true ISOLATED_CONFIG_DIR="$TMP/store"
export CLAUDE_CONFIG_DIR="$TMP/store" ISOLATED_NVM_DIR="$TMP/nvm"
export IWIKI_COMMAND=/test/iwiki-mcp IWIKI_LLM_KEY=test-key
export IWIKI_REMOTE_URL=https://example.invalid/mcp IWIKI_REMOTE_TOKEN=test-token
export CAPTURE="$TMP/args"
for mode in dual remote disabled; do
    (
        set +e
        case "$mode" in
            remote) unset IWIKI_LLM_KEY ;;
            disabled) unset IWIKI_LLM_KEY IWIKI_REMOTE_TOKEN ;;
        esac
        launch_claude false --print 'prompt with spaces' --mcp-config extra.json
    ) >/dev/null
    python3 - "$CAPTURE" "$TMP/store" "$mode" <<'PY'
import pathlib, sys
capture, store, mode = sys.argv[1:]
args = pathlib.Path(capture).read_bytes().decode().rstrip('\0').split('\0')
expected = ['code']
if mode != 'disabled':
    suffix = 'dual' if mode == 'dual' else 'remote'
    expected += ['--mcp-config', f'{store}/mcp/iwiki-{suffix}.json']
expected += ['--print', 'prompt with spaces', '--mcp-config', 'extra.json']
assert args == expected, (mode, args, expected)
assert pathlib.Path(capture + '.command').read_text() == '/test/iwiki-mcp'
PY
done
echo 'router-mcp-launch: 3 modes passed; user arguments preserved'
