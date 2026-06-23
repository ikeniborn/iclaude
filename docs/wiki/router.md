# Claude Code Router (CCR) Integration

## Overview

Routes Claude Code traffic through alternative AI providers — Anthropic, DeepSeek, OpenRouter, Ollama, Ollama Cloud, Gemini — via the `@musistudio/claude-code-router` (`ccr`) npm package acting as a local proxy. Enabled with `--router`: iclaude resolves the `ccr` binary, copies `router.json` into CCR's home, and either `exec`s `ccr code` (solo) or starts a `ccr start` daemon (combined with the PII proxy). Covers detection, install, status, config schema, the launch flow, attribution-header handling, per-project Langfuse tagging, and combined mode.

## Detection

`detect_router()` in `lib/router/detect.sh` returns 0 only when both hold: `router.json` exists (`$ISOLATED_NVM_DIR/.claude-isolated/router.json`, or `~/.claude/router.json` in `--system` mode), and `get_router_path()` resolves an executable `ccr`. If the config exists but the binary is missing, it warns and points at `--install-router`.

`get_router_path()` returns the first executable `ccr` it finds: `$ISOLATED_NVM_DIR/npm-global/bin/ccr` first, then `command -v ccr` on `PATH`. Returns an empty string when neither is found. A `skip_isolated="true"` argument forces the system path. Activation also requires the `--router` flag (`USE_ROUTER_FLAG`); see [[launcher#Router Launch Path (native)]].

## Configuration

`router.json` follows the CCR v2.0.0 schema. Top-level keys include `PORT` (default `3456`), `HOST` (default `127.0.0.1`), `LOG`, `LOG_LEVEL`, `API_TIMEOUT_MS`, a `Providers[]` array, a `Router` object of model slots, and an optional `transformers[]` list.

Each provider has `name`, `api_base_url`, `api_key` (use `${VAR}` placeholders so the file is safe to commit), `models`, and an optional `transformer.use`. The shipped `router.json.example` defines `anthropic`, `deepseek`, `openrouter`, `ollama`, `ollama-cloud`, and `gemini` providers. The `Router` object maps request classes to a `provider,model` pair: `default`, `background`, `think`, `longContext` (with `longContextThreshold`), `webSearch`, and `image`.

`get_ccr_port()` reads `PORT`/`HOST` via `jq` (falling back to `grep`/`sed`), validating the port is numeric and the host non-empty, and exports them as the `CCR_HOST`/`CCR_PORT` globals. When the config is absent it returns 1 and the defaults `127.0.0.1`/`3456` are retained.

## API Key Requirement

The **Anthropic** provider in `router.json` requires a real API key (`sk-ant-api03-...`) — subscription OAuth tokens (`sk-ant-oat01-...`) are rejected by `api.anthropic.com`. Other providers (DeepSeek, OpenRouter, Ollama, Gemini) need only their own keys (Ollama uses the literal `ollama`). With no Anthropic key, route every slot to a non-Anthropic provider. Keys live in `.claude_config` (e.g. `export DEEPSEEK_API_KEY=...`), referenced from `router.json` as `${VAR}`. See [[oauth#OAuth vs API Key]] for the OAuth-vs-API-key distinction and [[config#Environment Variable Export]] for the config variables.

## Installation

`install_isolated_router()` in `lib/router/install.sh` runs `npm install -g @musistudio/claude-code-router` inside the isolated NVM env (requires `--isolated-install` first), clears the bash command hash, and copies `router.json` from `router.json.example` if no config exists yet.

```bash
./iclaude.sh --install-router
```

After install, edit `router.json`, export the required API keys in `.claude_config`, then launch with `./iclaude.sh --router`. The install adds the new config to git tracking guidance (commit it with `${VAR}` placeholders only). To enable per-project Langfuse tagging, add `"x-project-id"` to a provider's `transformer.use` — the plugin path is already pre-registered in the example's `transformers` list. See [[router#Per-Project Tagging (X-Project-Id → Langfuse)]].

## Status

`check_router_status()` in `lib/router/status.sh` (via `--check-router`) reports the resolved binary path and version (`ccr -v`), the config location and size, and — when `jq` is present — the parsed provider names plus the `default`, `background`, `think`, and `longContext` models. It closes with a ready/not-configured verdict and a reminder that `--router` can combine with `--pii-proxy`.

```bash
./iclaude.sh --check-router
```

`save_lockfile()` in `lib/lockfile/save.sh` also records the CCR version (via `ccr --version`) into the lockfile alongside Claude Code and LSP versions — see [[lockfile#Save]].

## Launch Flow

`launch_claude()` in `lib/launcher/launch.sh` activates routing when `USE_ROUTER_FLAG=true` and `detect_router()` passes. It sets `CCR_HOME` to the isolated `.claude-isolated` dir (so CCR's PID file, logs, and config stay isolated rather than landing in `~/.claude-code-router/`), copies `router.json` to `$CCR_HOME/.claude-code-router/config.json`, prepends a Node v20+ bin to `PATH` (CCR 2.0.0 needs the `File` global, absent in Node 18) plus `npm-global/bin` (so CCR can spawn `claude`), and exports `ICLAUDE_ROUTER_ACTIVE=1` to suppress the rate-limit display in the [[statusline]].

In **solo** mode it ends with `HOME="$ccr_home" exec ccr code "$@"`, replacing the shell with CCR. In **combined** mode (PII proxy active) it cannot `exec`, so it starts CCR as a background daemon and falls through to the native `claude` launch. See [[launcher#Router Launch Path (native)]].

## Attribution Header

In router mode the launcher exports `CLAUDE_CODE_ATTRIBUTION_HEADER=0`, disabling Claude Code's `x-anthropic-billing-header`. That header's per-request billing hash (`cch=`) changes every request and invalidates the KV cache on proxies and routers (Ollama, CCR, Bedrock) that treat it as part of the system prompt. It is auto-disabled with `--router` and also settable via the `--no-attribution-header` flag; an explicit `CLAUDE_CODE_ATTRIBUTION_HEADER` already in the environment (e.g. from `settings.json`) is left untouched.

## Per-Project Tagging (X-Project-Id → Langfuse)

Attributes each session's LLM traffic to its repository in self-hosted Langfuse. CCR sends an `X-Project-Id` header upstream; LiteLLM's `project_tagger` turns it into the trace tag `project:<repo-name>` instead of `project:unknown`. See [[telemetry#Resource Attributes]] and [[langfuse-capture#Ingestion Payload]].

The id is derived and exported **before CCR forks**: `_init_project_id()` in [[launcher#Per-Project Tagging]] sets `ICLAUDE_PROJECT_ID` to the git toplevel basename (or `$PWD` basename), sanitized to a tag-safe slug; an explicit `ICLAUDE_PROJECT_ID` in the environment wins.

CCR 2.0.0 drops provider-level `headers` from `router.json` at `registerProvider`, so the only working injection path is a transformer plugin. `.claude-code-router/plugins/x-project-id.js` implements `transformRequestIn(request, provider)` returning `{ body, config: { headers: { "X-Project-Id": process.env.ICLAUDE_PROJECT_ID || "unknown" } } }`; CCR merges `config.headers` upstream (the same mechanism the built-in `gemini` transformer uses for `x-goog-api-key`). Enable it by adding `"x-project-id"` to the provider's `transformer.use` and the plugin path to the top-level `transformers` list (pre-registered in `router.json.example`).

Hermetic test `tests/test_x_project_id_forwarding.sh` runs CCR against a mock upstream that records headers and asserts `X-Project-Id` is forwarded (skip-aware, exit 77 when CCR is absent); `tests/test_project_id_unit.sh` covers the slug derivation and `tests/test_ccr_integration.sh` the overall launch wiring.

## Combined Mode: PII Proxy + Router

CCR and the PII proxy can run together. `--pii-proxy --router` chains traffic so masking happens before routing:

```
claude → PII proxy (:9000) → CCR (:3456) → providers
```

`start_ccr_server()` in `lib/launcher/launch.sh` launches CCR via `ccr start` (server-only, no `claude` child), health-checks the port over `/dev/tcp` for up to 5 s, and sets `ANTHROPIC_BASE_URL=http://CCR_HOST:CCR_PORT`. `start_pii_proxy_server()` then reads that as its upstream and overwrites `ANTHROPIC_BASE_URL` to its own port. If CCR is already listening, it is reused (`CCR_SESSION_OWNED=false`); otherwise the session owns the daemon (`CCR_PID`, `CCR_SESSION_OWNED=true`) and `stop_ccr_server()` tears it down on `EXIT`/`INT`/`TERM`. This chain also composes with the [[sandbox#Runtime (start_microvm)]] microVM mode. See [[pii-proxy#Architecture]] and [[proxy#Configuration Entry Point]].
