# Claude Code Router (CCR) Integration

Integrates the `@musistudio/claude-code-router` npm package (`ccr` binary) to route Claude Code traffic through alternative AI providers — OpenRouter, DeepSeek, Ollama, and others — by acting as a local proxy in front of the Anthropic API.

## Overview

CCR replaces or supplements the direct Anthropic API connection. When enabled (via `--router`), iclaude launches `ccr` and sets `ANTHROPIC_BASE_URL` to point at the CCR listener. Provider selection and model routing are governed by `router.json`. Claude Code itself is unaware of the redirection.

The router module requires a **real API key** (`sk-ant-api03-...`), not an OAuth token (`sk-ant-oat01-...`). See [[proxy#Configuration Entry Point]] for how the upstream HTTPS proxy interacts with CCR.

## Detection

`detect_router()` in `lib/router/detect.sh` returns 0 only when both conditions hold:

1. `router.json` exists at `$ISOLATED_NVM_DIR/.claude-isolated/router.json` (or `~/.claude/router.json` when not using the isolated environment).
2. The `ccr` binary is executable — checked first in `$ISOLATED_NVM_DIR/npm-global/bin/`, then via `command -v ccr` in `PATH`.

`get_router_path()` implements this search order and returns the resolved path or an empty string.

## Configuration

`router.json` follows the CCR v2.0.0 schema. Key fields:

| Field | Purpose |
|---|---|
| `PORT` | Port CCR listens on (default: `3456`) |
| `HOST` | Bind address (default: `127.0.0.1`) |
| `Providers[].name` | Human-readable provider label (shown in status) |
| `Router.default` | Model used for ordinary requests |
| `Router.background` | Model for background tasks |
| `Router.think` | Model for extended-thinking requests |
| `Router.longContext` | Model for long-context requests |

`get_ccr_port()` reads `PORT` and `HOST` from `router.json` using `jq` (falls back to `grep`/`sed`) and exports them as `CCR_HOST` and `CCR_PORT` globals. These defaults are `127.0.0.1` and `3456` when the config is absent.

Store provider API keys as shell exports in `.claude_config` (e.g. `export DEEPSEEK_API_KEY=...`). The `router.json` file itself should use `${VAR}` placeholders so it is safe to commit to git.

## Installation

`install_isolated_router()` in `lib/router/install.sh` runs `npm install -g @musistudio/claude-code-router` inside the isolated NVM environment and creates `router.json` from `router.json.example` if no config file exists yet.

**Install command:**
```bash
./iclaude.sh --install-router
```

After install, edit `router.json`, export required API keys in `.claude_config`, then launch with `./iclaude.sh --router`.

## Status

`check_router_status()` in `lib/router/status.sh` reports:

- Binary path and version (`ccr -v`)
- Config file location and size
- Parsed providers, default model, background model, think model, long-context model (requires `jq`)
- Whether both binary and config are present (ready vs. not configured)

**Status command:**
```bash
./iclaude.sh --check-router
```

## Per-Project Tagging (X-Project-Id → Langfuse)

Attributes each session's LLM traffic to its repository in self-hosted Langfuse. CCR sends an `X-Project-Id` header to the upstream provider; LiteLLM's `project_tagger` turns it into the trace tag `project:<repo-name>` instead of the default `project:unknown`.

The id is derived and exported **before CCR starts**: `_init_project_id()` in [[launcher#Per-Project Tagging]] (`lib/launcher/launch.sh`, called in `launch_claude()` right after router detection) sets `ICLAUDE_PROJECT_ID` to the git toplevel basename (or `$PWD` basename), sanitized to a tag-safe slug via `_derive_project_id()`. An explicit `ICLAUDE_PROJECT_ID` already in the environment (e.g. `.claude_config`) wins. CCR is forked on the host in every mode, so this host-side export reaches it.

CCR 2.0.0 does **not** forward provider-level `headers` from `router.json` — they are dropped at `registerProvider`. The only working injection path is a **transformer plugin**: `.claude-code-router/plugins/x-project-id.js` implements `transformRequestIn(request, provider)` returning `{ body, config: { headers: { "X-Project-Id": process.env.ICLAUDE_PROJECT_ID || "unknown" } } }`; CCR merges `config.headers` into the upstream request (the same mechanism the built-in `gemini` transformer uses for `x-goog-api-key`). Register it by adding `"x-project-id"` to the provider's `transformer.use` and the plugin path to the top-level `transformers` list.

Hermetic test: `tests/test_x_project_id_forwarding.sh` runs CCR against a mock upstream that records received headers and asserts `X-Project-Id` is forwarded (skip-aware, exit 77 when CCR is absent).

## Combined Mode: PII Proxy + Router

CCR and the PII proxy can run together. In combined mode traffic flows:

```
claude → PII proxy (:9000) → CCR (:3456) → providers
```

`ANTHROPIC_UPSTREAM_URL` on the PII proxy is set to `http://127.0.0.1:3456` (read from `CCR_HOST`/`CCR_PORT`). This means PII masking happens before routing decisions. See [[pii-proxy#Architecture]] for the PII proxy's request pipeline.
