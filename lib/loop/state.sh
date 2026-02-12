#!/usr/bin/env bash
# lib/loop/state.sh
# Loop Mode - State Persistence
#
# Part of Phase 11: Loop Mode extraction from iclaude-legacy.sh
# Contains loop state save/load functions for crash recovery

#######################################
# Save loop state to JSON file
# Creates checkpoint file for recovery after interruption
# Arguments:
#   None (reads global variables)
# Returns:
#   0 - State saved successfully
# Globals:
#   Reads CURRENT_TASK, CURRENT_ITERATION, COMPLETED_TASKS
# State File:
#   /tmp/iclaude-loop-state-$$.json
# Format:
#   {
#     "timestamp": "2026-02-12T14:30:52+00:00",
#     "current_task": "task_0",
#     "iteration": 3,
#     "completed_tasks": ["task_1", "task_2"]
#   }
#######################################
save_loop_state() {
	local state_file="/tmp/iclaude-loop-state-$$.json"

	# Create JSON state
	cat > "$state_file" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "current_task": "$CURRENT_TASK",
  "iteration": $CURRENT_ITERATION,
  "completed_tasks": [$(printf '"%s",' "${COMPLETED_TASKS[@]}" | sed 's/,$//')]
}
EOF

	return 0
}

#######################################
# Load loop state from file
# Restores execution state after crash or interruption
# Arguments:
#   None (sets global variables)
# Returns:
#   0 - State loaded successfully
#   1 - No state file found or jq unavailable
# Globals:
#   Sets CURRENT_TASK, CURRENT_ITERATION, COMPLETED_TASKS
# State File:
#   /tmp/iclaude-loop-state-$$.json
# Dependencies:
#   Requires jq for JSON parsing
#######################################
load_loop_state() {
	local state_file="/tmp/iclaude-loop-state-$$.json"

	if [[ ! -f "$state_file" ]]; then
		return 1
	fi

	# Check if jq is available
	if ! command -v jq &>/dev/null; then
		print_warning "jq not installed - cannot load state"
		return 1
	fi

	# Parse state using jq
	CURRENT_TASK=$(jq -r '.current_task' "$state_file")
	CURRENT_ITERATION=$(jq -r '.iteration' "$state_file")

	# Parse completed tasks array
	local completed_json
	completed_json=$(jq -r '.completed_tasks[]' "$state_file" 2>/dev/null)
	if [[ -n "$completed_json" ]]; then
		mapfile -t COMPLETED_TASKS <<< "$completed_json"
	fi

	print_info "Loaded loop state from $state_file"
	return 0
}
