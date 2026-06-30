---
review:
  plan_hash: f294b61738de89e8
  spec_hash: e85d04cbe5e9e7d2
  last_run: 2026-06-30
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - id: F-001
      phase: verifiability
      severity: INFO
      section: "Task 11: Final verification sweep"
      section_hash: de7b7a5d8a0b2f14
      fragment: "Run the project's normal test command for the remaining (non-iwiki) tests. Expected: green"
      text: >-
        Task 11 Step 6 (success criterion 6) defers to "the project's normal test
        command", but the repo has no single test runner — tests/ is a flat directory
        of individual *.sh/*.py scripts with no Makefile or run_tests entrypoint. The
        step instructs discovery first, so it is executable, but the DoD is not pinned
        to an exact command/expected output the way the other verify steps are.
      fix: >-
        Optional: pin the command (e.g. iterate the non-iwiki tests/ scripts and assert
        each exits 0) or name the project's actual CI invocation, so the criterion-6
        check is reproducible. Non-blocking.
      verdict: fixed
      verdict_at: 2026-06-30
      resolution: >-
        Task 11 Step 6 now pins a concrete command (iterate non-iwiki tests/*.sh and
        tests/*.py, skip *iwiki*, assert exit 0, echo TESTS_OK) plus a documented
        fallback for scripts needing a special invocation. DoD is now reproducible.
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-30-iwiki-plugin-to-mcp-design.md
result_check:
  verdict: OK
  plan_hash: f294b61738de89e8
  last_run: 2026-06-30
---
# iwiki Plugin → MCP Migration + Decommission — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all iwiki *usage instructions* (global CLAUDE.md + 5 personal skills) to the iwiki MCP server (`mcp__iwiki__wiki_*`), and decommission the in-repo plugin integration, keeping only the `plugin/iwiki/` source folder (disabled/dormant).

**Architecture:** Two parts. Part 1 rewrites instruction surfaces around the MCP domain model (`wiki_status` → `wiki_bind` → typed `wiki_*` tools), dropping the `docs/wiki/` concept. Part 2 deletes the install/activation machinery, wiki data, and tests, and disables the plugin. No `plugin/iwiki/` code changes.

**Tech Stack:** Markdown skill/instruction files; Bash (`iclaude.sh`, `lib/**`); the iwiki MCP server tools.

## Global Constraints

- **Scope = instructions + decommission only.** Do NOT modify any file under `plugin/iwiki/`.
- **Match each surface's existing language.** `CLAUDE.md` and `README.md` reuse their current language; the 5 skills are RU prose with EN identifiers — keep that style. New tool names/identifiers stay verbatim (`wiki_status`, `wiki_search`, …).
- **Keep `.iwikiignore`** (repo root) — used by the MCP server.
- **Keep `.claude-plugin/marketplace.json`** iwiki entry and the `uv` bootstrap in `lib/core/init.sh` (the dormant plugin engine may still be run manually).
- **Write flow rule (confirmed in Task 1):** `wiki_write_page` is followed by an explicit `wiki_index(domain)`.
- **Detection/bind canonical flow** (reused by every Part-1 surface):
  ```
  wiki_status → if a domain for this project exists in `domains` (name == project basename)
  but read/write unbound → wiki_bind(read=[<domain>], write=<domain>); then call wiki_* without
  an explicit domain. If no server / no project domain → iwiki not set up → skip silently.
  ```
- **Commit after every task.** Conventional commits, English messages, trailer:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Branch:** work on the current branch `dev-iwiki-engine-entrypoint` (user-directed; no new branch, no worktree).
- **No new placeholders.** Every edit below gives exact old → new text.

---

## Task 1: Confirm MCP write-flow indexing (live probe)

Confirms the resolved rule (`wiki_write_page` does NOT auto-index) before instruction wording depends on it. Uses a throwaway domain to avoid polluting the real `iclaude` domain.

**Files:** none (MCP tool calls only).

- [ ] **Step 1: Create a probe domain**

Call `wiki_create_domain(name="zz-probe-writeflow")`.

- [ ] **Step 2: Bind it**

Call `wiki_bind(read=["zz-probe-writeflow"], write="zz-probe-writeflow")`.

- [ ] **Step 3: Write a page with a unique token, do NOT index**

Call `wiki_write_page(domain="zz-probe-writeflow", slug="probe", markdown="# Probe\n\nUnique token: ZqxWriteflowProbe7731.", source="probe")`.

- [ ] **Step 4: Search for the token before indexing**

Call `wiki_search(query="ZqxWriteflowProbe7731", domains=["zz-probe-writeflow"])`.
Expected (per resolved rule): the page is NOT found (write not yet indexed).

- [ ] **Step 5: Index, then search again**

Call `wiki_index(domain="zz-probe-writeflow")`, then `wiki_search(query="ZqxWriteflowProbe7731", domains=["zz-probe-writeflow"])`.
Expected: the page IS found.

- [ ] **Step 6: Record the outcome**

If Step 4 found the page (auto-index), STOP and tell the user — the instruction wording in Tasks 2 & 5 must drop the explicit `wiki_index` step. Otherwise the resolved rule holds; proceed unchanged. No commit (no repo files changed).

---

## Task 2: CLAUDE.md — Getting Started + Keep Docs Current

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/CLAUDE.md`

- [ ] **Step 1: Rewrite the Getting Started iwiki gate**

Find:
```
1. **If the project has a `docs/wiki/`**, run `/iwiki-query` → retrieve relevant `docs/wiki/` sections; `/iwiki-lint` → check doc health. (No `docs/wiki/` → skip; iwiki is not set up in this project.)
```
Replace with:
```
1. **If the iwiki MCP server is connected**, call `wiki_status`. If it reports a domain bound to this project (convention: domain name == project basename), `wiki_bind(read=[<domain>], write=<domain>)`, then `wiki_search "<task topic>"` → retrieve relevant sections; `wiki_lint` → check doc health. (No server / no project domain → skip; iwiki is not set up for this project.)
```

- [ ] **Step 2: Rewrite the Keep Docs Current gate paragraph**

Find:
```
**After every change that alters functionality, architecture, or behavior — and only in a project that already has a `docs/wiki/` — update the project docs via iwiki before responding to the user.**
```
Replace with:
```
**After every change that alters functionality, architecture, or behavior — and only when the iwiki MCP server reports a domain bound to this project (`wiki_status`) — update the wiki via the MCP tools before responding to the user.**
```

- [ ] **Step 3: Rewrite the two action bullets**

Find:
```
- Run `iwiki:iwiki-ingest <changed-source>` to regenerate/update the affected `docs/wiki/` page.
- Run `/iwiki-lint` — no broken `[[refs]]`, no orphan or stale pages.
```
Replace with:
```
- Author/update the affected page markdown, then `wiki_write_page(domain, slug, markdown, source=<changed-source>)` followed by `wiki_index(domain)` (writes are not auto-indexed).
- Run `wiki_lint` — no broken `[[refs]]`, no orphan or stale pages.
```

- [ ] **Step 4: Replace the "invoke via skills / engine CLI" paragraph**

Find:
```
Always invoke iwiki via its **skills** (`iwiki:iwiki-ingest`, `/iwiki-query`, `/iwiki-lint`) — never guess engine subcommands. The `iwiki_engine` CLI exposes `index | search | related | status | lint` (`lint` is config-free, like `status`, and is what `/iwiki-lint` calls). When unsure of any CLI's subcommands, check `--help` before running.
```
Replace with:
```
Always use the iwiki MCP tools (`wiki_status`, `wiki_bind`, `wiki_search`, `wiki_related`, `wiki_read_page`, `wiki_write_page`, `wiki_index`, `wiki_lint`, `wiki_list_domains`, `wiki_list_pages`, `wiki_create_domain`) — never the old plugin skills or the `iwiki_engine` CLI.
```

- [ ] **Step 5: Verify no plugin usage remains**

Run: `grep -nE "iwiki:iwiki-|/iwiki-query|/iwiki-lint|/iwiki-ingest|iwiki_engine|docs/wiki/" .nvm-isolated/.claude-isolated/CLAUDE.md`
Expected: no matches.

- [ ] **Step 6: Commit**

```bash
git add .nvm-isolated/.claude-isolated/CLAUDE.md
git commit -m "docs(iwiki): migrate CLAUDE.md global instructions to MCP tools

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: context-awareness skill — detection via wiki_status, rename fields

The skill checks `docs/wiki/` and emits `wiki_initialized` / `wiki_index_path` / `wiki_summary`. Switch detection to `wiki_status`, replace `wiki_index_path` with `wiki_domain` everywhere (§5, output template, all examples), update description/delegates/changelog.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md`

- [ ] **Step 1: Rewrite §5 detection block**

Find the block starting `### 5. iwiki Detection` through the end of its `**Назначение:**` paragraph (current lines ~63–91). Replace its body with:
```
### 5. iwiki Detection

Документационный граф проекта живёт в **MCP-сервере iwiki** (внешний central-store,
адресуется доменами). Единственный источник документационного контекста проекта.

```
IF MCP-сервер iwiki подключён:
  1. wiki_status → project_dir, список `domains`, текущая привязка read/write
  2. Если домен проекта присутствует в `domains` (имя == basename проекта):
       - не привязан → wiki_bind(read=[<domain>], write=<domain>)
       - wiki_summary ← wiki_read_page(domain, "overview") (если есть)
         либо wiki_search('ключевые компоненты и архитектура проекта')
     Добавить в project_context:
       wiki_initialized: true
       wiki_domain: "<domain>"
       wiki_summary: <обзор страницы overview или результат wiki_search>
  3. Если домена проекта нет:
       wiki_initialized: false
       wiki_domain: null
       wiki_summary: null

ELSE (сервер не подключён):
  wiki_initialized: false
  wiki_domain: null
  wiki_summary: null
```

**Назначение:** Централизует проверку доступности документационного графа —
downstream-навыки (brainstorming, prd-generator) используют
`project_context.wiki_initialized` вместо самостоятельной проверки.
`wiki_search` — опциональный семантический поиск по секциям внутри задачи.
```

- [ ] **Step 2: Update the output template fields**

Find:
```
    "wiki_initialized": true|false,
    "wiki_index_path": "docs/wiki/index.md" | null,
    "wiki_summary": "синтезированный обзор из docs/wiki" | null
```
Replace with:
```
    "wiki_initialized": true|false,
    "wiki_domain": "<имя домена iwiki>" | null,
    "wiki_summary": "синтезированный обзор из домена iwiki" | null
```

- [ ] **Step 3: Update both filled examples (two occurrences)**

Find each occurrence of:
```
    "wiki_index_path": "docs/wiki/index.md",
```
Replace each with:
```
    "wiki_domain": "iclaude",
```
And the empty example — find:
```
    "wiki_index_path": null,
```
Replace with:
```
    "wiki_domain": null,
```

- [ ] **Step 4: Update description, delegates, and the §5 reference line**

Find in frontmatter `description:` the phrase `the docs/wiki/ iwiki documentation graph, surfacing its summary as project context` and replace with `the iwiki MCP domain for this project, surfacing its summary as project context`.

Find: `- \`iwiki:iwiki-query\` - Targeted semantic search over \`docs/wiki/\` pages (optional, in-task)`
Replace with: `- iwiki MCP \`wiki_search\` - Targeted semantic search over the project's iwiki domain (optional, in-task)`

Find: `- \`wiki_initialized\` / \`wiki_summary\` → Enables doc-graph-aware context without re-checking files`
Replace with: `- \`wiki_initialized\` / \`wiki_domain\` / \`wiki_summary\` → Enables doc-graph-aware context without re-checking files`

- [ ] **Step 5: Add a changelog entry**

At the top of the `## Changelog` list, add a new version entry above `### 1.4.1`:
```
### 1.5.0 (2026-06-30)
- iwiki detection switched from `docs/wiki/` files to the iwiki MCP server (`wiki_status`)
- Output field `wiki_index_path` → `wiki_domain`; `iwiki:iwiki-query` delegate → MCP `wiki_search`
```

- [ ] **Step 6: Verify**

Run: `grep -nE "iwiki:iwiki-|wiki_index_path|docs/wiki/" .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md`
Expected: matches only inside the new `### 1.5.0` and existing older changelog lines (history). No live `docs/wiki/` detection or `wiki_index_path` in the body/template/examples.

- [ ] **Step 7: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md
git commit -m "feat(context-awareness): detect iwiki via MCP wiki_status, rename wiki_index_path->wiki_domain

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: intent skill — Step 0 via MCP

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/intent/SKILL.md`

- [ ] **Step 1: Rewrite Step 0**

Find the `### Step 0: Load project context via iwiki (if available)` block through its closing line `If \`docs/wiki/\` is unavailable or query returns no results — skip silently. Do not block or mention the absence.` Replace the body with:
```
### Step 0: Load project context via iwiki (if available)

Before asking any questions, check the iwiki MCP server. If connected, `wiki_status`;
if a domain for this project exists, `wiki_bind(read=[<domain>], write=<domain>)` and load
context in parallel:

1. `wiki_search('<topic>')` — existing documentation for this topic

Store results as **wiki_context** for use in Steps 1–6 below.

Present to user:

```
Context from iwiki domain `<name>`:
[sections found, or "No documentation found for this topic"]
```

If the iwiki MCP server is unavailable, no project domain exists, or the search returns no
results — skip silently. Do not block or mention the absence.
```

- [ ] **Step 2: Verify**

Run: `grep -nE "iwiki:iwiki-|docs/wiki|/iwiki-" .nvm-isolated/.claude-isolated/skills/intent/SKILL.md`
Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/intent/SKILL.md
git commit -m "feat(intent): load Step 0 context via iwiki MCP wiki_search

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: agent-builder / prd-generator / prompt-verifier — iwiki Integration → MCP

Three skills share the gate→Query→Record shape. Apply the same transform to each: gate via `wiki_status`/`wiki_initialized`, Query via `wiki_search`, Record via author-markdown → `wiki_write_page` → `wiki_index`, and replace the "embedding-граф … `docs/wiki/`" prose.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/agent-builder/SKILL.md`
- Modify: `.nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md`
- Modify: `.nvm-isolated/.claude-isolated/skills/prompt-verifier/SKILL.md`

- [ ] **Step 1: agent-builder — Query gate**

Find:
```
IF exists("{CWD}/docs/wiki/"):
  Skill(skill="iwiki:iwiki-query", args='паттерны и спецификации Claude Code агентов')
```
Replace with:
```
IF iwiki MCP подключён AND wiki_status сообщает домен проекта (привязать через wiki_bind):
  wiki_search(query='паттерны и спецификации Claude Code агентов')
```

- [ ] **Step 2: agent-builder — Record prose + block**

Find:
```
iwiki — embedding-граф документации в `docs/wiki/`; наполнение через `iwiki:iwiki-ingest` из исходников.
```
Replace with:
```
iwiki — embedding-граф документации в MCP-сервере (доменная модель); запись страниц через `wiki_write_page` + `wiki_index`.
```
Then find:
```
IF exists("{CWD}/docs/wiki/") AND validation_passed:
  (опционально) Skill(skill="iwiki:iwiki-ingest") → создать/обновить страницу агента в docs/wiki/
    (name, description, tools, permissionMode — что и почему)

  Результат: спецификации агентов попадают в docs/wiki —
  переиспользуются как паттерны при создании следующих агентов.
```
Replace with:
```
IF wiki_status сообщает домен проекта AND validation_passed:
  (опционально) author markdown → wiki_write_page(domain, slug, markdown, source) → wiki_index(domain)
    страница агента (name, description, tools, permissionMode — что и почему)

  Результат: спецификации агентов попадают в домен iwiki —
  переиспользуются как паттерны при создании следующих агентов.
```

- [ ] **Step 3: prd-generator — Query gate**

Find:
```
IF project_context.wiki_initialized == true:
  Skill(skill="iwiki:iwiki-query", args='Product Requirements Documents и требования к продуктам')
```
Replace with:
```
IF project_context.wiki_initialized == true:
  wiki_search(query='Product Requirements Documents и требования к продуктам')
```

- [ ] **Step 4: prd-generator — Record prose + block**

Find:
```
iwiki — embedding-граф документации в `docs/wiki/`; наполнение через `iwiki:iwiki-ingest` из исходников.
```
Replace with:
```
iwiki — embedding-граф документации в MCP-сервере (доменная модель); запись страниц через `wiki_write_page` + `wiki_index`.
```
Then find:
```
IF project_context.wiki_initialized == true AND status IN ("success", "partial"):
  (опционально) Skill(skill="iwiki:iwiki-ingest") → создать/обновить страницу в docs/wiki/
    с целями продукта и целевой аудиторией (что и почему), ссылаясь на docs/prd/

  Результат: бизнес-цели и продуктовые паттерны попадают в docs/wiki —
  доступны для iwiki-query в следующих PRD.
```
Replace with:
```
IF project_context.wiki_initialized == true AND status IN ("success", "partial"):
  (опционально) author markdown → wiki_write_page(domain, slug, markdown, source) → wiki_index(domain)
    цели продукта и целевая аудитория (что и почему), ссылаясь на docs/prd/

  Результат: бизнес-цели и продуктовые паттерны попадают в домен iwiki —
  доступны для wiki_search в следующих PRD.
```

- [ ] **Step 5: prompt-verifier — Query gate**

Find:
```
IF exists("{CWD}/docs/wiki/"):
  Skill(skill="iwiki:iwiki-query", args='паттерны нарушений и best practices форматирования инструкций')
```
Replace with:
```
IF iwiki MCP подключён AND wiki_status сообщает домен проекта (привязать через wiki_bind):
  wiki_search(query='паттерны нарушений и best practices форматирования инструкций')
```

- [ ] **Step 6: prompt-verifier — Record prose + block**

Find:
```
iwiki — embedding-граф документации в `docs/wiki/`; наполнение через `iwiki:iwiki-ingest` из исходников.
```
Replace with:
```
iwiki — embedding-граф документации в MCP-сервере (доменная модель); запись страниц через `wiki_write_page` + `wiki_index`.
```
Then find:
```
IF exists("{CWD}/docs/wiki/") AND mode == "adapt" AND violations_found > 0:
  (опционально) Skill(skill="iwiki:iwiki-ingest") → создать/обновить страницу с примером нарушения
    и его исправлением (что и почему), ссылаясь на {verified_file_path}

  Результат: примеры нарушений и исправлений попадают в docs/wiki —
  переиспользуются как эталоны при следующих проверках документов.
```
Replace with:
```
IF wiki_status сообщает домен проекта AND mode == "adapt" AND violations_found > 0:
  (опционально) author markdown → wiki_write_page(domain, slug, markdown, source) → wiki_index(domain)
    пример нарушения и его исправление (что и почему), ссылаясь на {verified_file_path}

  Результат: примеры нарушений и исправлений попадают в домен iwiki —
  переиспользуются как эталоны при следующих проверках документов.
```

- [ ] **Step 7: Verify all three**

Run: `grep -nE "iwiki:iwiki-|docs/wiki/" .nvm-isolated/.claude-isolated/skills/{agent-builder,prd-generator,prompt-verifier}/SKILL.md`
Expected: no matches.

- [ ] **Step 8: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/agent-builder/SKILL.md .nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md .nvm-isolated/.claude-isolated/skills/prompt-verifier/SKILL.md
git commit -m "feat(skills): migrate agent-builder/prd-generator/prompt-verifier iwiki integration to MCP

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Disable the plugin

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/settings.json`

- [ ] **Step 1: Flip the enablement flag**

Find: `"iwiki@iclaude": true`
Replace with: `"iwiki@iclaude": false`

- [ ] **Step 2: Scan for any other iwiki hook entries**

Run: `grep -nE "iwiki" .nvm-isolated/.claude-isolated/settings.json`
Expected: only the `"iwiki@iclaude": false` line. If any iwiki hook command entries exist elsewhere, remove those entries (and report them). If only the flag matches, no further edit.

- [ ] **Step 3: Validate JSON**

Run: `python3 -m json.tool .nvm-isolated/.claude-isolated/settings.json >/dev/null && echo OK`
Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/settings.json
git commit -m "chore(iwiki): disable plugin (iwiki@iclaude=false), MCP server supersedes it

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Remove install machinery

**Files:**
- Delete: `lib/iwiki/detect.sh`, `lib/iwiki/install.sh` (whole `lib/iwiki/` dir)
- Modify: `iclaude.sh`, `lib/command/usage.sh`, `lib/config/env-map.sh`, `lib/core/init.sh`

- [ ] **Step 1: Remove the iclaude.sh sourcing block (Phase 8.0.1)**

Find (around lines 114–118):
```
# Load iwiki modules (Phase 8.0.1)
```
Delete the whole block: the comment line, the `if [[ -d "$LIB_DIR/iwiki" ]]; then` guard, the two `source` lines for `detect.sh`/`install.sh`, and its closing `fi`. (Read the exact lines first; remove only this block.)

- [ ] **Step 2: Remove the --install-iwiki dispatch case**

Find (around lines 510–512):
```
            --install-iwiki)
```
Delete the `--install-iwiki)` case branch including its `install_iwiki` call and `;;` terminator.

- [ ] **Step 3: Remove the usage line**

In `lib/command/usage.sh` find:
```
  --install-iwiki                   Install iwiki engine (uv + Python 3.12) and register the plugin
```
Delete this line.

- [ ] **Step 4: Remove the env-map export call**

In `lib/config/env-map.sh` find (lines 62–64):
```
    # Export the canonical iwiki engine dir on every launch (function lives in
    # lib/iwiki/detect.sh; absent when iwiki is not installed -> silently skip).
    command -v iwiki_export_engine_dir >/dev/null 2>&1 && iwiki_export_engine_dir
```
Delete these three lines.

- [ ] **Step 5: Fix the init.sh comment**

In `lib/core/init.sh` find (line 108):
```
    # uv binary (isolated). Used by iwiki engine + hooks.
```
Replace with:
```
    # uv binary (isolated). Used by the dormant iwiki plugin engine when run manually.
```

- [ ] **Step 6: Delete the lib/iwiki directory**

```bash
git rm lib/iwiki/detect.sh lib/iwiki/install.sh
```

- [ ] **Step 7: Verify no dangling references and clean parse**

Run:
```bash
grep -rnE "install_iwiki|iwiki_export_engine_dir|--install-iwiki|IWIKI_ENGINE_DIR" lib/ iclaude.sh
bash -n iclaude.sh && for f in lib/**/*.sh; do bash -n "$f"; done && echo PARSE_OK
./iclaude.sh --help 2>&1 | grep -i iwiki || echo "NO_IWIKI_IN_HELP"
```
Expected: grep returns nothing; `PARSE_OK`; `NO_IWIKI_IN_HELP`.

- [ ] **Step 8: Commit**

```bash
git add iclaude.sh lib/command/usage.sh lib/config/env-map.sh lib/core/init.sh lib/iwiki
git commit -m "refactor(iwiki): remove --install-iwiki and lib/iwiki install machinery

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Remove config block + wiki data

