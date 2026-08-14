#!/usr/bin/env bash
# Unit tests for the task-ledger skill contract and its local spool helper:
#   .claude-isolated/skills/task-ledger/{SKILL.md,scripts/task_spool.py}
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS="$ROOT/.nvm-isolated/.claude-isolated/skills"
skill="$SKILLS/task-ledger/SKILL.md"
helper="$SKILLS/task-ledger/scripts/task_spool.py"
context_skill="$SKILLS/context-awareness/SKILL.md"

PASS=0; FAIL=0
assert_eq(){ if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }
assert_contains(){ if [[ "$2" == *"$1"* ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: missing '$1'"; fi; }
assert_exit(){ local want=$1 name=$2; shift 2; "$@" >/dev/null 2>&1; assert_eq "$?" "$want" "$name"; }

TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT
home="$TD/home"

assert_exit 0 "task-ledger skill exists" test -f "$skill"
assert_exit 0 "task spool helper exists" test -f "$helper"
assert_exit 0 "context-awareness skill exists" test -f "$context_skill"

body="$(cat "$skill" 2>/dev/null || true)"
context_body="$(cat "$context_skill" 2>/dev/null || true)"

assert_contains "direct, chain, and LoEn" "$body" "all tasks tracked"
assert_contains "read-only" "$body" "read-only tasks tracked"
assert_contains "parent agent is the sole writer" "$body" "parent sole writer"
assert_contains "reference/tasks/<topic>" "$body" "canonical slug"
assert_contains "completion-pending" "$body" "completion waits"
assert_contains "never modify iwiki-mcp" "$body" "server stays external"
assert_contains "type: reference" "$body" "page metadata type"
assert_contains "status: stable" "$body" "page metadata status"
assert_contains 'tag `task`' "$body" "page metadata tag"
for section in "Current State" "TODO" "Subtasks" "Evidence" "Changelog"; do
  assert_contains "## $section" "$body" "required page section: $section"
done
for field in topic route lifecycle opened closed parent pending-delivery; do
  assert_contains "$field" "$body" "current state field: $field"
done
assert_contains "workflow-specific" "$body" "TODO stays workflow-specific"
assert_contains "direct or LoEn" "$body" "TODO does not impose chain stages"
assert_contains "Read or create" "$body" "page read before replay"
assert_contains "never call MCP" "$body" "helper never calls MCP"
assert_contains "wiki_sync" "$body" "helper never syncs"
assert_contains "history segments" "$body" "task history stays complete"
assert_contains "bounded active segment" "$body" "task history writes stay bounded"
assert_contains "domain changelog" "$body" "domain changelog is curated"
assert_contains "expected task-page orphan advisory" "$body" "task orphan is expected advisory"
assert_contains 'truncated to 16 hex characters' "$body" "idempotency key width"
assert_contains '$CLAUDE_CONFIG_DIR/state/iwiki-task-spool' "$body" "spool path is config-dir scoped"
for lifecycle in in-progress blocked completion-pending done; do
  assert_contains "\`$lifecycle\`" "$body" "lifecycle: $lifecycle"
done
for kind in open route dispatch return decision blocker verification gate close; do
  assert_contains "\`$kind\`" "$body" "event kind: $kind"
done

assert_contains 'task_page_slug' "$context_body" "context includes task page"
assert_contains 'task_delivery_pending' "$context_body" "context includes pending delivery"
assert_contains '$CLAUDE_CONFIG_DIR/state/iwiki-task-spool/<project>/<topic>.json' "$context_body" "context checks config-dir spool"
assert_contains 'even when iwiki is unavailable or the project domain is absent' "$context_body" "context checks spool without iwiki"
assert_contains 'task_delivery_pending: true when that queue file exists' "$context_body" "context maps queue presence to pending"
no_domain_branch="$(sed -n '/4\. Если домена проекта нет:/,/ELSE (сервер не подключён):/p' "$context_skill")"
outage_branch="$(sed -n '/ELSE (сервер не подключён):/,/```/p' "$context_skill")"
for branch in "$no_domain_branch" "$outage_branch"; do
  assert_contains 'task_delivery_pending: <spool result when topic known; otherwise false>' "$branch" "known-topic outage preserves spool result"
  assert_eq "$([[ "$branch" == *'task_delivery_pending: false'* ]] && echo true || echo false)" "false" "known-topic outage has no hard-coded false"
done

spool(){ python3 "$helper" "$@" --config-dir "$home" --project iclaude --topic wiki-task-ledger; }
enqueue(){ printf '%s' "$1" | spool enqueue; }

event='{"kind":"verification","occurred_at":"2026-08-14T12:00:00Z","actor":"root","summary":"focused suite passed","evidence":{"paths":["tests/test_task_ledger.sh"],"checks":[{"name":"task-ledger","status":"passed","exit_code":0}],"hashes":{"fixture":"0123456789abcdef"}}}'
assert_exit 0 "enqueue valid event" enqueue "$event"
queue_file="$home/state/iwiki-task-spool/iclaude/wiki-task-ledger.json"
assert_eq "$(stat -c '%a' "$queue_file")" "600" "spool mode is private"
first="$(spool list)"
assert_contains '"event_id"' "$first" "queued event has id"
assert_contains '"evidence_hash"' "$first" "queued event has evidence hash"
assert_exit 0 "duplicate enqueue is idempotent" enqueue "$event"
after_retry="$(spool list)"
assert_eq "$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)["events"]))' <<<"$after_retry")" "1" "one event after retry"

same_evidence='{"kind":"verification","occurred_at":"2026-08-14T12:01:00Z","actor":"root","summary":"same evidence retried later","evidence":{"paths":["tests/test_task_ledger.sh"],"checks":[{"name":"task-ledger","status":"passed","exit_code":0}],"hashes":{"fixture":"0123456789abcdef"}}}'
assert_exit 0 "timestamp and summary do not change idempotency" enqueue "$same_evidence"
after_semantic_retry="$(spool list)"
assert_eq "$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)["events"]))' <<<"$after_semantic_retry")" "1" "semantic retry remains one event"

second='{"kind":"close","occurred_at":"2026-08-14T12:02:00Z","actor":"root","summary":"task verified","evidence":{"paths":["docs/superpowers/plans/2026-08-12-wiki-task-ledger-plan.md"],"checks":[{"name":"result","status":"passed","exit_code":0}],"hashes":{"fixture":"fedcba9876543210"}}}'
assert_exit 0 "enqueue second ordered event" enqueue "$second"
ordered="$(spool list)"
assert_eq "$(python3 -c 'import json,sys; print(",".join(e["kind"] for e in json.load(sys.stdin)["events"]))' <<<"$ordered")" "verification,close" "events preserve enqueue order"
first_id="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["events"][0]["event_id"])' <<<"$ordered")"
assert_eq "${#first_id}" "16" "event id is 16 hex characters"
assert_exit 0 "acknowledge confirmed event" spool ack --event-id "$first_id"
after_ack="$(spool list)"
assert_eq "$(python3 -c 'import json,sys; print(",".join(e["kind"] for e in json.load(sys.stdin)["events"]))' <<<"$after_ack")" "close" "ack removes exactly one event"

secret='{"kind":"verification","occurred_at":"2026-08-14T12:00:00Z","actor":"root","summary":"token=abc123","evidence":{"paths":[],"checks":[],"hashes":{}}}'
assert_exit 2 "secret payload rejected" enqueue "$secret"
for leaked in 'password=hunter2' 'secret: value' 'api_key=abc' 'authorization: Basic abc' 'Bearer abc.def'; do
  payload="${event/focused suite passed/$leaked}"
  assert_exit 2 "sensitive summary rejected: $leaked" enqueue "$payload"
done

assert_eq "$(python3 - "$helper" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("task_spool", sys.argv[1])
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)
base = {
    "kind": "verification",
    "occurred_at": "2026-08-14T12:00:00Z",
    "actor": "root",
    "summary": "safe summary",
    "evidence": {"paths": ["tests/test_task_ledger.sh"], "checks": [{"name": "suite", "status": "passed", "exit_code": 0}], "hashes": {"fixture": "0123456789abcdef"}},
}
cases = []
unknown = dict(base); unknown["raw_output"] = "no"; cases.append(unknown)
bad_time = dict(base); bad_time["occurred_at"] = "2026-08-14T12:00:00+00:00"; cases.append(bad_time)
unsafe = dict(base); unsafe["evidence"] = dict(base["evidence"], paths=["../secret"]); cases.append(unsafe)
bad_check = dict(base); bad_check["evidence"] = dict(base["evidence"], checks=[{"name": "suite", "status": "unknown", "exit_code": 0}]); cases.append(bad_check)
bad_hash = dict(base); bad_hash["evidence"] = dict(base["evidence"], hashes={"fixture": "UPPERCASE"}); cases.append(bad_hash)
for value in cases:
    try:
        module.validate_event(value, "wiki-task-ledger")
    except ValueError:
        continue
    raise SystemExit("invalid event accepted")
print("OK")
PY
)" "OK" "schema rejects malformed inputs"

assert_eq "$(python3 - "$helper" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("task_spool", sys.argv[1])
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)
base = {
    "kind": "verification",
    "occurred_at": "2026-08-14T12:00:00Z",
    "actor": "root",
    "summary": "safe summary",
    "evidence": {"paths": ["tests/test_task_ledger.sh"], "checks": [{"name": "suite", "status": "passed", "exit_code": 0}], "hashes": {"fixture": "0123456789abcdef"}},
}
for field, value in (("actor", "root\r"), ("summary", "bad\u2028text")):
    candidate = dict(base); candidate[field] = value
    try: module.validate_event(candidate, "wiki-task-ledger")
    except ValueError: continue
    raise SystemExit("control character accepted")
