---
review:
  spec_hash: 474802015b6995a6
  last_run: 2026-10-01
  phases:
    structure: { status: passed }
    coverage: { status: passed }
    clarity: { status: passed }
    consistency: { status: passed }
  findings: []
chain:
  intent: docs/superpowers/intents/2026-10-01-per-project-oauth-login-fix-intent.md
---

# Design: per-project-oauth-login-fix

**Date:** 2026-10-01
**Status:** approved

## Scope and Source

Implement the approved intent's single common account login while keeping project
settings and conversation storage separate. No real credentials, account login,
publication, commits, or merge are authorized during development.

The existing symlink contract includes `.credentials.json` among disposable managed
assets. This design replaces only that credential rule. Other shared assets and
the ordinary settings synchronization retain their current behavior.

## Alternatives and Decision

1. Keep credential symlinks and repair them at startup. Rejected: native atomic file
   replacement can detach the link, and current repair deletes a saved login.
2. Keep independent account logins in every home. Rejected: contradicts the approved
   common-login outcome and repeats new-project authorization.
3. Use common authorization with managed project snapshots and compare-and-swap
   reconciliation. Recommended: supports native per-home writes, preserves conflicting
   credentials, and gives concurrent publication an explicit safety boundary.

Make the common interactive login/setup workflow the default launcher behavior.
Only `ICLAUDE_AUTH_MODE` in `.claude_config` selects `shared` (default) or `project`.
Do not add a new CLI flag, background watcher, external token-refresh request, or
custom authentication proxy. Config-directory selection does not select auth policy.

## R1 Common Login and Source Selection

Read auth policy only from the project's launcher `.claude_config`; ignore inherited
`ICLAUDE_AUTH_MODE`/`AUTH_MODE` values as selectors. Missing setting selects `shared`;
reject any value other than `shared` or `project` with a clear configuration error.
No CLI flag overrides this policy, including `--shared-config` and `--per-project-home`.

In default `shared` auth policy, the shared store remains the canonical location for
an interactive subscription login. On missing common login or real first-run metadata,
ordinary launcher startup directs the native interactive setup to the shared store
automatically. No `--shared-config` flag is required. After native setup completes,
verify actual persisted login/account/setup state, then prepare the requested project
home. Cancellation, failure, or missing persisted setup state stops the launch.
Noninteractive launches report the common-setup instruction rather than opening a
browser or waiting for input. Native CLI `auth login` requests passed through the
launcher are also directed to the common store under the common auth lock.

After explicit common login/renewal returns, subsequent project launches see that
authorization immediately. Common credentials do not belong to the project that
initiated the login. The launcher copies real onboarding/account metadata; it does
not set completion fields in place of native setup.

With `.claude_config` setting `ICLAUDE_AUTH_MODE=project`, direct account setup and
login to the active home, disable common publication/snapshot distribution, and preserve
existing local credentials. Different project homes then have separate logins.
The auth policy does not move histories/settings or enable another account implicitly.
Before a native project-mode write, detach a known legacy common credential link by
preserving that link as a private backup and creating a local copy. Unknown link targets
remain conflicts. Project mode never writes through a link into common credentials.

When canonical credentials contain a native login with refresh-token metadata, that
login takes precedence over a configured legacy setup token for isolated launcher
sessions. Unset the exported `CLAUDE_CODE_OAUTH_TOKEN` for this launch only; never edit
the user's `.claude_config`. During explicit common login/setup, suppress the legacy
token even if the shared store still contains an access-only stub.

Without a canonical interactive login, preserve the existing environment-token mode.
Do not infer that an access-only file proves interactive setup completion. Missing
real shared onboarding state enters real common setup for interactive launches or
produces a clear one-time common-setup instruction for noninteractive launches.
The launcher never marks authentication or onboarding successful on its own.

Acceptance: fake native login/setup in the shared store is selected by subsequent
launches in two fresh project homes; an older configured setup token is absent from
the native-login child environment. Legacy token mode remains usable when explicitly
configured and no common interactive login exists. Default startup and explicit login
require no shared-config flag. Only a config-file `project` value enables per-home login;
inherited environment values and CLI config-directory flags cannot change the policy.