**Files:**
- Modify: `.claude_config.example`
- Delete: `docs/wiki/` (tracked content + `.iwiki/` index)

- [ ] **Step 1: Remove the iwiki block from .claude_config.example**

Open `.claude_config.example`. Delete the contiguous iwiki configuration block (begins at the `#  iwiki (embedding-граф документации, плагин в репозитории)` header, around line 383, through the last `# ICLAUDE_IWIKI_SYNC_MAX_ASK="2"` line, around line 442). Remove the whole commented block and any blank separator line that becomes orphaned.

- [ ] **Step 2: Verify .iwikiignore is untouched**

Run: `test -f .iwikiignore && echo KEPT`
Expected: `KEPT`.

- [ ] **Step 3: Delete the wiki data directory**

```bash
git rm -r docs/wiki
```

- [ ] **Step 4: Verify**

Run: `test ! -e docs/wiki && echo GONE; grep -nE "IWIKI|iwiki" .claude_config.example || echo NO_IWIKI_CONFIG`
Expected: `GONE` and `NO_IWIKI_CONFIG`.

- [ ] **Step 5: Commit**

```bash
git add .claude_config.example docs/wiki
git commit -m "chore(iwiki): drop .claude_config.example iwiki block and docs/wiki data (moved to MCP)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: Remove iwiki tests

**Files:**
- Delete: `tests/test_iwiki_engine_entrypoint.sh`, `tests/test_iwiki_hook_failopen.sh`, `tests/test_iwiki_hooks.py`, `tests/test_iwiki_lint.py`

- [ ] **Step 1: Confirm no runner references them**

Run: `grep -rnE "test_iwiki" --include=*.sh --include=Makefile --include=*.mk --include=*.json --include=*.yml --include=*.yaml . | grep -v "^./tests/test_iwiki"`
Expected: no matches (nothing else references these tests).

- [ ] **Step 2: Delete the four test files**

```bash
git rm tests/test_iwiki_engine_entrypoint.sh tests/test_iwiki_hook_failopen.sh tests/test_iwiki_hooks.py tests/test_iwiki_lint.py
```

- [ ] **Step 3: Verify gone**

Run: `ls tests/ | grep iwiki || echo NO_IWIKI_TESTS`
Expected: `NO_IWIKI_TESTS`.

- [ ] **Step 4: Commit**

```bash
git add tests
git commit -m "test(iwiki): remove decommissioned in-repo integration tests

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 10: Rewrite README iwiki sections

