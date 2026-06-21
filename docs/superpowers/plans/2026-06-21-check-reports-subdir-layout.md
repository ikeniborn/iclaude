# Split check-* Reports Into Subdirectories — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route each IDD check command's HTML report into a per-artifact subdirectory of `docs/superpowers/reports/` and migrate the one existing flat report.

**Architecture:** Four single-line edits to the "Выход:" artifact-parameter bullet in each `commands/check-*.md` file (output path + "create directory" instruction now name a subdirectory), plus one `git mv` to relocate the existing report. No code, hooks, or iwiki touched.

**Tech Stack:** Markdown command files; `grep` for verification; `git mv` for migration.

**Spec:** `docs/superpowers/specs/2026-06-21-check-reports-subdir-layout-design.md`

---

## File Structure

Files modified (one line each), all under `.nvm-isolated/.claude-isolated/commands/`:

| File | Line | Subdir |
|------|------|--------|
| `check-intent.md` | 145 | `intents/` |
| `check-spec.md` | 141 | `specs/` |
| `check-plan.md` | 142 | `plans/` |
| `check-result.md` | 98 | `results/` |

File moved: `docs/superpowers/reports/2026-06-17-iwiki-result-check.html` → `docs/superpowers/reports/results/`.

> Note: these are Russian-language command files; the edited bullets stay in Russian. Only the directory segment of each path changes (and `result` → adds `results/`). The in-parentheses filename example is unchanged.

---

## Task 1: Repoint the four check-* output paths

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/check-intent.md:145`
- Modify: `.nvm-isolated/.claude-isolated/commands/check-spec.md:141`
- Modify: `.nvm-isolated/.claude-isolated/commands/check-plan.md:142`
- Modify: `.nvm-isolated/.claude-isolated/commands/check-result.md:98`

- [ ] **Step 1: Edit `check-intent.md` line 145**

Replace this exact line:

```
- Выход: `docs/superpowers/reports/<basename intent doc без .md>-check.html` (например `2026-06-17-foo-intent-check.html`). Создай каталог `docs/superpowers/reports/`, если его нет.
```

with:

```
- Выход: `docs/superpowers/reports/intents/<basename intent doc без .md>-check.html` (например `2026-06-17-foo-intent-check.html`). Создай каталог `docs/superpowers/reports/intents/`, если его нет.
```

- [ ] **Step 2: Edit `check-spec.md` line 141**

Replace this exact line:

```
- Выход: `docs/superpowers/reports/<basename спеки без .md>-check.html` (например `2026-06-17-foo-design-check.html`). Создай каталог `docs/superpowers/reports/`, если его нет.
```

with:

```
- Выход: `docs/superpowers/reports/specs/<basename спеки без .md>-check.html` (например `2026-06-17-foo-design-check.html`). Создай каталог `docs/superpowers/reports/specs/`, если его нет.
```

- [ ] **Step 3: Edit `check-plan.md` line 142**

Replace this exact line:

```
- Выход: `docs/superpowers/reports/<basename плана без .md>-check.html` (например `2026-06-17-foo-plan-check.html`). Создай каталог `docs/superpowers/reports/`, если его нет.
```

with:

```
- Выход: `docs/superpowers/reports/plans/<basename плана без .md>-check.html` (например `2026-06-17-foo-plan-check.html`). Создай каталог `docs/superpowers/reports/plans/`, если его нет.
```

- [ ] **Step 4: Edit `check-result.md` line 98**

Replace this exact line:

```
- Выход: `docs/superpowers/reports/<basename плана без .md>-result-check.html` (например `2026-06-17-foo-plan-result-check.html`). Создай каталог `docs/superpowers/reports/`, если его нет.
```

with:

```
- Выход: `docs/superpowers/reports/results/<basename плана без .md>-result-check.html` (например `2026-06-17-foo-plan-result-check.html`). Создай каталог `docs/superpowers/reports/results/`, если его нет.
```

- [ ] **Step 5: Verify all four paths now carry a subdirectory**

Run:

```bash
grep -rn "superpowers/reports/" .nvm-isolated/.claude-isolated/commands/
```

Expected: exactly four matches — `reports/intents/`, `reports/specs/`, `reports/plans/`, `reports/results/`. No bare `reports/<basename` flat path remains.

- [ ] **Step 6: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/check-intent.md \
        .nvm-isolated/.claude-isolated/commands/check-spec.md \
        .nvm-isolated/.claude-isolated/commands/check-plan.md \
        .nvm-isolated/.claude-isolated/commands/check-result.md
git commit -m "feat(commands): route check-* reports into per-artifact subdirs"
```

---

## Task 2: Migrate the existing flat report

**Files:**
- Move: `docs/superpowers/reports/2026-06-17-iwiki-result-check.html` → `docs/superpowers/reports/results/`

- [ ] **Step 1: Move the file into results/**

`git mv` creates the destination directory implicitly:

```bash
git mv docs/superpowers/reports/2026-06-17-iwiki-result-check.html \
       docs/superpowers/reports/results/2026-06-17-iwiki-result-check.html
```

- [ ] **Step 2: Verify the move**

Run:

```bash
ls docs/superpowers/reports/results/ && \
ls docs/superpowers/reports/2026-06-17-iwiki-result-check.html 2>&1
```

Expected: `results/` lists `2026-06-17-iwiki-result-check.html`; the second `ls` prints "No such file or directory" (flat copy is gone).

- [ ] **Step 3: Commit**

```bash
git add -A docs/superpowers/reports/
git commit -m "chore(reports): migrate existing result-check report into results/"
```

---

## Verification (whole plan)

1. `grep -rn "superpowers/reports/" .nvm-isolated/.claude-isolated/commands/` → four subdirectory paths, no flat path.
2. `ls docs/superpowers/reports/results/` → migrated file present; `docs/superpowers/reports/2026-06-17-iwiki-result-check.html` absent.
3. `git status` clean after both commits.
