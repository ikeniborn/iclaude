#!/bin/bash

#######################################
# Git Proxy Management Module
# Description: Backup and restore git proxy settings
#######################################

#######################################
# Save current git proxy settings to backup file
# Side effects:
#   - Creates GIT_BACKUP_FILE with chmod 600
#   - Saves current http.proxy and https.proxy from git config
#######################################
save_git_proxy_settings() {
    # Create backup file with restricted permissions
    touch "$GIT_BACKUP_FILE"
    chmod 600 "$GIT_BACKUP_FILE"

    # Get current git proxy settings (global config)
    local http_proxy=$(git config --global --get http.proxy 2>/dev/null || echo "")
    local https_proxy=$(git config --global --get https.proxy 2>/dev/null || echo "")

    # Save to backup file
    cat > "$GIT_BACKUP_FILE" << EOF
HTTP_PROXY=$http_proxy
HTTPS_PROXY=$https_proxy
EOF
}

#######################################
# Restore git proxy settings from backup
# Side effects:
#   - Restores git config --global http.proxy and https.proxy
#   - Removes GIT_BACKUP_FILE after restore
#######################################
restore_git_proxy() {
    if [[ ! -f "$GIT_BACKUP_FILE" ]]; then
        print_info "No git proxy backup found"
        return 0
    fi

    # Load backup settings
    source "$GIT_BACKUP_FILE"

    # Restore settings
    if [[ -n "$HTTP_PROXY" ]]; then
        git config --global http.proxy "$HTTP_PROXY"
    else
        git config --global --unset http.proxy 2>/dev/null || true
    fi

    if [[ -n "$HTTPS_PROXY" ]]; then
        git config --global https.proxy "$HTTPS_PROXY"
    else
        git config --global --unset https.proxy 2>/dev/null || true
    fi

    print_success "Git proxy settings restored"

    # Remove backup file
    rm -f "$GIT_BACKUP_FILE"
}
