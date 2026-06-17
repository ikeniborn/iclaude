# Before starting work

- Invoke `/iwiki-query` (or the `iwiki:iwiki-query` skill) to find relevant `docs/wiki/` sections before writing code.

# Post-task checklist (REQUIRED — do not skip)

After EVERY task, before responding to the user:

- [ ] Update `docs/wiki/` via `iwiki:iwiki-ingest` if you changed functionality, architecture, or behavior
- [ ] Run `/iwiki-lint` — no broken `[[refs]]`, no orphan/stale pages

---

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**iclaude** is a bash wrapper for launching Claude Code with HTTP/HTTPS proxy, isolated environment, OAuth auto-refresh, Claude Code Router, PII proxy (Presidio NLP), microVM sandbox (Firecracker), Graphify knowledge graph, and GSD framework.

Key paths: `.nvm-isolated/` (isolated env), `lib/` (18 bash modules), `docs/` (feature docs).

See [README.md](README.md) for the full feature list.

## IDD → SDD workflow

For non-trivial features (new module, new CLI flag, API change, architectural decision):

1. `/idd <topic>` — creates intent doc in `docs/superpowers/intents/`
2. `/brainstorm` — reads intent doc as context (Step 1 picks it up automatically)

### Phase gates & the check-runner protocol

A `PreToolUse` hook (`hooks/idd-gate.py`) on `Skill|Write|Edit|MultiEdit` blocks
each phase transition until the upstream artifact has passed its validator. The
`intent→spec` transition is caught on the `Skill` call; `spec→plan` and `plan→impl`
happen inline, so they are caught on the **write** of the downstream artifact (the
plan file, resp. any code edit outside `docs/superpowers/`). Mapped transitions:

| Skill | Upstream artifact | Validator |
|-------|-------------------|-----------|
| `brainstorming` | `intents/*-intent.md` | `/check-intent` |
| `writing-plans` | `specs/*-design.md` | `/check-spec` |
| `executing-plans` / `subagent-driven-development` | `plans/*.md` | `/check-plan` |
| `finishing-a-development-branch` | `plans/*.md` (`result_check`) | `/check-result` |

The gate is **open** when no matching artifact exists (hotfix escape) or when the
upstream artifact's state frontmatter passes its predicate:

- **`review:` artifacts** (intent / spec / plan): a matching body hash, all phases
  `passed`, and no open CRITICAL finding (`severity: CRITICAL` + `verdict: open`).
- **`result_check:` artifacts** (plan, for `finishing-a-development-branch`): a
  matching body hash and top-level `verdict: OK`.

Otherwise the gate blocks (`exit 2`) with a message naming the fix command. The hook
fails **open** on any internal error.

**Post-artifact nudge (complementary).** A `PostToolUse` hook (`hooks/idd-nudge.py`)
on `Write` fires when a skill creates an IDD artifact (`intents/*-intent.md`,
`specs/*-design.md`, `plans/*.md`) and the artifact is **not yet validated** for its
current body (same predicate as the gate). It injects `additionalContext` suggesting
the matching `/check-*` — so validation happens right after creation instead of only
being caught later by the blocking gate. It is **advisory** (never blocks, always
`exit 0`), stays silent once the artifact passes (so `/check-*` writing frontmatter
back does not loop), and skips `Edit` (no mid-authoring spam) and `check-result`
(needs `git diff` — left to the gate via `finishing-a-development-branch`).

**When the gate blocks, do NOT run the check inline — dispatch a clean-context
subagent:**

1. **Dispatch.** Call the Agent tool: read `commands/check-<X>.md` and execute its
   algorithm against `<artifact_path>`; run all deterministic phases; compute
   hashes via the canonical bash pipeline; write the `review:` block with new
   findings as `verdict: open` (for `check-result`, write the `result_check:`
   block with a single top-level `verdict: OK | needs_work` — it has no
   per-finding verdicts); do **not** request verdicts interactively — return the
   findings (`id, phase, severity, section, text`) as structured output. For
   `check-spec`, include a
   concise task/requirements summary in the prompt (the one input not derivable
   from the artifact alone).
2. **Subagent runs on a fresh context** — it reads only the target artifact, writes
   the state block, and returns findings. This is clean-context validation by
   construction, no `/clear` needed.
3. **Verdicts (main session).** Present any open CRITICAL findings and collect
   verdicts. `accepted` / `wontfix` → patch the frontmatter (gate opens — the
   predicate counts only CRITICAL with `verdict: open`). `fixed` → the user edits
   the artifact body (hash changes) → re-dispatch the subagent to re-validate.
4. **Retry.** Re-invoke the gated skill; the gate re-reads the now-passing state and
   allows the transition.

The check-runner dispatch is **never gated** — it uses Read/Bash/Edit and the Agent
tool, never a gated `Skill`. If the subagent dies or returns nothing, fall back to
running the check inline (clean-context benefit lost for that run; gate not wedged).

