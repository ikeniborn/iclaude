#!/usr/bin/env bash
# Telemetry module — sets OTEL env vars for Claude Code.
# Honors --no-telemetry flag and ICLAUDE_NO_TELEMETRY=1.

# Defensive fallbacks if sourced standalone (no logger module loaded yet).
command -v log_debug >/dev/null 2>&1 || log_debug() { :; }
command -v log_warn  >/dev/null 2>&1 || log_warn()  { echo "warn: $*" >&2; }

setup_telemetry() {
    if [[ "${ICLAUDE_NO_TELEMETRY:-0}" == "1" ]]; then
        log_debug "telemetry disabled (ICLAUDE_NO_TELEMETRY=1)"
        return 0
    fi

    local project toplevel remote existing_project
    # If caller already embedded iclaude.project in OTEL_RESOURCE_ATTRIBUTES, honour it.
    existing_project="$(printf '%s' "${OTEL_RESOURCE_ATTRIBUTES:-}" | tr ',' '\n' \
        | sed -n 's/^iclaude\.project=//p' | head -1)"
    if [[ -n "$existing_project" ]]; then
        project="$existing_project"
    else
        toplevel="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)" || toplevel=""
        remote="$(git -C "${toplevel:-$PWD}" remote get-url origin 2>/dev/null)" || remote=""
        if [[ -n "$remote" ]]; then
            # strip trailing .git, then take last path segment
            project="$(basename "${remote%.git}")"
        elif [[ -n "$toplevel" ]]; then
            project="$(basename "$toplevel")"
        else
            project="$(basename "$PWD")"
        fi
    fi

    export CLAUDE_CODE_ENABLE_TELEMETRY=1
    export OTEL_METRICS_EXPORTER=otlp
    export OTEL_LOGS_EXPORTER=otlp
    export OTEL_LOG_USER_PROMPTS=1
    export OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://127.0.0.1:4318}"
    export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
    export OTEL_METRIC_EXPORT_INTERVAL=10000

    # Auto-generate BasicAuth header from credentials if set and headers not already configured.
    # OTEL_EXPORTER_OTLP_CREDENTIALS="user:password"
    if [[ -n "${OTEL_EXPORTER_OTLP_CREDENTIALS:-}" && -z "${OTEL_EXPORTER_OTLP_HEADERS:-}" ]]; then
        local b64
        b64="$(printf '%s' "${OTEL_EXPORTER_OTLP_CREDENTIALS}" | base64 -w 0)"
        export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic ${b64}"
        log_debug "telemetry: BasicAuth header generated from OTEL_EXPORTER_OTLP_CREDENTIALS"
    fi

    export OTEL_RESOURCE_ATTRIBUTES="service.name=claude-code,service.namespace=iclaude,iclaude.project=${project},host=$(hostname),wrapper.version=${ICLAUDE_VERSION:-unknown},proxy.profile=${PROXY_PROFILE:-default},deployment.environment=production"

    log_debug "telemetry enabled: project=$project"
}

# Add OTEL endpoint host to NO_PROXY so traffic bypasses the proxy.
# Must be called AFTER configure_proxy_from_url() sets NO_PROXY.
patch_no_proxy_for_telemetry() {
    [[ "${CLAUDE_CODE_ENABLE_TELEMETRY:-0}" != "1" ]] && return 0
    local endpoint="${OTEL_EXPORTER_OTLP_ENDPOINT:-}"
    [[ -z "$endpoint" ]] && return 0
    local host
    host="$(printf '%s' "$endpoint" | sed -E 's|^https?://([^/:]+).*|\1|')"
    [[ -z "$host" || "$host" == "127.0.0.1" || "$host" == "localhost" ]] && return 0
    if [[ ",${NO_PROXY:-}," != *",${host},"* ]]; then
        NO_PROXY="${NO_PROXY:+${NO_PROXY},}${host}"
        export NO_PROXY
        log_debug "telemetry: ${host} added to NO_PROXY"
    fi
}

print_telemetry_status() {
    if [[ "${CLAUDE_CODE_ENABLE_TELEMETRY:-0}" != "1" ]]; then
        return 0
    fi
    local endpoint="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://127.0.0.1:4318}"
    local project
    project="$(printf '%s' "${OTEL_RESOURCE_ATTRIBUTES:-}" | tr ',' '\n' | awk -F= '/^iclaude\.project=/{print $2; exit}')"
    [[ -z "$project" ]] && project="unknown"
    echo ""
    if command -v print_info >/dev/null 2>&1; then
        print_info "Telemetry: enabled → ${endpoint} (project=${project}, protocol=${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf})"
    else
        echo "Telemetry: enabled → ${endpoint} (project=${project}, protocol=${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf})"
    fi
    echo ""
}

setup_telemetry || log_warn "telemetry setup failed (non-fatal)"
