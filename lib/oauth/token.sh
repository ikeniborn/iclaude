#!/bin/bash

#######################################
# OAuth Token Module
# Description: OAuth token validation, expiration checking, and automatic refresh
#######################################

#######################################
# Check token expiration across all credentials files
# Checks system and isolated credentials for expiring/expired tokens
# Returns:
#   0 - All tokens valid
#   1 - Token expired
#   2 - Token expiring soon (< 1 hour)
# Example:
#   check_token_expiration || echo "Token issues detected"
#######################################
check_token_expiration() {
    local warn_threshold=3600  # 1 hour in seconds
    local credentials_files=()

    # Check system credentials
    if [[ -f "$HOME/.claude/.credentials.json" ]]; then
        credentials_files+=("$HOME/.claude/.credentials.json")
    fi

    # Check isolated credentials if exists
    if [[ -f "$ISOLATED_NVM_DIR/.claude-isolated/.credentials.json" ]]; then
        credentials_files+=("$ISOLATED_NVM_DIR/.claude-isolated/.credentials.json")
    fi

    # If no credentials found, skip check
    if [[ ${#credentials_files[@]} -eq 0 ]]; then
        return 0
    fi

    # Check each credentials file
    local most_critical_status=0
    for creds_file in "${credentials_files[@]}"; do
        # Extract expires_at (in milliseconds)
        local expires_ms=$(jq -r '.claudeAiOauth.expiresAt // 0' "$creds_file" 2>/dev/null)

        # Skip if no expiration found or jq failed
        if [[ -z "$expires_ms" || "$expires_ms" == "0" || "$expires_ms" == "null" ]]; then
            continue
        fi

        # Convert to seconds
        local expires_sec=$((expires_ms / 1000))
        local current_sec=$(date +%s)
        local diff=$((expires_sec - current_sec))

        # Determine status
        if [[ $diff -lt 0 ]]; then
            # Token expired
            print_warning "OAuth token EXPIRED $((-diff / 60)) minutes ago"
            print_info "File: $creds_file"
            print_info "Expired at: $(date -d @$expires_sec '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
            echo ""
            print_info "Run '/login' in Claude Code to refresh authentication"
            echo ""
            most_critical_status=1
        elif [[ $diff -lt $warn_threshold ]]; then
            # Token expiring soon
            local minutes=$((diff / 60))
            print_warning "OAuth token expires in $minutes minutes"
            print_info "File: $creds_file"
            print_info "Expires at: $(date -d @$expires_sec '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
            echo ""
            if [[ $most_critical_status -eq 0 ]]; then
                most_critical_status=2
            fi
        fi
    done

    return $most_critical_status
}

#######################################
# Check OAuth token and refresh if needed
# Automatically refreshes tokens expiring within TOKEN_REFRESH_THRESHOLD (7 days default)
# Arguments:
#   $1 - skip_isolated (optional): "false" (default) or "true" to use system config
# Returns:
#   0 - Token valid or refreshed successfully
#   1 - Token expired and refresh failed
# Example:
#   check_oauth_token || echo "Token refresh failed"
#######################################
check_oauth_token() {
    local skip_isolated="${1:-false}"

    # Determine credentials file path
    local credentials_file=""

    if [[ "$skip_isolated" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
        # Use isolated config
        credentials_file="$ISOLATED_NVM_DIR/.claude-isolated/.credentials.json"
    else
        # Use system config
        credentials_file="$HOME/.claude/.credentials.json"
    fi

    # If credentials file doesn't exist, nothing to check
    if [[ ! -f "$credentials_file" ]]; then
        return 0
    fi

    # Validate jq is installed
    if ! validate_jq_installed; then
        print_warning "Cannot check token expiration without jq - skipping check"
        return 0
    fi

    # Extract expiresAt field using jq with specific JSON path
    # CRITICAL: Use .claudeAiOauth.expiresAt to avoid matching mcpOAuth.*.expiresAt
    local expires_at=$(jq -r '.claudeAiOauth.expiresAt // 0' "$credentials_file" 2>/dev/null)

    # If we couldn't parse expiresAt or it's invalid, show warning and skip check
    if [[ -z "$expires_at" || "$expires_at" == "0" || "$expires_at" == "null" ]]; then
        print_warning "OAuth token expiration not found in: $credentials_file"
        print_info "Run '/login' in Claude Code if you encounter authentication issues"
        return 0
    fi

    # Validate that expires_at is a number (catches jq errors)
    if ! [[ "$expires_at" =~ ^[0-9]+$ ]]; then
        print_warning "Invalid token expiration format in: $credentials_file"
        print_info "Expected numeric timestamp, got: $expires_at"
        return 0
    fi

    # Get current time in milliseconds
    local current_time_ms=$(($(date +%s) * 1000))

    # Calculate time remaining in seconds
    local time_remaining_ms=$((expires_at - current_time_ms))
    local time_remaining_sec=$((time_remaining_ms / 1000))
    local time_remaining_min=$((time_remaining_sec / 60))

    # If token is expired or will expire within threshold (7 days default)
    if [[ $time_remaining_sec -le $TOKEN_REFRESH_THRESHOLD ]]; then
        echo ""
        if [[ $time_remaining_sec -le 0 ]]; then
            print_warning "OAuth token has expired"
        else
            local days_remaining=$((time_remaining_sec / 86400))
            local hours_remaining=$(((time_remaining_sec % 86400) / 3600))
            if [[ $days_remaining -gt 0 ]]; then
                print_warning "OAuth token expires in ${days_remaining}d ${hours_remaining}h"
            else
                print_warning "OAuth token expires in $time_remaining_min minutes"
            fi
        fi
        print_info "File: $credentials_file"
        echo ""

        # Try to refresh the token automatically
        print_info "Attempting to refresh token automatically..."
        echo ""

        if refresh_oauth_token "$skip_isolated"; then
            echo ""
            print_success "Token refreshed successfully!"
            return 0
        else
            echo ""
            print_warning "Automatic token refresh failed"
            print_info "Please run '/login' in Claude Code to authenticate"
            # Don't delete credentials - refreshToken might still be usable by Claude Code
            return 1
        fi
    fi

    # Token is valid - show remaining time if less than 1 hour
    if [[ $time_remaining_min -lt 60 ]]; then
        print_warning "OAuth token expires in $time_remaining_min minutes"
        print_info "File: $credentials_file"
        # Safely calculate timestamp (already validated as numeric above)
        local expires_sec=$((expires_at / 1000))
        local expires_date=$(date -d "@${expires_sec}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
        print_info "Expires at: $expires_date"
        echo ""
    fi

    return 0
}

#######################################
# Refresh OAuth token using setup-token
# Uses 'claude setup-token' to generate a long-lived token (~1 year)
# Arguments:
#   $1 - skip_isolated (optional): "false" (default) or "true" to use system config
# Returns:
#   0 - Token refreshed successfully
#   1 - Failed to refresh token
# Example:
#   refresh_oauth_token || echo "Token refresh failed"
#######################################
refresh_oauth_token() {
    local skip_isolated="${1:-false}"

    print_info "Generating new long-lived OAuth token..."
    echo ""

    # Determine which claude binary to use
    local claude_cmd=""

    if [[ "$skip_isolated" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
        # Try isolated environment first
        if detect_nvm "false"; then
            claude_cmd=$(get_nvm_claude_path)
        fi
    else
        # Try system installation
        if detect_nvm "true"; then
            claude_cmd=$(get_nvm_claude_path)
        fi
    fi

    # Fallback to which claude
    if [[ -z "$claude_cmd" ]]; then
        claude_cmd=$(which claude 2>/dev/null || true)
    fi

    if [[ -z "$claude_cmd" ]]; then
        print_error "Claude Code not found. Cannot refresh token."
        return 1
    fi

    print_info "Using: $claude_cmd"
    echo ""

    # Run setup-token command
    # This opens browser for OAuth and creates long-lived token
    if "$claude_cmd" setup-token; then
        echo ""
        print_success "Long-lived OAuth token created successfully!"
        print_info "Token is valid for approximately 1 year"
        return 0
    else
        echo ""
        print_error "Failed to generate token"
        print_info "Please run '/login' manually in Claude Code"
        return 1
    fi
}

#######################################
# Validate that jq is installed
# Required for parsing JSON credentials file
# Returns:
#   0 - jq is installed
#   1 - jq is not installed
# Example:
#   validate_jq_installed || echo "jq not found"
#######################################
validate_jq_installed() {
    # Delegated to core/validation.sh
    validate_dependency "jq" "Install jq: sudo apt-get install jq (Debian/Ubuntu) or brew install jq (macOS)"
}
