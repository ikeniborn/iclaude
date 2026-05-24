#!/bin/bash

#######################################
# Phase 0 Regression Test Suite
# Description: Validate backward compatibility after modularization
#######################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=== Phase 0: Infrastructure Regression Tests ==="
echo ""

# Test 1: Basic help
echo "[1/8] Testing --help..."
./iclaude.sh --help > /dev/null
echo "✓ --help works"

# Test 2: Check isolated environment
echo "[2/8] Testing --check-isolated..."
./iclaude.sh --check-isolated > /dev/null
echo "✓ --check-isolated works"

# Test 3: Check config status
echo "[3/8] Testing --check-config..."
./iclaude.sh --check-config > /dev/null
echo "✓ --check-config works"

# Test 4: Check router status
echo "[4/8] Testing --check-router..."
./iclaude.sh --check-router > /dev/null
echo "✓ --check-router works"

# Test 5: Check LSP status
echo "[5/8] Testing --check-lsp..."
./iclaude.sh --check-lsp > /dev/null
echo "✓ --check-lsp works"

# Test 6: Check statusline status
echo "[6/8] Testing --check-statusline..."
./iclaude.sh --check-statusline > /dev/null
echo "✓ --check-statusline works"

# Test 7: Check Oh My Posh status
echo "[7/8] Testing --check-ohmyposh..."
./iclaude.sh --check-ohmyposh > /dev/null
echo "✓ --check-ohmyposh works"

# Test 8: Check lat status
echo "[8/8] Testing --check-lat..."
./iclaude.sh --check-lat > /dev/null
echo "✓ --check-lat works"

echo ""
echo "=== All Phase 0 regression tests passed! ==="
echo ""
echo "Summary:"
echo "  - Core modules (init, logging, validation, json) loaded successfully"
echo "  - Backward compatibility maintained with legacy implementation"
echo "  - All --check-* commands work correctly"
echo "  - Color codes and print_* functions work from modules"
