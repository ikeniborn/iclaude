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
  if [[ "$out" == *"wiki_code_index"* && "$out" == *"source_unavailable"* && "$out" == *"mcp/iwiki.json"* ]]; then
    pass "notes wiki_code_index needs local stdio config, not .iwiki.toml edit"
  else
    fail "notes wiki_code_index needs local stdio config, not .iwiki.toml edit"
  fi
}
t_remote_region

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
