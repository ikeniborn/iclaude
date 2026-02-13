#!/usr/bin/env bash
# lib/loop/retry.sh
# Loop Mode - Retry Logic with Exponential Backoff
#
# Part of Phase 12: Loop Mode extraction from iclaude-legacy.sh
# Contains exponential backoff retry mechanism

#######################################
# Retry task with exponential backoff
# Implements exponential backoff: 2s, 4s, 8s, 16s, 32s (capped at 60s)
# Arguments:
#   $1 - Task ID
#   $2 - Current iteration number (default: 1)
# Returns:
#   0 - Task succeeded within max iterations
#   1 - Max iterations reached without success
# Globals:
#   Reads TASK_MAX_ITERATIONS, TASK_NAME
# Backoff Formula:
#   delay = base_delay ** iteration (capped at 60s)
#   Example: 2^1=2s, 2^2=4s, 2^3=8s, 2^4=16s, 2^5=32s, 2^6=64s→60s
# Dependencies:
#   - invoke_claude_iteration() - Execute Claude
#   - verify_completion_promise() - Check completion
#######################################
retry_task_with_backoff() {
	local task_id="$1"
	local iteration="${2:-1}"
	local max_iterations="${TASK_MAX_ITERATIONS[$task_id]}"
	local task_name="${TASK_NAME[$task_id]}"
	local base_delay=2  # seconds

	print_info "Starting retry loop for: $task_name"
	echo "  Max iterations: $max_iterations"
	echo ""

	while [[ $iteration -lt $max_iterations ]]; do
		((iteration++))

		# Exponential backoff: 2^1=2s, 2^2=4s, 2^3=8s, 2^4=16s, 2^5=32s
		local delay=$((base_delay ** iteration))
		# Cap at 60 seconds
		if [[ $delay -gt 60 ]]; then
			delay=60
		fi

		print_info "⏳ Waiting ${delay}s before retry (iteration $iteration/$max_iterations)"
		sleep "$delay"

		# Execute iteration
		invoke_claude_iteration "$task_id" "$iteration"

		# Check if promise is met
		if verify_completion_promise "$task_id"; then
			print_success "Task completed successfully at iteration $iteration"
			return 0
		fi

		print_warning "Promise not met - will retry"
		echo ""
	done

	print_error "❌ Max iterations ($max_iterations) reached for task: $task_name"
	echo "  Task did not complete successfully"
	return 1
}
