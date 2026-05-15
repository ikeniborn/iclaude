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

    local project toplevel
    toplevel="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)" || toplevel=""
    if [[ -n "$toplevel" ]]; then
        project="$(basename "$toplevel")"
    else
        project="$(basename "$PWD")"
    fi

    export CLAUDE_CODE_ENABLE_TELEMETRY=1
    export OTEL_METRICS_EXPORTER=otlp
    export OTEL_LOGS_EXPORTER=otlp
    export OTEL_LOG_USER_PROMPTS=1
    export OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://127.0.0.1:4318}"
    export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
    export OTEL_METRIC_EXPORT_INTERVAL=10000

    export OTEL_RESOURCE_ATTRIBUTES="service.name=claude-code,service.namespace=iclaude,project=${project},host=$(hostname),wrapper.version=${ICLAUDE_VERSION:-unknown},proxy.profile=${PROXY_PROFILE:-default},deployment.environment=production"

    log_debug "telemetry enabled: project=$project"
}

setup_telemetry || log_warn "telemetry setup failed (non-fatal)"