Rewrite the three iwiki regions to the MCP model: remove `--install-iwiki`, `/iwiki-*`, and `docs/wiki/` references; describe the MCP server + `wiki_*` tools; fix the project-tree lines.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Rewrite "Граф документации (iwiki)" (≈258–292)**

Read the section `### Граф документации (iwiki)` through the line ending `bash-обёртка для установки — в \`lib/iwiki/\`.` Replace it with an MCP-oriented description:
```
### Граф документации (iwiki)

Документационный граф проекта обслуживает **MCP-сервер iwiki** — внешний central-store,
адресуемый доменами (один проект = один домен). Поиск, чтение и запись страниц выполняются
инструментами `wiki_*` напрямую из сессии.

| Инструмент | Назначение |
|---|---|
| `wiki_status` / `wiki_bind` | Определить домен проекта и привязать read/write |
| `wiki_search "вопрос"` | Семантический поиск по домену → секции + ссылки |
| `wiki_read_page` / `wiki_write_page` | Чтение и запись страниц домена |
| `wiki_index` | Переиндексация после записи (writes не индексируются автоматически) |
| `wiki_lint` | Здоровье домена: битые `[[refs]]`, сироты, устаревшие секции |
| `wiki_related` | Связанные секции по графу `[[refs]]` |

Исходник плагина сохранён в `plugin/iwiki/` (в архивном виде, отключён); активная работа
идёт через MCP-сервер.
```

