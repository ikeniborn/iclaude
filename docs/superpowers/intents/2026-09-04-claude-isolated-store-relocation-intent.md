---
topic: claude-isolated-store-relocation
review:
  intent_hash: fc10a327b3600f74
  last_run: 2026-09-04
  phases:
    structure:
      status: passed
    completeness:
      status: passed
    clarity:
      status: passed
    consistency:
      status: passed
    alignment:
      status: passed
  findings:
    - id: F-001
      phase: alignment
      severity: WARNING
      section: Constraints
      section_hash: 5fdb9e9f4c6e466c
      fragment: "The store lock and `LOCKFILE_HASH_FILE` move with the store; they are store state, not nvm state."
      text: >-
        The wiki page iclaude/architecture/per-project-homes documents the store lock
        as `$ISOLATED_NVM_DIR/.iclaude-store.lock` and describes `LOCKFILE_HASH_FILE`
        as store-anchored. The decision is unchanged (both stay store state), but the
        page's literal path becomes stale once the store moves.
      fix: >-
        Update the "Concurrency Locking" and "Settings Managed Region" sections of
        iclaude/architecture/per-project-homes in slice S7 so the lock path reads from
        the relocated store root.
      verdict: fixed
      verdict_at: 2026-09-04
result_check:
  verdict: OK
  intent_hash: fc10a327b3600f74
  last_run: 2026-09-04
  diff_base: origin/master
  outcomes:
    - id: DO-1
      status: PARTIAL
      note: >-
        The store path, the config-type label and the launch-time relocation are all in
        the diff (lib/core/init.sh, lib/config/status.sh, lib/config/isolated.sh,
        iclaude.sh) and unit-verified. Observing --check-config on a real installation
        is the human checkpoint the intent reserves and has not been run.
    - id: DO-2
      status: DONE
      note: >-
        87 renames out of .nvm-isolated; git ls-files on the legacy path returns 0; the
        store is tracked at the repository root. .claude-homes is runtime state and
        appears on first launch.
    - id: DO-3
      status: DONE
      note: >-
        cleanup_isolated_nvm only ever removed ISOLATED_NVM_DIR, and the store is no
        longer inside it. tests/test_store_relocation.sh now performs that removal and
        asserts the store, the login and the settings survive.
    - id: DO-4
      status: PARTIAL
      note: >-
        The two-pass image build is in lib/sandbox/install.sh and
        tests/test_microvm_image_layout.sh proves the guest layout, including that
        microvm.sh still reads /mnt/nvm/.claude-isolated. Booting a real VM needs
        firecracker and was not run.
    - id: DO-5
      status: DONE
      note: >-
        .gitignore re-anchored with its shape unchanged; tests/test_store_gitignore.sh
        passes 36 assertions over git check-ignore; the tree was clean after the move.
  excess: none
  findings:
    - id: R-001
      severity: WARNING
      text: >-
        The scenario's verifies binding tests/test_store_relocation.sh resolves
        unresolved: the published code-graph snapshot predates the file, because the
        local graph server holds a master checkout. It resolves once master carries the
        change and the graph is rebuilt.
      verdict: open
    - id: R-002
      severity: INFO
      text: >-
        DO-1 and DO-4 stay PARTIAL until the live relocation and a microVM boot are run
        on the real installation. Both are human checkpoints under the intent's autonomy
        zones, not gaps in the change.
      verdict: open
---
# Intent: claude-isolated-store-relocation

**Date:** 2026-09-04
**Status:** approved

## Objective

The shared Claude store lives at `.nvm-isolated/.claude-isolated` — inside the vendored
nvm tree. That parent is wrong: nvm is a third-party checkout that iclaude updates,
rebuilds, and (in `lib/nvm/cleanup.sh`) deletes wholesale, while the store holds the
login credential, every project transcript, the plugin set, and 4 GB of microVM and venv
artifacts. Three consequences are already visible in the repository:

- `--isolated-clean` runs `rm -rf "$ISOLATED_NVM_DIR"` and takes the whole store with it.
- `.gitignore` spends 58 lines (89–146) on allow/deny gymnastics to publish 87 asset files
  out of a 5.1 GB runtime directory.
- The nvm block image for the microVM is built by rsyncing the nvm tree, so unrelated
  Claude runtime state has to be excluded by 21 explicit `--exclude` patterns.

`.claude-homes/` was already lifted to the repository root for exactly this reason. Now,
while the two-layer isolation work (plan slices S1–S8) is fresh and the per-home symlink
layer is self-repairing, is the cheapest moment to finish the job: the store moves to
`<repo>/.claude-isolated`, a sibling of `.nvm-isolated` and `.claude-homes`.

Scope is the relocation only. The directory keeps its name, the internal layout of the
store is not reorganized, and no other part of the project structure is touched.

## Desired Outcomes

- After an update, `iclaude.sh --check-config` reports the store at `<repo>/.claude-isolated`
  and an existing installation keeps working with no manual step: the user is still logged
  in, past transcripts open, installed plugins are present, and per-home `settings.json`
  user keys are unchanged.
- `.nvm-isolated/` contains only nvm and node artifacts. `ls` at the repository root shows
  `.claude-isolated`, `.claude-homes`, and `.nvm-isolated` as three siblings.
- `--isolated-clean` removes the nvm tree and leaves the store — credentials, transcripts,
  and plugins survive a full nvm reinstall.
- A microVM session launched after the move still finds `/mnt/nvm/.claude-isolated` in the
  guest and starts Claude Code there; the guest path contract is unchanged.
- `.gitignore` addresses the store by its new root path, and `git status` is clean right
  after the move — no tracked asset is lost or duplicated.

