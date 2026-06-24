# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## Getting Started

**Load docs before exploring code — they encode decisions invisible in raw code.**

At the start of any task in an unfamiliar area, or after a gap of more than 1 day:

1. **If the project has a `docs/wiki/`**, run `/iwiki-query` → retrieve relevant `docs/wiki/` sections; `/iwiki-lint` → check doc health. (No `docs/wiki/` → skip; iwiki is not set up in this project.)
2. Map the `docs/` layout into context (complements iwiki's semantic search with a structural overview):
   ```bash
   tree -L 2 docs/ || find docs -maxdepth 2 | sort   # fallback when `tree` is absent
   ```
   Depth `-L 2` is chosen for the current project — its `docs/` nests at most 2 directory
   levels (e.g. `docs/superpowers/specs/`), so level 2 shows the full directory skeleton plus
   top-level files without flooding context with every leaf file. Raise the level for deeper trees.

Skip only when: familiar area, same session.

## Keep Docs Current (MANDATORY)

**After every change that alters functionality, architecture, or behavior — and only in a project that already has a `docs/wiki/` — update the project docs via iwiki before responding to the user.**

- Run `iwiki:iwiki-ingest <changed-source>` to regenerate/update the affected `docs/wiki/` page.
- Run `/iwiki-lint` — no broken `[[refs]]`, no orphan or stale pages.
- Skip only for changes that touch no functionality, architecture, or behavior (typo, comment, formatting).

Always invoke iwiki via its **skills** (`iwiki:iwiki-ingest`, `/iwiki-query`, `/iwiki-lint`) — never guess engine subcommands. The `iwiki_engine` CLI exposes `index | search | related | status | lint` (`lint` is config-free, like `status`, and is what `/iwiki-lint` calls). When unsure of any CLI's subcommands, check `--help` before running.

## Language Rules

- **Conversations and questions**: Russian — to match user expectations.
- **Documentation and code comments**: English — to keep docs universally readable.

## Think Before Coding

**Don't assume. Surface tradeoffs. Ask when unclear.**

Before implementing:
- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so.
- If something is unclear, stop. Name what's confusing. Ask.

## Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No unrequested features — scope creep compounds review cost.
- No abstractions for single-use code — increases cognitive load without reuse benefit.
- No "flexibility" not requested — premature generalization adds maintenance burden.
- No error handling for impossible scenarios — dead code misleads readers.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer call this overcomplicated?" If yes, simplify.

## Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't improve adjacent code or formatting — unrelated changes bloat diffs and risk regressions.
- Don't refactor things that aren't broken — stability is a feature.
- Match existing style — consistency beats personal preference.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

Test: every changed line must trace directly to the user's request.

## Branch Workflow

**Don't commit to main. Develop on a branch. Merge back only via PR.**

- Never commit work directly to the main branch (`master` / `main` / `prod`), and never merge or push to it directly — close every branch through a PR into main.
- **Branch naming is mandatory: `dev-<name>`, created from the up-to-date main branch.** Words inside `<name>` are joined with `-` (e.g. `dev-fix-phase1`). No exceptions.
- **If the project has long-lived branches beyond `master` / `main` / `prod`** (e.g. `dev`, `develop`, `staging`, `release/*`), always ask first — which branch to base the new `dev-*` off, and which branch to open the PR against. Don't assume.
- **When creating a `dev-*` branch, always ask first: create a worktree for it now?** This step is mandatory — never decide silently.
  - **Yes** → create the branch inside a new worktree `wk-<branch>` and do all the work there.
  - **No** → create the branch in place and keep working in the main worktree.
- For parallel work on several tasks, create one git worktree per branch.
- **Worktree naming is mandatory: `wk-<branch>`** — the literal `wk-` prefix followed by the full branch name. Example: branch `dev-fix-phase1` → worktree `wk-dev-fix-phase1`.
- After the PR is created, remove the branch's worktree — don't leave stale worktrees around.

Use **@skill:git-workflow** for commit messages and PR creation.

## Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals (verify by running real code or tests):
- "Add validation" → "Run the code with invalid inputs, confirm it rejects them"
- "Fix the bug" → "Reproduce it by running the affected path, confirm the fix removes it"
- "Refactor X" → "Run X before and after, confirm identical observable behavior"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```
