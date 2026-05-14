#!/bin/bash
# GSD detection module
# Provides: detect_gsd()

#######################################
# Check if GSD is installed in isolated environment.
# GSD installs skills to ${CLAUDE_CONFIG_DIR}/skills/gsd-*/
# Returns: 0 if installed, 1 otherwise
#######################################
detect_gsd() {
    local skills_dir="${CLAUDE_CONFIG_DIR}/skills"
    [[ -d "$skills_dir" ]] || return 1
    local found
    found=$(find "$skills_dir" -maxdepth 1 -type d -name 'gsd-*' 2>/dev/null | head -1)
    [[ -n "$found" ]]
}
