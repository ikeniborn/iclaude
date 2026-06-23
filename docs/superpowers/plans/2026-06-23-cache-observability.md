---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-23-cache-observability-design.md
review:
  plan_hash: c70cb7d76fa3de7c
  spec_hash: 0ca5f95ab1a32493
  last_run: 2026-06-23
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings: []
---

# Cache Observability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface Anthropic prompt-cache health in iclaude — per-turn hit-rate % and read/write split in the statusline, plus a cumulative end-of-session cache report.

**Architecture:** A1 — two stateless readers. The statusline computes per-turn hit-rate from the `current_usage` object already on its stdin (zero extra I/O). A new `SessionEnd` hook scans the session transcript `.jsonl` for cumulative totals (no state file). Neither surface shares state.

**Tech Stack:** Bash + `jq` + `awk` (statusline, already present); Python 3 stdlib only (hook); pytest (tests).

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-06-23-cache-observability-design.md`.
- **Fail-soft everywhere:** statusline edit and the hook must `exit 0` on any error and never break the Claude Code UI (match `block-secrets.py` and the statusline's existing `jq`-missing guard).
- **Python: stdlib only** for the hook — no third-party imports.
- **Surgical statusline edits:** touch only the jq parse, one new helper, and the cache-display block. No reformatting of adjacent code, no color (the segment is currently uncolored; adding color is out of scope).
- **No `$ saved`, no `/cache-report` command, no degradation-warning hook** (explicit spec non-goals).
- **Report shows raw integer token counts** (full precision; the statusline humanizes to K/M only because of width). Binding numbers come from the spec's Success Criteria.
- **hit-rate formula (both surfaces):** `read / (read + creation + input)`, integer percent; `n/a` when the denominator is 0.
- **Branch:** work on `dev-cache-observability` (already checked out); PR → `dev`. Conventional-commit messages; end each commit body with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` | Live per-turn cache segment: `📦 NN% · R../W..` (modify) |
| `.nvm-isolated/.claude-isolated/hooks/cache-report.py` | SessionEnd cumulative report from transcript (new) |
| `.nvm-isolated/.claude-isolated/settings.json` | Register the `SessionEnd` hook (modify) |
| `tests/test_statusline_cache.py` | pytest: statusline renders hit-rate + R/W from synthetic stdin (new) |
| `tests/test_cache_report.py` | pytest: hook aggregation/format/fail-soft (new) |
| `docs/wiki/statusline.md`, `docs/functions/STATUSLINE.md` | Doc refresh via iwiki (modify, post-task) |

---

## Task 1: Statusline cache segment (hit-rate % + read/write split)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` (jq parse ~55-82; new helper after `detect_real_context_window` ~151; cache-display block 200-214)
- Test: `tests/test_statusline_cache.py`

**Interfaces:**
- Consumes: Claude Code statusline stdin JSON → `.context_window.current_usage.{cache_read_input_tokens, cache_creation_input_tokens, input_tokens}`.
- Produces: the `CACHE_DISPLAY` shell variable, rendered as ` | 📦 <hit>% · R<read>/W<creation>`. No new exported symbols for other tasks.

- [ ] **Step 1: Write the failing test**

Create `tests/test_statusline_cache.py`:

