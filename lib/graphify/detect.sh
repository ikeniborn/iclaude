#!/bin/bash
# Graphify detection module
# Provides: detect_graphify()

#######################################
# Check if graphify is installed in isolated environment.
# Tests uv binary and graphify binary existence.
# Returns: 0 if installed, 1 otherwise
#######################################
detect_graphify() {
    [[ -x "$GRAPHIFY_UV_BIN" ]] || return 1
    [[ -x "${GRAPHIFY_TOOL_DIR}/bin/graphify" ]]
}
