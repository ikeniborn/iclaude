#!/bin/bash

#######################################
# iclaude.sh - Modular Entry Point
# Version: 2.3 (Modular Architecture - Phase 0-6)
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
# Load core modules (Phase 0)
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
# Load proxy modules (Phase 2)
#######################################
if [[ -d "$LIB_DIR/proxy" ]]; then
    source "${LIB_DIR}/proxy/validate.sh"
    source "${LIB_DIR}/proxy/credentials.sh"
    source "${LIB_DIR}/proxy/configure.sh"
    source "${LIB_DIR}/proxy/git.sh"
fi

#######################################
# Load NVM modules (Phase 3)
#######################################
if [[ -d "$LIB_DIR/nvm" ]]; then
    source "${LIB_DIR}/nvm/detect.sh"
    source "${LIB_DIR}/nvm/setup.sh"
    source "${LIB_DIR}/nvm/install.sh"
    source "${LIB_DIR}/nvm/claude.sh"
    source "${LIB_DIR}/nvm/repair.sh"
    source "${LIB_DIR}/nvm/cleanup.sh"
fi

#######################################
# Load lockfile modules (Phase 4)
#######################################
if [[ -d "$LIB_DIR/lockfile" ]]; then
    source "${LIB_DIR}/lockfile/save.sh"
    source "${LIB_DIR}/lockfile/install.sh"
fi

#######################################
# Load config modules (Phase 5)
#######################################
if [[ -d "$LIB_DIR/config" ]]; then
    source "${LIB_DIR}/config/isolated.sh"
    source "${LIB_DIR}/config/export.sh"
    source "${LIB_DIR}/config/status.sh"
fi

#######################################
# Load OAuth modules (Phase 6)
#######################################
if [[ -d "$LIB_DIR/oauth" ]]; then
    source "${LIB_DIR}/oauth/token.sh"
fi

#######################################
# Load legacy implementation
# TODO: Phase 7-9 will gradually extract remaining modules from legacy
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
