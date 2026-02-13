#!/bin/bash
# Streaming Integration Tests
# Tests streaming flow through provider-adapter

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$TEST_DIR/../lib" && pwd)"

# Source provider adapter (includes streaming modules)
source "$LIB_DIR/provider-adapter.sh"

# Test helper
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_true() {
    local command="$1"
    local test_name="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$command"; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Command failed: $command"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "=========================================="
echo "  Streaming Integration Tests"
echo "=========================================="
echo ""

# Setup test environment
TEST_SESSION_ID="integration_test_$$"
export CLAUDE_DIR="/tmp/claude-streaming-test-$$"
mkdir -p "$CLAUDE_DIR"
export DEBUG_STATUSLINE=0  # Disable debug output for clean test results

echo "Test Suite: Anthropic Streaming Flow"
echo "----------------------------"

# Anthropic streaming sequence
CHUNK1='{"type":"message_start","message":{"id":"msg_123","model":"claude-sonnet-4.5","usage":{"input_tokens":1000,"cache_read_input_tokens":500}}}'
CHUNK2='{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}'
CHUNK3='{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":50}}'
CHUNK4='{"type":"message_stop"}'

# Process chunk 1 (message_start)
parse_with_adapter "$CHUNK1" "$TEST_SESSION_ID"
assert_equals "1000" "$TOTAL_INPUT" "Chunk 1: Input tokens = 1000"
assert_equals "0" "$TOTAL_OUTPUT" "Chunk 1: Output tokens = 0"
assert_equals "500" "$CACHE_READ" "Chunk 1: Cache read = 500"
assert_equals "1" "$STREAMING_ACTIVE" "Chunk 1: Streaming active"

# Process chunk 2 (content_block_delta) - no token changes
parse_with_adapter "$CHUNK2" "$TEST_SESSION_ID"
assert_equals "1000" "$TOTAL_INPUT" "Chunk 2: Input tokens unchanged"
assert_equals "0" "$TOTAL_OUTPUT" "Chunk 2: Output tokens still 0"

# Process chunk 3 (message_delta) - output tokens added
parse_with_adapter "$CHUNK3" "$TEST_SESSION_ID"
assert_equals "1000" "$TOTAL_INPUT" "Chunk 3: Input tokens unchanged"
assert_equals "50" "$TOTAL_OUTPUT" "Chunk 3: Output tokens = 50"

# Process chunk 4 (message_stop)
parse_with_adapter "$CHUNK4" "$TEST_SESSION_ID"
assert_equals "50" "$TOTAL_OUTPUT" "Chunk 4: Output tokens still 50"

# Check state is marked as completed
STATE=$(get_streaming_state "$TEST_SESSION_ID")
COMPLETED=$(echo "$STATE" | jq -r '.completed')
assert_equals "true" "$COMPLETED" "Stream marked as completed"

echo ""

echo "Test Suite: Non-Streaming (Complete Response)"
echo "----------------------------"

# Complete response (non-streaming)
COMPLETE='{"context_window":{"total_input_tokens":2000,"total_output_tokens":300,"context_window_size":200000,"current_usage":{"cache_read_input_tokens":100,"cache_creation_input_tokens":50}},"model":{"display_name":"Claude Sonnet 4.5"},"cost":{"total_cost_usd":0.50}}'

# Reset globals
unset TOTAL_INPUT TOTAL_OUTPUT CACHE_READ STREAMING_ACTIVE

# Parse complete response
parse_with_adapter "$COMPLETE"
assert_equals "2000" "$TOTAL_INPUT" "Complete: Input tokens = 2000"
assert_equals "300" "$TOTAL_OUTPUT" "Complete: Output tokens = 300"
assert_equals "100" "$CACHE_READ" "Complete: Cache read = 100"
assert_equals "0.50" "$COST" "Complete: Cost = 0.50"
assert_true '[[ -z "${STREAMING_ACTIVE:-}" ]]' "Complete: Not streaming"

echo ""

echo "Test Suite: OpenAI Streaming Flow"
echo "----------------------------"

TEST_SESSION_ID="openai_test_$$"

# OpenAI streaming sequence
OPENAI_CHUNK1='{"id":"chatcmpl-123","choices":[{"delta":{"content":"Hello"},"index":0}]}'
OPENAI_CHUNK2='{"id":"chatcmpl-123","choices":[{"delta":{"content":" world"},"index":0}]}'
OPENAI_CHUNK3='{"id":"chatcmpl-123","choices":[{"delta":{},"finish_reason":"stop","index":0}],"model":"gpt-4o"}'

# Process chunks
parse_with_adapter "$OPENAI_CHUNK1" "$TEST_SESSION_ID"
assert_equals "1" "$STREAMING_ACTIVE" "OpenAI: Streaming active"

parse_with_adapter "$OPENAI_CHUNK2" "$TEST_SESSION_ID"
assert_equals "1" "$STREAMING_ACTIVE" "OpenAI: Still streaming"

parse_with_adapter "$OPENAI_CHUNK3" "$TEST_SESSION_ID"
STATE=$(get_streaming_state "$TEST_SESSION_ID")
COMPLETED=$(echo "$STATE" | jq -r '.completed')
assert_equals "true" "$COMPLETED" "OpenAI: Stream completed"

echo ""

echo "Test Suite: Ollama Streaming Flow"
echo "----------------------------"

TEST_SESSION_ID="ollama_test_$$"

# Ollama streaming sequence
OLLAMA_CHUNK1='{"model":"llama3.1","done":false,"message":{"content":"Hi"}}'
OLLAMA_CHUNK2='{"model":"llama3.1","done":false,"message":{"content":" there"}}'
OLLAMA_CHUNK3='{"model":"llama3.1","done":true,"prompt_eval_count":100,"eval_count":25}'

# Process chunks
parse_with_adapter "$OLLAMA_CHUNK1" "$TEST_SESSION_ID"
assert_equals "1" "$STREAMING_ACTIVE" "Ollama: Streaming active"

parse_with_adapter "$OLLAMA_CHUNK2" "$TEST_SESSION_ID"
assert_equals "1" "$STREAMING_ACTIVE" "Ollama: Still streaming"

parse_with_adapter "$OLLAMA_CHUNK3" "$TEST_SESSION_ID"
assert_equals "100" "$TOTAL_INPUT" "Ollama: Input tokens = 100"
assert_equals "25" "$TOTAL_OUTPUT" "Ollama: Output tokens = 25"

STATE=$(get_streaming_state "$TEST_SESSION_ID")
COMPLETED=$(echo "$STATE" | jq -r '.completed')
assert_equals "true" "$COMPLETED" "Ollama: Stream completed"

echo ""

# Cleanup
rm -rf "$CLAUDE_DIR"
unset CLAUDE_DIR

# Test Summary
echo "=========================================="
echo "  Test Results"
echo "=========================================="
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
