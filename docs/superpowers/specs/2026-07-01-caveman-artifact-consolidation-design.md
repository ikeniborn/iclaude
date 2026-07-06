# Caveman Artifact Consolidation & Cleanup — Design

**Date:** 2026-07-01
**Status:** Approved (design)
**Topic:** caveman-artifact-consolidation

## Problem

The caveman feature scatters its runtime artifacts directly in the isolated
config root (`$CLAUDE_CONFIG_DIR`, i.e. `.nvm-isolated/.claude-isolated/`):

- `.caveman-active` — mode flag (SessionStart)
- `.caveman-history.jsonl` — lifetime cumulative savings log
- `.caveman-statusline-suffix` — base/global statusline fallback
- `.caveman-statusline-suffix-<sessionId>` — one file **per session**

The per-session suffix files accumulate (18 present at design time) and are only
removed by an age-based prune (`pruneOldSessionSuffixes()`,
`hooks/caveman-stats.js:189-202`) that:

1. keeps files for **7 days**, not the desired 5;
2. runs only on the **Stop** hook (after each assistant turn), so a session that
   ends leaves its suffix file behind until the age threshold expires;
3. leaves everything in the config **root**, cluttering `ls`.

There is no SessionEnd cleanup for caveman artifacts (the existing SessionEnd
hook runs `cache-report.py` only).

## Goals

1. Consolidate **all** caveman artifacts into a single hidden directory
   `$CLAUDE_CONFIG_DIR/.caveman/` so the config root stays clean.
2. Delete a session's per-session suffix file **at session end**.
3. Keep an age-based prune as a safety net for sessions that die without a
   SessionEnd hook (crash / `kill -9`), lowered from 7 → **5 days**.
4. Preserve lifetime cumulative savings (`history.jsonl`, base suffix) across the
   migration — no reset of the Σ counter.

## Non-Goals

- No change to how savings are computed or displayed.
- No change to the statusline layout beyond the artifact paths it reads.
- No removal of pre-existing unrelated artifacts.

## New Layout

```
.claude-isolated/
  .caveman/
    active                 # was .caveman-active
    history.jsonl          # was .caveman-history.jsonl  (lifetime Σ)
    statusline-suffix      # was .caveman-statusline-suffix  (base fallback)
    suffix-<sessionId>     # was .caveman-statusline-suffix-<uuid>  (per-session)
```

The directory is hidden (`.caveman/`) to match the surrounding dotfile
convention; files inside drop the `.caveman-` prefix.

## Components

### New: `hooks/caveman-paths.js`

Single source of truth for artifact paths on the JS side. Exports:

- `cavemanDir(claudeDir)` — returns `<claudeDir>/.caveman`, creating it
  (`fs.mkdirSync(..., { recursive: true })`) on first call. Best-effort.
- `activeFlag(claudeDir)` → `<dir>/active`
- `history(claudeDir)` → `<dir>/history.jsonl`
- `baseSuffix(claudeDir)` → `<dir>/statusline-suffix`
- `sessionSuffix(claudeDir, sessionId)` → `<dir>/suffix-<sessionId>`
- `SESSION_SUFFIX_PREFIX` = `suffix-` (used by prune matching)
- `MAX_AGE_MS` = `5 * 86_400_000` (prune retention)
- `migrateLegacy(claudeDir)` — one-time, idempotent migration (see below).

All functions are best-effort and never throw (wrap FS calls in try/catch),
consistent with the existing hook code.

### New: `hooks/caveman-cleanup.js` (SessionEnd hook)

- Resolves `sessionId` the same way `caveman-stats.js` does (basename of the
  transcript file passed on stdin / hook input).
- Deletes `sessionSuffix(claudeDir, sessionId)` if present.
- Calls the shared prune (5-day age sweep over `.caveman/suffix-*`).
- No-op and silent if caveman is not active or paths are missing.

### Modified: JS hooks

Replace inline artifact-path literals with `require('./caveman-paths')` calls:

- `caveman-activate.js:15` — `activeFlag`; also call `cavemanDir()` +
  `migrateLegacy()` at SessionStart.
- `caveman-mode-tracker.js:16` — `activeFlag`.
- `caveman-config.js:163` — `activeFlag`; atomic temp+rename stays, temp file now
  created **inside** `.caveman/` (same dir as target, required for atomic rename).
