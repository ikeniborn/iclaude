#!/bin/bash

#######################################
# Proxy Credentials Module
# Description: Save, load, and manage proxy credentials
#######################################

#######################################
# Save proxy credentials to file
# Arguments:
#   $1 - Proxy URL
#   $2 - NO_PROXY value (optional, default: localhost,127.0.0.1,...)
# Returns:
#   Final proxy URL on stdout (after possible domain-to-IP conversion)
#   Exit code: 0 on success
# Side effects:
#   - Creates CREDENTIALS_FILE with chmod 600
#   - May prompt user for domain-to-IP conversion (for HTTP proxies)
#######################################
save_credentials() {
    local proxy_url=$1
    local no_proxy=${2:-localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org}

    # Extract protocol first
    local protocol=$(echo "$proxy_url" | grep -oP '^[^:]+')

    # Extract host from URL to check if it's a domain
    local remainder=$(echo "$proxy_url" | sed 's|^[^:]*://||')
    local host

    # Check if credentials present (contains @)
    if [[ "$remainder" =~ @ ]]; then
        local hostport=$(echo "$remainder" | sed 's|^[^@]*@||')
        host=$(echo "$hostport" | cut -d':' -f1)
    else
        host=$(echo "$remainder" | cut -d':' -f1)
    fi

    # If host is domain (not IP), handle based on protocol
    if ! is_ip_address "$host"; then
        # For HTTPS proxies, NEVER replace domain with IP
        # This is critical for OAuth and TLS (SNI, Host header)
        if [[ "$protocol" == "https" ]]; then
            print_info "Proxy URL contains domain name: $host" >&2
            echo "" >&2
            print_warning "IMPORTANT: Domain name will be preserved for HTTPS proxy" >&2
            print_info "Reason: OAuth/TLS requires proper domain for SNI and Host header" >&2
            print_info "Converting to IP would break authentication token refresh" >&2
            echo "" >&2
        else
            # For HTTP/SOCKS5, offer to resolve (old behavior)
            print_warning "Proxy URL contains domain name instead of IP address: $host" >&2
            echo "" >&2
            print_info "Attempting to resolve domain to IP address..." >&2

            local resolved_ip=$(resolve_domain_to_ip "$host")

            if [[ -n "$resolved_ip" ]]; then
                print_success "Resolved $host → $resolved_ip" >&2
                echo "" >&2
                print_info "Recommendation: Use IP address for better reliability" >&2
                echo "" >&2

                # Offer to replace domain with IP
                read -p "Replace domain with IP address? (Y/n): " -n 1 -r
                echo "" >&2

                if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                    # Replace domain with IP in URL
                    if [[ "$remainder" =~ @ ]]; then
                        # URL has credentials: protocol://user:pass@domain:port
                        local credentials=$(echo "$remainder" | grep -oP '^[^@]+')
                        local port=$(echo "$hostport" | cut -d':' -f2)
                        proxy_url="${protocol}://${credentials}@${resolved_ip}:${port}"
                    else
                        # URL has no credentials: protocol://domain:port
                        local port=$(echo "$remainder" | cut -d':' -f2)
                        proxy_url="${protocol}://${resolved_ip}:${port}"
                    fi
                    print_success "Updated URL to use IP address" >&2
                    # Show new URL with masked password
                    local display_url=$(echo "$proxy_url" | sed -E 's|://([^:]+):([^@]+)@|://\1:****@|')
                    echo "  New URL: $display_url" >&2
                else
                    print_warning "Keeping domain name (not recommended)" >&2
                    print_info "Domain resolution may fail or be unreliable" >&2
                fi
            else
                print_error "Failed to resolve domain: $host" >&2
                print_warning "Saving URL with domain name (may be unreliable)" >&2
            fi
            echo "" >&2
        fi
    fi

    # Create credentials file with restricted permissions
    touch "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"

    # Save URL, PROXY_INSECURE, PROXY_CA, NO_PROXY, and CLAUDE_CODE_MODEL (if set)
    cat > "$CREDENTIALS_FILE" << EOF
PROXY_URL=$proxy_url
PROXY_INSECURE=${PROXY_INSECURE:-false}
PROXY_CA=${PROXY_CA:-}
NO_PROXY=$no_proxy
CLAUDE_CODE_MODEL=${CLAUDE_CODE_MODEL:-}
EOF

    print_success "Credentials saved to: $CREDENTIALS_FILE" >&2

    # Return final URL (after possible domain-to-IP conversion)
    echo "$proxy_url"
}

