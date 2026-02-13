#!/bin/bash
# Adapter System Unit Tests
# Tests all provider adapters with mock fixtures

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$TEST_DIR/../lib" && pwd)"
FIXTURES_DIR="$TEST_DIR/fixtures"

# Source adapter system
source "$LIB_DIR/provider-adapter.sh"

# Test result helper
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

assert_not_empty() {
    local value="$1"
    local test_name="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -n "$value" ]] && [[ "$value" != "null" ]] && [[ "$value" != "0" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Value is empty or null: '$value'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "=========================================="
echo "  Provider Adapter System - Unit Tests"
echo "=========================================="
echo ""

# Test 1: Provider Detection
echo "Test Suite: Provider Detection"
echo "----------------------------"

SESSION_ANTHROPIC=$(cat "$FIXTURES_DIR/anthropic-session.json")
DETECTED=$(detect_provider_type "$SESSION_ANTHROPIC")
assert_equals "anthropic" "$DETECTED" "Detect Anthropic Claude format"

SESSION_OPENAI=$(cat "$FIXTURES_DIR/openai-session.json")
DETECTED=$(detect_provider_type "$SESSION_OPENAI")
assert_equals "openai" "$DETECTED" "Detect OpenAI format"

SESSION_OLLAMA=$(cat "$FIXTURES_DIR/ollama-session.json")
DETECTED=$(detect_provider_type "$SESSION_OLLAMA")
assert_equals "ollama" "$DETECTED" "Detect Ollama format"

SESSION_GEMINI=$(cat "$FIXTURES_DIR/gemini-session.json")
DETECTED=$(detect_provider_type "$SESSION_GEMINI")
assert_equals "gemini" "$DETECTED" "Detect Gemini format"

echo ""

# Test 2: Anthropic Adapter
echo "Test Suite: Anthropic Adapter"
echo "----------------------------"

source "$LIB_DIR/adapters/anthropic.sh"
UNIFIED=$(parse_anthropic_data "$SESSION_ANTHROPIC")

INPUT_TOKENS=$(echo "$UNIFIED" | jq -r '.total_input_tokens')
assert_equals "50000" "$INPUT_TOKENS" "Anthropic: Parse input tokens"

OUTPUT_TOKENS=$(echo "$UNIFIED" | jq -r '.total_output_tokens')
assert_equals "10000" "$OUTPUT_TOKENS" "Anthropic: Parse output tokens"

CACHE_READ=$(echo "$UNIFIED" | jq -r '.cache_read_tokens')
assert_equals "15000" "$CACHE_READ" "Anthropic: Parse cache read tokens"

COST=$(echo "$UNIFIED" | jq -r '.total_cost_usd')
assert_equals "1.05" "$COST" "Anthropic: Parse cost"

MODEL=$(echo "$UNIFIED" | jq -r '.model_name')
assert_equals "Sonnet 4.5" "$MODEL" "Anthropic: Parse model name"

echo ""

# Test 3: OpenAI Adapter
echo "Test Suite: OpenAI Adapter"
echo "----------------------------"

source "$LIB_DIR/adapters/openai.sh"
UNIFIED=$(parse_openai_data "$SESSION_OPENAI")

INPUT_TOKENS=$(echo "$UNIFIED" | jq -r '.total_input_tokens')
assert_equals "1500" "$INPUT_TOKENS" "OpenAI: Parse prompt tokens"

OUTPUT_TOKENS=$(echo "$UNIFIED" | jq -r '.total_output_tokens')
assert_equals "500" "$OUTPUT_TOKENS" "OpenAI: Parse completion tokens"

CACHE_READ=$(echo "$UNIFIED" | jq -r '.cache_read_tokens')
assert_equals "0" "$CACHE_READ" "OpenAI: Cache read = 0 (not supported)"

COST=$(echo "$UNIFIED" | jq -r '.total_cost_usd')
assert_not_empty "$COST" "OpenAI: Cost calculated"

MODEL=$(echo "$UNIFIED" | jq -r '.model_name')
assert_equals "DeepSeek Chat" "$MODEL" "OpenAI: Model display name"

echo ""

# Test 4: Ollama Adapter
echo "Test Suite: Ollama Adapter"
echo "----------------------------"

source "$LIB_DIR/adapters/ollama.sh"
UNIFIED=$(parse_ollama_data "$SESSION_OLLAMA")

INPUT_TOKENS=$(echo "$UNIFIED" | jq -r '.total_input_tokens')
assert_equals "850" "$INPUT_TOKENS" "Ollama: Parse prompt tokens"

OUTPUT_TOKENS=$(echo "$UNIFIED" | jq -r '.total_output_tokens')
assert_equals "320" "$OUTPUT_TOKENS" "Ollama: Parse completion tokens"

COST=$(echo "$UNIFIED" | jq -r '.total_cost_usd')
assert_equals "0" "$COST" "Ollama: Cost = 0 (local model)"

MODEL=$(echo "$UNIFIED" | jq -r '.model_name')
[[ "$MODEL" == *"local"* ]] && assert_equals "0" "0" "Ollama: Model name contains 'local'" || assert_equals "1" "0" "Ollama: Model name should contain 'local'"

echo ""

# Test 5: Gemini Adapter
echo "Test Suite: Gemini Adapter"
echo "----------------------------"

source "$LIB_DIR/adapters/gemini.sh"
UNIFIED=$(parse_gemini_data "$SESSION_GEMINI")

INPUT_TOKENS=$(echo "$UNIFIED" | jq -r '.total_input_tokens')
assert_equals "2500" "$INPUT_TOKENS" "Gemini: Parse prompt token count"

OUTPUT_TOKENS=$(echo "$UNIFIED" | jq -r '.total_output_tokens')
assert_equals "800" "$OUTPUT_TOKENS" "Gemini: Parse candidates token count"

COST=$(echo "$UNIFIED" | jq -r '.total_cost_usd')
assert_not_empty "$COST" "Gemini: Cost calculated"

MODEL=$(echo "$UNIFIED" | jq -r '.model_name')
assert_equals "Gemini 2.5 Pro" "$MODEL" "Gemini: Model display name"

echo ""

# Test 6: Generic Adapter (Fallback)
echo "Test Suite: Generic Adapter"
echo "----------------------------"

source "$LIB_DIR/adapters/generic.sh"

# Test with completely unknown format
UNKNOWN_SESSION='{"some_field": "value", "other_data": 123}'
UNIFIED=$(parse_generic_data "$UNKNOWN_SESSION")

# Should return valid JSON even with no recognizable data
RESULT=$(echo "$UNIFIED" | jq -r '.total_input_tokens')
assert_equals "0" "$RESULT" "Generic: Returns 0 tokens for unknown format"

MODEL=$(echo "$UNIFIED" | jq -r '.model_name')
assert_equals "Unknown Provider" "$MODEL" "Generic: Returns 'Unknown Provider'"

echo ""

# Test 7: Integration Test
echo "Test Suite: Full Integration"
echo "----------------------------"

# Test parse_with_adapter function
parse_with_adapter "$SESSION_ANTHROPIC"
assert_equals "anthropic" "$PROVIDER_TYPE" "Integration: Sets PROVIDER_TYPE"
assert_equals "50000" "$TOTAL_INPUT" "Integration: Sets TOTAL_INPUT"
assert_equals "10000" "$TOTAL_OUTPUT" "Integration: Sets TOTAL_OUTPUT"

echo ""

# Summary
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
