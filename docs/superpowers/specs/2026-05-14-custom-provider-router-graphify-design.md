# Custom OpenAI-Compatible Provider: CCR + Graphify Integration Design

**Date:** 2026-05-14  
**Status:** Draft

## Goal

Configure Claude Code Router (`router.json`) and Graphify to use a self-hosted
OpenAI-compatible provider instead of Ollama. One endpoint, two models (fast +
smart), all CCR roles covered, Graphify extraction via the same endpoint.

## Scope

- `router.json` — replace Ollama provider with custom provider block
- `.claude_config` — env variables for secrets and Graphify backend
- No code changes to `lib/` — purely configuration

## Out of Scope

- Changing transformer logic (not needed for OpenAI-compatible API)
- Adding a new named Graphify backend (using existing `ollama` backend with env override)

---

## router.json Changes

### Provider block

```json
{
  "name": "myprovider",
  "api_base_url": "${MY_PROVIDER_URL}/v1/chat/completions",
  "api_key": "${MY_PROVIDER_API_KEY}",
  "models": ["fast-model", "smart-model"]
}
```

No `transformer` field — the provider speaks OpenAI format natively. CCR passes
requests as-is.

### Router section

```json
"Router": {
  "default":              "myprovider,smart-model",
  "background":           "myprovider,fast-model",
  "think":                "myprovider,smart-model",
  "longContext":          "myprovider,smart-model",
  "longContextThreshold": 200000
}
```

`background` → fast model (cheap, quick sub-agent tasks).  
All other roles → smart model.

### Variable substitution

CCR resolves `${VAR}` at startup from the process environment. Variables must be
exported before `ccr` launches (done by `iclaude.sh` via `.claude_config`).

---

## .claude_config Additions

```bash
# Custom provider — CCR
export MY_PROVIDER_URL=https://your-provider.example.com
export MY_PROVIDER_API_KEY=your-secret-key

# Custom provider — Graphify extraction backend
# Graphify uses the `ollama` backend (OpenAI-compat) with OLLAMA_* env overrides.
export OLLAMA_BASE_URL=https://your-provider.example.com/v1
export OLLAMA_API_KEY=your-secret-key
export OLLAMA_MODEL=smart-model
export GRAPHIFY_EXTRA_ARGS="--backend ollama"
```

`MY_PROVIDER_URL` and `OLLAMA_BASE_URL` point to the same host; they differ only
in path suffix (`/v1/chat/completions` vs `/v1`).

---

## Graphify Backend Details

Graphify's `llm.py` resolves the `ollama` backend as:

| Variable         | Purpose                          | Default              |
|------------------|----------------------------------|----------------------|
| `OLLAMA_BASE_URL` | Base URL of OpenAI-compat API   | `http://localhost:11434/v1` |
| `OLLAMA_API_KEY`  | Bearer token for auth           | `"ollama"` (no-auth) |
| `OLLAMA_MODEL`    | Model name                      | `qwen2.5-coder:7b`  |

`GRAPHIFY_EXTRA_ARGS="--backend ollama"` is appended to every `graphify update`
call by `_graphify_rebuild_graph()` in `lib/graphify/install.sh`.

> **Note:** The standard `/graphify` skill runs via Claude Code subagents by
> default (no direct LLM call). `--backend ollama` activates only for the
> `graphify extract` sub-command triggered by `_graphify_rebuild_graph()` when
> `./iclaude.sh --graphify` is invoked.

---

## Security

- `MY_PROVIDER_API_KEY` and `OLLAMA_API_KEY` live in `.claude_config` (chmod 600, gitignored).
- `router.json` stores `${MY_PROVIDER_API_KEY}` — placeholder, safe to commit.
- `redact-secrets.py` hook does not cover `MY_PROVIDER_*` pattern by default.
  If the key follows a known pattern (e.g. `Bearer sk-...`), existing rules may
  catch it. Otherwise, add a custom redaction rule if needed.

---

## Implementation Steps

1. Edit `router.json` — replace Ollama provider block and Router section.
2. Add env exports to `.claude_config`.
3. Test CCR: `./iclaude.sh --test` or launch and verify router picks up the provider.
4. Test Graphify extraction: `./iclaude.sh --graphify` on a small project.