- [ ] **Step 2: Rewrite the IDD↔iwiki workflow region (≈350–397)**

In the `## Workflow разработки: IDD → iwiki → brainstorm` region, replace the command examples and prose:
- `/iwiki-ingest <файл>     ← обновить страницу docs/wiki/ из исходника` → `wiki_write_page + wiki_index  ← записать/обновить страницу домена iwiki`
- `/iwiki-lint              ← проверить здоровье docs/wiki/` → `wiki_lint                     ← проверить здоровье домена iwiki`
- In "Как работает IDD с iwiki", replace `/iwiki-query <тема>` references with `wiki_search "<тема>"` and `docs/wiki/` with "домен iwiki".
- Remove the `# Первичная настройка iwiki (один раз на машину)` / `./iclaude.sh --install-iwiki` lines (the MCP server replaces local install).
- Replace `# В сессии: /iwiki-ingest <путь>` with `# В сессии: author markdown → wiki_write_page → wiki_index`.
- Replace `IDD автоматически обогатит контекст через /iwiki-query` with `IDD автоматически обогатит контекст через wiki_search`.
- In the table, `\`iwiki\` | Граф документации: … в \`docs/wiki/\`` → `iwiki | Граф документации (MCP-сервер, домены): архитектурные решения, WHY, \`[[ссылки]]\``.

