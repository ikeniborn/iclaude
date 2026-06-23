#!/bin/bash

#######################################
# Config Env-Map Module
# Description: Single chokepoint that loads .claude_config (ICLAUDE_*-only,
#              no `export`) and translates each ICLAUDE_X back to the canonical
#              environment variable X that built-in tools read. Plus one-time
#              legacy auto-migration.
#######################################

# Native ICLAUDE_* names consumed verbatim (caveman hooks / statusline / runtime).
# These must NOT be de-prefixed.
ICLAUDE_NATIVE=(
    ICLAUDE_CHAT_LANG ICLAUDE_DOC_LANG ICLAUDE_NO_TELEMETRY ICLAUDE_NO_AUTO_UPDATE
    ICLAUDE_PII_ACTIVE ICLAUDE_PII_MASKING_LEVEL ICLAUDE_PII_ACTIVE_PORT ICLAUDE_PII_LOG_PATH
)

# Translated vars where an empty-but-set value is meaningful (default skips empties).
ICLAUDE_ALLOW_EMPTY=( ICLAUDE_PII_PROXY_MASK_TOKEN )

# Membership test: is $1 present among the remaining args?
_in_list() {
    local needle="$1"; shift
    local x
    for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
    return 1
}

#######################################
# Translate every set ICLAUDE_* var into the canonical name the tools expect.
# - Native names (denylist): exported verbatim, never de-prefixed.
# - Allow-empty names: exported even when set-but-empty.
# - All others: exported under the de-prefixed name when non-empty.
#######################################
apply_iclaude_env_map() {
    local v name
    for v in ${!ICLAUDE_@}; do
        if _in_list "$v" "${ICLAUDE_NATIVE[@]}"; then
            [[ -n ${!v:-} ]] && export "$v"
            continue
        fi
        name=${v#ICLAUDE_}
        if _in_list "$v" "${ICLAUDE_ALLOW_EMPTY[@]}"; then
            [[ -n ${!v+x} ]] && export "$name=${!v}"
        else
            [[ -n ${!v:-} ]] && export "$name=${!v}"
        fi
    done
}

#######################################
# The ONLY place that loads the config: source then translate.
# Safe to call multiple times (idempotent re-export).
#######################################
source_iclaude_config() {
    [[ -f "$CREDENTIALS_FILE" ]] || return 0
    source "$CREDENTIALS_FILE"
    apply_iclaude_env_map
}

#######################################
# Detect a legacy config: any `export ` line, or any active assignment whose
# variable name does not start with ICLAUDE_.
# Returns 0 (legacy) / 1 (already migrated or empty).
#######################################
_config_is_legacy() {
    local f="$1"
    [[ -f "$f" ]] || return 1
    grep -qE '^[[:space:]]*export[[:space:]]' "$f" && return 0
    grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$f" 2>/dev/null \
        | grep -qvE '^[[:space:]]*ICLAUDE_' && return 0
    return 1
}

#######################################
# One-time migration: rename active assignments to ICLAUDE_*, strip `export`.
# Comments and prose are left untouched. Writes a chmod-600 .bak first, rewrites
# via temp + mv. Idempotent (legacy markers vanish after a successful run).
#######################################
migrate_legacy_config() {
    local f="$CREDENTIALS_FILE"
    [[ -f "$f" ]] || return 0
    _config_is_legacy "$f" || return 0

    local bak="${f}.bak" tmp="${f}.tmp.$$"
    if ! cp -p "$f" "$bak" 2>/dev/null; then
        print_warning "Could not back up $f; skipping ICLAUDE_ migration (file left as-is)"
        return 0
    fi
    chmod 600 "$bak" 2>/dev/null || true

    if awk '
        {
            if ($0 ~ /^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=/) {
                match($0, /^[[:space:]]*/); indent = substr($0, 1, RLENGTH)
                rest = substr($0, RLENGTH + 1)
                sub(/^export[[:space:]]+/, "", rest)
                eq = index(rest, "=")
                name = substr(rest, 1, eq - 1)
                val  = substr(rest, eq)
                if (name !~ /^ICLAUDE_/) name = "ICLAUDE_" name
                print indent name val
            } else {
                print
            }
        }
    ' "$f" > "$tmp" 2>/dev/null && mv "$tmp" "$f"; then
        chmod 600 "$f" 2>/dev/null || true
        print_info "Migrated .claude_config → ICLAUDE_* (backup: $(basename "$bak"))"
    else
        rm -f "$tmp"
        print_warning "ICLAUDE_ migration failed; original left intact (backup: $(basename "$bak"))"
    fi
}
