#!/bin/bash
# lat.md detection module
# Provides: detect_lat(), detect_lat_project()

#######################################
# Check if lat CLI is installed in isolated npm.
# Sets LAT_BIN to the binary path on success.
# Returns: 0 if installed, 1 otherwise
#######################################
detect_lat() {
    local bin="${NPM_CONFIG_PREFIX:-${ISOLATED_NVM_DIR}/npm-global}/bin/lat"
    [[ -x "$bin" ]] || return 1
    LAT_BIN="$bin"
    export LAT_BIN
    return 0
}

#######################################
# Check if current project has lat.md/ directory.
# Sets LAT_PROJECT_ROOT on success.
# Returns: 0 if found, 1 otherwise
#######################################
detect_lat_project() {
    local lat_dir="${LAUNCH_DIR}/lat.md"
    [[ -d "$lat_dir" ]] || return 1
    LAT_PROJECT_ROOT="$lat_dir"
    export LAT_PROJECT_ROOT
    return 0
}
