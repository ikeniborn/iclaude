# iclaude — User Guide

> Version: 4.0 | Date: 2026-07

Русская версия: [docs/README.ru.md](docs/README.ru.md)

---

## What is iclaude

**iclaude** is a bash wrapper for launching [Claude Code](https://claude.ai/code) with extended capabilities: proxy management, an isolated environment, personal data protection, alternative LLM provider support, and session monitoring.

Claude Code is Anthropic's official CLI for working with the AI assistant directly from the terminal. iclaude solves the practical problems that arise when using it in real-world conditions.

---

## Problems it solves

### 1. Corporate networks and proxies

Claude Code cannot work through corporate HTTP/HTTPS proxies out of the box. iclaude:
- Persists proxy settings between sessions
- Supports HTTPS proxies with custom CA certificates
- Configures the git proxy in sync with Claude Code

### 2. Isolation from the system environment

A system-wide Claude Code install (`npm install -g`) competes with other global npm packages, requires sudo, and gives no version control. iclaude:
- Keeps Claude Code in `.nvm-isolated/` — a fully isolated directory
- Requires no system npm and no sudo to install
- Reproduces an exact version via a lockfile

### 3. Secret and personal data leakage

When working on real projects, API keys, passwords, JWT tokens, and customer personal data end up in the Claude Code context. iclaude:
- Blocks access to secret files (`.env`, `.pem`, `.key`, `.ssh/`)
- Automatically masks secrets in tool arguments before they reach the API
- Optionally runs an NLP proxy (Presidio) to mask PII in requests

### 4. API cost and alternative providers

The Anthropic API is expensive for background agents and bulk processing. iclaude:
- Integrates with Claude Code Router to route requests to DeepSeek, OpenRouter, Ollama, and other providers
- Runs background agents through a local Ollama instance (free)
- Shows the session cost in real time in the statusline

### 5. No session visibility

There is no built-in way to see how many tokens are used, which model is active, or whether the cache is working. iclaude:
- Adds a statusline with metrics: tokens, cache, cost, model, git branch
- Adapts the display to the terminal width
- Shows clickable links to the session history and project memory

### 6. Code execution safety

Claude Code can read, modify, and execute files with broad permissions. iclaude:
- Provides kernel-level isolation via Firecracker microVM
- Separates each project's configuration via `CLAUDE_CONFIG_DIR`

---

## Features

### Proxy management

| Flag | Action |
|------|--------|
| `--proxy <url>` | Set an HTTP/HTTPS proxy |
| `--proxy-ca <file>` | Set a CA certificate for HTTPS (secure) |
| `--proxy-insecure` | Disable TLS verification (not recommended) |
| `--no-proxy` | Launch without a proxy |
| `--test` | Test connectivity through the proxy |
| `--clear` | Clear saved credentials |
| `--restore-git-proxy` | Restore the git proxy from backup |

Settings are stored in `.claude_config` (chmod 600, git-excluded).

**Supported protocols:** HTTP, HTTPS. SOCKS5 is not supported — use Privoxy as a bridge.

### Isolated environment (NVM)

All Claude Code components are installed into `.nvm-isolated/` — an isolated directory inside the repository.

| Flag | Action |
|------|--------|
| `--isolated-install` | Initial install (no system npm) |
| `--repair-isolated` | Restore symlinks after `git clone` |
| `--repair-plugins` | Fix plugin paths after moving the project |
| `--check-isolated` | Isolated environment status and version |
| `--isolated-update` | Update Claude Code (no sudo) |
| `--install-from-lockfile` | Install exact versions from the lockfile |
| `--create-symlink` | Create the user-space `iclaude` launcher (`~/.local/bin`, override: `ICLAUDE_LINK_DIR`) |
| `--uninstall-symlink` | Remove the user-space `iclaude` launcher |
| `--cleanup-isolated` | Remove the environment, keeping the lockfile |

**User-space launcher.** `--isolated-install`, `--isolated-update`, and `--install-from-lockfile` create or repair the user launcher automatically — no sudo required. The default launcher path is `~/.local/bin/iclaude`; set `ICLAUDE_LINK_DIR` to use another directory. If the launcher directory is missing from `PATH`, an export line is appended to your shell profile (bash/zsh/fish) — restart the shell or source the profile afterwards. Existing non-symlink files at the target are left untouched; stale symlinks are repaired.

**Claude Code binary lookup order:**
1. `$npm_prefix/bin/claude` (npm symlink)
2. `bin/claude.exe` (native binary, v2.1.114+)
3. `cli.js` via `node` (legacy)

### Security: PreToolUse hooks

Two-layer protection is always active, no extra configuration needed.

**Layer 1 — `block-secrets.py`**: blocks file access by path (exit code 2).

| Pattern | Action |
|---------|--------|
| `.env`, `.pem`, `.key`, `.p12`, `.pfx` | Blocked |
| `.ssh/`, `.gnupg/` | Blocked |
| `.env.example`, `.env.sample` | Allowed (templates) |
| `.claude-isolated/hooks/` | Allowed (self-exclusion) |

**Layer 2 — `redact-secrets.py`**: masks content via `toolInputOverride`.

| Pattern | Replacement |
|---------|-------------|
| `sk-ant-...`, `sk-proj-...` | `[ANTHROPIC_API_KEY]` |
| `AKIA{16}` (AWS) | `[AWS_ACCESS_KEY_ID]` |
| `ghp_`, `github_pat_` | `[GITHUB_TOKEN]` |
| `eyJ...` (JWT) | `[JWT_REDACTED]` |
| `scheme://user:pass@host` | `[CREDENTIALS_REDACTED]` |
| `.env` variables (`KEY=value{20+}`) | `[ENV_VAR_REDACTED]` |
| PEM private keys | `[PRIVATE_KEY_REDACTED]` |

> `Edit.old_string` is not masked — it is a search pattern; masking it would break the Edit tool.

### PII proxy (Presidio NLP)

A local HTTP proxy between Claude Code and the Anthropic API. It intercepts requests and masks personal data using Microsoft Presidio (NLP) and regex.

```bash
./iclaude.sh --install-pii-proxy   # Install (Python venv + Presidio, ~587MB)
./iclaude.sh --pii-proxy           # Launch with PII masking
```

**Masking levels** (set in `.claude_config`):

| Level | Behavior |
|-------|----------|
| `standard` | Presidio NLP + regex (default) |
| `secrets` | Regex only: keys, tokens, passwords |
| `off` | Traffic passes through (debugging) |

When the PII proxy is active, the statusline shows a `🛡42` icon — a counter of masked items.

### Claude Code Router (alternative LLMs)

Routes Claude Code requests to alternative LLM providers.

```bash
./iclaude.sh --install-router   # Install CCR
./iclaude.sh --router           # Launch through the router
./iclaude.sh --check-router     # Status
```

**Supported providers:** DeepSeek, OpenRouter, Ollama, Gemini, OpenAI, Volcengine, SiliconFlow.

**Routing slots** (configured in `router.json`):

| Slot | Purpose |
|------|---------|
| `default` | Main requests |
| `background` | Background agents (Ollama recommended) |
| `think` | Plan Mode, reasoning tasks |
| `longContext` | Requests >60K tokens |
| `webSearch` | Requests with web search |

Dynamic model switching inside a session: `/model deepseek,deepseek-chat`.

### Statusline

Displays Claude Code metrics in the terminal status line in real time.

```bash
./iclaude.sh --install-statusline   # Install
./iclaude.sh --install-posh         # Install oh-my-posh (optional)
```

**Example output (full mode, ≥130 columns):**
```
💳 113K | 📊 51K (26%) | 📦 79K | Sonnet 4.5 | $1.06 🌐 | 🔀 deepseek | 🛡42 | ⛏ | 📄 | 🧠 | main +2
```

| Component | Meaning |
|-----------|---------|
| `💳 113K` | Total session tokens (for billing) |
| `📊 51K (26%)` | Active context (new tokens only, no cache) |
| `📦 79K` | Cached tokens (prompt cache) |
| `Sonnet 4.5` | Current model |
| `$1.06` | Session cost |
| `🔀 deepseek` | Active router provider |
| `🛡42` | PII proxy: 42 masked items |
| `⛏` | Caveman active. The saved-token counter (`⛏ 5.2k`) appears only after a manual `/caveman-stats` call |
| `📄` | Link to the readable session history |
| `🧠` | Link to the project's MEMORY.md |
| `main +2` | Git branch and uncommitted change count |

**Adaptive modes:**
- **Full** (≥130 columns): all components
- **Compact** (110–129): abbreviations, router/git hidden
- **Minimal** (<110): tokens, model, cost only

### Telemetry (OpenTelemetry + Langfuse)

Optional, off by default. `--no-telemetry` (or `ICLAUDE_NO_TELEMETRY=1` in `.claude_config`) is a global kill switch that overrides everything.

**OTEL metrics and logs.** With `ICLAUDE_USE_OTEL=true`, iclaude enables Claude Code's OpenTelemetry export (`CLAUDE_CODE_ENABLE_TELEMETRY=1`) and configures OTLP exporters for metrics and logs (http/protobuf, 10 s export interval):

| Variable (`.claude_config`, `ICLAUDE_` prefix) | Default | Description |
|------------------------------------------------|---------|-------------|
| `USE_OTEL` | `false` | Enable OTEL export (opt-in) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://127.0.0.1:4318` | OTLP collector endpoint |
| `OTEL_EXPORTER_OTLP_CREDENTIALS` | — | `user:password` — a BasicAuth header is generated automatically |
| `OTEL_LOG_USER_PROMPTS` | `0` | Prompt texts are not exported (privacy-safe default) |

Resource attributes identify the session: `service.name=claude-code`, `iclaude.project` (derived from the git remote or directory name), host, wrapper version, proxy profile. The OTLP host is added to `NO_PROXY` automatically so telemetry bypasses the corporate proxy. When enabled, the launch output prints a `Telemetry: enabled → <endpoint>` status line.

**Langfuse capture (via the PII proxy).** With `ICLAUDE_USE_LANGFUSE_CAPTURE=true`, the PII proxy parses each Anthropic request/response pair, scrubs secrets from both copies, and posts trace + generation batches to the Langfuse ingestion API. Requires `LANGFUSE_HOST`, `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY` (in `.claude_config` with the `ICLAUDE_` prefix); incompatible with `--router` and `--system`. Emission is fail-soft (daemon thread) — a Langfuse outage never breaks the session.

Details: [docs/functions/TELEMETRY.md](docs/functions/TELEMETRY.md).

### microVM isolation (Firecracker)

Runs Claude Code inside an isolated Firecracker virtual machine with a separate Linux kernel.

```bash
./iclaude.sh --install-microvm    # Install (~1.4 GB)
./iclaude.sh --sandbox-microvm    # Launch with kernel isolation
```

**Isolation levels:**

| Level | Mechanism | Active |
|-------|-----------|--------|
| Security hooks | block-secrets.py + redact-secrets.py | Always |
| Config isolation | CLAUDE_CONFIG_DIR in `.nvm-isolated/` | Always |
| microVM | Firecracker KVM (separate Linux kernel) | `--sandbox-microvm` |

### OAuth and tokens

```bash
./iclaude.sh --refresh-token   # Refresh the OAuth token (~1 year lifetime)
```

The token is stored in `CLAUDE_CONFIG_DIR` and used automatically on launch.

### Chrome integration

Browser task automation via the "Claude in Chrome" extension.

```bash
./iclaude.sh --chrome      # Enable Chrome integration
./iclaude.sh --no-chrome   # Disable explicitly
```

**Requirements:** Google Chrome, extension v1.0.36+, Claude Code CLI v2.0.73+, paid plan.

**Disabled by default** — enabling without the requirements in place causes startup errors.

### Configuration management

```bash
./iclaude.sh --check-config          # Configuration status
./iclaude.sh --export-config <path>  # Backup
./iclaude.sh --import-config <path>  # Restore
./iclaude.sh --isolated-config       # Use the isolated config
./iclaude.sh --shared-config         # Use the system ~/.claude/
```

**Key variables** (in `.claude_config`). All variables in the file take the `ICLAUDE_` prefix and no `export` (e.g. `ICLAUDE_CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000`); at launch iclaude de-prefixes them into the canonical names below:

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | 32000 | Output token limit (max 128000) |
| `CLAUDE_CODE_ENABLE_TASKS` | true | Tasks system |
| `CLAUDE_CODE_NO_CHROME` | false | Disable Chrome |
| `CLAUDE_CODE_MODEL` | claude-4-5-sonnet | Model |

### Token compression (Caveman)

Cuts output token usage by ~65–75% via [caveman](https://github.com/JuliusBrussee/caveman) — a compressive response style (drop articles/filler/pleasantries). Does not touch code, commits, security warnings, or error quotes.

```bash
./iclaude.sh --install-caveman      # Download 4 hooks + patch settings.json
./iclaude.sh --check-caveman        # Status: install, version, mode
./iclaude.sh --uninstall-caveman    # Remove
```

**Configuration (`.claude_config`, stored with the `ICLAUDE_` prefix — e.g. `ICLAUDE_CAVEMAN_DEFAULT_MODE`):**

| Variable | Default | Description |
|----------|---------|-------------|
| `CAVEMAN_DEFAULT_MODE` | `full` | `off` / `lite` / `full` / `ultra` / `wenyan-*` / `commit` / `review` / `compress` |
| `CAVEMAN_STATUSLINE` | `false` | Token-savings badge in the status line |

In a session: `/caveman lite|full|ultra` to switch, `stop caveman` to exit.

**Isolation:** hooks are installed only into `$CLAUDE_CONFIG_DIR/hooks/` — `~/.claude/` is not touched.

Details: [docs/functions/CAVEMAN.md](docs/functions/CAVEMAN.md).

### Loop Engineering (loen)

The `loen` plugin (`plugin/loen/`, marketplace `iclaude`) runs a managed `Plan → Act → Check → Report` loop with an independent verifier. The task is described by a machine-readable `loop.yaml` contract; the worker makes a minimal diff; deterministic gates and the `verifier` subagent confirm the result; the report lands in `docs/loen/<run-id>/report.html`.

```bash
# In a session:
/loop-delivery <task>              # run the loop (planner → approval → act → verifier → report)
/loop-repair <failure description> # repair: reproduce → isolate → minimal fix → regression test
/loop-autoresearch <goal metric>   # research: baseline → hypothesis → change → fixed eval → keep/revert
/loen:audit plan|act|check|result  # check a stage (mode-aware) + refresh report.html
/loen:loop-goal                    # optional: evidence-first /goal line from the approved loop.yaml + /loop recipe
/loen:governance [--triage]        # cross-run dashboard docs/loen/governance.html (offline loen_stats.py aggregator); --triage only suggests actions
```

**Artifacts:** `docs/loen/<run-id>/` (loop.yaml, plan.md, state.md, iterations/iter-NN/, experiments.jsonl, report.html, pr-summary.md). In research mode, eval writes JSONL metrics to `iterations/iter-NN/metrics.jsonl` (via `$LOEN_METRICS_PATH`), and every experiment is logged by the deterministic `log_experiment.py`. Templates are plugin assets. The `loop-guard.py` hook strictly enforces layout/naming and scope; in non-loop repositories it is a no-op.

**Verifier isolation (opt-in):** `verifier_isolation: microvm` in `loop.yaml` — the verifier runs headless inside a Firecracker microVM over a disposable tree snapshot (no write channel to the host). Requires the microVM to be installed (`./iclaude.sh --install-microvm`); default is `subagent`. See [docs/functions/MICROVM.md](docs/functions/MICROVM.md).

**Governance (cross-run):** `/loen:governance` builds the `docs/loen/governance.html` dashboard with the deterministic offline `loen_stats.py` aggregator (success rate, keep/revert, stop reasons, error taxonomy from REJECT verdicts, protected-path alerts, layout drift; cost/tokens and latency/VRAM are explicitly n/a, nothing invented). Everything is local: no network and no LLM in aggregation; `--triage` only suggests next actions — a human runs them.

Details: [docs/functions/LOEN.md](docs/functions/LOEN.md).

### Updates and diagnostics

```bash
./iclaude.sh --update           # Update Claude Code
./iclaude.sh --check-update     # Check for available updates
./iclaude.sh --check-isolated   # Isolated environment status
./iclaude.sh --check-router     # Claude Code Router status
./iclaude.sh --check-statusline # Statusline status
```

**Node.js version.** `--update` keeps the isolated environment's Node.js at or above Claude Code's `engines.node`. Before `npm install`, it reads the package requirement and, if the active major is outdated (e.g. v20 when v22 is required), **offers** (prompt, default yes) to install the required major inside the isolated environment. Global packages live in the shared `npm-global` prefix, so they survive a Node switch without migration. If the user declines or every download path fails, the update **aborts** — otherwise it would install a Claude Code that emits `EBADENGINE` or fails to start. The check runs even when Claude Code is already at the latest version. Fresh installs default to Node 22.

Node download takes two paths. First `nvm install <major>` (system `curl`). If it fails — the system OpenSSL cannot complete the TLS handshake to `nodejs.org` (`x509 unsupported algorithm`: GOST-patched OpenSSL in AltLinux or a TLS-intercepting proxy; fails even with `-k` and even bypassing the proxy) — the `fetch_node_via_node_tls` fallback kicks in: `scripts/fetch-node.js` downloads the tarball **through Node's own TLS stack** (the same reason `npm` works while `curl` does not), verifies `SHASUMS256.txt` (sha256), and extracts into `versions/node/`. The same fallback is wired into `install_isolated_nodejs` and `install_from_lockfile`, so `--update`, `--isolated-install`, and `--install-from-lockfile` self-heal; the fetcher can bootstrap from a system Node when the isolated environment has none yet.

---

## Quick start

### First install

```bash
git clone <repo>
cd iclaude

# Install the isolated environment (no system npm, no sudo).
# Creates the user launcher ~/.local/bin/iclaude automatically.
./iclaude.sh --isolated-install

# After git clone with an existing lockfile — reproduce exact versions instead:
./iclaude.sh --install-from-lockfile

# Configure a proxy (if needed)
./iclaude.sh --proxy https://proxy.example.com:8118

# Test connectivity
./iclaude.sh --test

# Launch (or just `iclaude` from anywhere once the launcher is on PATH)
./iclaude.sh
```

### Launch with an alternative provider (DeepSeek + Ollama)

```bash
# Install the router
./iclaude.sh --install-router

# Add the key to .claude_config (ICLAUDE_ prefix, no `export`)
echo "ICLAUDE_DEEPSEEK_API_KEY=sk-..." >> .claude_config

# Launch through the router
./iclaude.sh --router
```

### Launch with maximum data protection

```bash
# Install the PII proxy
./iclaude.sh --install-pii-proxy

# Launch with PII masking and microVM
./iclaude.sh --pii-proxy --sandbox-microvm
```

---

## Architecture

```
iclaude.sh
├── lib/core/        — initialization, global variables
├── lib/command/     — argument parsing, help
├── lib/proxy/       — HTTP/HTTPS proxy
├── lib/nvm/         — isolated NVM environment
├── lib/symlink/     — user-space iclaude launcher (~/.local/bin)
├── lib/lockfile/    — reproducible installs
├── lib/oauth/       — OAuth tokens
├── lib/router/      — Claude Code Router
├── lib/pii-proxy/   — PII NLP proxy (Presidio)
├── lib/sandbox/     — Firecracker microVM
├── lib/statusline/  — statusline metrics
├── lib/telemetry/   — OpenTelemetry export (OTLP)
├── lib/caveman/     — token compression hooks
├── lib/launcher/    — Claude Code launch (final exec)
├── plugin/loen/     — loop-engineering plugin
└── plugin/iwiki/    — iwiki plugin (archived/disabled; docs go through the iwiki MCP server)
```

Security hooks: `.nvm-isolated/.claude-isolated/hooks/`
Statusline scripts: `.nvm-isolated/.claude-isolated/scripts/`

---

## Documentation by topic

| Topic | File |
|-------|------|
| Proxy | `docs/functions/PROXY.md` |
| Router and providers | `docs/functions/ROUTER.md` |
| PII masking | `docs/functions/PII_MASKING.md` |
| Statusline | `docs/functions/STATUSLINE.md` |
| microVM | `docs/functions/MICROVM.md` |
| Token compression (Caveman) | `docs/functions/CAVEMAN.md` |
| Loop Engineering (loen) | `docs/functions/LOEN.md` |
| All commands | `docs/functions/CONFIGURATION.md` |
| Usage scenarios | `docs/functions/USE_CASES.md` |
| Telemetry | `docs/functions/TELEMETRY.md` |