## R2 Project Snapshots and State Separation

The following snapshot distribution applies to `shared` auth policy only.

Remove `.credentials.json` from generic destructive shared-asset repair. Fresh homes
receive a private mode-0600 snapshot of canonical subscription OAuth credentials,
not a credential symlink. Reconcile only the `claudeAiOauth` payload; preserve unrelated
home credential keys, including MCP OAuth state, and do not distribute them from the store.
Copy only actual account/onboarding fields from shared `.claude.json`; do not copy
another project's settings, transcript files, or project mappings during auth refresh.
Existing first-launch history migration retains its current contract.

Track the common baseline and project snapshot fingerprints in private per-home auth
state. Fingerprints are internal reconciliation data, never terminal token identifiers.
Include the account identity and copied account/onboarding projection in reconciliation.
Do not compare expiry dates as a rule for selecting between distinct account logins.

Existing independent credential files without a managed baseline are not automatically
adopted or replaced. Equal credentials may acquire a baseline without altering bytes;
different credentials produce a conflict with a manual migration checkpoint. For legacy
links to the canonical store, preserve the link as a uniquely named private backup
before replacing the home entry with a managed snapshot. Unexpected link targets fail
closed. No credential artifact is discarded.

When refreshing a managed snapshot, preserve the superseded file in a private backup
before replacement. Account metadata changes must leave unrelated `.claude.json`
keys byte-equivalent as JSON values. Settings/history/transcript files remain untouched
by authentication reconciliation.

Acceptance: fresh and managed homes share actual login state; legacy and conflicting
fixtures retain every original credential artifact. Project settings, history, and
unrelated account-config keys survive first and repeated launches.

## R3 Reconciliation and Concurrent Writes

Authentication writes require a bounded exclusive store lock and an exclusive home
auth lock. Unlike the convenience `iclaude_with_lock`, lock failure never permits an
unlocked auth write. Use lock order store then home consistently; timeout returns a
clear error and preserves all files.

The common workflow holds the store auth lock while native login/setup writes common
state. Project sessions hold a shared home-auth lock while native Claude uses that home;
parallel sessions with an unchanged managed snapshot may share this lock. A refresh
requiring a home write waits for the exclusive home lock rather than overwriting a live
session's credentials. No store lock is held throughout ordinary model use.

Compare the current common and home states against their recorded baseline under the
write locks. Unchanged home plus changed common refreshes the snapshot. Changed home
plus unchanged common may publish same-account native login/refresh state. If both
changed to the same resulting state, record that state as the baseline. Divergent
changes, deletion/logout, a different account identity, or an unknown baseline produce
a conflict and preserve both sides. Deletion must not resurrect an old login.

Native project-session credential changes are published after the native process exits
and its shared home-auth lock is released,
using the same compare-and-swap check. Ordinary isolated subscription launches therefore
retain a shell supervisor instead of using `exec` for native Claude. Propagate the native
exit status; a reconciliation conflict after native success returns a separate failure
and an actionable message. Existing proxy cleanup remains owned by existing traps.

Stop concurrent readers from observing half-published auth state: stage replacements
privately, retain old snapshots, publish under the common lock, and read the coherent
credentials/metadata pair under that same lock. On write failure, restore the old
pair before releasing the lock; if restoration fails, leave a recovery marker and
refuse subsequent auth preparation until manual recovery. Native shared-mode writes
must also hold this lock. Unsupported direct writes outside the launcher are conflicts,
not input the launcher silently repairs.

Acceptance: concurrent fixture launches with unchanged authorization both proceed;
only one divergent publisher succeeds from a baseline; the loser retains its files.
Missing flock, timeout, staged-write failure, and deleted credentials never cause a
partial common login to be used. Signal forwarding and child exit status remain correct.

## R4 Authentication Failures and Renewal

Let native Claude Code refresh native subscription credentials. Do not call
`setup-token` as an automatic replacement for a stored interactive login: that command
prints a token and does not persist login credentials. Preserve the explicit existing
setup-token command for users who intentionally use that workflow.

The launcher makes no network call to validate fixture or real tokens. A present token
is not declared valid. Native missing/expired/unrefreshable/revoked errors remain visible
and do not trigger an automatic login loop or fallback to another credential source.

