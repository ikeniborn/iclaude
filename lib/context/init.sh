#!/usr/bin/env bash
# lib/context/init.sh
# Context Management - Initialization & Path Helpers
#
# Part of Phase 10: Context Management extraction from iclaude-legacy.sh
# Contains 7 path helper functions (trivial, low risk)

# Configuration (moved from iclaude-legacy.sh:6769-6779)
CONTEXT_BASE_DIR="${CLAUDE_DIR:-$HOME/.claude}/contexts"
CONTEXT_EXPORTS_DIR="$CONTEXT_BASE_DIR/exports"
CONTEXT_SHARED_DIR="$CONTEXT_BASE_DIR/shared"
CONTEXT_BACKUPS_DIR="$CONTEXT_BASE_DIR/backups"
CONTEXT_TEMPLATES_DIR="$CONTEXT_BASE_DIR/templates"

# Default settings
CONTEXT_CLEANUP_DAYS=30
CONTEXT_MAX_HISTORY_SIZE=$((5 * 1024 * 1024))
CONTEXT_AUTO_SYNC=true

#######################################
# Initialize context directories
# Creates directory structure for context exports/backups
# Globals:
#   CONTEXT_EXPORTS_DIR
#   CONTEXT_SHARED_DIR
#   CONTEXT_BACKUPS_DIR
#   CONTEXT_TEMPLATES_DIR
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
init_context_directories() {
    mkdir -p "$CONTEXT_EXPORTS_DIR"
    mkdir -p "$CONTEXT_SHARED_DIR"
    mkdir -p "$CONTEXT_BACKUPS_DIR/daily"
    mkdir -p "$CONTEXT_BACKUPS_DIR/weekly"
    mkdir -p "$CONTEXT_BACKUPS_DIR/manual"
    mkdir -p "$CONTEXT_TEMPLATES_DIR"
}

#######################################
# Get project name from path
# Arguments:
#   $1 - Project path (default: pwd)
# Returns:
#   Project basename
#######################################
get_context_project_name() {
    local project_path="${1:-$(pwd)}"
    basename "$project_path"
}

#######################################
# Get project hash (Claude Code format)
# Converts path to hash by replacing slashes
# Arguments:
#   $1 - Project path (default: pwd)
# Returns:
#   Hashed project path
#######################################
get_context_project_hash() {
    local project_path="${1:-$(pwd)}"
    echo "$project_path" | sed 's|/|-|g' | sed 's|^-||'
}

#######################################
# Get project memory directory
# Arguments:
#   $1 - Project path (default: pwd)
# Returns:
#   Path to .claude/memory
#######################################
get_context_project_memory_dir() {
    local project_path="${1:-$(pwd)}"
    echo "$project_path/.claude/memory"
}

#######################################
# Get shared memory directory
# For worktree synchronization
# Arguments:
#   $1 - Project path
# Returns:
#   Path to shared memory directory
#######################################
get_context_shared_memory_dir() {
    local project_name=$(get_context_project_name "$1")
    local base_name=$(echo "$project_name" | sed 's|-worktrees-.*||')
    echo "$CONTEXT_SHARED_DIR/$base_name"
}

#######################################
# Check if current directory is a git worktree
# Arguments:
#   $1 - Project path (default: pwd)
# Returns:
#   0 if worktree, 1 otherwise
#######################################
is_context_worktree() {
    local project_path="${1:-$(pwd)}"
    [[ -f "$project_path/.git" ]] && grep -q "gitdir:" "$project_path/.git" 2>/dev/null
}

#######################################
# Get main worktree path
# If current path is a worktree, returns main repo path
# Arguments:
#   $1 - Project path (default: pwd)
# Returns:
#   Main worktree path or input path
#######################################
get_context_main_worktree() {
    local project_path="${1:-$(pwd)}"
    if is_context_worktree "$project_path"; then
        local gitdir=$(grep "gitdir:" "$project_path/.git" | cut -d' ' -f2)
        local main_path=$(dirname "$(dirname "$gitdir")")
        echo "$main_path"
    else
        echo "$project_path"
    fi
}
