#!/usr/bin/env bash

# claude-statusline.sh
# Custom status line script for Claude Code
# Shows: Project | Git Branch | Node Version | Time

set -euo pipefail

# Get project name (basename of current directory)
project_name=$(basename "$PWD")

# Get git branch (if in git repo)
if git rev-parse --is-inside-work-tree &>/dev/null; then
    git_branch=$(git branch --show-current 2>/dev/null || echo "detached")
    git_info=" | ${git_branch}"
else
    git_info=""
fi

# Get Node.js version (if available)
if command -v node &>/dev/null; then
    node_version=$(node --version 2>/dev/null || echo "unknown")
    node_info=" | Node ${node_version}"
else
    node_info=""
fi

# Get current time
current_time=$(date "+%H:%M:%S")

# Output status line
echo "${project_name}${git_info}${node_info} | ${current_time}"
