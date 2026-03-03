---
name: iclaude-commands
version: 1.0.0
description: CLI commands reference for iclaude.sh (8 categories)
user-invocable: false
dependencies: []
tags: [reference, iclaude, cli, commands]
files:
  - path: SKILL.md
    type: markdown
  - path: examples/testing-commands.md
    type: markdown
  - path: examples/installation-commands.md
    type: markdown
  - path: examples/workflow-examples.md
    type: markdown
---

# iclaude-commands

Reference guide for all iclaude.sh CLI commands organized by category.

## When to Use

Use this skill when:
- User asks "how to test proxy?" or "list all --flags"
- Planning implementation that needs specific command syntax
- Writing documentation/examples
- Troubleshooting command usage

**Manual reference only** (not auto-invoked)

## Command Categories

### 1. Testing & Validation
Commands for testing proxy, checking environment status, validating script.

**Key commands:** `--test`, `--check-isolated`, `--check-config`, `--refresh-token`

**См. подробнее:** `examples/testing-commands.md`

### 2. Installation & Updates
Commands for installing/updating isolated environment, managing lockfile.

**Key commands:** `--isolated-install`, `--update`, `--install-from-lockfile`, `--repair-isolated`

**См. подробнее:** `examples/installation-commands.md`

### 3. Running the Script
Basic launch commands with proxy/router/chrome options.

**Key commands:** `./iclaude.sh`, `--proxy URL`, `--no-proxy`, `--system`

### 4. Router Commands
Managing Claude Code Router (alternative LLM providers).

**Key commands:** `--install-router`, `--check-router`, `--router`

### 5. Chrome Integration
Chrome browser automation controls (enabled by default).

**Key commands:** `--no-chrome` (Chrome enabled by default)

### 6. LSP Server Management
Installing and checking LSP servers for code intelligence.

**Key commands:** `--install-lsp [lang...]`, `--check-lsp`

### 7. Sandbox Commands
Docker/bubblewrap sandbox availability checks.

**Key commands:** `--sandbox-check`, `--sandbox-install` (Linux only)

### 8. Loop Mode
Sequential/parallel task execution with retry logic (experimental).

**Key commands:** `--loop task.md`, `--loop-parallel task.md --max-parallel N`

## Quick Reference Table

| Category | Command | Purpose |
|----------|---------|---------|
| Testing | `--test` | Test proxy without launching |
| Testing | `--check-isolated` | Show versions/symlinks/lockfile |
| Install | `--isolated-install` | Install isolated environment |
| Install | `--update` | Update Claude Code |
| Install | `--install-from-lockfile` | Restore exact versions |
| Running | `./iclaude.sh` | Launch with saved proxy |
| Running | `--proxy URL` | Launch with custom proxy |
| Router | `--install-router` | Install Router package |
| Router | `--router` | Launch via router |
| LSP | `--install-lsp` | Install LSP servers |
| Sandbox | `--sandbox-check` | Check sandbox availability |
| PII Proxy | `--install-pii-proxy` | Install Presidio NLP (idempotent — skips installed components) |
| PII Proxy | `--install-pii-proxy --force` | Force reinstall all PII proxy components from scratch |
| PII Proxy | `--check-pii-proxy` | Show venv/model/process status |
| PII Proxy | `--pii-proxy` | Launch with PII masking active |

**Full tables:** См. `examples/testing-commands.md` и `examples/installation-commands.md`

## Command Combinations

### Development Workflow
```bash
./iclaude.sh --isolated-install  # 1. Install
./iclaude.sh --test              # 2. Test proxy
./iclaude.sh --proxy https://..  # 3. Launch with proxy
./iclaude.sh --check-isolated    # 4. Verify status
```

### CI/CD Workflow
```bash
./iclaude.sh --install-from-lockfile  # Restore exact versions
bash -n iclaude.sh                    # Validate syntax
./iclaude.sh --test                   # Test configuration
```

### Router Development
```bash
./iclaude.sh --install-router    # Install router
./iclaude.sh --check-router      # Verify config
./iclaude.sh --router            # Launch with router
./iclaude.sh                     # Launch without router (native Claude)
```

**См. больше примеров:** `examples/workflow-examples.md`

## Integration

**Input:** None (reference skill)
**Output:** Command syntax and examples

**Consumers:**
- iclaude-validation → Test commands
- iclaude-best-practices → Usage examples
- User → Command reference

## Examples

- **Testing commands:** `examples/testing-commands.md` - All testing/validation commands with examples
- **Installation commands:** `examples/installation-commands.md` - Install/update/repair commands
- **Workflow examples:** `examples/workflow-examples.md` - Common development/CI workflows

## Notes

- All commands assume current directory is iclaude project root
- Multiple flags can be combined (e.g., `--proxy --no-chrome`)
- Order matters: `--` separator must come last
- Router is opt-in: native Claude by default
- Chrome is opt-out: enabled by default
