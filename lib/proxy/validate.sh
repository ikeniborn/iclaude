#!/bin/bash

#######################################
# Proxy Validation Module
# Description: Validate proxy URLs, resolve domains to IPs, parse proxy components
#######################################

#######################################
# Validate proxy URL format
# Arguments:
#   $1 - Proxy URL (e.g., "https://user:pass@192.168.1.100:8118")
# Returns:
#   0 - Valid URL with IP address
#   1 - Invalid format
#   2 - Valid but contains domain (warning)
# Example:
#   validate_proxy_url "$proxy_url"
#   case $? in
#     0) echo "Valid IP" ;;
#     1) echo "Invalid format" ;;
#     2) echo "Domain detected" ;;
#   esac
#######################################
validate_proxy_url() {
    local url=$1

    # Basic format check: http(s)://[user:pass@]host:port
    if [[ ! "$url" =~ ^(http|https|socks5)://.*:[0-9]+$ ]]; then
        return 1
    fi

    # Extract host from URL
    local remainder=$(echo "$url" | sed 's|^[^:]*://||')
    local host

    # Check if credentials present (contains @)
    if [[ "$remainder" =~ @ ]]; then
        # Extract host:port after @
        local hostport=$(echo "$remainder" | sed 's|^[^@]*@||')
        host=$(echo "$hostport" | cut -d':' -f1)
    else
        # No credentials, extract host directly
        host=$(echo "$remainder" | cut -d':' -f1)
    fi

    # Validate that host is an IP address
    if ! is_ip_address "$host"; then
        return 2  # Return 2 to indicate "domain instead of IP"
    fi

    return 0
}

#######################################
# Check if host is IP address (IPv4)
# Arguments:
#   $1 - Host string
# Returns:
#   0 - Valid IPv4 address
#   1 - Not an IP address
#######################################
is_ip_address() {
    local host=$1
    # Regex for IPv4 address
    if [[ "$host" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Validate each octet is 0-255
        local IFS='.'
        local -a octets=($host)
        for octet in "${octets[@]}"; do
            if (( octet > 255 )); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

#######################################
# Resolve domain to IP address using fallback chain
# Arguments:
#   $1 - Domain name (e.g., "proxy.example.com")
# Returns:
#   IP address on stdout
#   Exit code: 0 on success, 1 on failure
# Fallback order:
#   1. getent (most reliable)
#   2. host
#   3. dig
#   4. nslookup
#######################################
resolve_domain_to_ip() {
    local domain=$1

    # Try using getent first (most reliable)
    if command -v getent &> /dev/null; then
        local ip=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -n1)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    fi

    # Fallback to host command
    if command -v host &> /dev/null; then
        local ip=$(host "$domain" 2>/dev/null | grep "has address" | awk '{print $4}' | head -n1)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    fi

    # Fallback to dig command
    if command -v dig &> /dev/null; then
        local ip=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    fi

    # Fallback to nslookup
    if command -v nslookup &> /dev/null; then
        local ip=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | tail -n1 | awk '{print $2}')
        if [[ -n "$ip" ]] && is_ip_address "$ip"; then
            echo "$ip"
            return 0
        fi
    fi

    return 1
}

#######################################
# Parse proxy URL and extract components
# Arguments:
#   $1 - Proxy URL
# Returns:
#   Key=value pairs on stdout (protocol, username, password, host, port)
# Example:
#   eval $(parse_proxy_url "https://user:pass@proxy.com:8118")
#   echo "$protocol"  # https
#   echo "$username"  # user
#   echo "$password"  # pass
#   echo "$host"      # proxy.com
#   echo "$port"      # 8118
#######################################
parse_proxy_url() {
    local url=$1

    # Extract protocol
    local protocol=$(echo "$url" | grep -oP '^[^:]+')

    # Extract everything after protocol://
    local remainder=$(echo "$url" | sed 's|^[^:]*://||')

    # Check if credentials present (contains @)
    if [[ "$remainder" =~ @ ]]; then
        # Extract user:pass
        local credentials=$(echo "$remainder" | grep -oP '^[^@]+')
        local username=$(echo "$credentials" | cut -d':' -f1)
        local password=$(echo "$credentials" | cut -d':' -f2-)

        # Extract host:port after @
        local hostport=$(echo "$remainder" | sed 's|^[^@]*@||')
        local host=$(echo "$hostport" | cut -d':' -f1)
        local port=$(echo "$hostport" | cut -d':' -f2)

        echo "protocol=$protocol"
        echo "username=$username"
        echo "password=$password"
        echo "host=$host"
        echo "port=$port"
    else
        # No credentials
        local host=$(echo "$remainder" | cut -d':' -f1)
        local port=$(echo "$remainder" | cut -d':' -f2)

        echo "protocol=$protocol"
        echo "username="
        echo "password="
        echo "host=$host"
        echo "port=$port"
    fi
}
