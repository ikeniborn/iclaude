#!/usr/bin/env bash
# lib/loop/executor.sh
# Loop Mode - Sequential Execution Orchestrator
#
# Part of Phase 12: Loop Mode extraction from iclaude-legacy.sh
# Contains sequential task execution logic with retry support

#######################################
# Invoke Claude Code for one iteration
# Executes Claude with task prompt and logs output
# Arguments:
#   $1 - Task ID (e.g., "task_0")
#   $2 - Iteration number
# Returns:
#   Exit code from Claude Code execution
# Globals:
#   Reads TASK_NAME, TASK_DESCRIPTION, TASK_COMPLETION_PROMISE
# Output:
#   Logs to /tmp/iclaude-loop-iter-<iteration>-$$.log
#######################################
invoke_claude_iteration() {
	local task_id="$1"
	local iteration="$2"

	# Get Claude binary path
	local claude_bin
	claude_bin=$(get_nvm_claude_path) || {
		print_error "Claude Code binary not found"
		echo "  Run: ./iclaude.sh --isolated-install"
		return 1
	}

	local task_name="${TASK_NAME[$task_id]}"
	local task_desc="${TASK_DESCRIPTION[$task_id]}"
	local promise="${TASK_COMPLETION_PROMISE[$task_id]}"

	print_info "Starting iteration $iteration for: $task_name"

	# Build prompt with context
	local prompt="Task: $task_name

Description:
$task_desc

Completion Promise:
$promise

This is iteration $iteration. Focus on meeting the completion promise.
"

	# Create temporary log file
	local log_file="/tmp/iclaude-loop-iter-${iteration}-$$.log"

	echo ""
	print_info "Invoking Claude Code..."
	echo "  Log file: $log_file"
	echo ""

	# Execute Claude Code with prompt
	# Inherit all environment variables (proxy, OAuth, etc.)
	echo "$prompt" | "$claude_bin" 2>&1 | tee "$log_file"

	local exit_code="${PIPESTATUS[0]}"

	if [[ $exit_code -eq 0 ]]; then
		print_success "Claude Code iteration $iteration completed"
	else
		print_warning "Claude Code iteration $iteration finished with code: $exit_code"
	fi

	return "$exit_code"
}

#######################################
# Verify completion promise is met
# Executes validation command and checks output
# Arguments:
#   $1 - Task ID
# Returns:
#   0 - Promise met (task successful)
#   1 - Promise not met (retry needed)
# Globals:
#   Reads TASK_VALIDATION_COMMAND, TASK_COMPLETION_PROMISE, TASK_NAME
# Validation Strategy:
#   1. Check validation command exit code
#   2. Check if output matches promise pattern (regex)
#######################################
verify_completion_promise() {
	local task_id="$1"

	local validation_cmd="${TASK_VALIDATION_COMMAND[$task_id]}"
	local promise="${TASK_COMPLETION_PROMISE[$task_id]}"
	local task_name="${TASK_NAME[$task_id]}"

	if [[ -z "$validation_cmd" ]]; then
		print_warning "No validation command specified - assuming success"
		return 0
	fi

	print_info "Verifying completion promise for: $task_name"
	echo "  Command: $validation_cmd"
	echo "  Expected: $promise"
	echo ""

	# Execute validation command
	local output
	local exit_code
	output=$(eval "$validation_cmd" 2>&1) || exit_code=$?
	exit_code=${exit_code:-0}

	echo "  Output:"
	echo "$output" | sed 's/^/    /'
	echo ""

	# Check if promise is met
	# Strategy 1: Check exit code (if promise is just about command success)
	# Strategy 2: Check output matches promise (regex or literal match)

	if [[ $exit_code -eq 0 ]]; then
		# Command succeeded - check if output contains promise pattern
		if [[ -z "$promise" ]] || echo "$output" | grep -qE "$promise"; then
			print_success "✓ Completion promise met!"
			return 0
		else
			print_warning "Command succeeded but promise not found in output"
			echo "  Expected pattern: $promise"
			return 1
		fi
	else
		print_warning "Validation command failed (exit code: $exit_code)"
		return 1
	fi
}

#######################################
# Execute single iteration (no retry logic)
# Wrapper around invoke_claude_iteration with state tracking
# Arguments:
#   $1 - Task ID
#   $2 - Iteration number (default: 1)
# Returns:
#   0 - Iteration executed (does not verify promise)
#   1 - Execution failed
# Globals:
#   Sets CURRENT_TASK, CURRENT_ITERATION for state persistence
#######################################
execute_single_iteration() {
	local task_id="$1"
	local iteration="${2:-1}"

	# Save current task state for recovery
	CURRENT_TASK="$task_id"
	CURRENT_ITERATION="$iteration"

	# Invoke Claude Code
	if ! invoke_claude_iteration "$task_id" "$iteration"; then
		print_error "Claude Code execution failed"
		return 1
	fi

	return 0
}

#######################################
# Execute tasks in sequential mode
# Main orchestrator for loop mode sequential execution
# Arguments:
#   $1 - Path to task file (.md)
# Returns:
#   0 - All tasks completed successfully
#   1 - All tasks failed
#   2 - Partial success (some tasks failed)
# Globals:
#   Reads TASKS, TASK_NAME arrays
#   Sets COMPLETED_TASKS array
# Workflow:
#   For each task:
#     1. Execute first iteration
#     2. Verify completion promise
#     3. If failed, retry with exponential backoff
#     4. Commit changes if git config specified
#######################################
execute_sequential_mode() {
	local task_file="$1"

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Loop Mode: Sequential Execution"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Load tasks
	if ! load_all_tasks "$task_file"; then
		print_error "Failed to load tasks from file"
		return 1
	fi

	echo ""
	print_info "Loaded ${#TASKS[@]} task(s)"
	echo ""

	local failed_tasks=0
	local total_tasks=${#TASKS[@]}

	# Execute each task sequentially
	for task_id in "${TASKS[@]}"; do
		local task_name="${TASK_NAME[$task_id]}"

		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo "  Executing: $task_name"
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo ""

		# Execute first iteration
		if ! execute_single_iteration "$task_id" 1; then
			print_error "Failed to execute task: $task_name"
			((failed_tasks++))
			continue
		fi

		# Verify completion promise
		if verify_completion_promise "$task_id"; then
			print_success "Task completed on first attempt: $task_name"
			COMPLETED_TASKS+=("$task_id")

			# Commit changes if git config specified
			git_commit_task_changes "$task_id"

			echo ""
			continue
		fi

		# Retry with exponential backoff
		print_info "Task needs retry - starting retry loop"
		echo ""

		if retry_task_with_backoff "$task_id" 1; then
			print_success "Task completed after retries: $task_name"
			COMPLETED_TASKS+=("$task_id")

			# Commit changes
			git_commit_task_changes "$task_id"
		else
			print_error "Task failed after max iterations: $task_name"
			((failed_tasks++))
		fi

		echo ""
	done

	# Summary
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Loop Execution Summary"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""
	print_info "Total tasks: $total_tasks"
	print_success "Completed: ${#COMPLETED_TASKS[@]}"

	if [[ $failed_tasks -gt 0 ]]; then
		print_error "Failed: $failed_tasks"
		echo ""

		if [[ ${#COMPLETED_TASKS[@]} -gt 0 ]]; then
			return 2  # Partial success
		else
			return 1  # Complete failure
		fi
	else
		echo ""
		print_success "All tasks completed successfully!"
		echo ""
		return 0
	fi
}
