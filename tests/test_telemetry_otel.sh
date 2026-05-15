#!/bin/bash
# Unit tests for lib/telemetry/otel.sh
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then echo "  ✓ $3"; PASS=$((PASS+1)); else echo "  ✗ $3 (got: '$1' want: '$2')"; FAIL=$((FAIL+1)); fi; }

# Stubs
log_debug() { :; }
log_warn() { :; }
ICLAUDE_VERSION="test-1.0"
PROXY_PROFILE="testprofile"

# Test 1: defaults exported
echo "Test 1: defaults"
unset ICLAUDE_NO_TELEMETRY CLAUDE_CODE_ENABLE_TELEMETRY OTEL_METRICS_EXPORTER OTEL_LOGS_EXPORTER OTEL_EXPORTER_OTLP_ENDPOINT OTEL_RESOURCE_ATTRIBUTES OTEL_LOG_USER_PROMPTS
source "$LIB_DIR/telemetry/otel.sh"
assert_eq "$CLAUDE_CODE_ENABLE_TELEMETRY" "1" "CLAUDE_CODE_ENABLE_TELEMETRY=1"
assert_eq "$OTEL_METRICS_EXPORTER" "otlp" "OTEL_METRICS_EXPORTER=otlp"
assert_eq "$OTEL_LOGS_EXPORTER" "otlp" "OTEL_LOGS_EXPORTER=otlp"
assert_eq "$OTEL_EXPORTER_OTLP_ENDPOINT" "http://127.0.0.1:4318" "endpoint default"
assert_eq "$OTEL_LOG_USER_PROMPTS" "1" "OTEL_LOG_USER_PROMPTS=1"
[[ "$OTEL_RESOURCE_ATTRIBUTES" == *"service.name=claude-code"* ]] && { echo "  ✓ resource attrs contain service.name"; PASS=$((PASS+1)); } || { echo "  ✗ resource attrs missing service.name"; FAIL=$((FAIL+1)); }
[[ "$OTEL_RESOURCE_ATTRIBUTES" == *"wrapper.version=test-1.0"* ]] && { echo "  ✓ wrapper.version"; PASS=$((PASS+1)); } || { echo "  ✗ wrapper.version"; FAIL=$((FAIL+1)); }
[[ "$OTEL_RESOURCE_ATTRIBUTES" == *"proxy.profile=testprofile"* ]] && { echo "  ✓ proxy.profile"; PASS=$((PASS+1)); } || { echo "  ✗ proxy.profile"; FAIL=$((FAIL+1)); }

# Test 2: opt-out via ICLAUDE_NO_TELEMETRY=1
echo "Test 2: opt-out"
unset CLAUDE_CODE_ENABLE_TELEMETRY OTEL_METRICS_EXPORTER OTEL_RESOURCE_ATTRIBUTES
ICLAUDE_NO_TELEMETRY=1
source "$LIB_DIR/telemetry/otel.sh"
assert_eq "${CLAUDE_CODE_ENABLE_TELEMETRY:-unset}" "unset" "no enable when opted out"
assert_eq "${OTEL_RESOURCE_ATTRIBUTES:-unset}" "unset" "no resource attrs when opted out"

# Test 3: project detection in non-git dir
echo "Test 3: project detection (non-git)"
unset ICLAUDE_NO_TELEMETRY CLAUDE_CODE_ENABLE_TELEMETRY OTEL_RESOURCE_ATTRIBUTES
TMPDIR_TEST=$(mktemp -d)
pushd "$TMPDIR_TEST" >/dev/null
source "$LIB_DIR/telemetry/otel.sh"
expected_project=$(basename "$TMPDIR_TEST")
[[ "$OTEL_RESOURCE_ATTRIBUTES" == *"project=${expected_project}"* ]] && { echo "  ✓ project=$expected_project"; PASS=$((PASS+1)); } || { echo "  ✗ project missing/wrong"; FAIL=$((FAIL+1)); }
popd >/dev/null
rm -rf "$TMPDIR_TEST"

echo ""
echo "Result: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
