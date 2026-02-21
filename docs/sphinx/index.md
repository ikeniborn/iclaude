---
title: iclaude Documentation
---

# iclaude

Bash-based wrapper for Claude Code with automatic proxy configuration, isolated environment, and AI agent integration.

**Key features:** Dual installation modes · Proxy management · OAuth token refresh · Router integration · Loop mode · LSP servers

```{toctree}
:maxdepth: 1
:caption: Getting Started

../README
../INSTALLATION
../MIGRATION
```

```{toctree}
:maxdepth: 1
:caption: Configuration

../CONFIGURATION
../CONFIG_HIERARCHY
../CLAUDE_CONFIG
../QUICK_CONFIG
../PROXY
```

```{toctree}
:maxdepth: 1
:caption: Features

../STATUSLINE
../USE_CASES
../INTEGRATIONS
../features/README
../features/context-monitoring
```

```{toctree}
:maxdepth: 1
:caption: Architecture

../architecture/statusline-architecture
../architecture/diagrams/README
../architecture/diagrams/data-flow-isolated-installation
../architecture/diagrams/data-flow-oauth-token-refresh
../architecture/diagrams/data-flow-proxy-configuration
../architecture/diagrams/data-flow-router-launch
```

```{toctree}
:maxdepth: 1
:caption: Development

../PLANNING
../MODULARIZATION-COMPLETE
../REMAINING_WORK
```

```{toctree}
:maxdepth: 2
:caption: API Reference
:hidden:

api-reference/index
```

---

:::{note}
**For AI agents:** This documentation generates `llms.txt` and `llms-full.txt` at build time.
Use them for efficient navigation: `docs/sphinx/_build/html/llms.txt`
:::
