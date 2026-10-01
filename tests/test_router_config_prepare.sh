#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/lib/router/detect.sh"
TASK_TMP=$(mktemp -d)
trap 'rm -rf "$TASK_TMP"' EXIT
printf '%s\n' '{"Providers":[{"api_key":"${ROUTER_API_KEY}"}],"transformers":[{"path":"${CLAUDE_CONFIG_DIR}/.claude-code-router/plugins/framework-request.js"}]}' > "$TASK_TMP/source.json"
prepare_router_config "$TASK_TMP/source.json" "$TASK_TMP/runtime.json" "$TASK_TMP/project home"
python3 - "$TASK_TMP/runtime.json" "$TASK_TMP/project home" <<'CHECK'
import json, sys
with open(sys.argv[1]) as f: data = json.load(f)
assert data['Providers'][0]['api_key'] == '${ROUTER_API_KEY}'
assert data['transformers'][0]['path'] == sys.argv[2] + '/.claude-code-router/plugins/framework-request.js'
print('Runtime plugin path and credential placeholder: PASS')
CHECK
