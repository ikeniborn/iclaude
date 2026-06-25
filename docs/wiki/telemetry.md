# Telemetry Module

## Overview

The telemetry module (`lib/telemetry/otel.sh`) configures OpenTelemetry (OTEL) export for Claude Code, wiring metrics, logs, resource attributes, optional BasicAuth, and proxy bypass to an OTLP collector. It is sourced in Phase 15 after argument parsing (see [[architecture#Phase and Sourcing Order]]); `source_iclaude_config` is called immediately before the source so `USE_OTEL`, the OTLP endpoint, credentials, and `OTEL_LOG_USER_PROMPTS` from [[config]] are all resolved in the environment when `setup_telemetry()` auto-runs.

## Activation

Telemetry is **opt-in (default OFF)**, symmetric with `USE_LANGFUSE_CAPTURE` (see [[langfuse-capture#Activation]]). Sourcing the module immediately calls `setup_telemetry()`; failure is non-fatal (`setup_telemetry || log_warn "telemetry setup failed (non-fatal)"`). `setup_telemetry()` exports the OTEL variables only when `USE_OTEL=true` (de-prefixed from `ICLAUDE_USE_OTEL`); otherwise it logs a debug line and returns without exporting anything.

`ICLAUDE_NO_TELEMETRY=1` is a **kill-switch** checked first — it overrides `USE_OTEL=true`. The `--no-telemetry` CLI flag is parsed in the Phase 15 `while`/`case` loop, which runs `export ICLAUDE_NO_TELEMETRY=1` before the module is sourced — so flag and env var are equivalent switches. Because `ICLAUDE_NO_TELEMETRY` is on the env-map native denylist (see [[config#Environment Variable Export]]), it can also be set verbatim in `.claude_config` (never de-prefixed). Note: a stale double-prefixed `ICLAUDE_ICLAUDE_NO_TELEMETRY=0` left in `.claude_config` de-prefixes to `ICLAUDE_NO_TELEMETRY=0` and, because config is now applied before telemetry setup, would override `--no-telemetry` — remove it and use `ICLAUDE_USE_OTEL` instead.

## OTEL Environment Variables

When enabled (`USE_OTEL=true`), `setup_telemetry()` exports the variables Claude Code reads to turn on and route its OTLP exporters. The endpoint and `OTEL_LOG_USER_PROMPTS` defer to a pre-existing value (so a `.claude_config` setting wins); the rest are set unconditionally.

| Variable | Value |
|----------|-------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `1` (master enable flag read by Claude Code) |
| `OTEL_METRICS_EXPORTER` | `otlp` |
| `OTEL_LOGS_EXPORTER` | `otlp` |
| `OTEL_LOG_USER_PROMPTS` | `${OTEL_LOG_USER_PROMPTS:-0}` (privacy-safe default `0`, overridable) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://127.0.0.1:4318` (default, overridable) |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` |
| `OTEL_METRIC_EXPORT_INTERVAL` | `10000` (ms) |

`OTEL_EXPORTER_OTLP_ENDPOINT` and `OTEL_LOG_USER_PROMPTS` use the `${VAR:-default}` form, so a value exported earlier (or in [[config]]) is preserved; the remaining variables are assigned with plain `export VAR=value` and overwrite anything inherited.

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

See also: [[observability]], [[architecture]], [[proxy]], [[config]], [[core]], [[launcher]]
