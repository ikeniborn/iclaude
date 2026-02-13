#!/bin/bash
# Streaming System Unit Tests
# Tests streaming detection, state management, and chunk parsing

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$TEST_DIR/../lib" && pwd)"

# Source streaming modules
source "$LIB_DIR/streaming-detector.sh"
source "$LIB_DIR/streaming-state.sh"
source "$LIB_DIR/streaming-parser.sh"

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

assert_false() {
    local command="$1"
    local test_name="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if ! eval "$command"; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Command should have failed: $command"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "=========================================="
echo "  Streaming System - Unit Tests"
echo "=========================================="
echo ""

# Test Suite 1: Streaming Detection
echo "Test Suite 1: Streaming Detection"
echo "----------------------------"

# Anthropic chunks
ANTHROPIC_START='{"type":"message_start","message":{"id":"msg_123","usage":{"input_tokens":1000}}}'
ANTHROPIC_DELTA='{"type":"message_delta","usage":{"output_tokens":50}}'
ANTHROPIC_STOP='{"type":"message_stop"}'
COMPLETE_RESPONSE='{"usage":{"prompt_tokens":1000,"completion_tokens":500}}'

assert_true 'is_streaming_chunk "$ANTHROPIC_START"' "Detect Anthropic message_start"
assert_true 'is_streaming_chunk "$ANTHROPIC_DELTA"' "Detect Anthropic message_delta"
assert_true 'is_streaming_chunk "$ANTHROPIC_STOP"' "Detect Anthropic message_stop"
assert_false 'is_streaming_chunk "$COMPLETE_RESPONSE"' "Reject complete response"

# OpenAI chunks
OPENAI_DELTA='{"choices":[{"delta":{"content":"Hello"},"index":0}]}'
OPENAI_STOP='{"choices":[{"delta":{},"finish_reason":"stop"}]}'

assert_true 'is_streaming_chunk "$OPENAI_DELTA"' "Detect OpenAI delta"
assert_true 'is_streaming_chunk "$OPENAI_STOP"' "Detect OpenAI stop"

# Ollama chunks
OLLAMA_DELTA='{"model":"llama3.1","done":false,"message":{"content":"Hi"}}'
OLLAMA_STOP='{"model":"llama3.1","done":true,"eval_count":127}'

assert_true 'is_streaming_chunk "$OLLAMA_DELTA"' "Detect Ollama streaming"
assert_true 'is_streaming_chunk "$OLLAMA_STOP"' "Detect Ollama done"

# Chunk type detection
TYPE_START=$(get_chunk_type "$ANTHROPIC_START")
assert_equals "start" "$TYPE_START" "Get chunk type: start"

TYPE_DELTA=$(get_chunk_type "$ANTHROPIC_DELTA")
assert_equals "delta" "$TYPE_DELTA" "Get chunk type: delta"

TYPE_STOP=$(get_chunk_type "$ANTHROPIC_STOP")
assert_equals "stop" "$TYPE_STOP" "Get chunk type: stop"

# Final chunk detection
assert_true 'is_final_chunk "$ANTHROPIC_STOP"' "Detect final chunk (Anthropic)"
assert_false 'is_final_chunk "$ANTHROPIC_START"' "Reject non-final chunk"

# Provider detection
PROVIDER_ANTHROPIC=$(get_streaming_provider "$ANTHROPIC_START")
assert_equals "anthropic" "$PROVIDER_ANTHROPIC" "Detect Anthropic provider"

PROVIDER_OPENAI=$(get_streaming_provider "$OPENAI_DELTA")
assert_equals "openai" "$PROVIDER_OPENAI" "Detect OpenAI provider"

PROVIDER_OLLAMA=$(get_streaming_provider "$OLLAMA_DELTA")
assert_equals "ollama" "$PROVIDER_OLLAMA" "Detect Ollama provider"

echo ""

# Test Suite 2: State Management
echo "Test Suite 2: State Management"
echo "----------------------------"

# Setup test environment
TEST_SESSION_ID="test_session_$$"
export CLAUDE_DIR="/tmp/claude-test-$$"
mkdir -p "$CLAUDE_DIR"

# Initialize state
assert_true 'init_streaming_state "$TEST_SESSION_ID" "anthropic" "claude-sonnet-4.5"' "Initialize streaming state"

# Check state exists
assert_true '[[ -f "$(get_state_file "$TEST_SESSION_ID")" ]]' "State file created"

# Get state
STATE=$(get_streaming_state "$TEST_SESSION_ID")
assert_true '[[ -n "$STATE" ]]' "Get streaming state"

# Check initial values
INITIAL_INPUT=$(echo "$STATE" | jq -r '.input_tokens')
assert_equals "0" "$INITIAL_INPUT" "Initial input tokens = 0"

INITIAL_OUTPUT=$(echo "$STATE" | jq -r '.output_tokens')
assert_equals "0" "$INITIAL_OUTPUT" "Initial output tokens = 0"

# Update state with tokens
UPDATE_DATA='{"input_tokens":1000,"cache_read_tokens":500}'
assert_true 'update_streaming_state "$TEST_SESSION_ID" "$UPDATE_DATA"' "Update streaming state"

# Check updated values
STATE=$(get_streaming_state "$TEST_SESSION_ID")
UPDATED_INPUT=$(echo "$STATE" | jq -r '.input_tokens')
assert_equals "1000" "$UPDATED_INPUT" "Input tokens updated to 1000"

CACHE_READ=$(echo "$STATE" | jq -r '.cache_read_tokens')
assert_equals "500" "$CACHE_READ" "Cache read tokens updated to 500"

# Accumulate more tokens
UPDATE_DATA2='{"output_tokens":50}'
assert_true 'update_streaming_state "$TEST_SESSION_ID" "$UPDATE_DATA2"' "Accumulate output tokens"

STATE=$(get_streaming_state "$TEST_SESSION_ID")
OUTPUT=$(echo "$STATE" | jq -r '.output_tokens')
assert_equals "50" "$OUTPUT" "Output tokens accumulated to 50"

# Check streaming active
assert_true 'is_streaming_active "$TEST_SESSION_ID"' "Streaming is active"

# Finalize state
assert_true 'finalize_streaming_state "$TEST_SESSION_ID"' "Finalize streaming state"

# Check not active after finalize
assert_false 'is_streaming_active "$TEST_SESSION_ID"' "Streaming not active after finalize"

# Cleanup test state
delete_streaming_state "$TEST_SESSION_ID"
rm -rf "$CLAUDE_DIR"
unset CLAUDE_DIR

echo ""

# Test Suite 3: Chunk Parsing
echo "Test Suite 3: Chunk Parsing"
echo "----------------------------"

# Parse Anthropic message_start
PARSED=$(parse_anthropic_chunk "$ANTHROPIC_START")
PARSED_INPUT=$(echo "$PARSED" | jq -r '.input_tokens')
assert_equals "1000" "$PARSED_INPUT" "Parse Anthropic start: input tokens"

# Parse Anthropic message_delta
PARSED=$(parse_anthropic_chunk "$ANTHROPIC_DELTA")
PARSED_OUTPUT=$(echo "$PARSED" | jq -r '.output_tokens')
assert_equals "50" "$PARSED_OUTPUT" "Parse Anthropic delta: output tokens"

# Parse Anthropic message_stop
PARSED=$(parse_anthropic_chunk "$ANTHROPIC_STOP")
PARSED_COMPLETED=$(echo "$PARSED" | jq -r '.completed')
assert_equals "true" "$PARSED_COMPLETED" "Parse Anthropic stop: completed=true"

# Parse OpenAI delta
PARSED=$(parse_openai_chunk "$OPENAI_DELTA")
assert_true '[[ -n "$PARSED" ]]' "Parse OpenAI delta chunk"

# Parse OpenAI stop
PARSED=$(parse_openai_chunk "$OPENAI_STOP")
PARSED_COMPLETED=$(echo "$PARSED" | jq -r '.completed')
assert_equals "true" "$PARSED_COMPLETED" "Parse OpenAI stop: completed=true"

# Parse Ollama stop
PARSED=$(parse_ollama_chunk "$OLLAMA_STOP")
PARSED_OUTPUT=$(echo "$PARSED" | jq -r '.output_tokens')
assert_equals "127" "$PARSED_OUTPUT" "Parse Ollama stop: eval_count=127"

# Auto-detect and parse
PARSED=$(parse_streaming_chunk "$ANTHROPIC_START")
PARSED_INPUT=$(echo "$PARSED" | jq -r '.input_tokens')
assert_equals "1000" "$PARSED_INPUT" "Auto-parse Anthropic chunk"

PARSED=$(parse_streaming_chunk "$OPENAI_DELTA")
assert_true '[[ -n "$PARSED" ]]' "Auto-parse OpenAI chunk"

PARSED=$(parse_streaming_chunk "$OLLAMA_STOP")
assert_true '[[ -n "$PARSED" ]]' "Auto-parse Ollama chunk"

echo ""

# Test Summary
echo "=========================================="
echo "  Test Results"
echo "=========================================="
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
