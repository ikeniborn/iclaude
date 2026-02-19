#!/usr/bin/env bash
# lib/loop/parser.sh
# Loop Mode - Task Loading and Parsing
#
# Part of Phase 11: Loop Mode extraction from iclaude-legacy.sh
# Contains Markdown task parser functions

#######################################
# Global variables for task management
# Declared here so the module is self-contained when sourced.
# Re-declaration is a no-op for already-declared associative arrays.
#######################################
declare -A TASK_NAME
declare -A TASK_DESCRIPTION
declare -A TASK_COMPLETION_PROMISE
declare -A TASK_VALIDATION_COMMAND
declare -A TASK_MAX_ITERATIONS
declare -A TASK_GIT_BRANCH
declare -A TASK_GIT_COMMIT_MSG
declare -A TASK_GIT_AUTO_PUSH
declare -A TASK_PARALLEL_GROUP
declare -a TASKS
declare -a COMPLETED_TASKS
CURRENT_TASK=""
CURRENT_ITERATION=0

#######################################
# Load a single task from Markdown file
# Parses task metadata from structured Markdown format
# Arguments:
#   $1 - Path to .md file
#   $2 - Task index (default: 0 for single task)
# Returns:
#   0 - Success
#   1 - File not found or parse error
# Globals:
#   Sets TASK_NAME, TASK_DESCRIPTION, TASK_COMPLETION_PROMISE,
#   TASK_VALIDATION_COMMAND, TASK_MAX_ITERATIONS, TASK_GIT_*,
#   TASK_PARALLEL_GROUP, TASKS array
# Markdown Format:
#   # Task: Task name
#   ## Description
#   Task description text
#   ## Completion Promise
#   Exit condition (e.g., "All tests pass")
#   ## Validation Command
#   Command to verify completion (e.g., "npm test")
#   ## Max Iterations
#   5
#   ## Git Config (optional)
#   Branch: feature/task-name
#   Commit message: feat: implement task
#   Auto-push: true
#   Group: 1  (for parallel mode)
#######################################
load_markdown_task() {
	local task_file="$1"
	local task_index="${2:-0}"

	if [[ ! -f "$task_file" ]]; then
		print_error "Task file not found: $task_file"
		return 1
	fi

	print_info "Loading task from: $task_file"

	# Extract task name (from "# Task:" line)
	local task_name
	task_name=$(grep "^# Task:" "$task_file" | head -n1 | sed 's/^# Task: //' | xargs)

	if [[ -z "$task_name" ]]; then
		print_error "Task name not found in file. Expected '# Task: [name]'"
		return 1
	fi

	# Use task index as unique identifier
	local task_id="task_${task_index}"

	# Store task name
	TASK_NAME["$task_id"]="$task_name"

	# Extract description (multi-line between ## Description and next ##)
	local description
	description=$(sed -n '/^## Description/,/^##/{/^## Description/d;/^##/d;p;}' "$task_file" | sed '/^$/d')
	TASK_DESCRIPTION["$task_id"]="$description"

	# Extract completion promise
	local promise
	promise=$(sed -n '/^## Completion Promise/,/^##/{/^## Completion Promise/d;/^##/d;p;}' "$task_file" | sed '/^$/d' | head -n1)
	TASK_COMPLETION_PROMISE["$task_id"]="$promise"

	# Extract validation command
	local validation_cmd
	validation_cmd=$(sed -n '/^## Validation Command/,/^##/{/^## Validation Command/d;/^##/d;p;}' "$task_file" | sed '/^$/d' | head -n1)
	TASK_VALIDATION_COMMAND["$task_id"]="$validation_cmd"

	# Extract max iterations (default: 5)
	local max_iter
	max_iter=$(sed -n '/^## Max Iterations/,/^##/{/^## Max Iterations/d;/^##/d;p;}' "$task_file" | sed '/^$/d' | head -n1 | xargs)
	TASK_MAX_ITERATIONS["$task_id"]="${max_iter:-5}"

	# Extract Git config (optional)
	local git_branch
	git_branch=$(sed -n 's/^Branch: //p' "$task_file" | head -n1 | xargs)
	TASK_GIT_BRANCH["$task_id"]="${git_branch}"

	local git_commit_msg
	git_commit_msg=$(sed -n 's/^Commit message: //p' "$task_file" | head -n1)
	TASK_GIT_COMMIT_MSG["$task_id"]="${git_commit_msg}"

	local git_auto_push
	git_auto_push=$(sed -n 's/^Auto-push: //p' "$task_file" | head -n1 | xargs)
	TASK_GIT_AUTO_PUSH["$task_id"]="${git_auto_push:-false}"

	# Extract parallel group (optional, default: 0 = sequential)
	local parallel_group
	parallel_group=$(sed -n 's/^Group: //p' "$task_file" | head -n1 | xargs)
	TASK_PARALLEL_GROUP["$task_id"]="${parallel_group:-0}"

	# Add to TASKS array
	TASKS+=("$task_id")

	print_success "Loaded task: $task_name"
	echo "  Description: ${description:0:60}..."
	echo "  Max iterations: ${TASK_MAX_ITERATIONS[$task_id]}"
	echo "  Validation: ${TASK_VALIDATION_COMMAND[$task_id]}"

	return 0
}

#######################################
# Load all tasks from Markdown file
# Supports multiple "# Task:" sections in one file
# Arguments:
#   $1 - Path to .md file
# Returns:
#   0 - Success (at least one task loaded)
#   1 - No tasks found or error
# Globals:
#   Initializes TASKS array, calls load_markdown_task() for each task
#######################################
load_all_tasks() {
	local task_file="$1"

	# Initialize tasks array
	TASKS=()

	# Validate file format before parsing
	if ! validate_task_file_format "$task_file"; then
		return 1
	fi

	# Count number of tasks (count "# Task:" headers)
	local task_count
	task_count=$(grep "^# Task:" "$task_file" 2>/dev/null | wc -l)

	if [[ "$task_count" -eq 0 ]]; then
		print_error "No tasks found in file (expected '# Task:' header)"
		return 1
	fi

	print_info "Found $task_count task(s) in file"

	# Extract line numbers for each task section
	local -a task_start_lines
	mapfile -t task_start_lines < <(grep -n "^# Task:" "$task_file" | cut -d: -f1)

	# Load each task
	local task_index=0
	for start_line in "${task_start_lines[@]}"; do
		# Determine end line (next task or end of file)
		local end_line
		local next_index=$((task_index + 1))
		if [[ $next_index -lt ${#task_start_lines[@]} ]]; then
			end_line=$((${task_start_lines[$next_index]} - 1))
		else
			end_line=$(wc -l < "$task_file")
		fi

		# Extract task section to temp file
		local temp_task_file="/tmp/iclaude-task-${task_index}-$$.md"
		sed -n "${start_line},${end_line}p" "$task_file" > "$temp_task_file"

		# Load task from temp file
		if ! load_markdown_task "$temp_task_file" "$task_index"; then
			print_warning "Failed to load task $task_index, skipping"
			rm -f "$temp_task_file"
			((task_index++))
			continue
		fi

		rm -f "$temp_task_file"
		((task_index++))
	done

	if [[ ${#TASKS[@]:-0} -eq 0 ]]; then
		print_error "No tasks successfully loaded"
		return 1
	fi

	return 0
}
