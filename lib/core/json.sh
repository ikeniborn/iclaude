#!/bin/bash

#######################################
# JSON Utilities Module
# Description: Helpers for reading/writing JSON files, especially lockfile
#######################################

#######################################
# Read a field from the lockfile using jq
# Arguments:
#   $1 - Field path (e.g., "nodeVersion" or ".lspServers.pyright")
# Returns:
#   Field value on stdout, or "unknown" if not found
#   Exit code: 0 on success, 1 on error
# Examples:
#   node_version=$(get_lockfile_field "nodeVersion") || return 1
#   is_sandbox=$(get_lockfile_field "sandboxAvailable") || return 1
#   pyright_ver=$(get_lockfile_field "lspServers.pyright") || return 1
#######################################
get_lockfile_field() {
    local field_path="$1"

    # Validate jq is installed
    validate_dependency "jq" "Install with: sudo apt install jq" || return 1

    # Validate lockfile exists
    if [[ ! -f "$ISOLATED_LOCKFILE" ]]; then
        print_error "Lockfile not found: $ISOLATED_LOCKFILE"
        return 1
    fi

    # Read field with jq
    local value
    value=$(jq -r ".${field_path} // \"unknown\"" "$ISOLATED_LOCKFILE" 2>/dev/null)

    # Check for null or empty
    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
        echo "unknown"
        return 1
    fi

    echo "$value"
    return 0
}

#######################################
# Write a field to the lockfile using jq
# Arguments:
#   $1 - Field path (e.g., "nodeVersion" or ".lspServers.pyright")
#   $2 - Value to write
# Returns:
#   Exit code: 0 on success, 1 on error
# Examples:
#   set_lockfile_field "claudeCodeVersion" "2.1.44" || return 1
#   set_lockfile_field "sandboxAvailable" "true" || return 1
#   set_lockfile_field "$lockfile_field" "$new_version" 2>/dev/null || true
#######################################
set_lockfile_field() {
    local field_path="$1"
    local value="$2"

    # Validate jq is installed
    validate_dependency "jq" "Install with: sudo apt install jq" || return 1

    # Validate lockfile exists (create if missing)
    if [[ ! -f "$ISOLATED_LOCKFILE" ]]; then
        echo '{}' > "$ISOLATED_LOCKFILE"
    fi

    # Write field with jq
    local tmp_file
    tmp_file=$(mktemp)

    if ! jq ".${field_path} = \"$value\"" "$ISOLATED_LOCKFILE" > "$tmp_file" 2>/dev/null; then
        print_error "Failed to update lockfile field: $field_path"
        rm -f "$tmp_file"
        return 1
    fi

    # Atomic move
    mv "$tmp_file" "$ISOLATED_LOCKFILE"
    return 0
}

#######################################
# Read a nested object field from the lockfile using jq
# Arguments:
#   $1 - Field path (e.g., "lspServers" to get entire object)
# Returns:
#   JSON object on stdout, or {} if not found
#   Exit code: 0 on success, 1 on error
# Examples:
#   lsp_servers=$(get_lockfile_object "lspServers") || return 1
#   deps=$(get_lockfile_object "sandboxDependencies") || return 1
#######################################
get_lockfile_object() {
    local field_path="$1"

    # Validate jq is installed
    validate_dependency "jq" "Install with: sudo apt install jq" || return 1

    # Validate lockfile exists
    if [[ ! -f "$ISOLATED_LOCKFILE" ]]; then
        print_error "Lockfile not found: $ISOLATED_LOCKFILE"
        echo '{}'
        return 1
    fi

    # Read object with jq
    local value
    value=$(jq -r ".${field_path} // {}" "$ISOLATED_LOCKFILE" 2>/dev/null)

    # Check for null
    if [[ "$value" == "null" ]]; then
        echo '{}'
        return 1
    fi

    echo "$value"
    return 0
}
