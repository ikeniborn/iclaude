# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## Getting Started

**Load docs before exploring code — they encode decisions invisible in raw code.**

## Skill Availability

The skill catalog injected into the current turn is authoritative. Never mark a listed
skill unavailable because a filesystem scan, `find`, or `rg` did not locate its
`SKILL.md`; invoke it through the `Skill` tool with the catalog name. Report a skill as
unavailable only when it is absent from that catalog or the `Skill` call itself fails.

At the start of any task in an unfamiliar area, or after a gap of more than 1 day:

1. **If the iwiki MCP server is connected**, apply the project binding (see **iwiki Project Binding** below), then `wiki_search(query="<task topic>")` → retrieve relevant sections; `wiki_lint` → check doc health. (No server / no `.iwiki.toml` → skip; iwiki is not set up for this project.)
2. Map the `docs/` layout into context (complements iwiki's semantic search with a structural overview):
   ```bash
   tree -L 2 docs/ || find docs -maxdepth 2 | sort   # fallback when `tree` is absent
   ```
   Depth `-L 2` is chosen for the current project — its `docs/` nests at most 2 directory
   levels (e.g. `docs/superpowers/specs/`), so level 2 shows the full directory skeleton plus
   top-level files without flooding context with every leaf file. Raise the level for deeper trees.

Skip only when: familiar area, same session.

## iwiki Project Binding (MANDATORY)

**One protocol for every wiki call, in every skill, in every mode.** The project-root
`.iwiki.toml` is the only source of the binding.

1. Read exactly three keys from `.iwiki.toml`: `read`, `write`, `primary`. Normalize the
   domain names. Never pass TOML text, paths, `base`, `iwiki_id`, tokens, or any other
   credential to a tool.
2. Call `wiki_bind(read=<read>, write=<write>, primary=<primary>)` with the **full**
   values — before `wiki_status`, `wiki_search`, task-ledger, or any other wiki call.
3. Then call `wiki_status` to confirm the effective scope.

Never narrow the binding to one domain and never infer a domain from the project
basename: the project's read scope routinely spans shared domains (e.g. `devops`), and
narrowing it hides the standards those domains carry. `primary` is the write target for
`wiki_write_page` / `wiki_update_page` / `wiki_index`; `write` is the full set of domains
that may be mutated.

No `.iwiki.toml`, an invalid scope, or a rejected bind (e.g. 403): report the reason
briefly, make no mutating wiki calls, and retain task lifecycle `completion-pending`. On
a hosted server the token's own grants remain the absolute authorization limit.

## Keep Docs Current (MANDATORY)

**After every change that alters functionality, architecture, or behavior — and only when the project binding succeeded (see **iwiki Project Binding**) — update the wiki via the MCP tools before responding to the user.**

- Pick the write tool by intent — all three auto-reindex the domain and auto-commit the base on success, so no manual `wiki_index` follows:
  - **New page** → `wiki_write_page(domain, slug, markdown, source=<changed-source>)`. Refuses to overwrite an existing page.
  - **Existing page** → `wiki_update_page(domain, slug, heading, new_body, source=<changed-source>)`. Rewrites one `##` section in place.
  - **Stale / removed source** → `wiki_delete_page(domain, slug)`. Drops the page and its vectors.
- Call `wiki_index(domain)` only to rebuild after out-of-band edits (markdown changed on disk without a tool) or a sync conflict — never as a routine step after a write.
- Run `wiki_lint` — no broken `[[refs]]`, no orphan or stale pages. Task pages (`reference/tasks/*`) and their history segments (`reference/task-history/*`) are exempt from the orphan check by design.
- Writes auto-commit the base locally; `wiki_sync` publishes those commits to the git remote (pull-rebase-push) — run it only when sharing the base across machines.
- Skip only for changes that touch no functionality, architecture, or behavior (typo, comment, formatting).

Always use the iwiki MCP tools (`wiki_status`, `wiki_bind`, `wiki_search`, `wiki_related`, `wiki_read_page`, `wiki_list_domains`, `wiki_list_pages`, `wiki_write_page`, `wiki_update_page`, `wiki_delete_page`, `wiki_index`, `wiki_create_domain`, `wiki_lint`, `wiki_sync`) — never the old plugin skills or the `iwiki_engine` CLI.

## Keep README Current (MANDATORY)

**After every change that alters functionality, behavior, usage, or setup — if the project has a `README.md` (and/or a localized `docs/README.ru.md`) — update it in the same task, before responding to the user.**

These files are the entry point for two audiences at once: business users who need to know what the project does and why it's useful, and technical specialists who need to know how to install, configure, and run it. Keep them true to the current code.

- **Scope of the update.** Reflect the change in whichever of these the file covers: what the project does and its value (business framing), features and capabilities, install / setup / configuration steps, usage instructions and examples, commands, flags, environment variables, and any versions or requirements you touched.
- **Both files stay in sync.** If both `README.md` and `docs/README.ru.md` exist, apply the same content change to both. `README.md` follows the documentation language (English); `docs/README.ru.md` is the Russian translation of the same information — keep them equivalent, only the language differs.
- **Only when they exist.** Do not create a `README.md` or `docs/README.ru.md` that the project does not already have unless the user asks. If only one of the two exists, update that one.
- **This is separate from the iwiki wiki.** The wiki (above) is internal/semantic documentation; the README files are the public, human-facing docs. Updating one does not exempt you from the other — do both when both apply.
- **Skip only for changes that touch no functionality, behavior, usage, or setup** (typo, comment, internal formatting).

## Task Log (iwiki, MANDATORY)

**Every task — direct, chain, or LoEn, including small fixes and read-only analysis — is tracked as one wiki page in the project's primary write domain: opened before task-specific analysis or implementation, updated at every material event, closed only when delivery is confirmed.** This follows the shared standard `devops/concept/wiki-task-ledger`. There is no in-repo task file. The `task-ledger` skill carries the operational detail — page shape, event schema, spool helper, and boundaries; the rules below stay authoritative.

Bounded discovery comes first and creates nothing: read the request, the project binding, and the minimum repository context needed to derive the domain, the `<topic>`, and the route. Then open the page — before analysing the task itself.

- **Preconditions.** Apply the **iwiki Project Binding** protocol, then write to `primary`. If the server is unreachable, say `Tracking: unavailable`, spool the redacted events with the `task-ledger` skill's `scripts/task_spool.py` to `$CLAUDE_CONFIG_DIR/state/iwiki-task-spool/<project>/<topic>.json`, continue working — but the task cannot reach `done`.
- **One page per topic**, slug `reference/tasks/<topic>`, frontmatter passed as tool parameters only: `type: reference`, `status: stable`, `tags: [task, <topic>, workflow:<direct|chain|loen>]`. Never put frontmatter inline in `markdown` — the server duplicates it and `wiki_lint` blocks on `pre_h2_text`.
- **No index page.** Project status is derived by enumerating task pages with `wiki_list_pages(domain)` filtered to the `reference/tasks/` prefix; use `wiki_search(query=..., tags=["task"])` only for content lookup within a topic.
- **Domain changelog** at `reference/domain-changelog` records only material domain-level changes — standards, releases, migrations, cross-task decisions — each linking to the relevant task page. It is not a task index and never repeats routine task events.
- **Five `##` sections, each once, never renamed or reordered**: `Current State`, `TODO`, `Subtasks`, `Evidence`, `Changelog`. No `###`. Each section opens with a lead of at most 250 characters, then a blank line.
- **History segments.** The event history lives in `reference/task-history/<topic>-<sequence>` pages, same frontmatter as the task page, two `##` sections: `Events` (at most 20, ordered, oldest first) and `Next` (the successor slug, or `none`). `Changelog` on the task page is a manifest only — first segment, active segment, event count. A new event rewrites the active segment alone; at 20 events open `<topic>-<sequence+1>` and point `Next` at it. Replay traverses the segment chain to load durable keys before appending.
- **Lifecycle** in the body: `in-progress`, `blocked`, `completion-pending`, `done`.
- **Single writer.** Only the parent agent writes. Subagents are read-only against the wiki (`wiki_search`, `wiki_read_page`, `wiki_related`) and return structured evidence — subtask id, role, outcome, changed paths, checks, blockers, proposed changelog text — which the parent records. Hooks never reach MCP; loop hooks write `docs/loen/<topic>/` and the parent mirrors loop state at four material stage boundaries: loop start (plan approved, `loop.yaml` armed) → `open`/`route`; each `loop-check` verdict → `verification`; each `loop-reflect` decision of `fix`, `revert`, or `handoff` → `decision`/`blocker`; the terminal `7_result.md` or `handoff.md` → `close`. Per-iteration act steps and hook-rendered `audit.html` refreshes are not mirrored.
- **Write points.** `open` before any task-specific analysis or implementation, after bounded discovery only; `route` when the workflow or model route is decided; `verification` at each `/check-chain` verdict or loop-check; `dispatch` before delegating and `return` when the subagent answers; `blocker` when blocked; `close` at the end. Tool calls are not events.
- **Idempotency.** Every segment event carries `key:` = `sha256(topic \n kind \n canonical redacted evidence)` truncated to 16 chars. Timestamp, actor, and the human-readable summary must not enter the key — otherwise a replay of the same fact appends a duplicate. An event whose key is present anywhere in the segment chain is not appended again. Entries are append-only; rewriting one is proposal-first and only to repair malformed or secret-bearing content.
- **Close is fail-closed.** `done` requires final evidence recorded, every spooled event delivered, and `wiki_lint` reporting no new finding for the task page or its segments. An `orphan` entry for `reference/tasks/*` or `reference/task-history/*` is the expected advisory — refusing a central index leaves those pages unreachable by link — and never blocks closure; any other finding does. Until then the task stays `completion-pending`.
- **Divergence** from the shared standard is recorded on `devops/concept/wiki-task-ledger` before it is implemented.

## Task Topic

**Every task must define one canonical `<topic>` before work starts.**

- `<topic>` is a semantic, English, lowercase kebab-case slug: words joined by hyphens, e.g. `thread-title-task-naming-policy`.
- Use the same `<topic>` across every controlled surface:
  - the wiki task page slug `reference/tasks/<topic>`;
  - chain artifact names in `docs/superpowers/`, for IDD→SDD work;
  - LoEn topic directory `docs/loen/<topic>/`, for LoEn loop work;
  - git branch suffix: `dev-<topic>`.
- Do not use vague topics such as `fix`, `update`, `work`, `misc`, `phase1`, or `changes`.
- Do not start a topic with `task`: the topic becomes a wiki tag next to the base tag `task`, and `wiki_lint` reports the pair as `tag_drift`.
- Prefer topics that describe the task domain and intended outcome, not just the implementation step.
- If a branch already exists, derive `<topic>` from the branch suffix unless it is vague.
- If controlled artifacts (task page slug, chain/LoEn topic, branch name) disagree, stop and normalize them to one `<topic>` before continuing.

## Workflow Route Selection

Classify the workflow before invoking `fix-intent`, `superpowers:brainstorming`, or
creating chain artifacts. Superpowers skills are selected tools; using an applicable
scoped skill does not by itself select `chain`. **This rule overrides generic Superpowers
wording that treats every behavior change as requiring brainstorming, and overrides
`fix-intent`'s own "before brainstorming for any non-trivial work" trigger.**

Before selecting a workflow, perform bounded routing discovery: read the request,
relevant documentation, affected code entrypoints, contracts, and available tests. This
discovery creates no chain artifacts and is not implementation. It may use safe,
non-mutating inspection or reproduction.

Absence of evidence is not evidence for chain. Recommend **direct** when discovery shows
the request or diagnosis is bounded, no chain trigger is evidenced, and a verification
or next discovery step is known. Unknown defect cause alone starts scoped debugging, not
chain. Typical examples: known-cause local fixes, typos, formatting, focused tests for
existing behavior, mechanical configuration or documentation edits, and read-only review.

Recommend **chain** only when the user explicitly requests it or discovery shows that a
durable approved intent is needed for a new capability or module, a public contract,
schema or migration, security/concurrency/transaction/data-invariant behavior, or coupled
subsystem work. Chain does not imply spec and plan: that decision occurs only after
`/check-chain intent` returns `OK`.

After intent validation, perform intent-scoped repository analysis and recommend
`execute` by default when implementation and verification are bounded. It implements
directly from the approved intent and marks Spec and Plan `n/a`. Recommend `full` only when
both an enumerated design-risk category and a named unresolved design decision are present:
a new module boundary, public compatibility strategy, architecture choice,
schema/migration/security/concurrency/transaction/data-integrity invariant, or coupled
subsystem design. Merely touching one of these areas is insufficient. General uncertainty,
task size, or the word "non-trivial" are not triggers.

Recommend **loen** only for tasks that operate a durable LoEn workspace through its own
loop lifecycle.

At task start, state the recommendation and its evidence. Do not invoke `fix-intent` or
start chain until the user accepts that recommendation; an explicit chain request counts
as acceptance. After intent validation, report `execute` or `full` with evidence and wait
before starting `full`. Prefer `execute` when no full trigger is evidenced.

Direct work creates no formal intent, spec, plan, or `/check-chain` artifacts, but still
gets a wiki task page per the Task Log rule above, and must not invoke `fix-intent`,
`superpowers:brainstorming`, `superpowers:writing-plans`,
`superpowers:subagent-driven-development`, or `superpowers:executing-plans`. Scoped
systematic debugging, TDD, and verification remain allowed.
`superpowers:finishing-a-development-branch` remains available after verified direct or
chain work. If direct scope crosses a chain trigger, stop and recommend chain.

```text
Workflow recommendation: direct | chain | loen
Continuation after intent: execute | full | n/a
Evidence: <bounded facts or qualifying trigger>
Intent required: yes | no
Confirmation required: yes | no
```

## Chain Order

After the user accepts chain, keep selected transitions gated by `/check-chain`:

**LoEn carve-out:** tasks that start, continue, audit, repair, research, review, or
govern durable LoEn workspaces through `loen:loop-*` skills use the LoEn lifecycle
only. Do not run `fix-intent`, `superpowers:brainstorming`, `superpowers:writing-plans`,
`superpowers:subagent-driven-development`, `superpowers:executing-plans`,
`superpowers:finishing-a-development-branch`, or `/check-chain` merely because a LoEn loop
is active — unless the user explicitly chooses the IDD→SDD chain for a separate non-LoEn
change.

1. `fix-intent` creates or updates `docs/superpowers/intents/*-intent.md`.
2. `/check-chain intent` validates the intent.
3. Report the continuation decision (`execute` or `full`) with evidence and wait for the user.
4. For `execute`, skip brainstorming and writing-plans, implement from the approved
   intent with scoped implementation skills, then run `/check-chain result <intent>`.
5. For `full`, run `superpowers:brainstorming` → `/check-chain spec` →
   `superpowers:writing-plans` → `/check-chain plan` → plan execution.
6. Run `/check-chain result <plan>` for `full`; result reconciliation always precedes
   branch finishing.

The hook `.claude-isolated/hooks/chain-gate.py` enforces these transitions on `Skill`,
`Write`, and `Edit` events. It is a transition gate only: validation state still comes
from frontmatter written by the `/check-chain` skill.

## Model and Reasoning Recommendations

For the main session, recommend only; never claim a switch. The user switches with
`/model` and verifies with `/status`. For subagents you dispatch yourself, set the route
directly via the `Agent` tool's `model`/`effort` parameters — no user confirmation needed.

### Execution Routes

Rules refer only to stable semantic routes, never model branding:

| Route | Capability target | Effort target |
|-------|-------------------|---------------|
| `mechanical` | Lowest-cost capable coding model | baseline |
| `engineering` | Balanced general coding model | baseline |
| `synthesis` | Strongest reasoning model for design synthesis | baseline |
| `deep` | Strongest single-agent reasoning model | deep |
| `escalation` | Strongest model after evidenced failure | maximum |
| `parallel-audit` | Strongest model for independent read-only audits | parallel |

### Current Catalog Mapping

Exact model IDs live only here. Update this table when the catalog changes; do not
rewrite classification or workflow rules.

| Route | Current model | Current effort |
|-------|---------------|----------------|
| `mechanical` | `claude-haiku-4-5` | `low` |
| `engineering` | `claude-sonnet-5` | `medium` |
| `synthesis` | `claude-opus-5` | `medium` |
| `deep` | `claude-opus-5` | `high` |
| `escalation` | `claude-opus-5` | `max` |
| `parallel-audit` | `claude-opus-5` | `xhigh` (separate read-only run) |

Resolve the semantic route through this table before recommending a switch. If the mapped
entry is absent from `/model`, keep the semantic route, describe its capability and effort
targets, mark resolution `unresolved`, and ask the user to select the current equivalent.
Never substitute a model by name from memory.

### Checkpoints

Reassess at direct task start, after chain or LoEn checks/reviews, and before next work:

| Boundary | Baseline |
|----------|----------|
| Direct task start → execution | Classify task |
| Direct check/review → next work | Reclassify if evidence changed |
| Start → chain intent or coordination | `engineering` |
| Intent OK → continuation decision | `engineering` |
| Intent execute → implementation | Classify task |
| Intent full → spec | `synthesis` |
| Spec OK → plan | `synthesis` |
| Plan OK → implementation | Classify each task |
| Implementation task complete → task review | `engineering` |
| Task review complete → next task | Classify next task |
| Execution → bounded result check | `engineering` |
| Execution → cross-system or critical result check | `deep` |
| Result OK → routine follow-up | `engineering` |

At LoEn loop start and after each check or review, classify the next work with the same
execution routes. LoEn workflow selection never implies a stronger model.

### Task Transition Gate

A task-scoped recommendation expires when that task reaches review or completion, or
when execution moves to another plan task. Never assume that the recommendation for the
previous task is suitable for the next one.

Before a task that requires a model switch:

1. Identify the next work and classify its execution route independently from current
   evidence.
2. Resolve the recommended exact model and effort through the current catalog mapping.
3. Establish the active exact model and effort from either a successful platform switch
   event after the requested switch or the latest `/status`. If neither is available,
   request `/status` before asking the user to switch.
4. Compare the active and recommended mappings. If they differ, report
   `Switch required: yes`, ask the user to switch with `/model`, and stop before the task.
5. Resume after a successful platform switch event or after the user confirms that
   `/status` shows the recommended mapping; the user may instead explicitly decline the
   switch under the downgrade or escalation rules below.

For `direct` work on the `mechanical` or `engineering` route, report the recommended
mapping but continue when the active mapping is unknown. Do not request `/status` unless
the user asks to change models or evidence reclassifies the task to `synthesis`, `deep`,
or `escalation`.

Apply the same gate when a scope change or newly discovered invariant reclassifies work
inside an active task. A matching active mapping uses `Decision: keep` and does not
require another switch.

This gate governs the main session only. For subagents you dispatch yourself, set the
resolved route directly via the `Agent` tool's `model`/`effort` parameters — no switch
request, no confirmation.

### Classification

Choose the lowest sufficient route:

1. **`mechanical`** only if work is fully defined, single-component, has known cause and
   verification, and changes no contract, schema, migration, concurrency, security, or
   data invariant.
2. **`synthesis`** for specification or planning synthesis without a deep trigger.
3. **`deep`** when evidence shows an unknown reproduced-defect cause, artifact/code
   contradiction, public compatibility change, transactional/concurrent/distributed
   invariants, migration/security/data risk, two or more coupled subsystem boundaries,
   or result reconciliation across coupled invariants.
4. **`engineering`** otherwise.

Never inherit a higher route. File count, task length, one failure, or a stage name are
not triggers. Gather ambiguous evidence at the lower route.

Workflow and execution routes are independent: direct does not imply `mechanical`, and
chain does not imply `deep`. Reclassify at task start, after each check or review, after
a scope change, and after any newly discovered invariant.

For `needs_work`, remain in the stage, change strategy, rerun, and reassess. The verdict
alone never requires escalation.

### Exceptional Routes

Use **`escalation`** only after two different `deep` strategies fail, reviewers
contradict the same invariant, a required test remains unexplained after strategy
change, an enumerated critical invariant set cannot be decomposed safely, or critical
migration reconciliation has credible data-loss risk.

Every critical migration requires a separate final integration review at `deep` or
higher, regardless of its implementation route.

Use **`parallel-audit`** only as a separate run with at least two independent read-only
audit directions, no shared writes, and one consolidation step. Never use it inside
active subagent orchestration.

Implementers never revise accepted intent, spec, or plan. Return drift to the earliest
gate. Never retry without changing strategy.

### Switch Handling

Use `keep`, `downgrade`, `escalate`, or `separate-run` (`parallel-audit`). If the active
mapping is unknown, ask the user to check `/status`, mark switch confirmation `pending`,
and stop before the next task; never guess or inherit the previous task's recommendation.

Wait when switching is required. A successful platform switch event confirms the resulting
mapping; request `/status` only when that event is unavailable. A declined downgrade may
continue with the extra cost recorded and switch confirmation marked `declined`. A declined
escalation stops the next work until explicit risk acceptance, also recorded as `declined`.
Critical-migration final review cannot be waived.

```text
Workflow: direct | chain | loen
Continuation: execute | full | n/a
Checkpoint: <check and verdict>
Next work: <stage or task>
Execution route: <semantic route>
Current mapping: <exact model / effort | unknown>
Recommended mapping: <exact model / effort | unresolved>
Decision: keep | downgrade | escalate | separate-run
Evidence: <artifact, finding, failure, invariant, or risk>
Higher route rejected because: <reason or n/a for parallel-audit>
Switch required: yes | no
Switch confirmation: n/a | pending | confirmed | declined
```

## Project Status Reports

**When the user asks for project status, progress, or "what's the state of X", build the answer from two sources together — never one alone: the project's task pages (what is being worked on) and the project's subject-matter wiki pages (what is documented as true).**

- **Read both first.** Apply the **iwiki Project Binding** protocol; then `wiki_list_pages(domain)` filtered to the `reference/tasks/` prefix for the full set of task pages, and `wiki_search(query=...)` / `wiki_read_page` for the topic's subject-matter pages. If iwiki is unavailable, say so — there is no in-repo fallback.
- **Report shape:** lead with overall state (counts by lifecycle, or the specific topic's `Current State`), then per-topic detail (the `TODO` stages and the latest events from the active history segment named in `Changelog`), then a **Discrepancies** section.
- **Reconcile the two sources and surface every mismatch.** Examples of discrepancies to flag:
  - A task page is `done` but the wiki has no subject-matter page (or a stale one) covering it.
  - The wiki documents a feature/behavior that has no matching task page.
  - A task page records a passed stage but the subject-matter page still describes the old behavior, or `wiki_lint` flags it stale. An `orphan` entry for a task or history page is expected by design, not a discrepancy.
  - Lifecycle, dates, or scope disagree between the two.
  - A task page sits at `completion-pending` with events still spooled.
- **No silent reconciliation.** Report discrepancies; do not fix the task page or the subject-matter page as a side effect of a status request. If none exist, state "task pages and documentation agree" explicitly.
- **Age signal.** List separately every task page whose `Current State` `Opened` is more than 14 days old and whose lifecycle is not `done`; this flags stalled work without changing its lifecycle or closing it automatically.

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
- **Branch naming is mandatory: `dev-<topic>`, created from the selected up-to-date base branch (main by default).** `<topic>` is the canonical slug from **Task Topic**. No exceptions.
- **If the project has long-lived branches beyond `master` / `main` / `prod`** (e.g. `dev`, `develop`, `staging`, `release/*`), always ask first — which branch to base the new `dev-*` off, and which branch to open the PR against. Don't assume.
- **When creating a `dev-*` branch, check existing local `dev-*` branches first.**
  - **No existing `dev-*` branch** → do not offer or create a worktree; create the branch in the main worktree.
  - **Another `dev-*` branch already exists** → ask first: create a worktree for the new branch now?
    - **Yes** → create the branch in a sibling worktree at `../<project>-<branch>` and do all the work there.
    - **No** → create the branch in place and keep working in the main worktree.
- For parallel work on several tasks, create one git worktree per branch.
- **Worktree naming is mandatory: `../<project>-<branch>`** — a sibling directory named with the project basename and the full branch name. Example: project `iclaude`, branch `dev-route-policy` → sibling worktree `../iclaude-dev-route-policy`.

### Git Worktrees and VS Code

- **Always create worktrees with `git worktree add` at the mandatory sibling path `../<project>-<branch>`.** Never create one inside the repository root — project-prefixed siblings avoid nested-repository status noise and name collisions across repositories.
- **Do not create worktrees with `EnterWorktree` or `superpowers:using-git-worktrees`.** `EnterWorktree` with `name` puts the worktree in `.claude/worktrees/` inside the repository, which violates the sibling rule. Use `EnterWorktree` only with `path`, to enter a sibling worktree you already created with `git worktree add`.
- Create the branch and worktree atomically from the up-to-date base branch; do not first check out the new `dev-*` branch in the main checkout and then try to add a worktree for the same branch.
  ```bash
  base="<base-branch>"
  branch="dev-<topic>"
  root="$(git rev-parse --show-toplevel)"
  project="$(basename "$root")"
  parent="$(dirname "$root")"
  git fetch origin "$base"
  git worktree add -b "$branch" "$parent/$project-$branch" "origin/$base"
  ```
- Open the worktree folder directly in VS Code when the work needs its own window:
  ```bash
  code --new-window "$parent/$project-$branch"
  ```
- If the `dev-*` branch already exists and is not checked out anywhere, attach it to the canonical path:
  ```bash
  branch="dev-<topic>"
  root="$(git rev-parse --show-toplevel)"
  project="$(basename "$root")"
  parent="$(dirname "$root")"
  git worktree add "$parent/$project-$branch" "$branch"
  ```
- If worktrees created outside VS Code do not appear there, enable detection in VS Code settings:
  ```json
  {
    "scm.repositories.explorer": true,
    "git.detectWorktrees": true,
    "git.detectWorktreesLimit": 50
  }
  ```
- Verify with `git worktree list --porcelain` before working.
- Remove worktrees only through Git, never by deleting the folder:
  ```bash
  branch="dev-<topic>"
  root="$(git rev-parse --show-toplevel)"
  project="$(basename "$root")"
  parent="$(dirname "$root")"
  git worktree remove "$parent/$project-$branch"
  git worktree prune
  ```
- After the PR is created, remove the branch's worktree — don't leave stale worktrees around.

Invoke the `git-workflow` skill (via the `Skill` tool) for branch creation, commit
messages, and PR creation — it is the executable form of the rules above.

`superpowers:finishing-a-development-branch` remains usable for the integration decision,
but its "merge locally into the base branch" option is **not** available here: the only
integration path is a PR. Pick its PR option, or run `git-workflow` Mode 3 directly.

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

## Mode: Piecemeal Growth

Piecemeal growth designs from forces that exist now: executable requirements, current workflows, and failures that have actually occurred. Like a desire path, the shape follows observed traffic; it is not paved in anticipation of journeys nobody has taken.

In this mode, keep the implementation as narrow as the present contract. Do not add configurability, concurrency, fallback paths, validation, or abstractions for possible future uses. Make assumptions explicit and let violations fail loudly, so new pressure is visible instead of being absorbed by speculative machinery.

When a new requirement or repeated failure appears, repair the design locally. Generalize only once reality has shown what the generalization must support.

This is not an argument against integrity at real boundaries: protect durable data, external callers, security, and failures with demonstrated likelihood or cost. It is an argument against paying complexity for imagined ones.