Acceptance: a fake native process returning revoked-token status remains a failure;
no setup-token invocation occurs automatically and no token value appears in output.

## R5 Integration and Documentation

Keep source selection in OAuth helpers, home preparation in home population, and session
lifecycle handling at the native launch boundary. A focused OAuth persistence module may
hold the locking, snapshot, and publication functions rather than expanding generic
shared-asset repair with credential-specific branches.

Non-subscription router/API-provider flows retain their existing behavior. Explicit
shared mode reads/writes the canonical store with the auth lock. System-mode credentials
are outside the isolated-store migration. MicroVM/router modes must not silently use a
different subscription source; if they cannot participate in the same persistence
contract, report the unsupported combination before credential mutation and document it.

Update README authentication guidance, the per-project-home architecture page, and the
credential-specific shared-asset specification with executable GWT bindings. Preserve
unchanged scenario IDs; the changed credential contract follows the approved intent and
requires its explicit replacement scenario/contract to be reviewed before mutation.

Acceptance: focused persistence, environment selection, launch/signal, shared mode, and
existing home/asset/settings regressions pass. Documentation matches the selected source
and lifecycle. Run the applicable full suite once on final code, using an isolated fixture
environment; a test that needs real credentials or external infrastructure is reported
as blocked, never called a pass.

## Risks and Human Checkpoints

- Existing different home logins require human migration approval; this task changes no
  real credential artifacts to make them match.
- Default shared interactive setup requires human login after account access is restored.
  Synthetic tests prove persistence, not restored Anthropic access or live acceptance
  of a revoked token.
- Snapshot publication and signal forwarding are shared-state/process boundaries;
  require focused failure and concurrency tests before result reconciliation.
- Native `/login` typed inside an already running project becomes common only after
  that project process exits and successful publication; launcher startup cannot
  intercept slash commands inside the native process. Launcher-managed login/setup
  uses the common store by default and makes its result available on return.
- Specification/plan approval is required before implementation. Publication, commits,
  live credential migration, and merge remain separate user checkpoints.

## Source Evidence

- Repository: `link_shared_assets` destroys materialized credential entries;
  `materialize_oauth_credentials` uses a temporary file and rename; home migration
  copies the shared `.claude.json` once; ordinary native launch uses `exec`.
- [Claude Code authentication](https://code.claude.com/docs/en/authentication):
  configuration-directory credential storage, environment-token priority across new
  sessions, native `/login`, and setup-token printing without credential persistence.
- Existing iwiki `architecture/per-project-homes` and
  `specification/shared-asset-symlink-layer` describe the current contract. The new
  credential exception is a reviewed proposal, not a claim that existing code changed.

## Acceptance (from intent)

The common-login outcomes apply to the default `shared` auth policy. An explicit
config-file `project` policy opts out of common account sharing only; data-preservation
and error-reporting outcomes still apply.

- With a valid established common login, opening a fresh project home does not require
  another account login. The project receives its own settings and history.
- Common login is the launcher's default, without requiring `--shared-config` for
  account setup or renewal. Only `ICLAUDE_AUTH_MODE` in `.claude_config` can change
  this policy: absent or `shared` selects common login; `project` selects local login.
  CLI flags and inherited environment variables do not change the auth policy.
- After an explicit login or renewal through the supported launcher workflow, a
  subsequent launch in the same or another project uses that common authorization,
  rather than reverting to an older configured token.
- Existing credential files are not silently deleted or overwritten while reconciling
  project homes. Conflicting authorization state is surfaced rather than guessed.
- Concurrent project launches retain the common authorization and do not corrupt
  credentials, settings, or conversation history.
- Missing, expired and unrefreshable, or revoked authorization requests a real login
  or reports the authentication failure; no success state is fabricated.
- Done when: synthetic first-launch and relaunch scenarios retain one common login;
  existing credential artifacts, settings, and histories are preserved; concurrent
  launches retain valid state; invalid authorization never appears authenticated;
  focused and relevant regressions plus the final full suite pass; documentation
  describes the verified workflow. Report that live account verification remains
  unavailable while the account is suspended.
