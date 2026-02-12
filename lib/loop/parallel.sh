#!/usr/bin/env bash
# lib/loop/parallel.sh
# Loop Mode - Parallel Execution Orchestrator
#
# Part of Phase 13: Loop Mode extraction from iclaude-legacy.sh
# Contains parallel task execution logic with git worktree isolation

#######################################
# Execute single task with retry logic
# Helper wrapper for both sequential and parallel execution
# Arguments:
#   $1 - Task ID
# Returns:
#   0 - Task completed
#   1 - Task failed after retries
# Globals:
#   Reads TASK_NAME
#   Modifies COMPLETED_TASKS array
# Workflow:
#   1. Execute first iteration via execute_single_iteration()
#   2. Verify completion with verify_completion_promise()
#   3. If failed, retry with retry_task_with_backoff()
#   4. Commit changes if successful
#######################################
execute_task_with_retry() {
	local task_id="$1"
	local task_name="${TASK_NAME[$task_id]}"

	print_info "Executing: $task_name"

	# Execute first iteration
	if ! execute_single_iteration "$task_id" 1; then
		print_error "Failed to execute task: $task_name"
		return 1
	fi

	# Verify completion promise
	if verify_completion_promise "$task_id"; then
		print_success "Task completed on first attempt: $task_name"
		COMPLETED_TASKS+=("$task_id")
		git_commit_task_changes "$task_id"
		return 0
	fi

	# Retry with exponential backoff
	if retry_task_with_backoff "$task_id" 1; then
		print_success "Task completed after retries: $task_name"
		COMPLETED_TASKS+=("$task_id")
		git_commit_task_changes "$task_id"
		return 0
	else
		print_error "Task failed after max iterations: $task_name"
		return 1
	fi
}

#######################################
# Execute parallel group of tasks
# Executes tasks in parallel with worktree isolation
# Arguments:
#   $1 - Space-separated task IDs (e.g., "task_0 task_1 task_2")
#   $2 - Max parallel agents (default: 5)
# Returns:
#   0 - All tasks in group attempted (check COMPLETED_TASKS for success)
# Globals:
#   Reads TASK_NAME
#   Modifies COMPLETED_TASKS array
# Workflow:
#   1. Create worktrees for each task
#   2. Execute tasks in background (limited by max_parallel)
#   3. Wait for all tasks to complete
#   4. Merge changes from worktrees
#   5. Cleanup worktrees
# Parallel Execution:
#   - Uses bash background jobs (&)
#   - Tracks PIDs for wait/kill
#   - Logs to /tmp/iclaude-parallel-logs-$$/
#   - Max concurrent limited by max_parallel parameter
# Fallback:
#   If not in git repository, falls back to sequential execution
#######################################
execute_parallel_group() {
	local group_tasks="$1"
	local max_parallel="$2"

	# Check if in git repository
	if ! git rev-parse --git-dir &>/dev/null; then
		print_warning "Not in git repository - falling back to sequential execution"
		for task_id in $group_tasks; do
			execute_task_with_retry "$task_id"
		done
		return 0
	fi

	# Create logs directory
	local logs_dir="/tmp/iclaude-parallel-logs-$$"
	mkdir -p "$logs_dir"
	print_info "Parallel task logs: $logs_dir"

	print_info "Creating worktrees for parallel execution..."

	# Create worktrees for each task
	local -a worktree_tasks
	for task_id in $group_tasks; do
		if create_task_worktree "$task_id"; then
			worktree_tasks+=("$task_id")
		else
			print_warning "Failed to create worktree for $task_id - will skip"
		fi
	done

	# Execute tasks in parallel (limited by max_parallel)
	local -a pids
	local -A pid_to_task
	local running=0

	for task_id in "${worktree_tasks[@]}"; do
		# Wait if max parallel reached
		while [[ $running -ge $max_parallel ]]; do
			# Check for finished jobs
			for pid in "${pids[@]}"; do
				if ! kill -0 "$pid" 2>/dev/null; then
					# Job finished
					wait "$pid" 2>/dev/null || true
					local exit_code=$?
					local finished_task="${pid_to_task[$pid]}"
					if [[ $exit_code -eq 0 ]]; then
						print_success "Task completed: ${TASK_NAME[$finished_task]}"
					else
						print_error "Task failed: ${TASK_NAME[$finished_task]} (exit: $exit_code)"
					fi
					((running--))
				fi
			done
			sleep 1
		done

		# Start task in background with logging
		local task_log="$logs_dir/${task_id}.log"
		(
			{
				echo "=== Task: ${TASK_NAME[$task_id]} ==="
				echo "Started: $(date -Iseconds)"
				echo ""
			} > "$task_log"

			local worktree_path_var="WORKTREE_PATH_${task_id}"
			local worktree_path="${!worktree_path_var}"

			cd "$worktree_path" || exit 1

			# Execute task with retry
			execute_task_with_retry "$task_id" >> "$task_log" 2>&1
			local exit_code=$?

			{
				echo ""
				echo "Finished: $(date -Iseconds)"
				echo "Exit code: $exit_code"
			} >> "$task_log"

			exit $exit_code
		) &

		local pid=$!
		pids+=("$pid")
		pid_to_task[$pid]="$task_id"
		((running++))
		print_info "Started task in background (PID: $pid): ${TASK_NAME[$task_id]}"
	done

	# Wait for all tasks to complete
	print_info "Waiting for all parallel tasks to complete..."
	for pid in "${pids[@]}"; do
		if kill -0 "$pid" 2>/dev/null; then
			wait "$pid" 2>/dev/null || true
			local exit_code=$?
			local finished_task="${pid_to_task[$pid]}"
			if [[ $exit_code -eq 0 ]]; then
				print_success "Task completed: ${TASK_NAME[$finished_task]}"
			else
				print_error "Task failed: ${TASK_NAME[$finished_task]} (exit: $exit_code)"
			fi
		fi
	done

	# Merge changes from worktrees
	print_info "Merging changes from worktrees..."

	for task_id in "${worktree_tasks[@]}"; do
		local task_name="${TASK_NAME[$task_id]}"

		print_info "Merging: $task_name"

		if merge_worktree_changes "$task_id"; then
			print_success "Merged: $task_name"
		else
			print_error "Failed to merge: $task_name"
		fi

		# Cleanup worktree regardless of merge success
		cleanup_worktree "$task_id"
	done

	return 0
}