#######################################
# Save model selection to credentials file
# Arguments:
#   $1 - Model name (e.g. claude-opus-4-6)
# Returns:
#   Exit code: 0 on success
# Side effects:
#   - Updates CLAUDE_CODE_MODEL line in CREDENTIALS_FILE (update-or-append)
#   - Creates CREDENTIALS_FILE with chmod 600 if it doesn't exist
#######################################
save_model_to_config() {
    local model_name="$1"

    if [[ -z "$model_name" ]]; then
        return 0
    fi

    # Ensure credentials file exists with correct permissions
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        touch "$CREDENTIALS_FILE"
        chmod 600 "$CREDENTIALS_FILE"
    fi

    # Update existing CLAUDE_CODE_MODEL line (including commented-out version) or append
    if grep -q "^#\?[[:space:]]*CLAUDE_CODE_MODEL=" "$CREDENTIALS_FILE" 2>/dev/null; then
        # Replace existing line (commented or uncommented)
        sed -i "s|^#\?[[:space:]]*CLAUDE_CODE_MODEL=.*|CLAUDE_CODE_MODEL=$model_name|" "$CREDENTIALS_FILE"
    else
        # Append new line
        echo "CLAUDE_CODE_MODEL=$model_name" >> "$CREDENTIALS_FILE"
    fi

    print_success "Model saved: $model_name" >&2
}

#######################################
# Load credentials from file
# Returns:
#   "URL|NO_PROXY" on stdout (pipe-separated)
#   Exit code: 0 on success, 1 if file missing or invalid
# Side effects:
#   - Exports PROXY_CA, PROXY_INSECURE
#   - Exports Claude Code configuration variables (DEBUG_STATUSLINE, etc.)
#######################################
load_credentials() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        return 1
    fi

    # Source the credentials file
    source "$CREDENTIALS_FILE"

    # Check if old format (single line with URL only)
    if [[ -z "${PROXY_URL:-}" ]]; then
        # Old format: first line is the URL
        PROXY_URL=$(head -n 1 "$CREDENTIALS_FILE")
        NO_PROXY="localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org"
    fi

    # Export loaded credentials to environment
    if [[ -n "${PROXY_CA:-}" ]] && [[ -f "$PROXY_CA" ]]; then
        export PROXY_CA
        export PROXY_INSECURE=false
    elif [[ "${PROXY_INSECURE:-true}" == "false" ]]; then
        export PROXY_INSECURE=false
    else
        export PROXY_INSECURE=true
    fi

    # Export Claude Code configuration variables (for statusline and other scripts)
    [[ -n "${DEBUG_STATUSLINE:-}" ]] && export DEBUG_STATUSLINE
    [[ -n "${CLAUDE_CODE_MAX_OUTPUT_TOKENS:-}" ]] && export CLAUDE_CODE_MAX_OUTPUT_TOKENS
    [[ -n "${CLAUDE_CODE_ENABLE_TASKS:-}" ]] && export CLAUDE_CODE_ENABLE_TASKS
    [[ -n "${CLAUDE_CODE_NO_CHROME:-}" ]] && export CLAUDE_CODE_NO_CHROME
    [[ -n "${CLAUDE_CODE_MODEL:-}" ]] && export CLAUDE_CODE_MODEL
    [[ -n "${CLAUDE_CODE_SESSION_TIMEOUT:-}" ]] && export CLAUDE_CODE_SESSION_TIMEOUT
    [[ -n "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" ]] && export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
    [[ -n "${TOKEN_REFRESH_THRESHOLD:-}" ]] && export TOKEN_REFRESH_THRESHOLD

    if [[ -z "$PROXY_URL" ]]; then
        return 1
    fi

    # Validate URL format (allow domains for backward compatibility)
    local validation_result
    validate_proxy_url "$PROXY_URL"
    validation_result=$?

    if [[ $validation_result -eq 1 ]]; then
        # Invalid format
        print_warning "Saved credentials have invalid format, will prompt for new URL" >&2
        return 1
    elif [[ $validation_result -eq 2 ]]; then
        # Domain instead of IP (warn only for HTTP, not HTTPS)
        local protocol=$(echo "$PROXY_URL" | grep -oP '^[^:]+')
        if [[ "$protocol" != "https" ]]; then
            # For HTTP: domain is not recommended
            print_warning "Saved proxy URL uses domain name instead of IP address" >&2
            print_info "Consider updating to IP address for better reliability" >&2
        fi
        # For HTTPS: domain is correct, no warning needed
    fi

    # Set default NO_PROXY if not present (backward compatibility)
    if [[ -z "${NO_PROXY:-}" ]]; then
        NO_PROXY="localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org"
    fi

    # Return URL and NO_PROXY (pipe-separated for reliable parsing)
    echo "$PROXY_URL|${NO_PROXY}"
    return 0
}

