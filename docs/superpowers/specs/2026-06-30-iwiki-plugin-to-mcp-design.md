---
review:
  spec_hash: 5583d4ffd01355ef
  last_run: 2026-06-30
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  findings: []
chain:
  intent: null
---
# iwiki: migrate usage to MCP server + decommission in-repo plugin integration

**Date:** 2026-06-30
**Status:** approved (design)
**Scope:** two parts — (1) rewrite usage instructions to drive the MCP server;
(2) decommission the in-repo iwiki integration, keeping only the `plugin/iwiki/`
source folder (disabled/dormant).

## Problem

The repo ships an in-project iwiki **plugin** (`plugin/iwiki/`: engine CLI, hooks,
skills, commands) plus install/activation machinery (`lib/iwiki/`, `--install-iwiki`,
`.claude_config.example` block, `.iwikiignore`) that stores a documentation graph in
each project's `docs/wiki/` directory. A separate iwiki **MCP server** (project
`iwiki-personal`, central store at `/home/ikeniborn/Documents/Project/iwiki-personal`)
now supersedes it through `mcp__iwiki__wiki_*` tools backed by an external,
domain-keyed store. The project already has a domain `iclaude`.

All iwiki *usage* should move to the MCP server, and the now-redundant in-repo
integration should be removed — leaving only the plugin source folder as a dormant
archive.

## Decisions (locked with user)

1. **Two-part scope:** instruction migration **and** decommission cleanup.
2. **Detection via `wiki_status`** (MCP-native), replacing the `exists docs/wiki/`
   gate. The `docs/wiki/` path is dropped as a concept everywhere.
3. **Full redesign** of integration sections around the MCP domain model
   (`wiki_status` → `wiki_bind` → typed tool calls), not a 1:1 token swap.
4. **Cross-domain search = optional.** Default: the project's bound domain. Cross-domain
   (`wiki_search` with `domains`/`scope`) is mentioned as an opt-in note only.
5. **Keep only `plugin/iwiki/`** folder; remove the rest of the in-repo integration
   (the full cleanup set below).
6. **Disable the plugin:** `settings.json` `iwiki@iclaude` → `false`. Folder stays as
   a dormant archive; its hooks no longer fire.

## MCP tool vocabulary (canonical mapping)

Replaces both the plugin skills and the `iwiki_engine` CLI catalog.

| Operation | Plugin (before) | MCP (after) |
|---|---|---|
| detect / bind | `exists docs/wiki/` | `wiki_status` → `wiki_bind(read, write)` |
| search | `/iwiki-query`, `iwiki:iwiki-query` | `wiki_search(query, domains?, scope?)` |
| related | engine `related` | `wiki_related(domain, section_id)` |
| read page | read `docs/wiki/*.md` | `wiki_read_page(domain, slug)` |
| write / update page | `iwiki:iwiki-ingest` | author markdown → `wiki_write_page(domain, slug, markdown, source)` |
| reindex | engine `index` | `wiki_index(domain)` |
| health | `/iwiki-lint` | `wiki_lint(domain?)` |
| list | — | `wiki_list_domains` / `wiki_list_pages(domain)` |
| new domain | `iwiki-init` | `wiki_create_domain(name)` |

**Detection / binding flow** (canonical, reused by every instruction surface):
```
1. wiki_status → project_dir, available `domains`, current `read`/`write` binding
2. If a domain for this project exists in `domains` (convention: name == project
   basename) but read/write is unbound → wiki_bind(read=[<domain>], write=<domain>)
   → subsequent tool calls omit the explicit `domain` arg
3. If no domain exists → iwiki is "not set up"; skip silently (do not auto-create
   unless the task is explicitly about initializing iwiki)
```

**Write flow** (replaces `iwiki-ingest` auto-generation): the model authors the page
markdown itself, then `wiki_write_page(domain, slug, markdown, source=<changed source
path>)`. The plugin skill generated the page from a source; the MCP tool only persists
caller-supplied markdown — instructions must make the authoring step explicit.

