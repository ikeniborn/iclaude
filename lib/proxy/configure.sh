#!/bin/bash

#######################################
# Proxy Configuration Module
# Description: Configure proxy environment variables and test connectivity
#######################################

#######################################
# Configure proxy from URL
# Arguments:
#   $1 - Proxy URL
#   $2 - NO_PROXY value (optional)
# Side effects:
#   - Exports HTTPS_PROXY, HTTP_PROXY, NO_PROXY
#   - Exports NODE_EXTRA_CA_CERTS or NODE_TLS_REJECT_UNAUTHORIZED
#   - May save credentials (if new URL)
#   - Configures git to use NO_PROXY
#######################################
configure_proxy_from_url() {
    local proxy_url=$1
    local no_proxy=${2:-localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org}
    local final_proxy_url="$proxy_url"

    # Only save credentials if this is a new URL (not loaded from file)
    # Check if credentials file exists and URL matches
    local skip_save=false
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        source "$CREDENTIALS_FILE"
        if [[ "${PROXY_URL:-}" == "$proxy_url" ]]; then
            # URL matches saved credentials - skip save to preserve PROXY_CA and PROXY_INSECURE
            skip_save=true
        fi
    fi

    if [[ "$skip_save" == false ]]; then
        # Save credentials (may convert domain to IP)
        # and get the final URL (possibly with IP instead of domain)
        final_proxy_url=$(save_credentials "$proxy_url" "$no_proxy")
    fi

    # Set environment variables with final URL (after possible domain-to-IP conversion)
    export HTTPS_PROXY="$final_proxy_url"
    export HTTP_PROXY="$final_proxy_url"
    export NO_PROXY="$no_proxy"

    # Configure TLS certificate handling
    if [[ -n "${PROXY_CA:-}" ]] && [[ -f "$PROXY_CA" ]]; then
        # Use provided CA certificate (secure mode)
        export NODE_EXTRA_CA_CERTS="$PROXY_CA"
        print_info "Using proxy CA certificate: $PROXY_CA"
    elif [[ "${PROXY_INSECURE:-true}" == "true" ]]; then
        # Fallback to insecure mode (disable TLS verification)
        export NODE_TLS_REJECT_UNAUTHORIZED=0
        print_warning "TLS certificate verification disabled (insecure mode)"
    fi

    # Configure git to ignore proxy
    configure_git_no_proxy
}

#######################################
# Configure git to use NO_PROXY environment variable
# Note: We don't modify git config globally anymore (can break other tools)
# Git automatically respects NO_PROXY environment variable
#######################################
configure_git_no_proxy() {
    # IMPORTANT: We no longer modify git config globally as it can break other tools
    # Git will automatically use NO_PROXY environment variable if set

    # Just log for information
    print_info "Git will use NO_PROXY for localhost/127.0.0.1 and git hosting services"

    # Note: We keep save_git_proxy_settings call for compatibility with restore function
    # but we don't actually modify git config anymore
}

#######################################
# Display proxy configuration
# Arguments:
#   $1 - Show password (true/false, default: false)
#######################################
display_proxy_info() {
    local show_password=${1:-false}

    echo ""
    print_success "Proxy configured:"
    echo ""

    if [[ "$show_password" == "true" ]]; then
        echo "  HTTPS_PROXY: $HTTPS_PROXY"
        echo "  HTTP_PROXY:  $HTTP_PROXY"
    else
        # Hide password
        local masked_https=$(echo "$HTTPS_PROXY" | sed -E 's|://([^:]+):([^@]+)@|://\1:****@|')
        local masked_http=$(echo "$HTTP_PROXY" | sed -E 's|://([^:]+):([^@]+)@|://\1:****@|')
        echo "  HTTPS_PROXY: $masked_https"
        echo "  HTTP_PROXY:  $masked_http"
    fi

    echo "  NO_PROXY:    $NO_PROXY"
    echo ""

    # Note: We no longer modify git proxy settings
    # Git respects NO_PROXY environment variable automatically
    print_info "Git will bypass proxy for: localhost, 127.0.0.1, github.com, gitlab.com, bitbucket.org"
    echo ""
}

#######################################
# Test proxy connectivity
# Returns:
#   0 - Proxy connection successful
#   1 - Proxy connection failed
# Note: Uses curl with proxy to test connection to google.com
#######################################
test_proxy() {
    print_info "Testing proxy connectivity..."

    # Use -x flag to explicitly pass proxy to curl (works better than env vars)
    local proxy_url="${HTTPS_PROXY:-${HTTP_PROXY}}"

    if [[ -z "$proxy_url" ]]; then
        print_warning "No proxy configured, skipping test"
        return 0
    fi

    # Prepare curl command with proxy (use -k for insecure mode by default)
    # Timeout 15s to allow TLS handshake with proxy + CONNECT + TLS to target
    local curl_opts=(-x "$proxy_url" -k -s -m 15 -o /dev/null -w "%{http_code}")

    # For HTTPS proxies, also use --proxy-insecure
    if [[ "$proxy_url" =~ ^https:// ]]; then
        curl_opts+=(--proxy-insecure)
    fi

    # Test connection through proxy to Anthropic API endpoint.
    # /v1/models returns 401 (Unauthorized) without an API key — confirming
    # the proxy can reach the API and the endpoint exists.
    # IMPORTANT: unset HTTPS_PROXY/HTTP_PROXY env vars before curl call.
    # If they are already exported (by configure_proxy_from_url), curl picks up
    # both the -x flag AND the env var, tries to proxy-through-proxy → returns 000.
    # We use -x explicitly, so env proxy vars must be cleared.
    local http_code=$(HTTPS_PROXY="" HTTP_PROXY="" https_proxy="" http_proxy="" \
        curl "${curl_opts[@]}" https://api.anthropic.com/v1/models 2>/dev/null)

    if [[ "$http_code" == "000" ]]; then
        print_warning "Proxy connection failed (timeout or refused)"
        echo ""
        echo "  This could mean:"
        echo "  - Proxy server is unreachable or down"
        echo "  - Incorrect credentials"
        echo "  - Firewall blocking the connection"
        echo ""
        echo "  Claude Code may still work if proxy becomes available"
        return 1
    else
        # Any non-000 response means the proxy can reach the Anthropic API.
        # 401 (no API key) is the expected response — confirms endpoint is live.
        print_success "Proxy connection successful (Anthropic API reachable)"
        return 0
    fi
}
