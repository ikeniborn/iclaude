# Intent: lat.md integration as llm-wiki replacement + graphify complement

**Date:** 2026-05-24
**Status:** draft

## Objective

Projects launched via iclaude suffer from weak code-to-documentation linkage and agent context loss during development sessions.
`llm-wiki` is ineffective as a documentation layer — it generates disconnected wiki entries without referential integrity between code and docs.
`lat.md` replaces it with a structured knowledge graph (`lat.md/` directory, bidirectional `[[section]]` links, code annotations `// @lat:`), enabling agents and developers to navigate from any code symbol to its documentation and back.
The integration is needed now because context loss and hallucination are active pain points degrading development quality.

## Desired Outcomes

- `lat.md` can be initialized and used in any project launched via iclaude
- Agents maintain accurate project context across sessions (no cold-start context loss)
- Documentation stays synchronized with code via `lat check` (referential integrity enforced)
- `llm-wiki` skill removed from the workflow as legacy
- `graphify` handles code structure graph; `lat.md` handles documentation knowledge graph — complementary, not overlapping
- Developers can query documentation semantically (`lat search`, `lat section`, `lat locate`)

## Health Metrics

- iclaude startup time must not increase noticeably from lat.md tooling
- graphify integration must continue to function (code graph unaffected)
- All existing iclaude flags must remain compatible
- Hallucination rate / context loss subjectively decreases in development sessions

## Constraints

- No hard technical constraints — all decisions are open for discussion during design
- lat.md requires Node.js 22+ and npm; iclaude already manages isolated Node via `.nvm-isolated/` — installation path TBD
- Optional semantic search requires OpenAI/Vercel AI Gateway API key — must not be a hard dependency
- lat.md MCP server integration is a candidate for wiring into iclaude's existing MCP config

## Autonomy Level

None — all implementation decisions must be discussed with user.

## Stop Rules

All architectural decisions require user approval:
- Whether lat.md installs into `.nvm-isolated/` or system npm
- Whether llm-wiki is deleted or just deprecated
- How graphify and lat.md divide responsibility (code graph vs doc graph boundary)
- Whether MCP server integration is in scope for v1
- Whether `lat check` runs as a pre-commit hook or on-demand only
