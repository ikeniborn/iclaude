#!/usr/bin/env bash
# Tests for hooks/iwiki-remote-scope.js: the SessionStart preflight that tells
# the agent to bind the project .iwiki.toml scope before any wiki call under
# a remote (Streamable HTTP) iwiki MCP server, and stays silent under stdio.
# Run: bash tests/test_iwiki_remote_scope.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.nvm-isolated/.claude-isolated/hooks"
HOOK="$HOOKS_DIR/iwiki-remote-scope.js"

FAILED=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }

# ---- stdio / unset: no managed region emitted ----
t_stdio_silent() {
  echo "[stdio] no IWIKI_REMOTE_URL -> no remote-scope region"
  local out
  out="$(env -u IWIKI_REMOTE_URL node "$HOOK")"
  if [[ "$out" == *"Remote iwiki project scope"* ]]; then
    fail "region absent under stdio"
  else
    pass "region absent under stdio"
  fi
}
t_stdio_silent

# ---- remote: managed region emitted with the preflight instruction ----
t_remote_region() {
  echo "[remote] IWIKI_REMOTE_URL set -> remote-scope region emitted"
  local out
  out="$(IWIKI_REMOTE_URL="https://iwiki.example.com/mcp" node "$HOOK")"
  if [[ "$out" == *"## Remote iwiki project scope"* ]]; then
    pass "region header present"
  else
    fail "region header present"
  fi
  if [[ "$out" == *"wiki_bind"* && "$out" == *"read"* && "$out" == *"write"* && "$out" == *"primary"* ]]; then
    pass "instructs wiki_bind with read/write/primary"
  else
    fail "instructs wiki_bind with read/write/primary"
  fi
  if [[ "$out" == *"[specifications].mode"* && "$out" == *"specification_mode"* ]]; then
    pass "carries the project specification mode on the bind"
  else
    fail "carries the project specification mode on the bind"
  fi
  if [[ "$out" == *"before"*"wiki_status"* ]]; then
    pass "orders bind before wiki_status"
  else
    fail "orders bind before wiki_status"
  fi
  if [[ "$out" == *"completion-pending"* && "$out" == *"403"* ]]; then
    pass "fail-closed on invalid scope / 403"
  else
    fail "fail-closed on invalid scope / 403"
  fi
}
t_remote_region

# ---- remote-only: code-graph note tells the agent to switch/add config ----
t_remote_only_code_graph_note() {
  echo "[remote-only] no local vars -> code-graph note says switch/add config"
  local out
  out="$(env -u IWIKI_COMMAND -u IWIKI_LLM_KEY IWIKI_REMOTE_URL="https://iwiki.example.com/mcp" node "$HOOK")"
  if [[ "$out" == *"wiki_code_index"* && "$out" == *"source_unavailable"* && "$out" == *"mcp/iwiki.json"* ]]; then
    pass "notes wiki_code_index needs a local config, not a .iwiki.toml edit"
  else
    fail "notes wiki_code_index needs a local config, not a .iwiki.toml edit"
  fi
  if [[ "$out" == *"iwiki-local"* && "$out" == *"iwiki-remote"* ]]; then
    fail "does not claim dual registration when local is not usable"
  else
    pass "does not claim dual registration when local is not usable"
  fi
}
t_remote_only_code_graph_note

# ---- dual: local vars also present -> note routes tools per server, no switch ----
t_dual_code_graph_note() {
  echo "[dual] IWIKI_COMMAND + IWIKI_LLM_KEY also set -> per-server routing note"
  local out
  out="$(IWIKI_REMOTE_URL="https://iwiki.example.com/mcp" IWIKI_COMMAND="/usr/local/bin/iwiki-mcp" IWIKI_LLM_KEY="sk-x" node "$HOOK")"
  if [[ "$out" == *"iwiki-local"* && "$out" == *"iwiki-remote"* ]]; then
    pass "routes code-graph tools to iwiki-local, rest to iwiki-remote"
  else
    fail "routes code-graph tools to iwiki-local, rest to iwiki-remote"
  fi
  if [[ "$out" == *"No config switch is needed"* ]]; then
    pass "tells the agent no config switch is needed in dual mode"
  else
    fail "tells the agent no config switch is needed in dual mode"
  fi
}
t_dual_code_graph_note

# ---- both modes: code reads carry the freshness gate and the no-source rule ----
t_code_read_contract_note() {
  echo "[remote+dual] code-read note states the freshness gate and no remote source"
  local remote_out dual_out mode
  remote_out="$(env -u IWIKI_COMMAND -u IWIKI_LLM_KEY IWIKI_REMOTE_URL="https://iwiki.example.com/mcp" node "$HOOK")"
  dual_out="$(IWIKI_REMOTE_URL="https://iwiki.example.com/mcp" IWIKI_COMMAND="/usr/local/bin/iwiki-mcp" IWIKI_LLM_KEY="sk-x" node "$HOOK")"
  for mode in remote dual; do
    local out
    [[ "$mode" == remote ]] && out="$remote_out" || out="$dual_out"
    if [[ "$out" == *"wiki_code_status"* && "$out" == *"fresh"* ]]; then
      pass "$mode: gates code results on wiki_code_status freshness"
    else
      fail "$mode: gates code results on wiki_code_status freshness"
    fi
    if [[ "$out" == *"include_source=true"* && "$out" == *"source_unavailable"* ]]; then
      pass "$mode: states a remote code read returns no file source"
    else
      fail "$mode: states a remote code read returns no file source"
    fi
  done
}
t_code_read_contract_note