- `caveman-stats-stop.js:24` — `activeFlag`.
- `caveman-stats.js` — `history` (301), `activeFlag` (323),
  `sessionSuffix` (359), `baseSuffix` (361); prune (189-202) uses
  `SESSION_SUFFIX_PREFIX` + `MAX_AGE_MS` from the shared module and scans
  `.caveman/` instead of the config root.

### Modified: `scripts/claude-statusline.sh`

Bash cannot import the JS module, so it holds the path once:

```bash
CAVEMAN_DIR="$CLAUDE_CONFIG_DIR/.caveman"
```

Update the three references (currently lines 333, 336, 340):

- active flag: `$CAVEMAN_DIR/active`
- per-session: `$CAVEMAN_DIR/suffix-${SESSION_ID}`
- base fallback: `$CAVEMAN_DIR/statusline-suffix`

### Modified: `settings.json`

Add the cleanup hook to the existing `SessionEnd` array (alongside
`cache-report.py`):

```json
{ "type": "command", "command": "node \"$CLAUDE_CONFIG_DIR/hooks/caveman-cleanup.js\"" }
```

## Migration (`migrateLegacy`)

Runs at SessionStart, idempotent and best-effort:

1. `mkdir -p .caveman/`.
2. If legacy `.caveman-history.jsonl` exists **and** new `.caveman/history.jsonl`
   does not → move it (preserves lifetime Σ). If both exist, leave the new one.
3. If legacy `.caveman-statusline-suffix` exists and new base does not → move it.
4. Delete every legacy `.caveman-statusline-suffix-*` in the root (stale
   per-session files; the current session's will be regenerated on the next Stop).
5. Delete legacy `.caveman-active` in the root after writing the new one.

Idempotent: after the first successful run, all legacy paths are gone, so later
runs are no-ops.

## Data Flow

- **SessionStart** → `caveman-activate.js`: `cavemanDir()` + `migrateLegacy()`,
  write `active`.
- **Stop** → `caveman-stats.js`: append `history.jsonl`, write `suffix-<id>` +
  base `statusline-suffix`, `prune(5d)`.
- **Statusline render** → `claude-statusline.sh`: read `active`; prefer
  `suffix-<SESSION_ID>`, else base `statusline-suffix`.
- **SessionEnd** → `caveman-cleanup.js`: delete `suffix-<id>`, `prune(5d)`.

## Error Handling

- Every FS op is wrapped best-effort (existing convention) — a missing dir, race,
  or permission error degrades silently, never breaking a hook.
- Atomic write of `active` (temp + rename) is preserved; temp file lives in
  `.caveman/` so rename stays on one filesystem.
- Migration never overwrites an existing new-layout `history.jsonl`.

## Testing

Extend `tests/test_caveman_session_savings.sh`:

1. Artifacts are created under `.caveman/`; config root has no `.caveman-*` files.
2. SessionEnd hook removes the current session's `suffix-<id>`.
3. Prune removes a `suffix-*` file with mtime > 5 days, keeps one < 5 days.
4. Migration: legacy `history.jsonl` is moved (Σ preserved), legacy
   `suffix-*` files are deleted, second run is a no-op.

## Backward Compatibility

A session already running under the old layout migrates on the next SessionStart;
its statusline suffix regenerates on the next Stop. No manual step required.

## Affected Files

| File | Change |
|------|--------|
| `hooks/caveman-paths.js` | **new** — shared paths, prune constants, migration |
| `hooks/caveman-cleanup.js` | **new** — SessionEnd delete + prune |
| `hooks/caveman-activate.js` | use paths module; call migration |
| `hooks/caveman-mode-tracker.js` | use paths module |
| `hooks/caveman-config.js` | use paths module (atomic temp inside `.caveman/`) |
| `hooks/caveman-stats-stop.js` | use paths module |
| `hooks/caveman-stats.js` | use paths module; prune scans `.caveman/`, 7→5 days |
| `scripts/claude-statusline.sh` | `CAVEMAN_DIR` + 3 path updates |
| `settings.json` | add `caveman-cleanup.js` to SessionEnd |
| `tests/test_caveman_session_savings.sh` | 4 new assertions |
