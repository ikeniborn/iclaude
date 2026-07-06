#!/bin/bash
# E2E telemetry smoke: run iclaude, verify metric+log appear
set -u
PASS=0; FAIL=0
chk() { if eval "$1"; then echo "  ✓ $2"; PASS=$((PASS+1)); else echo "  ✗ $2"; FAIL=$((FAIL+1)); fi; }

# Resolve service endpoints. Prometheus and Loki may not have published
# ports on the host — fall back to the container IP on proxy-net.
resolve_ip() {
    local name="$1"
    sudo docker inspect "$name" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null
}
PROM_IP=$(resolve_ip minipc-traefik-prometheus-1)
LOKI_IP=$(resolve_ip minipc-traefik-loki)
PROM="http://${PROM_IP:-localhost}:9090"
LOKI="http://${LOKI_IP:-localhost}:3100"

echo "[1] otel-collector health"
chk "curl -fsS http://127.0.0.1:13133/ >/dev/null" "collector :13133 OK"

echo "[2] prometheus scrape targets"
chk "curl -fsS $PROM/api/v1/targets | grep -q '\"job\":\"otel-collector\"'" "otel-collector target present"
chk "curl -fsS -G '$PROM/api/v1/query' --data-urlencode 'query=up{job=\"otel-collector\"}' | grep -q '\"value\":\\[.*,\"1\"\\]'" "otel-collector up=1"

echo "[3] loki ready"
chk "curl -fsS $LOKI/ready 2>/dev/null | grep -q ready" "loki ready"

echo "[4] run iclaude print mode"
TESTDIR=$(mktemp -d); cd "$TESTDIR"; git init -q
iclaude --print "say hi" >/dev/null 2>&1 || true
sleep 35

echo "[5] prometheus has claude_code_session_count_total"
chk "curl -fsS '$PROM/api/v1/query?query=claude_code_session_count_total' | grep -q '\"result\":\\[{'" "session metric exists"

echo "[6] loki has claude-code service"
chk "curl -fsS -G '$LOKI/loki/api/v1/query_range' --data-urlencode 'query={service_name=\"claude-code\"}' --data-urlencode 'limit=1' | grep -q '\"result\":\\[{'" "loki has claude-code logs"

echo "[7] opt-out: ICLAUDE_NO_TELEMETRY=1 → no new metric increment"
BEFORE=$(curl -s "$PROM/api/v1/query?query=sum(claude_code_session_count_total)" | python3 -c "import json,sys; r=json.load(sys.stdin)['data']['result']; print(r[0]['value'][1] if r else 0)")
ICLAUDE_NO_TELEMETRY=1 iclaude --print "opt-out test" >/dev/null 2>&1 || true
sleep 35
AFTER=$(curl -s "$PROM/api/v1/query?query=sum(claude_code_session_count_total)" | python3 -c "import json,sys; r=json.load(sys.stdin)['data']['result']; print(r[0]['value'][1] if r else 0)")
chk "[[ \"$BEFORE\" == \"$AFTER\" ]]" "no metric change with ICLAUDE_NO_TELEMETRY=1 (before=$BEFORE after=$AFTER)"

cd /; rm -rf "$TESTDIR"
echo ""
echo "Result: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