## Health Metrics

Nothing on this list may degrade; each is measured, not assumed.

- **Store integrity.** OAuth login, `projects/` transcripts, `history.jsonl`, `plugins/`,
  and store `settings.json` are byte-identical before and after the migration.
- **microVM.** `tests/test_microvm_workspace.sh` and `tests/test-microvm-dual.sh` pass; the
  guest mounts `/mnt/nvm` and resolves `/mnt/nvm/.claude-isolated`.
- **PII proxy and router.** `tests/test_pii_supervisor.sh`, `tests/test-pii-parallel.sh`,
  and `tests/test_ccr_integration.sh` pass; the PII venv, pid directory, and `router.json`
  resolve through the relocated store.
- **Specification scenarios.** All 8 `iclaude` Given-When-Then scenarios stay `resolved`
  after `wiki_spec_resolve`; their IDs do not change, because observable behavior does not
  change — only a path does.
- **Per-project homes.** `tests/test_shared_asset_links.sh`, `tests/test_per_project_home.sh`,
  `tests/test_home_migration.sh`, and `tests/test_home_lifecycle_gc.sh` pass; existing homes
  re-point their shared-asset symlinks without losing user-owned settings keys.

## Strategic Context

- **Interacts with:** `lib/core/init.sh` (path chokepoint), `lib/nvm/setup.sh` (re-export),
  `lib/config/isolated.sh` (homes, shared-asset links, migration), `lib/sandbox/install.sh`
  and `lib/sandbox/microvm.sh` (guest image build and guest config), `lib/router/*`,
  `lib/lsp/*`, `lib/oauth/token.sh`, `lib/launcher/launch.sh`, `lib/lockfile/save.sh` and
  `lib/nvm/install.sh` (store lock), `lib/nvm/cleanup.sh` and `lib/nvm/repair.sh`.
  Human side: every existing iclaude installation migrates on its next launch.
- **Priority trade-off:** trust. The store holds the only copy of the login credential and
  of every project transcript; a fast or cheap migration that risks them is not acceptable.
  Speed is secondary, cost is irrelevant at this size.

## Constraints

### Steering (behavioral guidance)

- Keep the directory name `.claude-isolated`. Of 133 references, roughly 60 use the bare
  string (comments, rsync excludes, the `repair.sh` grep, the guest path); renaming would
  pull all of them into the diff for no benefit.
- Route every path through the existing `ISOLATED_CONFIG_DIR` chokepoint rather than
  introducing a new variable — the export already exists in `lib/core/init.sh`.
- Do not reorganize the store's internal layout, split it by data class, or touch
  `docs/superpowers/` history. Out of scope.
- Deliver as sequential slices, each independently verifiable, ordered by dependency.

### Hard (architectural enforcement)

- **The microVM guest contract is frozen.** Inside the guest the store stays at
  `/mnt/nvm/.claude-isolated`. `lib/sandbox/microvm.sh` and `lib/sandbox/guest-init.sh`
  are not changed by this work; only the host-side image build learns a second source.
- **No compatibility symlink.** `.nvm-isolated/.claude-isolated` disappears entirely.
  A symlink would be copied verbatim by the image build's `rsync -a` and land in the guest
  as a dangling link. Rollback is the reverse `mv`, performed manually.
- **The migration never copies and never deletes.** It is a single `mv` within one
  filesystem, guarded by "old path exists and new path does not". A failed precondition is
  a no-op, not a partial move.
- **`ISOLATED_CONFIG_DIR` is authoritative.** No module may reconstruct the store path from
  `ISOLATED_NVM_DIR` after this change, including `lib/config/isolated.sh:389`, which today
  ignores the override that line 275 respects.
- The store lock and `LOCKFILE_HASH_FILE` move with the store; they are store state, not
  nvm state.

## Autonomy Zones

- **Full autonomy (reversible, low risk):** library path edits, the migration function
  itself, microVM host-side image build changes, `.gitignore` rewrite, test updates,
  documentation updates, wiki and specification updates, commits on the topic branch.
- **Guarded (log + confidence threshold):** changing behavior of `lib/nvm/cleanup.sh` and
  `lib/nvm/repair.sh`; each behavioral change is stated in the commit message and recorded
  on the task page.
- **Proposal-first (needs approval):** executing the real `mv` of the live 5.1 GB store on
  this machine; running `git mv` on the 87 tracked asset files.
- **No autonomy (human only):** any operation that deletes store content, force-pushes,
  or rewrites git history; opening the PR into `master`.

> These zones OVERRIDE subagent-driven-development's "continuous execution,
> don't pause" default. Any task touching proposal-first / no-go decisions
> is marked HUMAN CHECKPOINT in the plan.

## Stop Rules

- **Halt if:** the migration precondition is ambiguous (both old and new store paths exist,
  or either is not a directory); the old and new paths are on different filesystems, so the
  `mv` would become a 5.1 GB copy; a store file's content would have to be rewritten to
  complete the move.
- **Escalate if:** any of the 8 specification scenarios stops resolving; a microVM or PII
  test that passed before the move fails after it and two different fix strategies fail;
  the guest image build cannot reproduce `/mnt/nvm/.claude-isolated` without changing the
  guest contract.
- **Done when:** on this machine, after the change, `iclaude.sh --check-config` reports the
  store at `<repo>/.claude-isolated`; `.nvm-isolated/.claude-isolated` does not exist;
  a launched session is still logged in and lists its past transcripts; a microVM session
  starts and resolves `/mnt/nvm/.claude-isolated`; the named home, microVM, PII, router, and
  shared-asset tests pass with exit code 0; `git status` is clean; and all 8 scenarios
  report `resolved`.
