# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## Getting Started

**Load docs before exploring code — they encode decisions invisible in raw code.**

At the start of any task in an unfamiliar area, or after a gap of more than 1 day:

1. **If the iwiki MCP server is connected**, call `wiki_status`. If it reports a domain bound to this project (convention: domain name == project basename), `wiki_bind(read=[<domain>], write=<domain>)`, then `wiki_search "<task topic>"` → retrieve relevant sections; `wiki_lint` → check doc health. (No server / no project domain → skip; iwiki is not set up for this project.)
2. Map the `docs/` layout into context (complements iwiki's semantic search with a structural overview):
   ```bash
   tree -L 2 docs/ || find docs -maxdepth 2 | sort   # fallback when `tree` is absent
   ```
   Depth `-L 2` is chosen for the current project — its `docs/` nests at most 2 directory
   levels (e.g. `docs/superpowers/specs/`), so level 2 shows the full directory skeleton plus
   top-level files without flooding context with every leaf file. Raise the level for deeper trees.

Skip only when: familiar area, same session.

## Keep Docs Current (MANDATORY)

**After every change that alters functionality, architecture, or behavior — and only when the iwiki MCP server reports a domain bound to this project (`wiki_status`) — update the wiki via the MCP tools before responding to the user.**

- Author/update the affected page markdown, then `wiki_write_page(domain, slug, markdown, source=<changed-source>)` followed by `wiki_index(domain)` (writes are not auto-indexed).
- Run `wiki_lint` — no broken `[[refs]]`, no orphan or stale pages.
- Skip only for changes that touch no functionality, architecture, or behavior (typo, comment, formatting).

Always use the iwiki MCP tools (`wiki_status`, `wiki_bind`, `wiki_search`, `wiki_related`, `wiki_read_page`, `wiki_write_page`, `wiki_index`, `wiki_lint`, `wiki_list_domains`, `wiki_list_pages`, `wiki_create_domain`) — never the old plugin skills or the `iwiki_engine` CLI.

## Task Log (docs/TODO.md)

**Every elaboration task that runs through the IDD→SDD chain (intent → spec → plan → result) is tracked as one row in `docs/TODO.md`: opened when work starts, closed when it finishes.**

Purpose: a single human-readable index of what is being worked on and what is done — **one row per chain `<topic>`** (the shared chain key the `check-*` commands converge on), never per finding or per step.

- **One file, one table.** `docs/TODO.md` holds a single Markdown table, one row per `<topic>`.
- **Columns:** `Topic | Status | Intent | Spec | Plan | Result | Opened | Closed | Notes`.
  - `Status`: `in-progress` while any stage is still open; `done` once `check-result` returns `OK`.
  - Stage cells (`Intent` / `Spec` / `Plan`): `✓` once that stage's `check-*` passes (verdict `OK`, including a cached quick-exit); `–` if not reached yet; `n/a` if the stage does not exist for this topic (e.g. no intent).
  - `Result`: `OK` / `needs_work` / `–`.
  - `Opened` / `Closed`: ISO date (`YYYY-MM-DD`). `Closed` stays empty until the task is `done`.
  - `Notes`: optional one-line context.
- **Upsert, never duplicate.** Keyed by `<topic>`: update the matching row in place if it exists, otherwise append a new one.
- **Lifecycle (driven by the `check-*` commands):**
  - The first `check-*` run for a topic **opens** the row (`Opened: <today>`, `Status: in-progress`). Normally that is `check-intent`; if there is no intent, `check-spec` opens it and marks `Intent: n/a`.
  - `check-spec` / `check-plan` mark their own stage cell `✓` and keep `Status: in-progress`.
  - `check-result` **closes** the row on verdict `OK` (`Result: OK`, `Status: done`, `Closed: <today>`); on `needs_work` it sets `Result: needs_work` and leaves the row open.
- **Create on demand.** If `docs/TODO.md` is absent, the first `check-*` run creates it with the header row, then appends.
- **Manual rows are allowed.** A task may be added by hand before any `check-*` run; the commands then update the matching `<topic>` row instead of duplicating it.

## Language Rules

- **Conversations and questions**: Russian — to match user expectations.
- **Documentation and code comments**: English — to keep docs universally readable.

## Copy-Friendly Command Output

**Bash/Python commands the user runs must be copy-pasteable straight from the terminal.**

- Put every runnable command in a fenced code block (```` ```bash ```` / ```` ```python ````) — never inline in prose.
- No leading indentation inside the fence. The first column is column 1, so copying grabs no stray spaces.
- One command per line. No trailing whitespace.
- No shell prompt prefixes (`$`, `>`, `#`) — they get copied too and break paste.
- Don't wrap long commands with manual line breaks; let the terminal soft-wrap, or use explicit `\` continuations.

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