- [ ] **Step 3: Fix the project-tree lines (≈463–464)**

Find:
```
├── lib/iwiki/       — движок документации (iwiki: detect + install)
├── plugin/iwiki/    — iwiki плагин (Python-движок + slash-команды)
```
Replace with:
```
├── plugin/iwiki/    — iwiki плагин, архивный/отключён (Python-движок + slash-команды); работа идёт через MCP-сервер
```

- [ ] **Step 4: Verify**

Run: `grep -nE "/iwiki-query|/iwiki-lint|/iwiki-ingest|--install-iwiki|docs/wiki/|lib/iwiki/" README.md`
Expected: no matches.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs(iwiki): rewrite README iwiki sections for the MCP server

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 11: Final verification sweep

**Files:** none (verification + one summary commit if needed).

- [ ] **Step 1: Success criterion 1 — no live plugin usage in migrated surfaces**

Run:
```bash
grep -rnE "iwiki:iwiki-|/iwiki-query|/iwiki-lint|/iwiki-ingest|iwiki_engine|docs/wiki/" \
  .nvm-isolated/.claude-isolated/CLAUDE.md \
  .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/intent/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/agent-builder/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/prompt-verifier/SKILL.md \
  README.md
```
Expected: matches only in changelog/history lines (e.g. context-awareness older changelog), no live "use X" directives.

