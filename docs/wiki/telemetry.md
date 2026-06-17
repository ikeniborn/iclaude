# Telemetry Module

The telemetry module (`lib/telemetry/otel.sh`) configures OpenTelemetry (OTEL) export for Claude Code, wiring metrics, logs, and resource attributes to an OTLP collector. It is loaded inside Phase 15 after argument parsing (see [[architecture#Phase and Sourcing Order]]), so the `--no-telemetry` flag and `ICLAUDE_NO_TELEMETRY` are already resolved when it runs.

## Activation

Sourcing the module immediately calls `setup_telemetry()` (the failure is non-fatal — a failed setup only logs a warning). Telemetry is **on by default**; it is disabled only when `ICLAUDE_NO_TELEMETRY=1`, in which case `setup_telemetry()` logs a debug line and returns without exporting any variables.

The launch flow normally sets `ICLAUDE_NO_TELEMETRY` from the `--no-telemetry` flag before this module is sourced, so the flag and the environment variable are equivalent switches.

## OTEL Environment Variables

When enabled, `setup_telemetry()` exports the variables Claude Code reads to turn on and route its OTLP exporters. Endpoint and protocol are defaulted but respect any value already present in the environment.

| Variable | Value |
|----------|-------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `1` (master enable flag read by Claude Code) |
| `OTEL_METRICS_EXPORTER` | `otlp` |
| `OTEL_LOGS_EXPORTER` | `otlp` |
| `OTEL_LOG_USER_PROMPTS` | `1` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://127.0.0.1:4318` (default, overridable) |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` |
| `OTEL_METRIC_EXPORT_INTERVAL` | `10000` (ms) |

`OTEL_EXPORTER_OTLP_ENDPOINT` uses the `${VAR:-default}` form, so an endpoint exported earlier (or in [[config]]) is preserved; everything else is set unconditionally.

## Resource Attributes

`OTEL_RESOURCE_ATTRIBUTES` is built as a comma-separated string identifying the service and the project being worked on. The fixed attributes are `service.name=claude-code`, `service.namespace=iclaude`, and `deployment.environment=production`; the dynamic ones are `host` (`hostname`), `wrapper.version` (`ICLAUDE_VERSION`), `proxy.profile` (`PROXY_PROFILE`), and `iclaude.project`.

The `iclaude.project` value is resolved in this order:

1. An existing `iclaude.project=` entry already embedded in `OTEL_RESOURCE_ATTRIBUTES` (honoured as-is).
2. The basename of the git `origin` remote URL (trailing `.git` stripped).
3. The basename of the git toplevel directory.
4. The basename of `$PWD`.

## Authentication

When `OTEL_EXPORTER_OTLP_CREDENTIALS` is set as `user:password` and `OTEL_EXPORTER_OTLP_HEADERS` is not already configured, the module base64-encodes the credentials and exports `OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <b64>"`. If headers are already present, the credentials are ignored.

## Proxy Bypass

`patch_no_proxy_for_telemetry()` keeps OTLP traffic off the upstream proxy by appending the endpoint host to `NO_PROXY`. It is a no-op when telemetry is disabled, when no endpoint is set, or when the host is `127.0.0.1` / `localhost`.

It must be called **after** `configure_proxy_from_url()` has set `NO_PROXY` (see [[proxy]]); it extracts the host from `OTEL_EXPORTER_OTLP_ENDPOINT` and adds it only if not already present in the `NO_PROXY` list.

## Status Output

`print_telemetry_status()` prints a one-line summary — endpoint, resolved `iclaude.project`, and protocol — when `CLAUDE_CODE_ENABLE_TELEMETRY=1`, returning silently otherwise. It uses `print_info` from [[core]] when available and falls back to a plain `echo`.

## Defensive Fallbacks

If the module is sourced standalone before the logger from [[core]] is loaded, it defines no-op `log_debug` and a stderr-printing `log_warn` so the functions remain callable in isolation.

See also: [[architecture]], [[proxy]], [[config]], [[core]]
