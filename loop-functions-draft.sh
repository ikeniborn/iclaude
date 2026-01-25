#!/bin/bash
# Loop Mode Functions for iclaude.sh
# This file contains all loop mode implementation
# To be inserted into iclaude.sh after check_router_status() (~line 2180)

#######################################
# Global variables for task management
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
# Arguments:
#   $1 - Path to .md file
#   $2 - Task index (default: 0 for single task)
# Returns:
#   0 - Success
#   1 - File not found or parse error
# Sets global TASK_* variables for the loaded task
#######################################
load_markdown_task() {
    local task_file="$1"
    local task_index="${2:-0}"

    if [[ ! -f "$task_file" ]]; then
        print_error "Task file not found: $task_file"
        return 1
    fi

    print_info "Loading task from: $task_file"

    # Extract task name (first line after "# Task:")
    local task_name
    task_name=$(grep -A1 "^# Task:" "$task_file" | tail -n1 | sed 's/^# Task: //' | xargs)

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
#######################################
load_all_tasks() {
    local task_file="$1"

    if [[ ! -f "$task_file" ]]; then
        print_error "Task file not found: $task_file"
        return 1
    fi

    # Count number of tasks (count "# Task:" headers)
    local task_count
    task_count=$(grep -c "^# Task:" "$task_file" || echo "0")

    if [[ "$task_count" -eq 0 ]]; then
        print_error "No tasks found in file (expected '# Task:' header)"
        return 1
    fi

    print_info "Found $task_count task(s) in file"

    # For now, load only the first task
    # TODO: Week 2 will implement multi-task loading
    load_markdown_task "$task_file" 0

    return 0
}

#######################################
# Invoke Claude Code for one iteration
# Arguments:
#   $1 - Task ID
#   $2 - Iteration number
# Returns:
#   Exit code from Claude Code execution
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
# Arguments:
#   $1 - Task ID
# Returns:
#   0 - Promise met (task successful)
#   1 - Promise not met (retry needed)
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
# Retry task with exponential backoff
# Arguments:
#   $1 - Task ID
#   $2 - Current iteration number
# Returns:
#   0 - Task succeeded within max iterations
#   1 - Max iterations reached without success
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

#######################################
# Execute single iteration (no retry logic)
# Arguments:
#   $1 - Task ID
#   $2 - Iteration number
# Returns:
#   0 - Iteration executed (does not verify promise)
#   1 - Execution failed
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
# Git commit task changes
# Arguments:
#   $1 - Task ID
# Returns:
#   0 - Changes committed successfully
#   1 - No changes or commit failed
#######################################
git_commit_task_changes() {
    local task_id="$1"
    local task_name="${TASK_NAME[$task_id]}"
    local commit_msg="${TASK_GIT_COMMIT_MSG[$task_id]}"
    local branch="${TASK_GIT_BRANCH[$task_id]}"
    local auto_push="${TASK_GIT_AUTO_PUSH[$task_id]}"

    # Skip if no git config specified
    if [[ -z "$branch" ]] && [[ -z "$commit_msg" ]]; then
        print_info "No git configuration - skipping commit"
        return 0
    fi

    # Check if we're in a git repository
    if ! git rev-parse --git-dir &>/dev/null; then
        print_warning "Not in a git repository - skipping commit"
        return 0
    fi

    print_info "Committing changes for: $task_name"

    # Create/checkout branch if specified
    if [[ -n "$branch" ]]; then
        echo "  Branch: $branch"
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            git checkout "$branch" 2>/dev/null || {
                print_error "Failed to checkout branch: $branch"
                return 1
            }
        else
            git checkout -b "$branch" 2>/dev/null || {
                print_error "Failed to create branch: $branch"
                return 1
            }
        fi
    fi

    # Stage all changes
    git add .

    # Check if there are changes to commit
    if git diff --cached --quiet; then
        print_warning "No changes to commit"
        return 0
    fi

    # Use default commit message if not specified
    if [[ -z "$commit_msg" ]]; then
        commit_msg="feat: $task_name"
    fi

    # Commit with Co-Authored-By
    git commit -m "$commit_msg

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>" || {
        print_error "Git commit failed"
        return 1
    }

    print_success "Changes committed: $commit_msg"

    # Auto-push if configured
    if [[ "$auto_push" == "true" ]]; then
        print_info "Auto-pushing to remote..."
        if git push -u origin "$branch" 2>&1; then
            print_success "Pushed to remote: $branch"
        else
            print_warning "Push failed - you may need to push manually"
            return 1
        fi
    fi

    return 0
}

#######################################
# Execute tasks in sequential mode
# Arguments:
#   $1 - Path to task file (.md)
# Returns:
#   0 - All tasks completed successfully
#   1 - One or more tasks failed
#   2 - Partial success (some tasks completed)
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

#######################################
# Execute tasks in parallel mode
# (Week 2 implementation - placeholder for now)
# Arguments:
#   $1 - Path to task file (.md)
#   $2 - Max parallel agents (default: 5)
# Returns:
#   0 - All tasks completed
#   1 - One or more tasks failed
#######################################
execute_parallel_mode() {
    local task_file="$1"
    local max_parallel="${2:-5}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Loop Mode: Parallel Execution"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    print_warning "Parallel mode not yet implemented (Week 2)"
    echo "  For now, use sequential mode: ./iclaude.sh --loop task.md"
    echo ""

    return 1
}