## Commands

### Daily

```bash
./iclaude.sh                    # Launch with saved settings
./iclaude.sh --no-proxy         # Launch without proxy
./iclaude.sh --update           # Update Claude Code (npm + lockfile)
```

### Testing

```bash
./iclaude.sh --test             # Test proxy configuration
./iclaude.sh --check-isolated   # Check isolated environment status
bash -n iclaude.sh              # Validate script syntax

# Security hooks test suite (28 tests)
python3 -m pytest tests/test_patterns_examples.py -v

# Test block-secrets hook (should print "BLOCKED" and exit 2)
echo '{"tool_name":"Read","tool_input":{"file_path":"/project/.env"}}' \
  | python3 .nvm-isolated/.claude-isolated/hooks/block-secrets.py; echo "exit: $?"
```

### Installation

```bash
./iclaude.sh --isolated-install       # First-time install
./iclaude.sh --repair-isolated        # After git clone: download native binary + repair symlinks
./iclaude.sh --install-from-lockfile  # Install exact versions from lockfile
./iclaude.sh --install-lsp            # Install LSP servers (TypeScript + Python)
./iclaude.sh --install-pii-proxy      # Install PII proxy (Python venv + Presidio NLP)
./iclaude.sh --install-graphify       # Install Graphify (uv + Python 3.12 + graphifyy)
./iclaude.sh --install-iwiki          # Install iwiki engine + register plugin
./iclaude.sh --install-gsd            # Install GSD framework (npx get-shit-done-cc)
./iclaude.sh --check-gsd              # Check GSD installation status
./iclaude.sh --install-microvm        # Install Firecracker (~1.4GB)
./iclaude.sh --sandbox-microvm        # Launch with microVM kernel isolation
```

## Features

| Feature | Docs |
|---------|------|
| Proxy Management (HTTPS/HTTP, CA certs) | [docs/PROXY.md](docs/PROXY.md) |
| Router Integration (OpenRouter, DeepSeek, Ollama) | [docs/ROUTER.md](docs/ROUTER.md) |
| PII Proxy (Presidio NLP, SSE streaming) | [docs/PII_MASKING.md](docs/PII_MASKING.md) |
| Status Line (context usage, cache, session links) | [docs/STATUSLINE.md](docs/STATUSLINE.md) |
| microVM Sandbox (Firecracker, virtio-blk+SSH, KVM) | [docs/MICROVM.md](docs/MICROVM.md) |
| Graphify Knowledge Graph (uv, Python 3.12, graphifyy) | `lib/graphify/` |
| iwiki Documentation Graph (embeddings, in-repo plugin) | `plugin/iwiki/` |
| GSD Framework (meta-prompting, spec-driven dev) | [docs/superpowers/specs/2026-05-14-gsd-integration-design.md](docs/superpowers/specs/2026-05-14-gsd-integration-design.md) |
| OAuth Token Management | `lib/oauth/token.sh` |
| Configuration Variables | [docs/CONFIGURATION.md](docs/CONFIGURATION.md) |

## Security Hooks (PreToolUse)

Two-layer protection. Configured in `settings.json` via `$CLAUDE_CONFIG_DIR`.

**Layer 1: `block-secrets.py`** — blocks file access (exit 2)

| Pattern | Action |
|---------|--------|
| `.env`, `.pem`, `.key`, `.p12`, `.pfx` | Blocked |
| `.ssh/`, `.gnupg/` | Blocked |
| `.env.example`, `.env.sample` | Allowed |
| `.nvm-isolated/.claude-isolated/hooks/` | Allowed (self-exclusion) |

**Layer 2: `redact-secrets.py`** — redacts content (`toolInputOverride`)

| Pattern | Replacement |
|---------|-------------|
| `sk-ant-...`, `sk-proj-...` | `[ANTHROPIC_API_KEY]` |
| `AKIA[0-9A-Z]{16}` | `[AWS_ACCESS_KEY_ID]` |
| `ghp_`, `github_pat_` | `[GITHUB_TOKEN]` |
| `eyJ...` (JWT) | `[JWT_REDACTED]` |
| `scheme://[CREDENTIALS]@host` | `[CREDENTIALS_REDACTED]` |
| `.env` vars (`KEY=value{20+}`) | `[ENV_VAR_REDACTED]` |
| PEM private keys | `[PRIVATE_KEY_REDACTED]` |

`Edit.old_string` is NOT redacted — it is a search pattern; masking would break the Edit tool.

## Isolation Mechanisms

- `CLAUDE_CONFIG_DIR` isolation (always active) — config in `.nvm-isolated/.claude-isolated/`
- microVM (Firecracker) — kernel-level isolation via `--sandbox-microvm`

bubblewrap (bwrap) was removed (2026-03) because it created 0-byte read-only stub files in `.claude/` of other open projects.

