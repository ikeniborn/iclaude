---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-01-iwiki-mcp-user-scope-design.md
review:
  plan_hash: 6bd565410e5df655
  spec_hash: ff63ddc066677423
  last_run: 2026-07-01
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings: []
---

# iwiki MCP User-Scope Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Register the `iwiki` MCP server for iclaude from a tracked, secret-free `mcp/iwiki.json` whose `${IWIKI_*}` placeholders are proxied from `.claude_config` (`ICLAUDE_IWIKI_*`), with the binary resolved to an absolute path at launch.

**Architecture:** A new `lib/iwiki/mcp.sh` resolves the `iwiki-mcp` binary (`command -v`) into `IWIKI_COMMAND` and gates registration. `launch.sh` appends `--mcp-config <config-dir>/mcp/iwiki.json` to the native launch command when iwiki is configured. Claude Code expands `${IWIKI_COMMAND}` and each `${IWIKI_*}` from the process environment (already exported by `lib/config/env-map.sh`) when it spawns the stdio server. The tracked config file holds only placeholders — no secrets.

**Tech Stack:** Bash (POSIX-ish), existing `lib/core/logging.sh` print helpers, `jq` for JSON edits, standalone `tests/*.sh` PASS/FAIL harness.

**Spec:** `docs/superpowers/specs/2026-07-01-iwiki-mcp-user-scope-design.md`

**Branch:** `dev-iwiki-mcp-user-scope` (already created from `dev`; PR target `dev`; no worktree).

---

## File Structure

- **Create** `lib/iwiki/mcp.sh` — iwiki MCP helper: `iwiki_mcp_config_file`, `iwiki_resolve_command`, `iwiki_mcp_enabled`. One responsibility: resolve the binary + decide whether to register.
- **Create** `tests/test_iwiki_mcp.sh` — unit tests for the three helper functions.
- **Create** `.nvm-isolated/.claude-isolated/mcp/iwiki.json` — tracked, secret-free MCP config (`${IWIKI_*}` placeholders only).
- **Modify** `iclaude.sh` — source `lib/iwiki/mcp.sh` in the Phase 0 core block.
- **Modify** `lib/launcher/launch.sh` — append `--mcp-config` to `claude_cmd_arr` when `iwiki_mcp_enabled`.
- **Modify** `.gitignore` — un-ignore `.nvm-isolated/.claude-isolated/mcp/`.
- **Modify** `.claude_config` (gitignored, local) — add `ICLAUDE_IWIKI_BASE_DIR`.
- **Modify** `.claude_config.example` (tracked) — add a documented iwiki MCP block.
- **Modify** `.nvm-isolated/.claude-isolated/settings.json` (tracked) — remove the dead `"mcpServers": {}` key.
- **Edit at runtime** `.nvm-isolated/.claude-isolated/.claude.json` (gitignored) — remove the stale manual `mcpServers.iwiki` block (not committed).

---

## Task 1: iwiki MCP helper module + unit tests (`lib/iwiki/mcp.sh`)

**Files:**
- Create: `lib/iwiki/mcp.sh`
- Test: `tests/test_iwiki_mcp.sh`

- [ ] **Step 1: Write the failing test** — `tests/test_iwiki_mcp.sh`