- [ ] **Step 2: Success criterion 2 — no dangling shell symbols**

Run: `grep -rnE "install_iwiki|iwiki_export_engine_dir|--install-iwiki|IWIKI_ENGINE_DIR" lib/ iclaude.sh`
Expected: no matches.

- [ ] **Step 3: Success criterion 3 — clean parse + help**

Run:
```bash
bash -n iclaude.sh && for f in lib/**/*.sh; do bash -n "$f" || echo "PARSE_FAIL $f"; done && echo PARSE_OK
./iclaude.sh --help >/dev/null 2>&1 && echo HELP_OK
```
Expected: `PARSE_OK` and `HELP_OK`.

- [ ] **Step 4: Success criterion 4 — files removed / retained**

Run:
```bash
for p in lib/iwiki docs/wiki tests/test_iwiki_engine_entrypoint.sh tests/test_iwiki_hook_failopen.sh tests/test_iwiki_hooks.py tests/test_iwiki_lint.py; do test ! -e "$p" && echo "GONE $p" || echo "STILL_PRESENT $p"; done
test -f .iwikiignore && echo "KEPT .iwikiignore"
grep -qE "IWIKI|iwiki" .claude_config.example && echo "CONFIG_STILL_HAS_IWIKI" || echo "CONFIG_CLEAN"
```
Expected: all `GONE …`, `KEPT .iwikiignore`, `CONFIG_CLEAN`.

