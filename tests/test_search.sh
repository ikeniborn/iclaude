#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LIB_DIR="$ROOT/lib"
source "$LIB_DIR/search/search.sh"
export ICLAUDE_SEARCH_MODE=inherit
search_prepare_launch false false '' --strict-mcp-config
[[ ${#SEARCH_LAUNCH_ARGS[@]} == 0 ]]
export ICLAUDE_SEARCH_MODE=disabled
search_prepare_launch false false ''
[[ ${SEARCH_LAUNCH_ARGS[0]} == --disallowedTools && ${SEARCH_LAUNCH_ARGS[1]} == WebSearch ]]
export ICLAUDE_SEARCH_MODE=native ICLAUDE_ROUTER_SEARCH_MODE=disabled
search_prepare_launch true false ''
[[ ${SEARCH_LAUNCH_ARGS[1]} == WebSearch ]]
search_prepare_launch false false ''
[[ ${#SEARCH_LAUNCH_ARGS[@]} == 0 ]]
if search_prepare_launch false true ''; then exit 1; fi
export ICLAUDE_SEARCH_MODE=framework ICLAUDE_SEARCH_MCP_COMMAND=/bin/true
export ICLAUDE_SEARCH_API_URL=https://example.invalid/v1/websearch
export ICLAUDE_SEARCH_API_ENV_KEY=SEARCH_TEST_TOKEN SEARCH_TEST_TOKEN=synthetic-test-token
search_prepare_launch false false ''
[[ "$FRAMEWORK_WEBSEARCH_TOKEN" == synthetic-test-token ]]
[[ "${SEARCH_LAUNCH_ARGS[*]}" != *synthetic-test-token* ]]
[[ "${SEARCH_LAUNCH_ARGS[*]}" == *framework-search* ]]
echo 'search: mode, isolation, microVM, secret-free argv passed'
# A following inherit launch restores caller-owned canonical variables.
export ICLAUDE_SEARCH_MODE=inherit
search_prepare_launch false false ''
[[ -z ${FRAMEWORK_WEBSEARCH_TOKEN+x} && -z ${FRAMEWORK_WEBSEARCH_URL+x} ]]
export FRAMEWORK_WEBSEARCH_TOKEN=original-token FRAMEWORK_WEBSEARCH_URL=original-url
export ICLAUDE_SEARCH_MODE=framework
search_prepare_launch false false ''
export ICLAUDE_SEARCH_MODE=disabled
search_prepare_launch false false ''
[[ $FRAMEWORK_WEBSEARCH_TOKEN == original-token && $FRAMEWORK_WEBSEARCH_URL == original-url ]]
# The inherit fast path must not spawn Python, even with microVM enabled.
python3() { echo 'unexpected Python startup' >&2; return 99; }
export ICLAUDE_SEARCH_MODE=inherit
search_prepare_launch false true '' --strict-mcp-config
unset -f python3
[[ ${#SEARCH_LAUNCH_ARGS[@]} == 0 ]]
echo 'search: credential restoration and zero-process inherit passed'