**Open item (resolve during implementation):** does `wiki_write_page` auto-reindex, or
must `wiki_index(domain)` follow it? Verify before finalizing write-flow wording. If
unknown, instructions say "`wiki_write_page`, then `wiki_index` if not yet searchable."

---

## Part 1 — Instruction migration to MCP

### 1.1 `.nvm-isolated/.claude-isolated/CLAUDE.md` (global instructions)

**Getting Started** (lines ~9–23): replace the `docs/wiki/` gate + `/iwiki-query` /
`/iwiki-lint` calls with the MCP flow:
```
1. iwiki context (if the iwiki MCP server is connected):
   - wiki_status → domains, project_dir, read/write binding
   - project domain present but unbound → wiki_bind(read=[<domain>], write=<domain>)
   - wiki_search(<task topic>) → relevant sections
   - wiki_lint → doc health
2. tree -L 2 docs/ — structural overview (project docs ≠ wiki; unchanged)
```

**Keep Docs Current** (lines ~25–32):
- gate `already has a docs/wiki/` → `has a bound iwiki domain (wiki_status)`
- `iwiki:iwiki-ingest <source>` → author/update markdown → `wiki_write_page(...)`
  (+ `wiki_index` per open item)
- `/iwiki-lint` → `wiki_lint`
- the paragraph "Always invoke iwiki via its **skills** … `iwiki_engine` CLI exposes
  index | search | related | status | lint" → replace wholesale with the MCP tool
  catalog: "Always use the iwiki MCP tools (`wiki_status`, `wiki_bind`, `wiki_search`,
  `wiki_related`, `wiki_read_page`, `wiki_write_page`, `wiki_index`, `wiki_lint`,
  `wiki_list_domains`, `wiki_list_pages`, `wiki_create_domain`) — never the old plugin
  skills or engine CLI."

### 1.2 `skills/context-awareness/SKILL.md`

- **§5 iwiki Detection**: replace `IF exists {CWD}/docs/wiki/` + index-file read with
  `wiki_status` (+ `wiki_list_domains` if needed). Output fields:
  - `wiki_initialized` ← project domain bound/present?
  - `wiki_domain` ← domain name (new)
  - `wiki_summary` ← `wiki_read_page(domain, "overview")` or `wiki_search`
  - **drop** `wiki_index_path`
- Update the `### 5.` prose to describe the MCP domain instead of `docs/wiki/`.
- **description** frontmatter: "detects the docs/wiki/ iwiki documentation graph" →
  "detects the iwiki MCP domain for this project".
- **dependencies / delegates**: `iwiki:iwiki-query` → iwiki MCP (`wiki_search`).
- Add a changelog entry documenting the plugin→MCP switch.

### 1.3 `skills/intent/SKILL.md`

- **Step 0**: gate `exists docs/wiki/` → `wiki_status`; `Skill(iwiki:iwiki-query …)` →
  `wiki_search(<topic>)`; present "Context from iwiki domain `<name>`".

### 1.4–1.6 `skills/agent-builder`, `skills/prd-generator`, `skills/prompt-verifier`

Each has an "iwiki Integration" section with the same gate→Query→Record shape:
- gate `exists("{CWD}/docs/wiki/")` → `wiki_status` (project domain bound?)
- **Query**: `Skill(iwiki:iwiki-query, args=…)` → `wiki_search(query=…)`
- **Record**: `Skill(iwiki:iwiki-ingest)` → author markdown → `wiki_write_page(domain,
  slug, markdown, source)` (+ `wiki_index` per open item)
- Replace the "iwiki — embedding-граф документации в `docs/wiki/`" prose with the MCP
  domain description.

---

## Part 2 — Decommission in-repo integration

Keep only `plugin/iwiki/`. Remove everything below.

### 2.1 Install machinery
- Delete `lib/iwiki/detect.sh` and `lib/iwiki/install.sh` (the whole `lib/iwiki/` dir).
- `iclaude.sh`: remove the Phase 8.0.1 sourcing block (lines ~114–118,
  `if [[ -d "$LIB_DIR/iwiki" ]] … source detect.sh/install.sh`) and the
  `--install-iwiki)` case (lines ~510–512, `install_iwiki`).
