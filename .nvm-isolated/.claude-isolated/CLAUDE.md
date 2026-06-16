# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## No Tests (MANDATORY — overrides everything)

**This rule is absolute. It applies regardless of which skill, tool, agent, or workflow is active — including any skill that mandates TDD or test-first development. No exception, no rationalization.**

**What is banned — functional tests only:** code (or test-driven generation) that asserts runtime behavior in a red→green loop — write failing test, then write code until it passes. This includes unit, integration, e2e, snapshot, property, and smoke tests.

- Do NOT create such functional tests, nor test scaffolding/fixtures for them.
- Do NOT add or run a functional testing framework, test runner, or test dependency (e.g. `vitest`, `jest`, `pytest`, `mocha`; `npm test` when it runs such a suite).
- Do NOT use tests as a verification step. Verify behavior by running the real code/command and observing output.
- If a skill (e.g. `test-driven-development`) instructs you to write tests, follow this rule instead and skip the test step.

**ALLOWED (not "tests" — code-correctness checks, encouraged):**
- Linters and formatters (e.g. `ruff`, `eslint`, `shellcheck`, `bash -n`, `prettier`).
- Type checkers and static analysis (e.g. `mypy`, `tsc --noEmit`, LSP diagnostics).
- Syntax / semantic / correctness validation that does not exercise runtime behavior with assertions.
- **lat.md test-specs** (spec sections, `require-code-mention`, link/code-ref checks via `lat check`). These describe and validate code↔doc traceability — NOT red→green functional tests. Keep and maintain them.

The ban targets **functional tests** (red→green, assert runtime behavior). Static code-quality checks and lat.md spec-validation are fine and recommended.

**On finding existing functional tests in the project** (NOT lint, type-check, or lat.md specs):
- Report them (path + what they assert).
- Recommend deletion.
- Offer to delete them as a concrete action — ask for confirmation, then remove on approval.

## Getting Started

**Load graph and docs before exploring code — they encode decisions invisible in raw code.**

At the start of any task in an unfamiliar area, or after a gap of more than 1 day:

1. Run `graphify-context` → loads architecture, dependencies, clusters into context.
2. Run `update-docs` → checks lat.md/ integrity and updates sections.

Skip only when: familiar area, same session.

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

## Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals (verify by running real code, never by writing tests — see **No Tests**):
- "Add validation" → "Run the code with invalid inputs, confirm it rejects them"
- "Fix the bug" → "Reproduce it by running the affected path, confirm the fix removes it"
- "Refactor X" → "Run X before and after, confirm identical observable behavior"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```
