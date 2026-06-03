# Design: Suppress npx fallback on launch

**Date:** 2026-06-03  
**Status:** approved  
**Intent:** [docs/superpowers/intents/2026-06-03-suppress-npx-fallback-intent.md](../intents/2026-06-03-suppress-npx-fallback-intent.md)

## Problem

`lib/launcher/launch.sh` lines 612–637 contain an npx fallback that fires when binary detection finds no Claude Code. This fallback calls `npx @anthropic-ai/claude-code`, which triggers an interactive npm install prompt and reaches out to the npm registry — violating the isolated-environment architecture where binaries are delivered only via CI/CD.

## Solution

**Approach A — Minimal.** Delete the npx fallback block. Replace with a context-aware error that exits 1.

## Architecture

Single file change: `lib/launcher/launch.sh`.

### Before (lines 612–637)

```bash
# If still not found, try npx as fallback
if [[ -z "$claude_cmd" ]]; then
    if command -v npx &> /dev/null; then
        print_info "Using npx to run Claude Code..."
        if [[ "$use_pii_proxy" == "true" ]]; then
            ...
            npx @anthropic-ai/claude-code "$@"
            exit $?
        fi
        exec npx @anthropic-ai/claude-code "$@"
    else
        print_error "Claude Code not found"
        echo ""
        echo "Install Claude Code globally:"
        echo "  npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
fi
```

### After

```bash
if [[ -z "$claude_cmd" ]]; then
    if [[ "$skip_isolated" == "true" ]]; then
        print_error "Claude Code not found in system."
        echo ""
        echo "Install globally:"
        echo "  npm install -g @anthropic-ai/claude-code"
    else
        print_error "Claude Code not found in isolated environment."
        echo ""
        echo "Restore the isolated environment:"
        echo "  ./iclaude.sh --repair-isolated"
        echo ""
        echo "Updates are delivered via CI/CD (git pull + --install-from-lockfile),"
        echo "not via local npm install."
    fi
    exit 1
fi
```

## Error message logic

| Context | Trigger | Message |
|---------|---------|---------|
| Normal launch (`skip_isolated=false`) | Binary missing in `.nvm-isolated/` | `--repair-isolated` |
| `--system` flag (`skip_isolated=true`) | Binary missing in system | `npm install -g` |

## Out of scope

- `--update`, `--repair-isolated`, `--install-from-lockfile` — intentionally call npm, unchanged
- `lib/nvm/detect.sh`, `lib/nvm/repair.sh` — not modified
- CI/CD pipeline — not modified

## Health checks

- `./iclaude.sh --update` — no regression
- `./iclaude.sh --repair-isolated` — no regression
- `./iclaude.sh --install-from-lockfile` — no regression
- `./iclaude.sh` with binary present — no change in behavior
- `./iclaude.sh` with binary absent — prints `--repair-isolated` error, exits 1, no npm prompt
