# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 0. Project Exploration — Start Here

**Before exploring code manually — load the graph and wiki first.**

At the start of any task involving an unfamiliar codebase or after a long break:
1. Run `/graphify-context` → load knowledge graph into context (architecture, dependencies, clusters).
2. Run `/llm-wiki` → load wiki entries for the relevant domain.

Why: the graph and wiki encode decisions, constraints, and patterns that are invisible in raw code. Reading code without them wastes time rediscovering known context.

- New project or feature area → mandatory.
- Returning after a break (>1 day) → mandatory.
- Familiar area, same session → skip.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Knowledge Actualization

**After every non-trivial change — update the graph and wiki.**

After completing any feature, bugfix, or refactor:
1. Run `/graphify` → rebuild knowledge graph from updated codebase.
2. Run `/llm-wiki` → sync wiki entries affected by the change.

Why: stale graph/wiki misleads future sessions. Fresh context is cheap; rediscovery is expensive.

- Trivial changes (typo, comment, formatting) — skip.
- Non-trivial changes (new module, API change, architectural decision) — mandatory.
- If unsure — update. False positives cost less than stale knowledge.

