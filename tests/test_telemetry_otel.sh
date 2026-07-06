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

# Test 1: opt-in via USE_OTEL=true exports defaults
echo "Test 1: opt-in defaults (USE_OTEL=true)"
unset ICLAUDE_NO_TELEMETRY CLAUDE_CODE_ENABLE_TELEMETRY OTEL_METRICS_EXPORTER OTEL_LOGS_EXPORTER OTEL_EXPORTER_OTLP_ENDPOINT OTEL_RESOURCE_ATTRIBUTES OTEL_LOG_USER_PROMPTS
USE_OTEL=true
source "$LIB_DIR/telemetry/otel.sh"
assert_eq "${CLAUDE_CODE_ENABLE_TELEMETRY:-unset}" "1" "CLAUDE_CODE_ENABLE_TELEMETRY=1"
assert_eq "${OTEL_METRICS_EXPORTER:-unset}" "otlp" "OTEL_METRICS_EXPORTER=otlp"
assert_eq "${OTEL_LOGS_EXPORTER:-unset}" "otlp" "OTEL_LOGS_EXPORTER=otlp"
assert_eq "${OTEL_EXPORTER_OTLP_ENDPOINT:-unset}" "http://127.0.0.1:4318" "endpoint default"
assert_eq "${OTEL_LOG_USER_PROMPTS:-unset}" "0" "OTEL_LOG_USER_PROMPTS default 0"
[[ "${OTEL_RESOURCE_ATTRIBUTES:-}" == *"service.name=claude-code"* ]] && { echo "  ✓ resource attrs contain service.name"; PASS=$((PASS+1)); } || { echo "  ✗ resource attrs missing service.name"; FAIL=$((FAIL+1)); }
[[ "${OTEL_RESOURCE_ATTRIBUTES:-}" == *"wrapper.version=test-1.0"* ]] && { echo "  ✓ wrapper.version"; PASS=$((PASS+1)); } || { echo "  ✗ wrapper.version"; FAIL=$((FAIL+1)); }
[[ "${OTEL_RESOURCE_ATTRIBUTES:-}" == *"proxy.profile=testprofile"* ]] && { echo "  ✓ proxy.profile"; PASS=$((PASS+1)); } || { echo "  ✗ proxy.profile"; FAIL=$((FAIL+1)); }

# Test 2: off by default (no USE_OTEL = opt-in not set)
echo "Test 2: off when USE_OTEL unset"
unset CLAUDE_CODE_ENABLE_TELEMETRY OTEL_METRICS_EXPORTER OTEL_RESOURCE_ATTRIBUTES OTEL_LOG_USER_PROMPTS ICLAUDE_NO_TELEMETRY USE_OTEL
source "$LIB_DIR/telemetry/otel.sh"
assert_eq "${CLAUDE_CODE_ENABLE_TELEMETRY:-unset}" "unset" "no enable when USE_OTEL unset"
assert_eq "${OTEL_RESOURCE_ATTRIBUTES:-unset}" "unset" "no resource attrs when USE_OTEL unset"

# Test 3: kill-switch ICLAUDE_NO_TELEMETRY=1 overrides USE_OTEL=true
echo "Test 3: kill-switch overrides opt-in"
unset CLAUDE_CODE_ENABLE_TELEMETRY OTEL_RESOURCE_ATTRIBUTES OTEL_LOG_USER_PROMPTS
USE_OTEL=true
ICLAUDE_NO_TELEMETRY=1
source "$LIB_DIR/telemetry/otel.sh"
assert_eq "${CLAUDE_CODE_ENABLE_TELEMETRY:-unset}" "unset" "kill-switch wins over USE_OTEL"

# Test 4: CREDENTIALS -> HEADERS auth generation (the actual bug)
echo "Test 4: CREDENTIALS -> HEADERS"
unset ICLAUDE_NO_TELEMETRY CLAUDE_CODE_ENABLE_TELEMETRY OTEL_EXPORTER_OTLP_HEADERS OTEL_RESOURCE_ATTRIBUTES OTEL_LOG_USER_PROMPTS
USE_OTEL=true
OTEL_EXPORTER_OTLP_CREDENTIALS="otel:secret"
source "$LIB_DIR/telemetry/otel.sh"
expected_hdr="Authorization=Basic $(printf '%s' 'otel:secret' | base64 -w 0)"
assert_eq "${OTEL_EXPORTER_OTLP_HEADERS:-unset}" "$expected_hdr" "HEADERS generated from CREDENTIALS"
unset OTEL_EXPORTER_OTLP_CREDENTIALS OTEL_EXPORTER_OTLP_HEADERS

# Test 5: config-provided OTEL_LOG_USER_PROMPTS is preserved (not clobbered)
echo "Test 5: OTEL_LOG_USER_PROMPTS preserve"
unset ICLAUDE_NO_TELEMETRY CLAUDE_CODE_ENABLE_TELEMETRY OTEL_RESOURCE_ATTRIBUTES
USE_OTEL=true
OTEL_LOG_USER_PROMPTS=1
source "$LIB_DIR/telemetry/otel.sh"
assert_eq "${OTEL_LOG_USER_PROMPTS:-unset}" "1" "config value 1 preserved"

# Test 6: project detection in non-git dir
echo "Test 6: project detection (non-git)"
unset ICLAUDE_NO_TELEMETRY CLAUDE_CODE_ENABLE_TELEMETRY OTEL_RESOURCE_ATTRIBUTES OTEL_LOG_USER_PROMPTS
USE_OTEL=true
TMPDIR_TEST=$(mktemp -d)
pushd "$TMPDIR_TEST" >/dev/null
source "$LIB_DIR/telemetry/otel.sh"
expected_project=$(basename "$TMPDIR_TEST")
[[ "${OTEL_RESOURCE_ATTRIBUTES:-}" == *"iclaude.project=${expected_project}"* ]] && { echo "  ✓ iclaude.project=$expected_project"; PASS=$((PASS+1)); } || { echo "  ✗ iclaude.project missing/wrong"; FAIL=$((FAIL+1)); }
popd >/dev/null
rm -rf "$TMPDIR_TEST"

echo ""
echo "Result: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
