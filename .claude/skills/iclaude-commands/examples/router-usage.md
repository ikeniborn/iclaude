# Example: Claude Code Router Usage

This example demonstrates how to use Claude Code Router to route requests to alternative LLM providers.

## Scenario

You want to use DeepSeek for development tasks while keeping native Claude for production.

## Installation

```bash
# 1. Install router in isolated environment
./iclaude.sh --install-router

# 2. Edit router configuration
nano router.json
```

## Configuration

Edit `router.json` (example uses environment variable substitution):

```json
{
  "providers": {
    "deepseek": {
      "type": "openai",
      "baseURL": "https://api.deepseek.com/v1",
      "apiKey": "${DEEPSEEK_API_KEY}"
    }
  },
  "defaultProvider": "deepseek",
  "defaultModel": "deepseek-chat"
}
```

## Environment Setup

```bash
# Export API key (add to ~/.bashrc for persistence)
export DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxx

# Verify router configuration
./iclaude.sh --check-router
```

## Usage

```bash
# Launch via router (opt-in)
./iclaude.sh --router

# Launch with native Claude (default)
./iclaude.sh
```

## Router + Proxy

Router automatically inherits proxy configuration:

```bash
# Both router and Claude use the same proxy
./iclaude.sh --proxy https://proxy:8118 --router
```

## Checking Router Status

```bash
./iclaude.sh --check-router
```

**Expected output:**

```
Router status:
✓ Router installed (version 1.2.3)
✓ Configuration: /path/to/router.json
✓ Default provider: deepseek
✓ Default model: deepseek-chat
✓ Environment variables resolved

Configured providers:
  - deepseek (OpenAI-compatible)
  - openrouter (OpenRouter)

Router will be used on next launch (--router flag required)
```

## Multiple Providers

Configure multiple providers for different use cases:

```json
{
  "providers": {
    "deepseek": {
      "type": "openai",
      "baseURL": "https://api.deepseek.com/v1",
      "apiKey": "${DEEPSEEK_API_KEY}"
    },
    "openrouter": {
      "type": "openrouter",
      "apiKey": "${OPENROUTER_API_KEY}"
    },
    "ollama": {
      "type": "ollama",
      "baseURL": "http://localhost:11434"
    }
  },
  "defaultProvider": "deepseek"
}
```

## Provider Selection

**Default provider** (from `router.json`):

```bash
./iclaude.sh --router
```

**Override provider** (if router supports runtime selection):

```bash
# Note: Provider override depends on router CLI support
ccr code --provider openrouter
```

## Troubleshooting

### Router Not Found

**Problem:** `ccr` binary not in PATH.

**Solution:**

```bash
# Reinstall router
./iclaude.sh --install-router

# Verify installation
which ccr  # Should show: .nvm-isolated/npm-global/bin/ccr
```

### Configuration Errors

**Problem:** Invalid JSON syntax or missing environment variables.

**Check syntax:**

```bash
# Validate JSON
jq . router.json
```

**Check environment:**

```bash
# Verify API keys are exported
env | grep -E "API_KEY"
```

### Native Claude vs Router

**Launching native Claude** (default):

```bash
./iclaude.sh  # NO --router flag
```

**Launching via router** (opt-in):

```bash
./iclaude.sh --router  # WITH --router flag
```

## Best Practices

1. **Use environment variables for API keys** (never commit secrets)
2. **Commit `router.json` with `${VAR}` placeholders** (team sharing)
3. **Document required environment variables** in README.md
4. **Use `.gitignore` for local overrides** (`router.local.json`)

## Related Commands

- `--install-router` - Install Claude Code Router
- `--check-router` - Verify router status
- `--router` - Launch via router (opt-in)
- Default launch (no `--router` flag) - Use native Claude

## Documentation Links

- Router Configuration: `router.json.example`
- Lockfile Integration: `.nvm-isolated-lockfile.json` (includes router version)