#######################################
# Execute tasks in parallel mode
# Main orchestrator for parallel execution with group support
# Arguments:
#   $1 - Path to task file (.md)
#   $2 - Max parallel agents (default: 5)
# Returns:
#   0 - All tasks completed successfully
#   1 - All tasks failed
#   2 - Partial success (some tasks failed)
# Globals:
#   Reads TASKS, TASK_NAME, TASK_PARALLEL_GROUP arrays
#   Modifies COMPLETED_TASKS array
# Group Execution:
#   - Group 0: Sequential execution (compatibility)
#   - Group >0: Parallel execution with worktrees
# Workflow:
#   1. Load tasks from file
#   2. Group tasks by TASK_PARALLEL_GROUP
#   3. Sort groups (sequential group 0 first)
#   4. Execute each group:
#      - Group 0: execute_task_with_retry() sequentially
#      - Group >0: execute_parallel_group()
#   5. Summarize results
#######################################
execute_parallel_mode() {
	local task_file="$1"
	local max_parallel="${2:-5}"

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Loop Mode: Parallel Execution"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Load tasks
	if ! load_all_tasks "$task_file"; then
		print_error "Failed to load tasks from file"
		return 1
	fi

	echo ""
	print_info "Loaded ${#TASKS[@]} task(s)"
	print_info "Max parallel agents: $max_parallel"
	echo ""

	# Group tasks by parallel group ID
	declare -A parallel_groups
	for task_id in "${TASKS[@]}"; do
		local group_id="${TASK_PARALLEL_GROUP[$task_id]}"
		if [[ -z "${parallel_groups[$group_id]}" ]]; then
			parallel_groups[$group_id]="$task_id"
		else
			parallel_groups[$group_id]="${parallel_groups[$group_id]} $task_id"
		fi
	done

	# Sort groups (sequential group 0 first, then parallel groups)
	local -a sorted_groups
	mapfile -t sorted_groups < <(printf '%s\n' "${!parallel_groups[@]}" | sort -n)

	local total_failed=0
	local total_completed=0

	# Execute each group
	for group_id in "${sorted_groups[@]}"; do
		local group_tasks="${parallel_groups[$group_id]}"
		local task_count=$(echo "$group_tasks" | wc -w)

		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		if [[ "$group_id" -eq 0 ]]; then
			echo "  Group: Sequential (Group 0)"
		else
			echo "  Group: Parallel (Group $group_id) - $task_count task(s)"
		fi
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo ""

		if [[ "$group_id" -eq 0 ]]; then
			# Sequential execution for group 0
			for task_id in $group_tasks; do
				if ! execute_task_with_retry "$task_id"; then
					((total_failed++))
				else
					((total_completed++))
				fi
			done
		else
			# Parallel execution for group > 0
			execute_parallel_group "$group_tasks" "$max_parallel"
			local group_exit=$?

			# Count results
			for task_id in $group_tasks; do
				if [[ " ${COMPLETED_TASKS[*]} " =~ " ${task_id} " ]]; then
					((total_completed++))
				else
					((total_failed++))
				fi
			done
		fi

		echo ""
	done

	# Summary
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Parallel Execution Summary"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""
	print_info "Total tasks: ${#TASKS[@]}"
	print_success "Completed: $total_completed"

	if [[ $total_failed -gt 0 ]]; then
		print_error "Failed: $total_failed"
		echo ""

		if [[ $total_completed -gt 0 ]]; then
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
