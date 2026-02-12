#!/usr/bin/env bash
# lib/loop/validator.sh
# Loop Mode - Task File Validation
#
# Part of Phase 11: Loop Mode extraction from iclaude-legacy.sh
# Contains task file format validation

#######################################
# Validate task file format
# Checks for required Markdown structure and sections
# Arguments:
#   $1 - Path to .md file
# Returns:
#   0 - Valid format
#   1 - Invalid format or user rejected
# Required sections:
#   - "# Task:" header
#   - "## Description" section
#   - "## Completion Promise" section
#   - "## Validation Command" section
# Interactive:
#   Prompts user to continue if missing optional sections
#######################################
validate_task_file_format() {
	local task_file="$1"

	# Check file existence and readability
	if [[ ! -f "$task_file" ]]; then
		print_error "Task file not found: $task_file"
		return 1
	fi

	if [[ ! -r "$task_file" ]]; then
		print_error "Task file not readable: $task_file"
		return 1
	fi

	# Check for "# Task:" headers
	if ! grep -q "^# Task:" "$task_file" 2>/dev/null; then
		print_error "Invalid task file format"
		echo ""
		echo "Expected format:"
		echo "  # Task: Task name"
		echo "  ## Description"
		echo "  ## Completion Promise"
		echo "  ## Validation Command"
		echo ""
		return 1
	fi

	# Check for required sections (with warning)
	local -a missing=()
	grep -q "^## Description" "$task_file" 2>/dev/null || missing+=("Description")
	grep -q "^## Completion Promise" "$task_file" 2>/dev/null || missing+=("Completion Promise")
	grep -q "^## Validation Command" "$task_file" 2>/dev/null || missing+=("Validation Command")

	if [[ ${#missing[@]} -gt 0 ]]; then
		print_warning "Missing sections: ${missing[*]}"
		echo "Continue? (yes/no)"
		read -r response
		if [[ ! "$response" =~ ^(yes|y)$ ]]; then
			print_error "Task file validation rejected by user"
			return 1
		fi
	fi

	return 0
}