for path in (".env", "config/.env.local", "auth/token.txt", "credentials/file", "private-key.pem", "a" * 1025):
    candidate = dict(base); candidate["evidence"] = dict(base["evidence"], paths=[path])
    try: module.validate_event(candidate, "wiki-task-ledger")
    except ValueError: continue
    raise SystemExit("unsafe path accepted")
for summary in ("SERVICE_API_KEY=abc", "CLIENT_TOKEN: abc", "access_key=abc", "private_key=abc", "x-api-key=abc", "api-key: abc", "access-token=abc", "client-secret: abc"):
    candidate = dict(base); candidate["summary"] = summary
    try: module.validate_event(candidate, "wiki-task-ledger")
    except ValueError: continue
    raise SystemExit("secret assignment accepted")
for path in ("lib/iwiki/mcp.sh", "lib/oauth/token-refresh.sh", "docs/credential-format.md"):
    candidate = dict(base); candidate["evidence"] = dict(base["evidence"], paths=[path])
    module.validate_event(candidate, "wiki-task-ledger")
print("OK")
PY
)" "OK" "schema rejects controls and sensitive paths"

assert_eq "$(python3 - "$helper" "$home" <<'PY'
import json
import subprocess
import sys

helper, home = sys.argv[1:]
base = {"kind": "verification", "occurred_at": "2026-08-14T12:00:00Z", "actor": "root", "summary": "safe", "evidence": {"paths": [], "checks": [], "hashes": {}}}
for value in ({**base, "kind": None}, {**base, "kind": ["verification"]}, ["not", "an", "event"]):
    result = subprocess.run([sys.executable, helper, "enqueue", "--config-dir", home, "--project", "iclaude", "--topic", "wiki-task-ledger"], input=json.dumps(value), text=True, capture_output=True)
    if result.returncode != 2 or "task_spool:" not in result.stderr or "Traceback" in result.stderr:
        raise SystemExit("CLI validation leaked traceback")
