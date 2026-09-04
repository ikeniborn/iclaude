#!/usr/bin/env node
// caveman-cleanup — Claude Code SessionEnd hook.
//
// Deletes THIS session's per-session statusline-suffix file (it is useless once
// the session ends) and prunes any suffix files older than MAX_AGE_MS as a
// safety net for sessions that died without a SessionEnd (crash / kill -9).
//
// Best-effort and silent: never throws, emits nothing — SessionEnd must not fail
// over caveman cleanup.

const fs = require('fs');
const os = require('os');
const path = require('path');
const paths = require('./caveman-paths');

let input = '';
process.stdin.on('data', (chunk) => { input += chunk; });
process.stdin.on('end', () => {
  try {
    const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');

    let data = {};
    try { data = JSON.parse(input); } catch {}

    // Session id is the transcript basename, matching caveman-stats.js.
    if (data.transcript_path) {
      const sessionId = path.basename(data.transcript_path, '.jsonl');
      try { fs.unlinkSync(paths.sessionSuffix(claudeDir, sessionId)); } catch {}
    }

    paths.pruneSessionSuffixes(claudeDir);
  } catch {
    // Never break the SessionEnd hook chain over cleanup.
  }
});