# ---- both modes: specification policy is server-side, read from wiki_status ----
t_specification_policy_note() {
  echo "[remote+dual] specification note points at wiki_status, not the project file"
  local remote_out dual_out mode
  remote_out="$(env -u IWIKI_COMMAND -u IWIKI_LLM_KEY IWIKI_REMOTE_URL="https://iwiki.example.com/mcp" node "$HOOK")"
  dual_out="$(IWIKI_REMOTE_URL="https://iwiki.example.com/mcp" IWIKI_COMMAND="/usr/local/bin/iwiki-mcp" IWIKI_LLM_KEY="sk-x" node "$HOOK")"
  for mode in remote dual; do
    local out
    [[ "$mode" == remote ]] && out="$remote_out" || out="$dual_out"
    if [[ "$out" == *"specifications"* && "$out" == *"wiki_status"* ]]; then
      pass "$mode: takes the effective specification mode from wiki_status"
    else
      fail "$mode: takes the effective specification mode from wiki_status"
    fi
    if [[ "$out" == *"[specifications] mode"* && "$out" == *"source: project"* && "$out" == *"wiki_bind(specification_mode"* ]]; then
      pass "$mode: gates the project file mode on 'source: project' and carries it on wiki_bind"
    else
      fail "$mode: gates the project file mode on 'source: project' and carries it on wiki_bind"
    fi
    if [[ "$out" == *"project_mode_suppressed"* && "$out" == *"completion-pending"* ]]; then
      pass "$mode: fail-closed on a refused or mismatched specification mode"
    else
      fail "$mode: fail-closed on a refused or mismatched specification mode"
    fi
  done
}
t_specification_policy_note

# ---- binding provenance: token_default means the session binding was lost ----
t_binding_provenance_note() {
  echo "[remote+dual] binding provenance note names binding_source and its fallback"
  local remote_out dual_out
  remote_out="$(env -u IWIKI_COMMAND -u IWIKI_LLM_KEY IWIKI_REMOTE_URL="https://iwiki.example.com/mcp" node "$HOOK")"
  dual_out="$(IWIKI_REMOTE_URL="https://iwiki.example.com/mcp" IWIKI_COMMAND="iwiki-mcp" IWIKI_LLM_KEY="k" node "$HOOK")"
  local mode out
  for mode in remote dual; do
    [[ "$mode" == remote ]] && out="$remote_out" || out="$dual_out"
    if [[ "$out" == *"binding_source"* && "$out" == *"token_default"* && "$out" == *"re-bind"* ]]; then
      pass "$mode: re-binds when binding_source reports token_default"
    else
      fail "$mode: re-binds when binding_source reports token_default"
    fi
    if [[ "$out" == *"binding_defaulted"* && "$out" == *"binding_not_selected"* ]]; then
      pass "$mode: names the domain-free code-read fallback signals"
    else
      fail "$mode: names the domain-free code-read fallback signals"
    fi
    if [[ "$out" == *"primary_substituted"* && "$out" == *"requested_primary"* ]]; then
      pass "$mode: treats a substituted primary as a binding error"
    else
      fail "$mode: treats a substituted primary as a binding error"
    fi
    if [[ "$out" == *'`scope`'* && "$out" == *'scope="all"'* ]]; then
      pass "$mode: keeps wiki_search scope at its project default"
    else
      fail "$mode: keeps wiki_search scope at its project default"
    fi
    if [[ "$out" == *"wiki_spec_search"* && "$out" == *"without an explicit \`domains\`"* ]]; then
      pass "$mode: names the defaulted specification search scope"
    else
      fail "$mode: names the defaulted specification search scope"
    fi
    if [[ "$out" == *'`wiki_search(intent="write")` prefers the bound primary'* ]]; then
      pass "$mode: names the defaulted write-intent target"
    else
      fail "$mode: names the defaulted write-intent target"
    fi
    if [[ "$out" == *"not_bound_primary"* && "$out" == *"not a missing grant"* ]]; then
      pass "$mode: reads a refused resolve as a binding mismatch"
    else
      fail "$mode: reads a refused resolve as a binding mismatch"
    fi
  done
}
t_binding_provenance_note

# ---- remote output never contains the URL/token themselves ----
t_remote_no_secrets() {
  echo "[remote] emitted region carries no URL or token"
  local out
  out="$(IWIKI_REMOTE_URL="https://iwiki.example.com/mcp" IWIKI_REMOTE_TOKEN="sk-secret-token" node "$HOOK")"
  if [[ "$out" == *"iwiki.example.com"* || "$out" == *"sk-secret-token"* ]]; then
    fail "no secret/URL leakage in emitted text"
  else
    pass "no secret/URL leakage in emitted text"
  fi
}
t_remote_no_secrets

# ---- idempotent: identical output across repeated invocations ----
t_idempotent() {
  echo "[remote] repeated invocations emit identical output"
  local out1 out2
  out1="$(IWIKI_REMOTE_URL="https://iwiki.example.com/mcp" node "$HOOK")"
  out2="$(IWIKI_REMOTE_URL="https://iwiki.example.com/mcp" node "$HOOK")"
  if [[ "$out1" == "$out2" ]]; then
    pass "idempotent output"
  else
    fail "idempotent output"
  fi
}
t_idempotent

echo "iwiki-remote-scope: FAILED=$FAILED"
exit "$FAILED"
