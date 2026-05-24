This directory defines the high-level concepts, business logic, and architecture of iclaude — a bash wrapper for launching Claude Code with HTTP/HTTPS proxy, isolated environment, OAuth auto-refresh, Claude Code Router, PII proxy, microVM sandbox, and security hooks.

## Sections

Key subsystems documented in this directory.

- [[architecture]] — module loading phases, global variables, binary detection
- [[launch-flow]] — `launch_claude()` decision tree, execution paths
- [[proxy]] — HTTPS/HTTP proxy configuration, TLS, CA certs
- [[pii-proxy]] — Presidio NLP PII masking proxy, shared/per-session modes
- [[router]] — CCR integration, combined modes, attribution header
- [[sandbox]] — Firecracker microVM isolation, workspace sync, SSH ControlMaster
- [[security]] — PreToolUse hooks: block-secrets, redact-secrets
- [[isolation]] — `CLAUDE_CONFIG_DIR` isolation, session IDs, --system mode
- [[oauth]] — OAuth token refresh, token types, expiry threshold