print("OK")
PY
)" "OK" "CLI invalid inputs are controlled"

assert_eq "$(python3 - "$helper" "$home" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("task_spool", sys.argv[1])
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)
home = Path(sys.argv[2])
queue = home / "state/iwiki-task-spool/iclaude/boundary-test.json"
queue.parent.mkdir(parents=True, exist_ok=True)
queue.write_text(json.dumps({"schema_version": True, "project": "iclaude", "topic": "boundary-test", "events": []}))
try: module.list_events(home, "iclaude", "boundary-test")
except ValueError: pass
else: raise SystemExit("boolean schema version accepted")
queue.unlink()
target = home / "outside.json"; target.write_text("outside")
queue.symlink_to(target)
event = {"kind": "verification", "occurred_at": "2026-08-14T12:00:00Z", "actor": "root", "summary": "safe", "evidence": {"paths": [], "checks": [], "hashes": {}}}
try: module.enqueue(home, "iclaude", "boundary-test", event)
except ValueError: pass
else: raise SystemExit("symlink queue accepted")
if target.read_text() != "outside": raise SystemExit("symlink target changed")
queue.unlink()
print("OK")
PY
)" "OK" "queue boundary rejects symlinks and bad schema type"

assert_eq "$(python3 - "$helper" "$home" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