```bash
#!/usr/bin/env bash
# Unit tests for lib/iwiki/mcp.sh:
#   iwiki_mcp_config_file, iwiki_resolve_command, iwiki_mcp_enabled.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/iwiki/mcp.sh"

PASS=0; FAIL=0
assert_eq(){ if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }

TD=$(mktemp -d)
# Fake iwiki-mcp on an absolute PATH entry so `command -v` yields an absolute path.
mkdir -p "$TD/bin"; printf '#!/bin/sh\n' > "$TD/bin/iwiki-mcp"; chmod +x "$TD/bin/iwiki-mcp"

# iwiki_resolve_command: resolves via PATH to the absolute binary path.
assert_eq "$(PATH="$TD/bin:$PATH"; unset IWIKI_COMMAND; iwiki_resolve_command; printf '%s' "$IWIKI_COMMAND")" \
  "$TD/bin/iwiki-mcp" "resolve via PATH -> absolute"

# iwiki_resolve_command: an explicit override wins over PATH resolution.
assert_eq "$(PATH="$TD/bin:$PATH"; IWIKI_COMMAND=/custom/iwiki-mcp; iwiki_resolve_command; printf '%s' "$IWIKI_COMMAND")" \
  "/custom/iwiki-mcp" "override respected"

# iwiki_mcp_config_file: path is <config dir>/mcp/iwiki.json.
assert_eq "$(CLAUDE_CONFIG_DIR=/x/.claude-isolated iwiki_mcp_config_file)" \
  "/x/.claude-isolated/mcp/iwiki.json" "config file path"

# Prepare a config dir with the tracked file present.
mkdir -p "$TD/.claude-isolated/mcp"; printf '{}' > "$TD/.claude-isolated/mcp/iwiki.json"

# iwiki_mcp_enabled: YES when binary + LLM key + config file all present.
assert_eq "$(PATH="$TD/bin:$PATH"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; IWIKI_LLM_KEY=sk-x; unset IWIKI_COMMAND; iwiki_mcp_enabled && echo YES || echo NO)" \
  "YES" "enabled when all set"

# iwiki_mcp_enabled: NO without an LLM key.
assert_eq "$(PATH="$TD/bin:$PATH"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; unset IWIKI_LLM_KEY IWIKI_COMMAND; iwiki_mcp_enabled && echo YES || echo NO)" \
  "NO" "disabled without LLM key"

# iwiki_mcp_enabled: NO when the binary is not resolvable.
assert_eq "$(PATH="/nonexistent"; CLAUDE_CONFIG_DIR="$TD/.claude-isolated"; IWIKI_LLM_KEY=sk-x; unset IWIKI_COMMAND; iwiki_mcp_enabled && echo YES || echo NO)" \
  "NO" "disabled without binary"

# iwiki_mcp_enabled: NO when the tracked config file is missing.
assert_eq "$(PATH="$TD/bin:$PATH"; CLAUDE_CONFIG_DIR="$TD/nowhere"; IWIKI_LLM_KEY=sk-x; unset IWIKI_COMMAND; iwiki_mcp_enabled && echo YES || echo NO)" \
  "NO" "disabled without config file"

rm -rf "$TD"
echo "iwiki-mcp: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_iwiki_mcp.sh`
Expected: FAIL — `source: lib/iwiki/mcp.sh: No such file or directory`, nonzero exit.

- [ ] **Step 3: Create the module** — `lib/iwiki/mcp.sh`

```bash
#!/bin/bash

#######################################
# iwiki MCP Registration Helper
# Description: Resolves the iwiki-mcp binary to an absolute path and decides
#              whether the tracked, secret-free mcp/iwiki.json should be handed
#              to Claude Code via --mcp-config. The IWIKI_* values are already
#              exported by lib/config/env-map.sh (de-prefixed from
#              ICLAUDE_IWIKI_* in .claude_config); this module only resolves the
#              binary path and evaluates the enable gate.
#######################################

# Absolute path to the tracked, secret-free MCP config file.
# Lives under the isolated Claude config dir (CLAUDE_CONFIG_DIR).
iwiki_mcp_config_file() {
    printf '%s' "${CLAUDE_CONFIG_DIR:-${ISOLATED_CONFIG_DIR:-}}/mcp/iwiki.json"
}

# Resolve the iwiki-mcp executable to an absolute path and export IWIKI_COMMAND.
# Honors an explicit override (ICLAUDE_IWIKI_COMMAND -> IWIKI_COMMAND via
# env-map); otherwise resolves it from PATH with `command -v` (absolute path).
iwiki_resolve_command() {
    IWIKI_COMMAND="${IWIKI_COMMAND:-$(command -v iwiki-mcp 2>/dev/null)}"
    export IWIKI_COMMAND
}

# Return 0 (enabled) only when the iwiki MCP server should be registered:
#   - the binary resolved (IWIKI_COMMAND non-empty), AND
#   - iwiki is configured (IWIKI_LLM_KEY non-empty), AND
#   - the tracked config file exists.
# Returns 1 otherwise, so launch proceeds without the server (no hard failure).
iwiki_mcp_enabled() {
    iwiki_resolve_command
    [[ -n "${IWIKI_COMMAND:-}" ]]            || return 1
    [[ -n "${IWIKI_LLM_KEY:-}" ]]            || return 1
    [[ -f "$(iwiki_mcp_config_file)" ]]      || return 1
    return 0
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test_iwiki_mcp.sh`
Expected: PASS — `iwiki-mcp: PASS=7 FAIL=0`, exit 0.