#######################################
# Clear saved credentials
# Side effects:
#   - Deletes CREDENTIALS_FILE
#######################################
clear_credentials() {
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        rm -f "$CREDENTIALS_FILE"
        print_success "Saved credentials cleared"
    else
        print_info "No saved credentials found"
    fi
}

#######################################
# Prompt user for proxy URL (interactive)
# Returns:
#   "URL|NO_PROXY" on stdout (pipe-separated)
#   Exit code: 0 on success, 1 on failure
# Side effects:
#   - Prompts user for input if no saved credentials
#   - Validates URL format
#######################################
prompt_proxy_url() {
    local saved_credentials

    # Check if credentials exist
    if saved_credentials=$(load_credentials); then
        # Parse pipe-separated output: URL|NO_PROXY
        local saved_url=$(echo "$saved_credentials" | cut -d'|' -f1)
        local saved_no_proxy=$(echo "$saved_credentials" | cut -d'|' -f2)

        print_info "Saved proxy found" >&2
        echo "" >&2
        # Hide password in display
        local display_url=$(echo "$saved_url" | sed -E 's|://([^:]+):([^@]+)@|://\1:****@|')
        echo "  URL: $display_url" >&2
        echo "" >&2

        # Auto-use saved proxy (no confirmation needed)
        echo "$saved_url|$saved_no_proxy"
        return 0
    fi

    # Prompt for new URL
    echo "" >&2
    print_info "Enter proxy URL" >&2
    echo "" >&2
    echo "Format: protocol://username:password@host:port" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  HTTPS (recommended): https://alice:secret123@proxy.example.com:8118" >&2
    echo "  HTTP (not recommended): http://alice:secret123@192.168.1.100:8118" >&2
    echo "" >&2
    echo "Note: HTTPS proxies REQUIRE domain names (not IPs) for OAuth/TLS to work" >&2
    echo "Supported protocols: https (recommended), http" >&2
    echo "" >&2

    while true; do
        local proxy_url=""
        if [ -t 0 ]; then
            read -p "Proxy URL: " proxy_url >&2
        else
            # Non-interactive mode: cannot prompt for new URL
            print_error "Cannot prompt for proxy URL in non-interactive mode" >&2
            echo "Use: iclaude --proxy <url>" >&2
            exit 1
        fi

        if [[ -z "$proxy_url" ]]; then
            print_error "URL cannot be empty" >&2
            continue
        fi

        local validation_result
        validate_proxy_url "$proxy_url"
        validation_result=$?

        if [[ $validation_result -eq 1 ]]; then
            print_error "Invalid URL format" >&2
            echo "Expected: protocol://[user:pass@]host:port" >&2
            continue
        elif [[ $validation_result -eq 2 ]]; then
            # Domain in URL - check protocol
            local protocol=$(echo "$proxy_url" | grep -oP '^[^:]+')
            if [[ "$protocol" == "https" ]]; then
                # For HTTPS: domain is REQUIRED (no warning)
                print_success "HTTPS proxy with domain name - correct for OAuth/TLS!" >&2
                echo "" >&2
            else
                # For HTTP: domain is not recommended
                print_warning "URL contains domain name instead of IP address" >&2
                echo "Domains may be less reliable than IP addresses" >&2
                echo "Consider using IP address (will be resolved during save)" >&2
                echo "" >&2
            fi
        fi

        # Return URL with default NO_PROXY (pipe-separated)
        echo "$proxy_url|localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org"
        return 0
    done
}
