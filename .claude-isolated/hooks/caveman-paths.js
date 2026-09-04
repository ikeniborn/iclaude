#!/usr/bin/env node
// caveman-paths — single source of truth for on-disk caveman artifact paths.
//
// All caveman artifacts live under $CLAUDE_CONFIG_DIR/.caveman/ so they don't
// clutter the config root:
//   active              — mode flag (was .caveman-active)
//   history.jsonl       — lifetime savings log (was .caveman-history.jsonl)
//   statusline-suffix   — cumulative-only fallback (was .caveman-statusline-suffix)
//   suffix-<sessionId>  — per-session badge (was .caveman-statusline-suffix-<id>)
//
// This module holds pure path builders plus two maintenance helpers
// (migrateLegacy, pruneSessionSuffixes). Every function is best-effort and must
// never throw out of a hook.

const fs = require('fs');
const path = require('path');

// Per-session suffix files older than this are pruned so .caveman/ doesn't grow
// without bound. 5 days keeps a working window while a session may still be open.
const MAX_AGE_MS = 5 * 86_400_000;
// Basename prefix for per-session suffix files (suffix-<sessionId>). The base
// fallback file is 'statusline-suffix', which does NOT start with this prefix,
// so the prune never touches it.
const SESSION_SUFFIX_PREFIX = 'suffix-';

// Pure path builder — no side effects, so readers/guards can compute a path
// without creating the directory. Writers (safeWriteFlag/appendFlag) and
// migrateLegacy create .caveman/ on demand.
function cavemanDir(claudeDir) {
  return path.join(claudeDir, '.caveman');
}
function activeFlag(claudeDir) { return path.join(cavemanDir(claudeDir), 'active'); }
function history(claudeDir)    { return path.join(cavemanDir(claudeDir), 'history.jsonl'); }
function baseSuffix(claudeDir) { return path.join(cavemanDir(claudeDir), 'statusline-suffix'); }
function sessionSuffix(claudeDir, sessionId) {
  return path.join(cavemanDir(claudeDir), SESSION_SUFFIX_PREFIX + sessionId);
}

// One-time, idempotent migration of legacy root-level artifacts into .caveman/.
// Best-effort: any failure leaves the legacy file in place (harmless — readers
// only look in .caveman/). Persistent files (history, base suffix, active) are
// moved when the destination is absent, otherwise the stale legacy copy is
// dropped. Legacy per-session suffix files are always deleted — their sessions
// are over and the current session regenerates its own on the next Stop.
function migrateLegacy(claudeDir) {
  const dir = cavemanDir(claudeDir);
  try { fs.mkdirSync(dir, { recursive: true }); } catch {}

  const moves = [
    ['.caveman-history.jsonl',     path.join(dir, 'history.jsonl')],
    ['.caveman-statusline-suffix', path.join(dir, 'statusline-suffix')],
    ['.caveman-active',            path.join(dir, 'active')],
  ];
  for (const [legacyName, dest] of moves) {
    const src = path.join(claudeDir, legacyName);
    try {
      if (!fs.existsSync(src)) continue;
      if (!fs.existsSync(dest)) fs.renameSync(src, dest);
      else fs.unlinkSync(src); // dest already present — drop the stale legacy copy
    } catch {}
  }

  try {
    for (const name of fs.readdirSync(claudeDir)) {
      if (name.startsWith('.caveman-statusline-suffix-')) {
        try { fs.unlinkSync(path.join(claudeDir, name)); } catch {}
      }
    }
  } catch {}
}

// Delete per-session suffix files older than MAX_AGE_MS. Never throws — a prune
// failure must not break stats or session cleanup.
function pruneSessionSuffixes(claudeDir) {
  const dir = cavemanDir(claudeDir);
  const now = Date.now();
  let names;
  try { names = fs.readdirSync(dir); } catch { return; }
  for (const name of names) {
    if (!name.startsWith(SESSION_SUFFIX_PREFIX)) continue;
    const p = path.join(dir, name);
    try {
      if (now - fs.statSync(p).mtimeMs > MAX_AGE_MS) fs.unlinkSync(p);
    } catch {}
  }
}

module.exports = {
  cavemanDir, activeFlag, history, baseSuffix, sessionSuffix,
  migrateLegacy, pruneSessionSuffixes, MAX_AGE_MS, SESSION_SUFFIX_PREFIX,
};