- [ ] **Step 5: Syntax-check the module**

Run: `bash -n lib/iwiki/mcp.sh && echo OK`
Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add lib/iwiki/mcp.sh tests/test_iwiki_mcp.sh
git commit -m "feat(iwiki): add MCP registration helper (resolve binary + enable gate)"
```

---

## Task 2: Tracked secret-free MCP config file + `.gitignore`

**Files:**
- Create: `.nvm-isolated/.claude-isolated/mcp/iwiki.json`
- Modify: `.gitignore`

- [ ] **Step 1: Create the MCP config file** — `.nvm-isolated/.claude-isolated/mcp/iwiki.json`

Create the directory and file with exactly this content (placeholders only — no secrets):

```json
{
  "mcpServers": {
    "iwiki": {
      "type": "stdio",
      "command": "${IWIKI_COMMAND}",
      "args": [],
      "env": {
        "IWIKI_BASE_DIR":          "${IWIKI_BASE_DIR}",
        "IWIKI_LLM_BASE_URL":      "${IWIKI_LLM_BASE_URL}",
        "IWIKI_LLM_KEY":           "${IWIKI_LLM_KEY}",
        "IWIKI_EMBED_MODEL":       "${IWIKI_EMBED_MODEL:-text-embedding-3-small}",
        "IWIKI_EMBED_DIMENSIONS":  "${IWIKI_EMBED_DIMENSIONS:-1536}",
        "IWIKI_CHUNK_SIZE":        "${IWIKI_CHUNK_SIZE:-512}",
        "IWIKI_CHUNK_OVERLAP":     "${IWIKI_CHUNK_OVERLAP:-64}",
        "IWIKI_SUMMARY_MAX_CHARS": "${IWIKI_SUMMARY_MAX_CHARS:-400}",
        "IWIKI_TOP_K":             "${IWIKI_TOP_K:-8}",
        "IWIKI_SCORE_THRESHOLD":   "${IWIKI_SCORE_THRESHOLD:-0.2}",
        "IWIKI_GRAPH_DEPTH":       "${IWIKI_GRAPH_DEPTH:-2}"
      }
    }
  }
}
```

- [ ] **Step 2: Validate the JSON**

Run: `jq empty .nvm-isolated/.claude-isolated/mcp/iwiki.json && echo "JSON OK"`
Expected: `JSON OK` (the `${...}` placeholders are valid JSON string values).

- [ ] **Step 3: Confirm no secret leaked into the file**

Run: `grep -c 'sk-\|litellm.ikeniborn\|5Z3To' .nvm-isolated/.claude-isolated/mcp/iwiki.json`
Expected: `0` — only `${IWIKI_*}` placeholders, no literal values.

- [ ] **Step 4: Un-ignore the new directory** — `.gitignore`

The blanket rule `.nvm-isolated/.claude-isolated/*` ignores everything under the isolated dir; a set of `!`-exceptions follows (`commands/`, `skills/`, `agents/`, the CHANGELOG). Add these two lines immediately after the existing `!.nvm-isolated/.claude-isolated/CHANGELOG-v7.0.md` line:

```
!.nvm-isolated/.claude-isolated/mcp/
!.nvm-isolated/.claude-isolated/mcp/**
```

- [ ] **Step 5: Verify the file is now tracked-eligible**

Run: `git check-ignore .nvm-isolated/.claude-isolated/mcp/iwiki.json; echo "rc=$?"`
Expected: `rc=1` (NOT ignored — no output line, exit 1).

- [ ] **Step 6: Commit**

```bash
git add .gitignore .nvm-isolated/.claude-isolated/mcp/iwiki.json
git commit -m "feat(iwiki): tracked secret-free mcp/iwiki.json; un-ignore mcp/ dir"
```

---

## Task 3: Config surface — `ICLAUDE_IWIKI_BASE_DIR`

**Files:**
- Modify: `.claude_config` (gitignored, local — NOT committed)
- Modify: `.claude_config.example` (tracked)

- [ ] **Step 1: Add `ICLAUDE_IWIKI_BASE_DIR` to the local `.claude_config`**

Insert this line immediately before the existing `ICLAUDE_IWIKI_LLM_KEY=` line:

```
ICLAUDE_IWIKI_BASE_DIR="/home/altuser/Документы/Project/iwiki-personal"
```

- [ ] **Step 2: Verify env-map exports `IWIKI_BASE_DIR`**

Run:
```bash
CREDENTIALS_FILE="$(pwd)/.claude_config" bash -c '
  print_info(){ :; }; print_warning(){ :; }; print_error(){ :; }
  source lib/config/env-map.sh
  source_iclaude_config
  printf "IWIKI_BASE_DIR=%s\n" "${IWIKI_BASE_DIR:-<unset>}"
'
```
Expected: `IWIKI_BASE_DIR=/home/altuser/Документы/Project/iwiki-personal`.

- [ ] **Step 3: Add a documented iwiki MCP block to `.claude_config.example`**

Append this block to the end of `.claude_config.example` (the file currently has no iwiki section — it was removed during the plugin decommission; this documents the vars the MCP server reads):

```
# ============================================================
#  IWIKI MCP SERVER (semantic docs wiki over MCP)
# ============================================================
# The iwiki MCP server (`iwiki-mcp`, installed as a uv/pipx tool on PATH) is
# registered at launch from the tracked, secret-free
# .nvm-isolated/.claude-isolated/mcp/iwiki.json via --mcp-config. That file uses
# ${IWIKI_*} placeholders; the values below are de-prefixed by env-map
# (ICLAUDE_IWIKI_X -> IWIKI_X) and expanded into the server's env at spawn time.
# The server is only registered when IWIKI_LLM_KEY is set and `iwiki-mcp`
# resolves on PATH.
#
# Required (server halts without these):
# ICLAUDE_IWIKI_BASE_DIR="/home/user/wiki"          # shared wiki base dir
# ICLAUDE_IWIKI_LLM_BASE_URL="https://.../v1"        # OpenAI-compatible embeddings endpoint
# ICLAUDE_IWIKI_LLM_KEY="..."                        # embeddings API key (secret — keep here, not in git)
#
# Embedding model (defaults shown; EMBED_DIMENSIONS must match the model):
# ICLAUDE_IWIKI_EMBED_MODEL="text-embedding-3-small"
# ICLAUDE_IWIKI_EMBED_DIMENSIONS="1536"
#
# Search / indexing tuning (optional; server defaults apply when unset):
# ICLAUDE_IWIKI_CHUNK_SIZE="512"
# ICLAUDE_IWIKI_CHUNK_OVERLAP="64"
# ICLAUDE_IWIKI_SUMMARY_MAX_CHARS="400"
# ICLAUDE_IWIKI_TOP_K="8"
# ICLAUDE_IWIKI_SCORE_THRESHOLD="0.2"
# ICLAUDE_IWIKI_GRAPH_DEPTH="2"
#
# Optional: override the binary path (default: resolved via `command -v iwiki-mcp`):
# ICLAUDE_IWIKI_COMMAND=
```

- [ ] **Step 4: Syntax-check the example sources cleanly**

Run: `bash -n .claude_config.example && echo "SYNTAX OK"`
Expected: `SYNTAX OK`.

- [ ] **Step 5: Commit (example only — `.claude_config` is gitignored)**

```bash
git add .claude_config.example
git commit -m "docs(config): document iwiki MCP env vars in .claude_config.example"
```

---

## Task 4: Wire `--mcp-config` into launch (`iclaude.sh` + `lib/launcher/launch.sh`)

**Files:**
- Modify: `iclaude.sh` (Phase 0 core source block, ~line 38)
- Modify: `lib/launcher/launch.sh` (after `claude_cmd_arr` is built, ~line 824)

- [ ] **Step 1: Source the helper in the Phase 0 core block** — `iclaude.sh`

Immediately after the line `source "${LIB_DIR}/config/env-map.sh"`, add:

```bash
source "${LIB_DIR}/iwiki/mcp.sh"
```

- [ ] **Step 2: Append `--mcp-config` to the native launch command** — `lib/launcher/launch.sh`

Find this existing block (the array is built once, then used by both the PII-proxy branch and the standard `exec` branch):

```bash
    local -a claude_cmd_arr
    read -ra claude_cmd_arr <<< "$claude_cmd"
```

Immediately after those two lines, insert:

```bash

    # Register the iwiki MCP server from the tracked, secret-free mcp/iwiki.json
    # when configured. iwiki_mcp_enabled resolves + exports IWIKI_COMMAND so
    # Claude Code can expand ${IWIKI_COMMAND}/${IWIKI_*} at spawn time. The flag
    # is added to claude_cmd_arr, so it flows into BOTH launch branches below.
    # (The microVM path execs earlier and is intentionally not covered.)
    if iwiki_mcp_enabled; then
        claude_cmd_arr+=( --mcp-config "$(iwiki_mcp_config_file)" )
    fi
```

- [ ] **Step 3: Syntax-check both files**

Run: `bash -n iclaude.sh && bash -n lib/launcher/launch.sh && echo OK`
Expected: `OK`.

- [ ] **Step 4: Verify the flag is assembled (dry check with a stub)**

Run:
```bash
bash -c '
  print_info(){ :; }; print_warning(){ :; }; print_error(){ :; }
  source lib/iwiki/mcp.sh
  TD=$(mktemp -d); mkdir -p "$TD/bin" "$TD/cfg/mcp"
  printf "#!/bin/sh\n" > "$TD/bin/iwiki-mcp"; chmod +x "$TD/bin/iwiki-mcp"
  printf "{}" > "$TD/cfg/mcp/iwiki.json"
  PATH="$TD/bin:$PATH" CLAUDE_CONFIG_DIR="$TD/cfg" IWIKI_LLM_KEY=sk-x
  export PATH CLAUDE_CONFIG_DIR IWIKI_LLM_KEY
  claude_cmd_arr=(claude)
  if iwiki_mcp_enabled; then claude_cmd_arr+=( --mcp-config "$(iwiki_mcp_config_file)" ); fi
  printf "%s " "${claude_cmd_arr[@]}"; echo
  rm -rf "$TD"
'
```
Expected: `claude --mcp-config <tmp>/cfg/mcp/iwiki.json ` (flag present; `IWIKI_COMMAND` resolved).

- [ ] **Step 5: Commit**

```bash
git add iclaude.sh lib/launcher/launch.sh
git commit -m "feat(iwiki): register MCP server via --mcp-config in launch"
```

---

## Task 5: Remove stale/dead MCP config (`.claude.json` + `settings.json`)

**Files:**
- Edit at runtime: `.nvm-isolated/.claude-isolated/.claude.json` (gitignored — NOT committed)
- Modify: `.nvm-isolated/.claude-isolated/settings.json` (tracked)

- [ ] **Step 1: Remove the stale manual `mcpServers.iwiki` block from `.claude.json`**

The server now comes from `--mcp-config`; the hard-coded runtime entry (with a literal secret) must not double-define it. Run:

```bash
F=.nvm-isolated/.claude-isolated/.claude.json
tmp="$F.tmp.$$"
jq 'del(.mcpServers.iwiki)' "$F" > "$tmp" && mv "$tmp" "$F"
```

- [ ] **Step 2: Verify the stale block is gone**

Run: `jq '.mcpServers' .nvm-isolated/.claude-isolated/.claude.json`
Expected: `{}` (or an object without an `iwiki` key).

- [ ] **Step 3: Remove the dead `mcpServers` key from `settings.json`**

Claude Code ignores `mcpServers` in `settings.json`; the empty stub is misleading. Run:

```bash
F=.nvm-isolated/.claude-isolated/settings.json
tmp="$F.tmp.$$"
jq 'del(.mcpServers)' "$F" > "$tmp" && mv "$tmp" "$F"
```

- [ ] **Step 4: Verify + validate**

Run:
```bash
jq 'has("mcpServers")' .nvm-isolated/.claude-isolated/settings.json
jq empty .nvm-isolated/.claude-isolated/settings.json && echo "settings JSON OK"
```
Expected: `false`, then `settings JSON OK`.

- [ ] **Step 5: Commit (settings.json only — `.claude.json` is gitignored)**

```bash
git add .nvm-isolated/.claude-isolated/settings.json
git commit -m "chore(config): drop dead mcpServers key from settings.json"
```

---

## Task 6: End-to-end verification + iwiki wiki refresh

**Files:** none (verification + wiki)

- [ ] **Step 1: Full syntax pass**

Run:
```bash
bash -n iclaude.sh && bash -n lib/iwiki/mcp.sh && bash -n lib/launcher/launch.sh && echo "syntax OK"
```
Expected: `syntax OK`.

- [ ] **Step 2: Re-run the unit test**

Run: `bash tests/test_iwiki_mcp.sh`
Expected: `iwiki-mcp: PASS=7 FAIL=0`, exit 0.

- [ ] **Step 3: Secret-leak check on the tracked file (SC2)**

Run: `grep -nE 'IWIKI_LLM_KEY' .nvm-isolated/.claude-isolated/mcp/iwiki.json`
Expected: exactly one line — `"IWIKI_LLM_KEY": "${IWIKI_LLM_KEY}"` — the placeholder, never a literal key.

- [ ] **Step 4: Live launch — server connects (SC3)**

Launch iclaude in a project that has an `.iwiki.toml` binding (e.g. this repo):
```bash
./iclaude.sh
```
Inside the session run `/mcp` and confirm `iwiki` shows **connected**, then call one tool (e.g. `wiki_status`) and confirm it returns the resolved base/domains — proving the real key/URL reached the server through `${...}` expansion.

- [ ] **Step 5: Disabled-path smoke (SC4)**

With `iwiki-mcp` off `PATH`, confirm launch proceeds without the server and without error:
```bash
PATH="$(echo "$PATH" | tr ':' '\n' | grep -v '\.local/bin' | paste -sd:)" ./iclaude.sh --check-isolated; echo "exit: $?"
```
Expected: runs cleanly (no "iwiki" registration, no failure). (Adjust the PATH filter if `iwiki-mcp` lives elsewhere.)

- [ ] **Step 6: Git hygiene (SC5)**

Run:
```bash
git check-ignore .nvm-isolated/.claude-isolated/.claude.json; echo "claude.json ignored rc=$?"
git check-ignore .nvm-isolated/.claude-isolated/mcp/iwiki.json; echo "mcp file ignored rc=$?"
git status --short
```
Expected: `.claude.json` → `rc=0` (ignored); `mcp/iwiki.json` → `rc=1` (tracked); no stray secret files staged.

- [ ] **Step 7: iwiki wiki refresh (project post-task checklist)**

The change alters iclaude's MCP integration behavior. Update the bound project domain (`iclaude`) via the iwiki MCP tools: author/update the page describing the iwiki MCP registration flow, then:
```text
wiki_write_page(domain="iclaude", slug="iwiki-mcp-registration", markdown=..., source="lib/iwiki/mcp.sh")
wiki_index(domain="iclaude")
wiki_lint()
```
Expected: `wiki_lint` reports no broken `[[refs]]`, no orphan/stale pages.

- [ ] **Step 8: Open the PR into `dev`**

Use the `git-workflow` skill to push `dev-iwiki-mcp-user-scope` and open a PR **targeting `dev`** (not `master`). Summarize: tracked secret-free `mcp/iwiki.json` + `--mcp-config`, `IWIKI_*` proxied from `.claude_config`, stale `.claude.json`/`settings.json` cleanup.

---

## Self-Review notes (author)

- **Spec coverage:** R1 tracked file (T2), R2 variable set incl. `SUMMARY_MAX_CHARS` + `${VAR:-default}` (T2), R3 `IWIKI_COMMAND` resolution (T1), R4 launch wiring both branches / microVM excluded (T4), R5 config surface `.claude_config` + example (T3), R6 cleanup `.claude.json` + `settings.json` (T5), R7 `.gitignore` un-ignore (T2). Success criteria SC1–SC5 map to T6 steps 1/3/4/5/6.
- **Type/name consistency:** `iwiki_mcp_config_file`, `iwiki_resolve_command`, `iwiki_mcp_enabled`, `IWIKI_COMMAND`, `CLAUDE_CONFIG_DIR` used identically across T1 (module + tests), T4 (wiring + dry check), and T6.
- **Secret discipline:** literal secrets only ever touch gitignored files (`.claude_config`, `.claude.json`); every committed file (`mcp/iwiki.json`, example, settings.json) is placeholder-only or secret-free, enforced by T2 step 3 and T6 step 3.
- **Line-number anchors are pre-change** (`iclaude.sh` ~38, `launch.sh` ~824); implementers match by the quoted context, since edits shift later numbers.