- [ ] **Step 5: Success criterion 5 — plugin disabled**

Run: `grep -nE "iwiki@iclaude" .nvm-isolated/.claude-isolated/settings.json`
Expected: `"iwiki@iclaude": false`.

- [ ] **Step 6: Success criterion 6 — remaining tests pass**

The repo has no single runner — `tests/` is a flat dir of individual `*.sh`/`*.py` scripts. Run each non-iwiki script and assert exit 0:
```bash
fail=0
for t in tests/*.sh; do case "$t" in *iwiki*) continue;; esac; bash "$t" >/dev/null 2>&1 || { echo "FAIL $t"; fail=1; }; done
for t in tests/*.py; do case "$t" in *iwiki*) continue;; esac; python3 "$t" >/dev/null 2>&1 || { echo "FAIL $t"; fail=1; }; done
[ "$fail" = 0 ] && echo TESTS_OK
```
Expected: no `FAIL …` lines and `TESTS_OK`; the four iwiki tests are absent. (If a script needs a special invocation — e.g. `pytest` — fall back to the project's documented command for that file.)

- [ ] **Step 7: Confirm plugin folder intact (criterion 8)**

Run: `test -d plugin/iwiki && echo PLUGIN_FOLDER_INTACT`
Expected: `PLUGIN_FOLDER_INTACT`.

- [ ] **Step 8: Confirm Task 1 probe domain residue (optional cleanup note)**

Run: `wiki_list_domains` — if `zz-probe-writeflow` remains and the MCP server exposes a domain-removal path, remove it; otherwise note the residue to the user (no delete tool available).

---

## Self-Review (completed by plan author)

**Spec coverage:** Part 1 §1.1 → Task 2; §1.2 → Task 3; §1.3 → Task 4; §1.4–1.6 → Task 5. Part 2 §2.1 → Task 7; §2.2 → Task 8 (config) + Global Constraint (`.iwikiignore` kept); §2.3 → Task 8 (data); §2.4 → Task 9; §2.5 → Task 6; §2.6 → Task 10. Write-flow open item → Task 1. Success criteria 1–8 → Task 11. "Not touched" (plugin/iwiki, marketplace.json, uv) → Global Constraints. All covered.

**Placeholder scan:** all edits give exact old→new text; verification steps give exact commands + expected output. No TBD/TODO.

**Type/term consistency:** field rename `wiki_index_path`→`wiki_domain` applied uniformly (Task 3 §5 + template + examples + delegates + changelog). Tool names uniform (`wiki_status`/`wiki_bind`/`wiki_search`/`wiki_write_page`/`wiki_index`/`wiki_lint`). Detection gate phrasing consistent across CLAUDE.md and the 5 skills.