```python
#!/usr/bin/env python3
"""Statusline cache segment: hit-rate % + read/write split rendering."""
import json
import os
import shutil
import subprocess

import pytest

SCRIPT = os.path.join(
    os.path.dirname(__file__), "..",
    ".nvm-isolated", ".claude-isolated", "scripts", "claude-statusline.sh",
)

pytestmark = pytest.mark.skipif(
    shutil.which("jq") is None or shutil.which("awk") is None,
    reason="statusline requires jq + awk",
)


def _run(session_json):
    env = dict(os.environ, ICLAUDE_SL_NO_CACHE="1")  # bypass the 3s render cache
    return subprocess.run(
        ["bash", SCRIPT],
        input=json.dumps(session_json),
        capture_output=True, text=True, env=env, timeout=15,
    ).stdout


def test_segment_shows_hitrate_and_split():
    # read=900, creation=50, input=50 -> hit-rate = 900/1000 = 90%
    out = _run({
        "context_window": {
            "total_input_tokens": 1000, "total_output_tokens": 100,
            "context_window_size": 200000, "used_percentage": 5,
            "current_usage": {
                "cache_read_input_tokens": 900,
                "cache_creation_input_tokens": 50,
                "input_tokens": 50,
            },
        },
        "model": {"display_name": "Opus 4.8"},
        "cost": {"total_cost_usd": 0.1},
        "session_id": "test", "transcript_path": "",
        "workspace": {"project_dir": "/tmp"},
    })
    assert "📦 90% · R900/W50" in out


def test_segment_hidden_when_no_cache():
    out = _run({
        "context_window": {
            "total_input_tokens": 0, "total_output_tokens": 0,
            "context_window_size": 200000, "used_percentage": 0,
            "current_usage": {
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
                "input_tokens": 0,
            },
        },
        "model": {"display_name": "Opus 4.8"},
        "cost": {"total_cost_usd": 0},
        "session_id": "test", "transcript_path": "",
        "workspace": {"project_dir": "/tmp"},
    })
    assert "📦" not in out
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 -m pytest tests/test_statusline_cache.py -v`
Expected: `test_segment_shows_hitrate_and_split` FAILS — current output shows the summed `📦 950`, not `📦 90% · R900/W50`. (`test_segment_hidden_when_no_cache` already passes — the zero guard exists.)

- [ ] **Step 3: Add the `input_tokens` field to the one-shot jq parse**

In `claude-statusline.sh`, change the last jq line (currently `  (.workspace.project_dir // .cwd // "")`) to add a trailing comma and a new field:

```bash
  (.workspace.project_dir // .cwd // ""),
  (.context_window.current_usage.input_tokens // 0 | tostring)
' 2>/dev/null)
```

Then, in the `read -r` block immediately below, add one line after `    read -r PROJECT_DIR`:

```bash
    read -r PROJECT_DIR
    read -r _SD_CACHE_INPUT
```

- [ ] **Step 4: Add a `humanize` helper**

Insert directly after the closing `}` of `detect_real_context_window()` (before `# Parse session data`):

```bash
# Humanize a token count: K for thousands, M for millions (matches the cache split).
humanize() {
    local n="${1:-0}"
    [[ "$n" =~ ^[0-9]+$ ]] || n=0
    if [[ $n -ge 1000000 ]]; then
        awk "BEGIN {printf \"%.1fM\", ($n / 1000000.0)}"
    elif [[ $n -ge 1000 ]]; then
        awk "BEGIN {printf \"%.0fK\", ($n / 1000.0)}"
    else
        printf '%s' "$n"
    fi
}
```

- [ ] **Step 5: Replace the cache-display block**

Replace the existing block (lines ~200-214, from `# Format cache display (show only if >0)` through the `tr -d` cleanup) with:

```bash
# Format cache display: per-turn hit-rate % + read/write split (replaces summed count).
CACHE_DISPLAY=""
if [[ $TOTAL_CACHE -gt 0 ]]; then
    # Uncached input of the current request (per-turn); 0 for non-Anthropic providers.
    CACHE_INPUT="${_SD_CACHE_INPUT:-0}"
    [[ "$CACHE_INPUT" =~ ^[0-9]+$ ]] || CACHE_INPUT=0
    # hit-rate = cache_read / (cache_read + cache_creation + uncached_input)
    HR_DENOM=$((CACHE_READ + CACHE_CREATION + CACHE_INPUT))
    if [[ $HR_DENOM -gt 0 ]]; then
        HIT_RATE=$(awk "BEGIN {printf \"%.0f\", ($CACHE_READ * 100.0 / $HR_DENOM)}")
        CACHE_DISPLAY=" | 📦 ${HIT_RATE}% · R$(humanize "$CACHE_READ")/W$(humanize "$CACHE_CREATION")"
    else
        CACHE_DISPLAY=" | 📦 n/a"
    fi
    # Strip any stray newlines so the segment stays on one line.
    CACHE_DISPLAY=$(printf '%s' "$CACHE_DISPLAY" | tr -d '\n\r')
fi
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `python3 -m pytest tests/test_statusline_cache.py -v`
Expected: both tests PASS.

- [ ] **Step 7: Syntax-check the script**

Run: `bash -n .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
Expected: no output, exit 0.

