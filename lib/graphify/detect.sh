#!/bin/bash
# Graphify detection module
# Provides: detect_graphify()

#######################################
# Check if graphify is installed in isolated environment.
# uv can be in isolated location or system PATH.
# Returns: 0 if installed, 1 otherwise
#######################################
detect_graphify() {
    { [[ -x "$GRAPHIFY_UV_BIN" ]] || command -v uv &>/dev/null; } || return 1
    [[ -x "${GRAPHIFY_TOOL_DIR}/graphifyy/bin/graphify" ]]
}
