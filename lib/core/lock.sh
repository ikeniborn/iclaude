#!/bin/bash

#######################################
# Core Lock Module
# Description: flock-based mutual exclusion with fail-soft semantics (S6).
#              A lock problem (missing flock, unwritable lock file, timeout)
#              warns and runs the command anyway — never blocks or fails a
#              launch. Every acquisition is timeout-bounded.
#######################################

# Override point for tests; empty means "use flock from PATH".
ICLAUDE_FLOCK_BIN="${ICLAUDE_FLOCK_BIN:-flock}"

#######################################
# Run a command under an exclusive flock on the given lock file.
# Fail-soft: when the lock cannot be created or acquired within the timeout,
# a warning is printed and the command runs unlocked.
# Arguments:
#   $1 - lock file path
#   $2 - timeout in seconds
#   $@ - command and its arguments
# Returns:
#   the command's exit code
#######################################
iclaude_with_lock() {
	local lockfile="$1" timeout="$2"
	shift 2
	local fd rc

	if ! command -v "$ICLAUDE_FLOCK_BIN" &>/dev/null; then
		print_warning "flock not available; running without lock: $lockfile"
		"$@"
		return $?
	fi

	mkdir -p "$(dirname "$lockfile")" 2>/dev/null
	if ! exec {fd}>"$lockfile" 2>/dev/null; then
		print_warning "Cannot open lock file $lockfile; running without lock"
		"$@"
		return $?
	fi

	if ! "$ICLAUDE_FLOCK_BIN" -w "$timeout" "$fd" 2>/dev/null; then
		print_warning "Lock busy after ${timeout}s: $lockfile; proceeding without exclusive lock"
		"$@"
		rc=$?
		exec {fd}>&-
		return $rc
	fi

	"$@"
	rc=$?
	exec {fd}>&-
	return $rc
}
