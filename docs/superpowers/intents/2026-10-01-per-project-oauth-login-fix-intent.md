---
review:
  intent_hash: 6761f029a3defe70
  last_run: 2026-10-01
  phases:
    structure: { status: passed }
    completeness: { status: passed }
    clarity: { status: passed }
    consistency: { status: passed }
    alignment: { status: passed }
  findings: []
workflow:
  route: chain
  continuation: full
---

# Intent: per-project-oauth-login-fix

**Date:** 2026-10-01
**Status:** approved

## Objective

Remove repeated account authorization when the launcher opens a new project, and
prevent a successful login from being discarded or shadowed on a later launch.
The user confirmed one account login shared across projects, with separate project
history and settings. This fixes launcher authentication persistence; it does not
restore access to the account suspended by Anthropic.

This proposal supersedes the credential-specific part of the earlier shared-asset
contract: an independent `.credentials.json` must not be destroyed merely to restore
a store symlink. Other managed assets retain their existing behavior. The current
architecture wiki describes the existing implementation; update its credential
contract and any affected GWT scenario before claiming the fix is complete.

## Desired Outcomes

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

## Health Metrics

- Zero lost credential artifacts and zero unintended writes to real user credentials
  during development and verification.
- Existing project settings, history, and transcripts remain byte-identical in fixtures
  except for the specific authentication metadata changes required by this fix.
- Focused first-launch, relaunch, credential-preservation, and concurrent-launch
  scenarios pass; existing home migration, shared assets, environment mapping,
  settings synchronization, and launch wiring regressions pass.
- The final unchanged code state passes the repository's applicable full test suite
  once. Explicit shared mode continues to work without a new per-project login.

## Strategic Context

- Interacts with: `iclaude.sh`, project-home population in `lib/config/isolated.sh`,
  OAuth helpers in `lib/oauth/token.sh`, environment mapping in `lib/config/env-map.sh`,
  and Claude Code's account configuration and credential persistence.
- Existing diagnosis: most homes link credentials to the shared store; some have
  independent login files. The configured environment token can take precedence over
  a stored login. Shared account metadata lacks completed first-run state.
- Priority trade-off: reliability and preservation of authorization and user data
  take precedence over startup speed or implementation cost.

## Constraints

### Steering (behavioral guidance)

- Limit changes to the launcher authentication and home-state boundaries needed for
  the confirmed outcomes; follow existing Bash conventions.
- Use synthetic credentials and isolated temporary fixtures for verification.
- Explain the supported common-login workflow and any remaining manual checkpoint.

### Hard (architectural enforcement)

- Keep project settings, history, and transcripts separate while sharing account login.
- Keep auth policy separate from config-directory selection. Existing `--shared-config`
  does not become a requirement for common login and cannot override auth policy.
- Do not change, delete, refresh, or submit real user credentials during this task.
- Do not bypass Anthropic's account restriction or fabricate a successful authorization
  or onboarding state in place of an actual supported authentication workflow.
- Do not log token values or include them in repository artifacts, reports, or wiki.
- Preserve credential artifacts when fixing launcher persistence; credential conflicts
  must not be resolved through silent destructive replacement.

## Autonomy Zones

- Full autonomy (reversible, low risk): code, tests, and documentation changes on
  `dev-per-project-oauth-login-fix`, plus task-ledger and relevant wiki updates.
- Guarded (test-backed): authentication persistence and shared-state synchronization
  changes, including parallel execution; verify with synthetic fixtures before claiming
  the outcome.
- Proposal-first (needs approval): changing the confirmed single-account scope,
  publication, commits or pull requests, or a change requiring real credential migration.
- No autonomy (human only): real account login or token refresh, credential deletion,
  account appeal submission, and merging the change.

## Stop Rules

- Halt if: completion requires real account access, changing real credentials, bypassing
  a revoked token, or silently choosing between conflicting account identities.
- Escalate if: supported Claude Code behavior cannot retain common authorization
  without violating credential preservation or project-state separation.
- Done when: synthetic first-launch and relaunch scenarios retain one common login;
  existing credential artifacts, settings, and histories are preserved; concurrent
  launches retain valid state; invalid authorization never appears authenticated;
  focused and relevant regressions plus the final full suite pass; documentation
  describes the verified workflow. Report that live account verification remains
  unavailable while the account is suspended.
