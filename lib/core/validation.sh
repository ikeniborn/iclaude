#!/bin/bash

#######################################
# Validation Module
# Description: Utility functions for validating dependencies, files, and other preconditions
#######################################

#######################################
# Validate that a command exists on the system
# Arguments:
#   $1 - Command name (e.g., "jq", "git", "node")
#   $2 - Installation hint (optional, e.g., "Install with: sudo apt install jq")
# Returns:
#   0 - Command exists
#   1 - Command not found
# Example:
#   validate_dependency "jq" "Install with: sudo apt install jq" || return 1
#######################################
validate_dependency() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        print_error "$cmd is required but not installed"
        if [[ -n "$install_hint" ]]; then
            echo "$install_hint"
        fi
        return 1
    fi

    return 0
}

#######################################
# Validate that a file exists
# Arguments:
#   $1 - File path
# Returns:
#   0 - File exists
#   1 - File not found
#######################################
validate_file_exists() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        print_error "File not found: $file_path"
        return 1
    fi

    return 0
}

#######################################
# Validate that a directory exists
# Arguments:
#   $1 - Directory path
# Returns:
#   0 - Directory exists
#   1 - Directory not found
#######################################
validate_directory_exists() {
    local dir_path="$1"

    if [[ ! -d "$dir_path" ]]; then
        print_error "Directory not found: $dir_path"
        return 1
    fi

    return 0
}
