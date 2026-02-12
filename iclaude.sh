#!/bin/bash

#######################################
# iclaude.sh - Modular Entry Point
# Version: 2.0 (Modular Architecture - Phase 0)
# Description: Wrapper that loads modular components and delegates to legacy implementation
#######################################

set -euo pipefail

#######################################
# Determine library directory
#######################################
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

#######################################
# Load core modules
#######################################
if [[ ! -d "$LIB_DIR/core" ]]; then
    echo "ERROR: Core modules not found at $LIB_DIR/core"
    echo "Please ensure lib/ directory structure exists."
    exit 1
fi

# Load core modules in order
source "${LIB_DIR}/core/init.sh"
source "${LIB_DIR}/core/logging.sh"
source "${LIB_DIR}/core/validation.sh"
source "${LIB_DIR}/core/json.sh"

#######################################
# Initialize environment
#######################################
init_environment

#######################################
# Load legacy implementation
# TODO: Phase 1-9 will gradually extract modules from legacy
#######################################
if [[ ! -f "${SCRIPT_DIR}/iclaude-legacy.sh" ]]; then
    print_error "Legacy implementation not found: ${SCRIPT_DIR}/iclaude-legacy.sh"
    exit 1
fi

source "${SCRIPT_DIR}/iclaude-legacy.sh"

#######################################
# Call main function
#######################################
main "$@"
