#!/bin/bash
# Statusline detection module
# Provides function for detecting statusline script installation

#######################################
# Detect if statusline script is installed and executable
# Returns:
#   0 - statusline script exists and is executable
#   1 - statusline script not found or not executable
#######################################
detect_statusline() {
	# Quietly setup isolated environment to get ISOLATED_CONFIG_DIR
	setup_isolated_nvm &>/dev/null || true

	local statusline_script="$ISOLATED_CONFIG_DIR/scripts/claude-statusline.sh"

	if [[ -f "$statusline_script" ]] && [[ -x "$statusline_script" ]]; then
		return 0
	fi

	return 1
}
