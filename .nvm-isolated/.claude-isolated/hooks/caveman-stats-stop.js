#!/usr/bin/env node
// caveman-stats-stop — Stop hook that refreshes the caveman statusline suffix
// after every assistant turn, so the ⛏ badge shows live token-savings without
// the user having to run /caveman-stats manually.
//
// Side-effect only: it execs caveman-stats.js (which appends a snapshot to the
// lifetime history and rewrites $CLAUDE_CONFIG_DIR/.caveman-statusline-suffix),
// discarding stdout. No decision/reason is emitted — Stop continues normally.
//
// Runs only when caveman is active (.caveman-active present); otherwise exits
// immediately so non-caveman sessions pay nothing.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

let input = '';
process.stdin.on('data', (chunk) => { input += chunk; });
process.stdin.on('end', () => {
  try {
    const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
    // Cheap guard: skip entirely when caveman isn't active.
    if (!fs.existsSync(path.join(claudeDir, '.caveman-active'))) return;

    let data = {};
    try { data = JSON.parse(input); } catch {}

    const argv = [path.join(__dirname, 'caveman-stats.js')];
    // Pass the active session's transcript so we read THIS session, not whichever
    // JSONL was modified most recently (matters with concurrent sessions).
    if (data.transcript_path) argv.push('--session-file', data.transcript_path);

    execFileSync(process.execPath, argv, { stdio: 'ignore', timeout: 5000 });
  } catch {
    // Never break the Stop hook chain over a stats refresh failure.
  }
});
