---
name: git-workflow
description: Git workflow for this environment — dev-<topic> branches, sibling worktrees, Conventional Commits, and PRs into the main branch. Use when creating a branch, committing, pushing, or opening a PR, or when the user says "commit", "create branch", "open PR", "fix commit message".
user-invocable: false
# version: 3.0.0
# tags: git, branch, worktree, commit, conventional-commits, pull-request
---

# Git Workflow

Branch, commit and PR rules for this environment. The Branch Workflow section of
`CLAUDE.md` is authoritative; this skill is its executable form. Never commit, merge or
push directly to the main branch (`master` / `main` / `prod`) — every branch closes
through a PR.

## Mode 1 — create a branch

Preconditions, in order:

1. **Topic.** One canonical `<topic>`: English, lowercase kebab-case, semantic. The same
   slug is used for the branch suffix, the wiki task page and any chain/LoEn artifacts.
   Derive it from an existing branch suffix when one exists and is not vague.
2. **Base branch.** Default is the main branch. If the repository has long-lived branches
   beyond `master` / `main` / `prod` (`dev`, `develop`, `staging`, `release/*`), ask which
   one to branch from and which one the PR targets. Do not assume.
3. **Worktree decision.** List existing `dev-*` branches first:
   - none → create the branch in the main worktree, do not offer a worktree;
   - one or more → ask whether to create a worktree for the new branch. Yes → sibling
     worktree at `../<project>-<branch>`; no → create in place.

Branch name is mandatory: `dev-<topic>`. No other pattern, no `_v2` suffixes — one topic,
one branch. If the branch already exists and is checked out nowhere, attach it instead of
creating a variant.

In the main worktree:

```bash
base="<base-branch>"
branch="dev-<topic>"
git fetch origin "$base"
git switch -c "$branch" "origin/$base"
git branch --show-current
```

As a sibling worktree (atomic — never check the branch out first and add a worktree after):

```bash
base="<base-branch>"
branch="dev-<topic>"
root="$(git rev-parse --show-toplevel)"
project="$(basename "$root")"
parent="$(dirname "$root")"
git fetch origin "$base"
git worktree add -b "$branch" "$parent/$project-$branch" "origin/$base"
```

Attach an existing branch to its canonical worktree path:

```bash
branch="dev-<topic>"
root="$(git rev-parse --show-toplevel)"
project="$(basename "$root")"
parent="$(dirname "$root")"
git worktree add "$parent/$project-$branch" "$branch"
```

Uncommitted changes in the way → stop and report; the user commits or stashes. A missing
base branch → stop and report. Verify with `git worktree list --porcelain` before working.

## Mode 2 — commit and push

Assumes the work is already on its `dev-<topic>` branch.

```bash
git branch --show-current      # must be dev-<topic>, never the main branch
git status
git diff --staged
git add <files>
git commit -m "<message>"
git push -u origin "$(git branch --show-current)"
```

Message format — Conventional Commits, types from `../_shared/commit-types.json`
(`feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`):

```text
<type>(<scope>)?<!>?: <subject ≤72 chars, imperative>

<body — why, not what; wrap at 100>

<footers: Fixes #123 / BREAKING CHANGE: …>

Co-Authored-By: <the co-author line your harness specifies>
```

Take the co-author line from the harness instructions of the current session — it names
the model actually producing the commit. Never copy a model name out of this file or out
of an older commit.

Breaking changes: `!` after the type/scope **and** a `BREAKING CHANGE:` footer describing
the migration.

## Mode 3 — open a PR

Push first, then open the PR against the base branch agreed in Mode 1:

```bash
gh pr create --base "<base-branch>" --head "$(git branch --show-current)" \
  --title "<type>: <summary>" --body "<body>"
```

Body: what changed and why, how it was verified (commands and their result), and links to
the task page / chain artifacts when they exist. Follow the repository's PR template when
it has one.

After the PR exists:

- remove the branch's worktree if one was created — `git worktree remove "$parent/$project-$branch"` then `git worktree prune`;
- the parent agent records the event on the wiki task page (see Task Log in `CLAUDE.md`);
  this skill never writes the wiki itself.

## Safety rules

```yaml
NEVER:
  - commit, merge, or push directly to master/main/prod — PR only
  - force push a shared branch (--force-with-lease on your own branch only)
  - commit secrets or credentials (.env, keys, tokens)
  - use --no-verify
  - amend or rebase commits that are already pushed to a shared branch
  - create a branch outside the dev-<topic> pattern
  - create a worktree inside the repository root

ALWAYS:
  - verify the current branch before staging (git branch --show-current)
  - review the staged diff before committing (git diff --staged)
  - explain "why" in the commit body for non-trivial changes
  - reference the issue when fixing one (Fixes #123)
  - branch from an up-to-date base (git fetch origin <base> first)
```

## Examples

### Feature on a fresh branch

```bash
git fetch origin master
git switch -c dev-user-authentication origin/master
# … implement …
git add app/api/auth.py app/services/jwt_service.py tests/test_auth.py
git commit -m "feat(api): add user authentication endpoint

JWT-based login: email/password credentials return an access token.
Verified: pytest tests/test_auth.py -q → 12 passed.

Co-Authored-By: <harness co-author line>"
git push -u origin dev-user-authentication
gh pr create --base master --head dev-user-authentication \
  --title "feat(api): add user authentication endpoint" --body "…"
```

### Parallel work in a sibling worktree

Another `dev-*` branch already exists, the user agreed to a worktree:

```bash
git fetch origin master
git worktree add -b dev-sql-injection-fix ../myproject-dev-sql-injection-fix origin/master
code --new-window ../myproject-dev-sql-injection-fix
```

```bash
git add app/api/auth.py
git commit -m "fix(security): prevent SQL injection in the auth endpoint

Replace string concatenation with a parameterized query.

Fixes #456

Co-Authored-By: <harness co-author line>"
git push -u origin dev-sql-injection-fix
```

### Breaking change

```bash
git commit -m "feat(api)!: change the transaction response format

Return transactions nested under data with pagination metadata.

BREAKING CHANGE: clients must read response.data instead of the bare array.
Migration guide: docs/migration/v2-api.md

Co-Authored-By: <harness co-author line>"
```

## Changelog

### 3.0.0

- Aligned with `CLAUDE.md`: mandatory `dev-<topic>` branches, sibling worktrees at
  `../<project>-<branch>`, PR-only integration, base-branch question for repositories with
  long-lived branches.
- Added the PR mode (`gh pr create`); removed the delegation to the non-existent
  `pr-automation` skill and the `structured-planning` / `validation-framework` PHASE
  pipeline that no longer exists.
- Removed the dead `@shared:GIT-CONVENTIONS.md` / `@shared:TOON-REFERENCE.md` references
  and the TOON output schema; commit types now come from `../_shared/commit-types.json`.
- Co-author line is taken from the harness instead of a hard-coded model name.
