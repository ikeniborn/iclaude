# Basic Usage Example — git-workflow

## Scenario

A bug fix on a fresh branch: branch from an up-to-date base, commit with a Conventional
Commits message, push, open a PR.

Task: the login form rejects valid e-mail addresses containing a plus sign.
Topic: `email-validation-plus-sign`.

---

## Step 1 — branch

No other `dev-*` branch exists, so no worktree is offered; the branch is created in the
main worktree from the up-to-date base.

```bash
git fetch origin master
git switch -c dev-email-validation-plus-sign origin/master
git branch --show-current
```

---

## Step 2 — inspect before staging

```bash
git branch --show-current
git status
git diff
```

Changes:

- `src/auth.py` — widened the e-mail regex to accept `+` in the local part
- `tests/test_auth.py` — regression test for `user+tag@example.com`

---

## Step 3 — commit

Type `fix`, scope `auth`. The body states why; the verification line records the evidence.
The co-author trailer is the one the current harness specifies.

```bash
git add src/auth.py tests/test_auth.py
git commit -m "fix(auth): accept plus-addressed e-mails in login validation

The regex rejected the plus sign in the local part, so plus-addressed
accounts could not log in. Widened it to the RFC 5322 local-part subset
already used by the signup form.

Verified: pytest tests/test_auth.py -q → 8 passed.

Fixes #231

Co-Authored-By: <harness co-author line>"
```

---

## Step 4 — push and open the PR

```bash
git push -u origin dev-email-validation-plus-sign
gh pr create --base master --head dev-email-validation-plus-sign \
  --title "fix(auth): accept plus-addressed e-mails in login validation" \
  --body "Fixes #231. Regression test added; pytest tests/test_auth.py → 8 passed."
```

Nothing is merged locally — integration happens through the PR.

---

## Related

- [git-workflow/SKILL.md](../SKILL.md)
- [_shared/commit-types.json](../../_shared/commit-types.json)