- `lib/command/usage.sh`: remove the `--install-iwiki` help line (63).
- `lib/config/env-map.sh`: remove the `iwiki_export_engine_dir` call (lines 62–64).
- `lib/core/init.sh`: update the line-108 comment that claims uv is "Used by iwiki
  engine + hooks" (uv bootstrap itself stays — the dormant plugin engine may still be
  run manually; do not remove the uv install without separate confirmation).

### 2.2 Config
- Remove the iwiki block in `.claude_config.example` (lines 383–442).
- Delete `.iwikiignore` (repo root).

### 2.3 Wiki data
- Delete `docs/wiki/` (content + `.iwiki/` index). Data now lives in the MCP domain.

### 2.4 Tests
- Remove `tests/test_iwiki_engine_entrypoint.sh`, `tests/test_iwiki_hook_failopen.sh`,
  `tests/test_iwiki_hooks.py`, `tests/test_iwiki_lint.py`. They guard the decommissioned
  in-repo integration and require the install path being deleted. No external test
  runner references them (verified). This retires iwiki from CI; the plugin source
  remains as a dormant archive.

### 2.5 Plugin disable
- `settings.json` (`.nvm-isolated/.claude-isolated/settings.json`): `iwiki@iclaude`
  `true` → `false`. Check for any iwiki hook entries elsewhere in settings.json and
  remove if present.

### 2.6 README
- Rewrite the iwiki sections to the MCP model (or trim): "Граф документации (iwiki)"
  (258–292), "Workflow разработки: IDD → iwiki" (350–397), and the project-tree lines
  (463–464, which list `lib/iwiki/` and describe the plugin). Remove `--install-iwiki`,
  `/iwiki-*`, and `docs/wiki/` references; point to the MCP tools.

---

## Not touched

- `plugin/iwiki/**` — source folder kept intact, but disabled via settings.
- `.claude-plugin/marketplace.json` iwiki entry — leaves the (disabled) plugin
  registered; folder still resolves. Out of cleanup set.
- Historical records under `docs/superpowers/{specs,plans,intents,reports}/**`.

## Success criteria

1. `grep -rn "iwiki:iwiki-\|/iwiki-query\|/iwiki-lint\|/iwiki-ingest\|iwiki_engine\|docs/wiki/"`
   over the migrated instruction files (CLAUDE.md + 5 skills) + README returns **zero**
   live usage directives (changelog history lines excepted).
2. `grep -rn "install_iwiki\|iwiki_export_engine_dir\|--install-iwiki\|IWIKI_ENGINE_DIR"`
   over `lib/`, `iclaude.sh`, `lib/command/usage.sh` returns **zero**.
3. `bash -n iclaude.sh` and every `lib/**/*.sh` parse cleanly; `./iclaude.sh --help`
   runs without referencing iwiki and without errors from removed sourcing.
4. `lib/iwiki/`, `.iwikiignore`, `docs/wiki/`, and the four `tests/test_iwiki_*` files
   are gone; `.claude_config.example` has no iwiki block.
5. `settings.json` has `iwiki@iclaude: false`; no orphaned iwiki hook entries.
6. The remaining test suite passes (run after cleanup).
7. Migrated surfaces drive the MCP server (detection via `wiki_status`, search via
   `wiki_search`, writes via `wiki_write_page`, health via `wiki_lint`); the
   detection/bind and write flows read coherently and are self-contained per skill.
8. `plugin/iwiki/` folder intact.

## Verification / order of work (for the plan)

1. Part 1 instruction edits (CLAUDE.md + 5 skills).
2. Part 2 decommission: disable plugin → remove install wiring → remove config →
   remove `docs/wiki/` → remove tests → README.
3. Resolve the `wiki_write_page` reindex open item against the live MCP server.
4. Verify: greps (criteria 1–2), `bash -n` + `--help` (criterion 3), file absence
   (criterion 4), settings (criterion 5), remaining tests (criterion 6).