helper, home = sys.argv[1:]
queue = Path(home) / "state/iwiki-task-spool/iclaude/schema-version-test.json"
queue.parent.mkdir(parents=True, exist_ok=True)
queue.write_text(json.dumps({"schema_version": True, "project": "iclaude", "topic": "schema-version-test", "events": []}))
result = subprocess.run([sys.executable, helper, "list", "--config-dir", home, "--project", "iclaude", "--topic", "schema-version-test"], text=True, capture_output=True)
if result.returncode != 2 or "schema_version" not in result.stderr or "Traceback" in result.stderr:
    raise SystemExit("schema version error was not controlled")
queue.unlink()
print("OK")
PY
)" "OK" "schema version CLI error is controlled"

assert_eq "$(python3 - "$helper" "$TD" <<'PY'
import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("task_spool", sys.argv[1])
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)
home = Path(sys.argv[2]) / "unsafe-home"
unsafe = home / "state" / "iwiki-task-spool"
unsafe.mkdir(parents=True)
unsafe.chmod(0o755)
event = {"kind": "verification", "occurred_at": "2026-08-14T12:00:00Z", "actor": "root", "summary": "safe", "evidence": {"paths": [], "checks": [], "hashes": {}}}
try: module.enqueue(home, "iclaude", "unsafe-dir", event)
except ValueError: print("OK")
else: raise SystemExit("unsafe directory accepted")
PY
)" "OK" "unsafe preexisting spool directory rejected"

assert_eq "$(python3 - "$helper" "$TD" <<'PY'
import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("task_spool", sys.argv[1])
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)
home = Path(sys.argv[2]) / "launcher-home"
home.mkdir()
home.chmod(0o775)
event = {"kind": "verification", "occurred_at": "2026-08-14T12:00:00Z", "actor": "root", "summary": "safe", "evidence": {"paths": [], "checks": [], "hashes": {}}}
if module.list_events(home, "iclaude", "launcher-home")["events"] != []:
    raise SystemExit("new queue is not empty")
module.enqueue(home, "iclaude", "launcher-home", event)
if len(module.list_events(home, "iclaude", "launcher-home")["events"]) != 1:
    raise SystemExit("trusted launcher home could not enqueue")
print("OK")
PY
)" "OK" "trusted launcher config dir supports spool"

assert_eq "$(python3 - "$helper" "$home" <<'PY'
import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("task_spool", sys.argv[1])
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)
config_dir = Path(sys.argv[2])
queue = config_dir / "state/iwiki-task-spool/iclaude/wiki-task-ledger.json"
before = queue.read_bytes()
event = {
    "kind": "blocker",
    "occurred_at": "2026-08-14T12:03:00Z",
    "actor": "root",
    "summary": "simulated delivery failure",
    "evidence": {"paths": [], "checks": [], "hashes": {}},
}
original_replace = module.os.replace
def fail_replace(source, target):
    raise OSError("simulated replace failure")
module.os.replace = fail_replace
try:
    try:
        module.enqueue(config_dir, "iclaude", "wiki-task-ledger", event)
    except OSError:
        pass
    else:
        raise SystemExit("enqueue unexpectedly succeeded")
finally:
    module.os.replace = original_replace
print("OK" if queue.read_bytes() == before else "CHANGED")
PY
)" "OK" "replace failure preserves valid queue"

remaining_id="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["events"][0]["event_id"])' <<<"$after_ack")"
assert_exit 0 "acknowledge final event" spool ack --event-id "$remaining_id"
assert_exit 1 "empty queue file removed" test -e "$queue_file"

gate_event='{"kind":"gate","occurred_at":"2026-08-14T12:04:00Z","actor":"root","summary":"chain gate passed","evidence":{"paths":["docs/superpowers/intents/2026-08-12-wiki-task-ledger-intent.md"],"checks":[{"name":"intent","status":"passed","exit_code":0}],"hashes":{"intent":"0123456789abcdef"}}}'
assert_exit 0 "enqueue gate event" bash -c 'printf "%s" "$1" | python3 "$2" enqueue --config-dir "$3" --project iclaude --topic chain-gate-event' _ "$gate_event" "$helper" "$home"
gate_queue="$(python3 "$helper" list --config-dir "$home" --project iclaude --topic chain-gate-event)"
assert_eq "$(python3 -c 'import json,sys; print(json.load(sys.stdin)["events"][0]["kind"])' <<<"$gate_queue")" "gate" "list preserves gate event"

assert_exit 1 "legacy repository TODO removed" test -e "$ROOT/docs/TODO.md"

echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
