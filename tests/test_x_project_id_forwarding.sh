#!/usr/bin/env bash
# Hermetic integration test: CCR forwards ICLAUDE_PROJECT_ID as the X-Project-Id
# header to the provider api_base_url. Uses a local Python mock upstream that records
# received headers. No Ollama/LiteLLM needed.
# Exit codes: 0=pass, 1=fail, 77=skip (ccr/node20/python missing or ports busy).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOCK_PORT=18473
CCR_PORT=3458
CCR_HOST=127.0.0.1
PROJECT_ID="ci-test-proj"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
skip() { echo "SKIP: $*"; exit 77; }

command -v python3 >/dev/null 2>&1 || skip "python3 not found"

# Locate ccr binary (isolated env first)
CCR_CMD=""
for c in "$REPO_ROOT/.nvm-isolated/npm-global/bin/ccr" "$(command -v ccr 2>/dev/null || true)"; do
    [[ -x "$c" ]] && { CCR_CMD="$c"; break; }
done
[[ -z "$CCR_CMD" ]] && skip "ccr binary not found (run: ./iclaude.sh --install-router)"

# CCR v2.0.0 needs node v20+; prepend it to PATH like lib/launcher/launch.sh does
_node20=$(find "$REPO_ROOT/.nvm-isolated/versions/node" -maxdepth 1 -type d \
    -name "v2[0-9]*" 2>/dev/null | LC_ALL=C sort | tail -1)
[[ -n "$_node20" && -d "$_node20/bin" ]] && export PATH="$_node20/bin:$PATH"

# Refuse to clobber an already-bound port
for p in "$MOCK_PORT" "$CCR_PORT"; do
    if (: >/dev/tcp/127.0.0.1/"$p") 2>/dev/null; then
        skip "port $p already in use — cannot run hermetic test"
    fi
done

WORK=$(mktemp -d)
HDR_FILE="$WORK/headers.txt"
MOCK_PID=""; CCR_PID=""
cleanup() {
    [[ -n "$CCR_PID" ]]  && { kill "$CCR_PID"  2>/dev/null; wait "$CCR_PID"  2>/dev/null; }
    [[ -n "$MOCK_PID" ]] && { kill "$MOCK_PID" 2>/dev/null; wait "$MOCK_PID" 2>/dev/null; }
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

# --- mock upstream: records lowercased "key: value" headers, returns minimal JSON ---
cat > "$WORK/mock_upstream.py" <<'PY'
import http.server, json, sys
HDR_FILE = sys.argv[1]
PORT = int(sys.argv[2])

class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        with open(HDR_FILE, "w") as f:
            for k, v in self.headers.items():
                f.write(f"{k.lower()}: {v}\n")
        try:
            self.rfile.read(int(self.headers.get("content-length", 0) or 0))
        except Exception:
            pass
        body = json.dumps({
            "id": "chatcmpl-mock", "object": "chat.completion", "created": 0, "model": "mock-model",
            "choices": [{"index": 0, "message": {"role": "assistant", "content": "OK"}, "finish_reason": "stop"}],
            "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass

http.server.HTTPServer(("127.0.0.1", PORT), H).serve_forever()
PY

python3 "$WORK/mock_upstream.py" "$HDR_FILE" "$MOCK_PORT" &
MOCK_PID=$!
# Wait for mock to bind (max 5s)
_ok=false
for _ in $(seq 1 25); do
    (: >/dev/tcp/127.0.0.1/"$MOCK_PORT") 2>/dev/null && { _ok=true; break; }
    sleep 0.2
done
[[ "$_ok" == "true" ]] || fail "mock upstream did not start on :$MOCK_PORT"

# --- purpose-built config: single provider → mock, using the x-project-id transformer plugin ---
CCR_HOME="$WORK/ccr-home"
mkdir -p "$CCR_HOME/.claude-code-router"
cat > "$CCR_HOME/.claude-code-router/config.json" <<JSON
{
  "PORT": $CCR_PORT,
  "HOST": "$CCR_HOST",
  "LOG": false,
  "transformers": [
    { "path": "$REPO_ROOT/.nvm-isolated/.claude-isolated/.claude-code-router/plugins/x-project-id.js" }
  ],
  "Providers": [
    {
      "name": "mockprov",
      "api_base_url": "http://127.0.0.1:$MOCK_PORT/v1/chat/completions",
      "api_key": "test-key",
      "models": ["mock-model"],
      "transformer": { "use": ["x-project-id"] }
    }
  ],
  "Router": { "default": "mockprov,mock-model" }
}
JSON

# --- start CCR with ICLAUDE_PROJECT_ID in its process env ---
HOME="$CCR_HOME" ICLAUDE_PROJECT_ID="$PROJECT_ID" "$CCR_CMD" start >"$WORK/ccr.log" 2>&1 &
CCR_PID=$!
_ready=false
for _ in $(seq 1 20); do
    kill -0 "$CCR_PID" 2>/dev/null || fail "CCR exited early. Log: $(cat "$WORK/ccr.log" 2>/dev/null)"
    (: >/dev/tcp/"$CCR_HOST"/"$CCR_PORT") 2>/dev/null && { _ready=true; break; }
    sleep 0.5
done
[[ "$_ready" == "true" ]] || fail "CCR not ready on :$CCR_PORT after 10s. Log: $(cat "$WORK/ccr.log" 2>/dev/null)"

# --- send one request through CCR; response body is irrelevant (header captured at receipt) ---
curl -s --max-time 10 "http://$CCR_HOST:$CCR_PORT/v1/messages" \
    -H "x-api-key: test" \
    -H "anthropic-version: 2023-06-01" \
    -H "Content-Type: application/json" \
    -d '{"model":"mock-model","max_tokens":16,"messages":[{"role":"user","content":"hi"}]}' \
    >/dev/null 2>&1 || true

# Give the upstream a moment to flush the header file
for _ in $(seq 1 10); do [[ -s "$HDR_FILE" ]] && break; sleep 0.2; done

[[ -s "$HDR_FILE" ]] || fail "mock upstream received no request (header file empty). CCR log: $(cat "$WORK/ccr.log" 2>/dev/null)"

if grep -qi "^x-project-id: ${PROJECT_ID}$" "$HDR_FILE"; then
    pass "CCR forwarded X-Project-Id: ${PROJECT_ID} to upstream"
else
    echo "ERROR: captured headers:" >&2
    cat "$HDR_FILE" >&2
    fail "X-Project-Id not forwarded as '${PROJECT_ID}'"
fi