- [ ] **Step 8: Commit**

```bash
git add .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh tests/test_statusline_cache.py
git commit -m "feat(statusline): show cache hit-rate % and read/write split

Replace the summed cache token count with per-turn hit-rate and an
R/W split, computed from current_usage (read/creation/input_tokens).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: SessionEnd cumulative cache report hook

**Files:**
- Create: `.nvm-isolated/.claude-isolated/hooks/cache-report.py`
- Modify: `.nvm-isolated/.claude-isolated/settings.json` (add `SessionEnd` under `hooks`)
- Test: `tests/test_cache_report.py`

**Interfaces:**
- Consumes: hook stdin JSON → `transcript_path`, `session_id`; the transcript `.jsonl` (each `type:"assistant"` line → `message.usage.{cache_read_input_tokens, cache_creation_input_tokens, input_tokens, output_tokens}`).
- Produces (functions the test imports):
  - `aggregate(transcript_path: str) -> dict` → keys `{"read","creation","input","output","turns"}` (all ints; all-zero on missing/unreadable file).
  - `format_report(session_id: str, agg: dict) -> str` → human-readable report ending in `\n`.
  - `main() -> int` → reads stdin, writes the report file under `<config>/logs/`, best-effort echo to `/dev/tty`, always returns 0.

- [ ] **Step 1: Write the failing test**

Create `tests/test_cache_report.py`:

```python
#!/usr/bin/env python3
"""SessionEnd cache report: aggregation, formatting, and fail-soft behavior."""
import importlib.util
import json
import os

HOOK = os.path.join(
    os.path.dirname(__file__), "..",
    ".nvm-isolated", ".claude-isolated", "hooks", "cache-report.py",
)


def _load():
    spec = importlib.util.spec_from_file_location("cache_report", HOOK)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _write_jsonl(path, rows):
    with open(path, "w", encoding="utf-8") as fh:
        for r in rows:
            fh.write(json.dumps(r) + "\n")


def _assistant(read, creation, inp, out):
    return {"type": "assistant", "message": {"usage": {
        "cache_read_input_tokens": read,
        "cache_creation_input_tokens": creation,
        "input_tokens": inp,
        "output_tokens": out,
    }}}


def test_aggregate_sums_assistant_turns(tmp_path):
    mod = _load()
    p = tmp_path / "t.jsonl"
    _write_jsonl(p, [
        {"type": "user", "message": {"content": "hi"}},      # ignored
        _assistant(500, 100, 25, 200),
        _assistant(500, 100, 25, 250),
    ])
    agg = mod.aggregate(str(p))
    assert agg == {"read": 1000, "creation": 200, "input": 50,
                   "output": 450, "turns": 2}


def test_format_report_has_hitrate_and_split(tmp_path):
    mod = _load()
    # read=1000, creation=200, input=50 -> 1000/1250 = 80%
    agg = {"read": 1000, "creation": 200, "input": 50, "output": 450, "turns": 2}
    report = mod.format_report("sess-1", agg)
    assert "80%" in report
    assert "cache-read   1000" in report
    assert "cache-write  200" in report
    assert "turns        2" in report


def test_aggregate_missing_transcript_is_empty():
    mod = _load()
    agg = mod.aggregate("/no/such/file.jsonl")
    assert agg["turns"] == 0
    assert agg["read"] == 0


