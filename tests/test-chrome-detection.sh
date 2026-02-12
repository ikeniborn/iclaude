#!/usr/bin/env bash
# Test suite for Chrome extension detection with spaces in profile names

set -uo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the detection library
source "$PROJECT_ROOT/lib/chrome/detection.sh"

# Helper function to print test results
print_test_result() {
    local test_name="$1"
    local result="$2"

    if [[ "$result" == "pass" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        ((TESTS_FAILED++))
    fi
}

# Create test Chrome config directory
create_test_chrome_dir() {
    local temp_dir="$1"
    local profile_name="$2"
    local has_extension="$3"

    local profile_path="$temp_dir/$profile_name/Extensions/fcoeoabgfenejglbffodgkkbkcdhcgfn/1.0.40_0"
    mkdir -p "$profile_path"

    if [[ "$has_extension" == "true" ]]; then
        # Create manifest.json with Claude in Chrome string
        cat > "$profile_path/manifest.json" <<EOF
{
  "name": "Claude in Chrome",
  "version": "1.0.40",
  "manifest_version": 3,
  "description": "Browser automation extension"
}
EOF
    else
        # Create manifest.json without Claude string
        cat > "$profile_path/manifest.json" <<EOF
{
  "name": "Some Other Extension",
  "version": "1.0.0",
  "manifest_version": 3
}
EOF
    fi
}

# Test 1: Default profile (no spaces)
test_default_profile() {
    local temp_dir="/tmp/test-chrome-detection-$$-default"
    trap "rm -rf '$temp_dir'" RETURN

    # Create Chrome config structure directly
    local chrome_config="$temp_dir/.config/google-chrome"
    mkdir -p "$chrome_config"
    create_test_chrome_dir "$chrome_config" "Default" "true"

    # Override HOME for this test
    HOME_BACKUP="$HOME"
    HOME="$temp_dir"

    if is_claude_chrome_extension_installed 2>/dev/null; then
        print_test_result "Test 1: Default profile (no spaces)" "pass"
    else
        print_test_result "Test 1: Default profile (no spaces)" "fail"
    fi

    HOME="$HOME_BACKUP"
}

# Test 2: Profile with space (main bug fix)
test_profile_with_space() {
    local temp_dir="/tmp/test-chrome-detection-$$-space"
    trap "rm -rf '$temp_dir'" RETURN

    # Create Chrome config structure directly
    local chrome_config="$temp_dir/.config/google-chrome"
    mkdir -p "$chrome_config"
    create_test_chrome_dir "$chrome_config" "Profile 1" "true"

    # Override HOME for this test
    HOME_BACKUP="$HOME"
    HOME="$temp_dir"

    if is_claude_chrome_extension_installed 2>/dev/null; then
        print_test_result "Test 2: Profile with space (Profile 1)" "pass"
    else
        print_test_result "Test 2: Profile with space (Profile 1)" "fail"
    fi

    HOME="$HOME_BACKUP"
}

# Test 3: Multiple profiles, extension in one with space
test_multiple_profiles() {
    local temp_dir="/tmp/test-chrome-detection-$$-multiple"
    trap "rm -rf '$temp_dir'" RETURN

    # Create Chrome config structure directly
    local chrome_config="$temp_dir/.config/google-chrome"
    mkdir -p "$chrome_config"
    create_test_chrome_dir "$chrome_config" "Default" "false"
    create_test_chrome_dir "$chrome_config" "Profile 2" "true"

    # Override HOME for this test
    HOME_BACKUP="$HOME"
    HOME="$temp_dir"

    if is_claude_chrome_extension_installed 2>/dev/null; then
        print_test_result "Test 3: Multiple profiles (extension in Profile 2)" "pass"
    else
        print_test_result "Test 3: Multiple profiles (extension in Profile 2)" "fail"
    fi

    HOME="$HOME_BACKUP"
}

# Test 4: No extension (negative test)
test_no_extension() {
    local temp_dir="/tmp/test-chrome-detection-$$-noext"
    trap "rm -rf '$temp_dir'" RETURN

    # Create Chrome config structure directly
    local chrome_config="$temp_dir/.config/google-chrome"
    mkdir -p "$chrome_config"
    create_test_chrome_dir "$chrome_config" "Profile 1" "false"

    # Override HOME for this test
    HOME_BACKUP="$HOME"
    HOME="$temp_dir"

    if ! is_claude_chrome_extension_installed 2>/dev/null; then
        print_test_result "Test 4: No extension (should return 1)" "pass"
    else
        print_test_result "Test 4: No extension (should return 1)" "fail"
    fi

    HOME="$HOME_BACKUP"
}

# Test 5: Chromium browser
test_chromium_browser() {
    local temp_dir="/tmp/test-chrome-detection-$$-chromium"
    trap "rm -rf '$temp_dir'" RETURN

    # Create Chromium config structure directly
    local chromium_config="$temp_dir/.config/chromium"
    mkdir -p "$chromium_config"
    create_test_chrome_dir "$chromium_config" "Profile 1" "true"

    # Override HOME for this test
    HOME_BACKUP="$HOME"
    HOME="$temp_dir"

    if is_claude_chrome_extension_installed 2>/dev/null; then
        print_test_result "Test 5: Chromium browser (Profile 1)" "pass"
    else
        print_test_result "Test 5: Chromium browser (Profile 1)" "fail"
    fi

    HOME="$HOME_BACKUP"
}

# Test 6: Regex pattern matching (claude.*chrome)
test_regex_pattern() {
    local temp_dir="/tmp/test-chrome-detection-$$-regex"
    trap "rm -rf '$temp_dir'" RETURN

    # Create Chrome config structure directly
    local chrome_config="$temp_dir/.config/google-chrome"
    local profile_path="$chrome_config/Profile 1/Extensions/test-ext/1.0.0"
    mkdir -p "$profile_path"

    # Create manifest with lowercase "claude for chrome" (matches regex)
    cat > "$profile_path/manifest.json" <<EOF
{
  "name": "claude for chrome",
  "version": "1.0.0"
}
EOF

    # Override HOME for this test
    HOME_BACKUP="$HOME"
    HOME="$temp_dir"

    if is_claude_chrome_extension_installed 2>/dev/null; then
        print_test_result "Test 6: Regex pattern (claude.*chrome)" "pass"
    else
        print_test_result "Test 6: Regex pattern (claude.*chrome)" "fail"
    fi

    HOME="$HOME_BACKUP"
}

# Main test execution
echo "=========================================="
echo "Chrome Extension Detection Test Suite"
echo "=========================================="
echo ""

test_default_profile
test_profile_with_space
test_multiple_profiles
test_no_extension
test_chromium_browser
test_regex_pattern

echo ""
echo "=========================================="
echo "Test Results:"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "=========================================="

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
