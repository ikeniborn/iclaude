# Telemetry Module

## Overview

The telemetry module (`lib/telemetry/otel.sh`) configures OpenTelemetry (OTEL) export for Claude Code, wiring metrics, logs, resource attributes, optional BasicAuth, and proxy bypass to an OTLP collector. It is sourced in Phase 15 after argument parsing (see [[architecture#Phase and Sourcing Order]]), so `--no-telemetry` / `ICLAUDE_NO_TELEMETRY` is already resolved when `setup_telemetry()` auto-runs.

## Activation

Telemetry is **on by default**. Sourcing the module immediately calls `setup_telemetry()`; failure is non-fatal (`setup_telemetry || log_warn "telemetry setup failed (non-fatal)"`). It is disabled only when `ICLAUDE_NO_TELEMETRY=1`, in which case `setup_telemetry()` logs a debug line and returns without exporting any variables.

The `--no-telemetry` CLI flag is parsed in the Phase 15 `while`/`case` loop, which runs `export ICLAUDE_NO_TELEMETRY=1` before the module is sourced — so flag and env var are equivalent switches. Because `ICLAUDE_NO_TELEMETRY` is on the env-map native denylist (see [[config#Environment Variable Export]]), it can also be set verbatim in `.claude_config` (never de-prefixed).

## OTEL Environment Variables

When enabled, `setup_telemetry()` exports the variables Claude Code reads to turn on and route its OTLP exporters. Only the endpoint defers to a pre-existing value; everything else is set unconditionally.

| Variable | Value |
|----------|-------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `1` (master enable flag read by Claude Code) |
| `OTEL_METRICS_EXPORTER` | `otlp` |
| `OTEL_LOGS_EXPORTER` | `otlp` |
| `OTEL_LOG_USER_PROMPTS` | `1` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://127.0.0.1:4318` (default, overridable) |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` |
| `OTEL_METRIC_EXPORT_INTERVAL` | `10000` (ms) |

`OTEL_EXPORTER_OTLP_ENDPOINT` uses the `${VAR:-default}` form, so an endpoint exported earlier (or in [[config]]) is preserved; the remaining six variables are assigned with plain `export VAR=value` and overwrite anything inherited.

## Resource Attributes

`OTEL_RESOURCE_ATTRIBUTES` is built as one comma-separated string identifying the service and the project being worked on. The fixed attributes are `service.name=claude-code`, `service.namespace=iclaude`, and `deployment.environment=production`; the dynamic ones are `host` (`hostname`), `wrapper.version` (`ICLAUDE_VERSION`, default `unknown`), `proxy.profile` (`PROXY_PROFILE`, default `default`), and `iclaude.project`.

The `iclaude.project` value is resolved in this order:

1. An existing `iclaude.project=` entry already embedded in `OTEL_RESOURCE_ATTRIBUTES` (parsed out and honoured as-is).
2. The basename of the git `origin` remote URL (trailing `.git` stripped). The remote is looked up against the git toplevel directory, falling back to `$PWD`.
3. The basename of the git toplevel directory.
4. The basename of `$PWD`.

## Authentication

When `OTEL_EXPORTER_OTLP_CREDENTIALS` is set (as `user:password`) and `OTEL_EXPORTER_OTLP_HEADERS` is not already configured, the module base64-encodes the credentials (`base64 -w 0`) and exports `OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <b64>"`. If headers are already present, the credentials are ignored.

## Proxy Bypass

`patch_no_proxy_for_telemetry()` keeps OTLP traffic off the upstream proxy by appending the endpoint host to `NO_PROXY`. It is a no-op when telemetry is disabled (`CLAUDE_CODE_ENABLE_TELEMETRY != 1`), when no endpoint is set, or when the extracted host is `127.0.0.1` / `localhost`.

It is invoked from the launch flow **immediately after** `configure_proxy_from_url()` has set `NO_PROXY` (see [[proxy]]). It extracts the host from `OTEL_EXPORTER_OTLP_ENDPOINT` via a `sed` regex and appends it only if not already present in the comma-delimited `NO_PROXY` list.

## Status Output

`print_telemetry_status()` prints a one-line summary — endpoint, resolved `iclaude.project` (default `unknown`), and protocol — when `CLAUDE_CODE_ENABLE_TELEMETRY=1`, returning silently otherwise. It is called from the launcher just before handoff (see [[launcher]]). It uses `print_info` from [[core]] when available and falls back to a plain `echo`.

## Defensive Fallbacks

If the module is sourced standalone before the logger from [[core]] is loaded, it defines a no-op `log_debug` and a stderr-printing `log_warn` (only when those functions are not already defined), so its functions remain callable in isolation.

See also: [[architecture]], [[proxy]], [[config]], [[core]], [[launcher]]
