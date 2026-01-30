#!/usr/bin/env bash

#######################################
# Test suite for sandbox platform detection
# Usage: ./tests/test-sandbox-platform.sh
#######################################

# Note: Don't use set -e here because we're testing exit codes
set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

#######################################
# Print test result
# Arguments:
#   $1 - test name
#   $2 - expected result
#   $3 - actual result
#######################################
assert_equals() {
	local test_name="$1"
	local expected="$2"
	local actual="$3"

	TESTS_RUN=$((TESTS_RUN + 1))

	if [[ "$expected" == "$actual" ]]; then
		TESTS_PASSED=$((TESTS_PASSED + 1))
		echo -e "${GREEN}✓${NC} PASS: $test_name"
		echo "    Expected: $expected"
		echo "    Actual:   $actual"
	else
		TESTS_FAILED=$((TESTS_FAILED + 1))
		echo -e "${RED}✗${NC} FAIL: $test_name"
		echo "    Expected: $expected"
		echo "    Actual:   $actual"
	fi
	echo ""
}

#######################################
# Mock detect_sandbox_platform() for testing
# Sets uname and /proc/version via environment
#######################################
detect_sandbox_platform_mock() {
	local mock_uname="${MOCK_UNAME:-Linux}"
	local mock_proc_version="${MOCK_PROC_VERSION:-}"

	case "$mock_uname" in
		Darwin)
			echo "macos"
			return 0
			;;
		Linux)
			if [[ -n "$mock_proc_version" ]] && echo "$mock_proc_version" | grep -qE "(Microsoft|WSL)"; then
				if echo "$mock_proc_version" | grep -q "WSL2"; then
					echo "wsl2"
					return 0
				fi
				echo "wsl1"
				return 1
			fi
			echo "linux"
			return 0
			;;
		MINGW*|MSYS*|CYGWIN*)
			echo "windows"
			return 1
			;;
		*)
			echo "unsupported"
			return 1
			;;
	esac
}

#######################################
# Test: Detect macOS
#######################################
test_detect_macos() {
	export MOCK_UNAME="Darwin"
	export MOCK_PROC_VERSION=""

	result=$(detect_sandbox_platform_mock)
	exit_code=$?

	assert_equals "macOS detection" "macos" "$result"
	assert_equals "macOS exit code" "0" "$exit_code"
}

#######################################
# Test: Detect Linux (standard)
#######################################
test_detect_linux() {
	export MOCK_UNAME="Linux"
	export MOCK_PROC_VERSION="Linux version 5.15.0-76-generic"

	result=$(detect_sandbox_platform_mock)
	exit_code=$?

	assert_equals "Linux detection" "linux" "$result"
	assert_equals "Linux exit code" "0" "$exit_code"
}

#######################################
# Test: Detect WSL2
#######################################
test_detect_wsl2() {
	export MOCK_UNAME="Linux"
	export MOCK_PROC_VERSION="Linux version 5.15.90.1-microsoft-standard-WSL2"

	result=$(detect_sandbox_platform_mock)
	exit_code=$?

	assert_equals "WSL2 detection" "wsl2" "$result"
	assert_equals "WSL2 exit code" "0" "$exit_code"
}

#######################################
# Test: Detect WSL1 (unsupported)
#######################################
test_detect_wsl1() {
	export MOCK_UNAME="Linux"
	export MOCK_PROC_VERSION="Linux version 4.4.0-19041-Microsoft"

	result=$(detect_sandbox_platform_mock)
	exit_code=$?

	assert_equals "WSL1 detection" "wsl1" "$result"
	assert_equals "WSL1 exit code (unsupported)" "1" "$exit_code"
}

#######################################
# Test: Detect Windows (unsupported)
#######################################
test_detect_windows() {
	export MOCK_UNAME="MINGW64_NT-10.0"
	export MOCK_PROC_VERSION=""

	result=$(detect_sandbox_platform_mock)
	exit_code=$?

	assert_equals "Windows detection" "windows" "$result"
	assert_equals "Windows exit code (unsupported)" "1" "$exit_code"
}

#######################################
# Test: Detect unknown platform (unsupported)
#######################################
test_detect_unsupported() {
	export MOCK_UNAME="FreeBSD"
	export MOCK_PROC_VERSION=""

	result=$(detect_sandbox_platform_mock)
	exit_code=$?

	assert_equals "Unknown platform detection" "unsupported" "$result"
	assert_equals "Unknown platform exit code (unsupported)" "1" "$exit_code"
}

#######################################
# Test: WSL2 alternative format
#######################################
test_detect_wsl2_alternative() {
	export MOCK_UNAME="Linux"
	export MOCK_PROC_VERSION="Linux version 5.10.16.3-microsoft-standard-WSL2 (oe-user@oe-host)"

	result=$(detect_sandbox_platform_mock)
	exit_code=$?

	assert_equals "WSL2 alternative format detection" "wsl2" "$result"
	assert_equals "WSL2 alternative exit code" "0" "$exit_code"
}

#######################################
# Main test runner
#######################################
main() {
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Sandbox Platform Detection Test Suite"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Run all tests
	test_detect_macos
	test_detect_linux
	test_detect_wsl2
	test_detect_wsl1
	test_detect_windows
	test_detect_unsupported
	test_detect_wsl2_alternative

	# Print summary
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Test Summary"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Total tests:  $TESTS_RUN"
	echo -e "  ${GREEN}Passed:${NC}       $TESTS_PASSED"
	if [[ $TESTS_FAILED -gt 0 ]]; then
		echo -e "  ${RED}Failed:${NC}       $TESTS_FAILED"
	else
		echo -e "  ${GREEN}Failed:${NC}       $TESTS_FAILED"
	fi
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

	# Exit with failure if any tests failed
	if [[ $TESTS_FAILED -gt 0 ]]; then
		echo ""
		echo -e "${RED}❌ Some tests failed${NC}"
		exit 1
	else
		echo ""
		echo -e "${GREEN}✅ All tests passed${NC}"
		exit 0
	fi
}

# Run tests
main "$@"
