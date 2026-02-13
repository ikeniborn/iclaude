#!/bin/bash
# Statusline Integration Test
# Tests statusline.sh with all provider adapters

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSLINE_SCRIPT="$(cd "$TEST_DIR/.." && pwd)/claude-statusline.sh"
FIXTURES_DIR="$TEST_DIR/fixtures"

echo "=========================================="
echo "  Statusline Integration Tests"
echo "=========================================="
echo ""

# Test helper
test_provider() {
    local provider_name="$1"
    local fixture_file="$2"
    local expected_icon="$3"

    echo -n "Testing $provider_name... "

    # Run statusline with fixture
    local output
    output=$(cat "$fixture_file" | "$STATUSLINE_SCRIPT" 2>/dev/null | tail -1)

    # Check if output generated
    if [[ -z "$output" ]] || [[ "$output" == *"awaiting"* ]]; then
        echo -e "${RED}✗ FAILED${NC} (no output or awaiting)"
        echo "  Output: $output"
        return 1
    fi

    # Check for provider icon (if expected)
    if [[ -n "$expected_icon" ]] && [[ "$output" != *"$expected_icon"* ]]; then
        echo -e "${RED}✗ FAILED${NC} (missing icon)"
        echo "  Output: $output"
        echo "  Expected icon: $expected_icon"
        return 1
    fi

    # Check basic elements present
    if [[ "$output" != *"|"* ]] || [[ "$output" != *"$"* ]]; then
        echo -e "${RED}✗ FAILED${NC} (malformed output)"
        echo "  Output: $output"
        return 1
    fi

    echo -e "${GREEN}✓ PASSED${NC}"
    echo "  Output: $output"
    return 0
}

# Test 1: Anthropic (native Claude)
test_provider "Anthropic Claude" \
    "$FIXTURES_DIR/anthropic-session.json" \
    "" # No icon for native Claude

echo ""

# Test 2: OpenAI (DeepSeek)
test_provider "OpenAI/DeepSeek" \
    "$FIXTURES_DIR/openai-session.json" \
    "🤖"

echo ""

# Test 3: Ollama (local)
test_provider "Ollama Local" \
    "$FIXTURES_DIR/ollama-session.json" \
    "🦙"

echo ""

# Test 4: Google Gemini
test_provider "Google Gemini" \
    "$FIXTURES_DIR/gemini-session.json" \
    "✨"

echo ""

echo "=========================================="
echo "  All Integration Tests Completed"
echo "=========================================="