## Notes

### Native Binary (since v2.1.114)

Claude Code uses a native binary (`bin/claude.exe`, ~237MB) excluded from git (exceeds GitHub 100MB limit).

After `git clone`, run `--repair-isolated` to download the binary via `npm install` + postinstall. Without it, detection falls through to the legacy `cli.js` path, or fails with a clear error.

**Pull-time refresh.** A tracked `.githooks/post-merge` hook (active via `core.hooksPath=.githooks`) runs after `git pull`/merge. When the pulled commit bumped `claudeCodeVersion`, it compares the lockfile version against the real on-disk binary (`claude --version`) and offers a `y/N` prompt to run `--install-from-lockfile`. It is fail-soft: silent when in sync, warn-only when non-interactive (CI/GUI), never blocks the pull. Opt out with `export ICLAUDE_NO_AUTO_UPDATE=1`. The launch-time `check_lockfile_changes()` is a fallback for pulls that bypass git hooks.

Detection order (`lib/nvm/detect.sh::get_nvm_claude_path()`):
1. `$npm_prefix/bin/claude` (symlink)
2. `bin/claude.exe` (native binary, v2.1.114+)
3. `cli.js` via `node` (legacy pre-v2.1.114)

### Chrome Integration

DISABLED BY DEFAULT — requires paid plan + Chrome extension v1.0.36+ + Claude Code CLI v2.0.73+; enabling without these causes startup errors.

```bash
./iclaude.sh --chrome    # Enable Chrome integration
./iclaude.sh --no-chrome # Disable explicitly
```

### Tasks System

ENABLED BY DEFAULT. Disable only if the tasks UI conflicts with your workflow:

```bash
CLAUDE_CODE_ENABLE_TASKS=false ./iclaude.sh
```

### Plans Directory

Plans saved to `docs/plans/` via `.claude/settings.json`:
```json
{ "plansDirectory": "docs/plans" }
```

### Configuration Best Practices

- Use HTTPS proxy (not HTTP) for OAuth compatibility
- Run `--repair-isolated` after `git clone`
- Verify lockfile after `--update`
- Test proxy with `--test` before launching

## Architecture

**Version 4.0** — modular bash in `lib/` (18 modules: core, command, proxy, nvm, oauth, router, lsp, config, lockfile, update, launcher, statusline, chrome, ohmyposh, pii-proxy, sandbox, graphify, iwiki).

Source order: Phase 0 (core) → Phase 2–8.1 (feature modules) → Phase 14 (command dispatch).

Key exports (set by `lib/core/init.sh` + `lib/nvm/setup.sh`):
- `ISOLATED_NVM_DIR` — `.nvm-isolated/`
- `CLAUDE_CONFIG_DIR` — exported before Claude launch; used by hooks
- `NPM_CONFIG_PREFIX` — `$ISOLATED_NVM_DIR/npm-global`

When modifying `lib/` modules, invoke **@skill:iclaude-architecture** first.

## Security Considerations

1. `.claude_config` — chmod 600, never committed; use `.claude_config.example` as template
2. Prefer `--proxy-ca` over `--proxy-insecure`
3. `undici` does not verify target server certs when proxying HTTPS ([HackerOne #1583680](https://hackerone.com/reports/1583680))
4. Router API keys: store in `.claude_config` as `export DEEPSEEK_API_KEY=...`
5. PII Proxy runs on localhost only (127.0.0.1)
6. CCR requires real API key (`sk-ant-api03-...`), not OAuth token (`sk-ant-oat01-...`)

## Skills

Before answering questions about this project, invoke **@skill:context-awareness** to load relevant docs.

- **@skill:iclaude-architecture** — implementation details of `lib/` modules
- **@skill:iclaude-commands** — CLI command reference
- **@skill:lsp-integration** — LSP integration
- **@skill:git-workflow** — commit messages and PR creation

---

## iwiki reference

iwiki maintains an embedding-indexed wiki in `docs/wiki/` — markdown pages with `[[refs]]` cross-links, searched semantically.

### Commands
- `/iwiki-query "question"` — semantic search over docs/wiki/, returns an answer + source `[[file#Heading]]` links.
- `/iwiki-ingest <source-path>` — generate/update a docs/wiki page from a source file/folder, then refresh the index (guarded: shows a diff).
- `/iwiki-lint` — report broken `[[refs]]`, orphan/stale pages, gaps.

### Config (.claude_config)
```bash
export IWIKI_LLM_BASE_URL="https://your-provider/v1"
export IWIKI_LLM_KEY="..."
export IWIKI_EMBED_MODEL="text-embedding-3-small"
export IWIKI_EMBED_DIMENSIONS="1536"
```

### Syntax
- Wiki links: `[[target]]` or `[[target|alias]]` — cross-references between docs/wiki pages/sections.
- Section ids: `docs/wiki/<file>.md#Heading`.