def test_main_missing_transcript_exits_zero(monkeypatch, capsys):
    mod = _load()
    monkeypatch.setattr("sys.stdin",
                        __import__("io").StringIO(json.dumps(
                            {"transcript_path": "/no/such/file.jsonl",
                             "session_id": "x"})))
    assert mod.main() == 0
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 -m pytest tests/test_cache_report.py -v`
Expected: FAIL at module load — `cache-report.py` does not exist yet (`spec_from_file_location` returns `None` / `FileNotFoundError`).

- [ ] **Step 3: Create the hook**

Create `.nvm-isolated/.claude-isolated/hooks/cache-report.py`:

```python
#!/usr/bin/env python3
"""SessionEnd hook: cumulative Anthropic prompt-cache report for the session.

Reads the session transcript (.jsonl), sums per-turn cache usage across all
assistant messages, and writes a human-readable cache report. Fail-soft: any
error exits 0 so the Claude Code UI is never affected.
"""
import json
import os
import sys


def aggregate(transcript_path):
    """Sum cache usage across assistant turns in a transcript .jsonl.

    Returns {"read","creation","input","output","turns"} (ints). Non-JSON lines
    and non-assistant messages are skipped; a missing/unreadable file yields
    all-zero totals.
    """
    agg = {"read": 0, "creation": 0, "input": 0, "output": 0, "turns": 0}
    if not transcript_path or not os.path.isfile(transcript_path):
        return agg
    try:
        with open(transcript_path, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except (ValueError, TypeError):
                    continue
                if obj.get("type") != "assistant":
                    continue
                usage = (obj.get("message") or {}).get("usage") or {}
                agg["read"] += int(usage.get("cache_read_input_tokens", 0) or 0)
                agg["creation"] += int(usage.get("cache_creation_input_tokens", 0) or 0)
                agg["input"] += int(usage.get("input_tokens", 0) or 0)
                agg["output"] += int(usage.get("output_tokens", 0) or 0)
                agg["turns"] += 1
    except OSError:
        return agg
    return agg


def format_report(session_id, agg):
    """Build the human-readable report string (raw token counts, full precision)."""
    denom = agg["read"] + agg["creation"] + agg["input"]
    hit = "n/a" if denom == 0 else "%.0f%%" % (agg["read"] * 100.0 / denom)
    return (
        "iclaude cache report — session %s\n"
        "  cache-read   %d tok (%s)\n"
        "  cache-write  %d tok\n"
        "  uncached in  %d tok\n"
        "  output       %d tok\n"
        "  turns        %d\n"
    ) % (session_id, agg["read"], hit, agg["creation"],
         agg["input"], agg["output"], agg["turns"])


def _config_dir():
    env = os.environ.get("CLAUDE_CONFIG_DIR")
    if env:
        return env
    # Fallback: hooks/ -> .claude-isolated/
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
    except (ValueError, TypeError):
        return 0
    agg = aggregate(data.get("transcript_path", ""))
    if agg["turns"] == 0:
        return 0  # nothing to report
    report = format_report(data.get("session_id", "unknown"), agg)
    # Primary sink: log file under the config dir.
    try:
        logs_dir = os.path.join(_config_dir(), "logs")
        os.makedirs(logs_dir, exist_ok=True)
        fname = "cache-report-%s.txt" % data.get("session_id", "unknown")
        with open(os.path.join(logs_dir, fname), "w", encoding="utf-8") as fh:
            fh.write(report)
    except OSError:
        pass
    # Best-effort: echo to the controlling terminal as the session closes.
    try:
        with open("/dev/tty", "w") as tty:
            tty.write("\n" + report)
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `python3 -m pytest tests/test_cache_report.py -v`
Expected: all 4 tests PASS.

- [ ] **Step 5: Register the SessionEnd hook**

In `.nvm-isolated/.claude-isolated/settings.json`, add a `SessionEnd` key to the `hooks` object (mirror the matcher-less `Stop` entry). Insert it after the `Stop` entry:

```json
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/cache-report.py\""
          }
        ]
      }
    ]
```

- [ ] **Step 6: Verify settings.json is valid and the hook runs end-to-end**

Run:
```bash
python3 -c "import json; json.load(open('.nvm-isolated/.claude-isolated/settings.json')); print('settings OK')"
printf '%s\n' '{"type":"assistant","message":{"usage":{"cache_read_input_tokens":1000,"cache_creation_input_tokens":200,"input_tokens":50,"output_tokens":450}}}' > /tmp/cache-test.jsonl
echo '{"transcript_path":"/tmp/cache-test.jsonl","session_id":"smoke"}' \
  | CLAUDE_CONFIG_DIR=/tmp/cfgtest python3 .nvm-isolated/.claude-isolated/hooks/cache-report.py; echo "exit: $?"
cat /tmp/cfgtest/logs/cache-report-smoke.txt
```
Expected: `settings OK`; hook `exit: 0`; report file contains `cache-read   1000 tok (80%)` and `turns        1`.

- [ ] **Step 7: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/cache-report.py \
        .nvm-isolated/.claude-isolated/settings.json \
        tests/test_cache_report.py
git commit -m "feat(hooks): add SessionEnd cumulative cache report

New cache-report.py sums per-turn cache usage from the transcript and
writes a hit-rate + read/write summary to <config>/logs (best-effort
echo to /dev/tty). Registered as a SessionEnd hook. Fail-soft (exit 0).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Documentation refresh (iwiki)

**Files:**
- Modify: `docs/wiki/statusline.md`, `docs/functions/STATUSLINE.md` (regenerated by iwiki)

**Interfaces:** none (docs only).

- [ ] **Step 1: Ingest the changed sources into the wiki**

Invoke the `iwiki:iwiki-ingest` skill on the statusline script and the new hook so the affected `docs/wiki/` pages regenerate. Sources:
- `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- `.nvm-isolated/.claude-isolated/hooks/cache-report.py`

Review the diff it shows; accept if it accurately reflects the hit-rate segment and the SessionEnd report.

- [ ] **Step 2: Lint the wiki**

Invoke `/iwiki-lint` (or the `iwiki:iwiki-lint` skill).
Expected: no broken `[[refs]]`, no new orphan/stale pages introduced by this change. (Pre-existing mtime "stale" noise from a fresh worktree is acceptable — broken/orphans must be clean.)

- [ ] **Step 3: Commit**

```bash
git add docs/wiki docs/functions/STATUSLINE.md
git commit -m "docs(statusline): document cache hit-rate segment + SessionEnd report

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage**

| Spec item | Task |
|-----------|------|
| Statusline per-turn hit-rate % + R/W split (replace summed `📦`) | Task 1 |
| Add `current_usage.input_tokens` to jq parse | Task 1, Step 3 |
| SessionEnd cumulative report (read/.jsonl, hit-rate + split) | Task 2 |
| Report sinks: log file + best-effort `/dev/tty` | Task 2, Step 3 |
| Register SessionEnd hook in settings.json | Task 2, Step 5 |
| Edge: missing/empty transcript → exit 0 silently | Task 2 (`aggregate`/`main`), test Step 1 |
| Edge: denom 0 → `n/a` | Task 1 (display block) + Task 2 (`format_report`) |
| Fail-soft everywhere (exit 0) | Both tasks; constraint stated |
| Tests (hook + statusline) | Tasks 1 & 2 |
| Docs via iwiki | Task 3 |
| Non-goals (no $, no /cache-report, no warning hook, no TTL change) | Honored — none implemented |

No gaps.

**2. Placeholder scan:** No TBD/TODO; every code/test step contains complete code and exact commands with expected output.

**3. Type consistency:** `aggregate` returns `{"read","creation","input","output","turns"}`; `format_report(session_id, agg)` and the tests read exactly those keys. Statusline uses `_SD_CACHE_INPUT` (set by the new jq+read pair) and `humanize` (defined in Task 1, Step 4) — both defined before use. Success-criteria numbers verified: Task 1 → 900/1000 = 90%, `R900/W50`; Task 2 → 1000/1250 = 80%, `cache-read 1000`, `turns 2`.
