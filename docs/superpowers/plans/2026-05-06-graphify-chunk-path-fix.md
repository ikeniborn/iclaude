# Graphify: Fix Chunk Files Written to Wrong Directory — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure semantic extraction subagents write `.graphify_chunk_NN.json` files to the directory configured in `GRAPHIFY_OUT`, not to the hardcoded fallback `graphify-out/`.

**Architecture:** The orchestrating Claude session resolves the literal `GRAPHIFY_OUT` value and injects it as `CHUNK_OUTPUT_PATH` into each subagent prompt before dispatch. Subagents receive an explicit Write-tool instruction with a relative path — no env var inheritance required.

**Tech Stack:** Markdown skill file (SKILL.md) — no code dependencies, no tests framework.

---

## File Map

| File | Change |
|------|--------|
| `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md` | Step B2 prompt template (line 288, 291–292) + Step B3 missing-file warning (line 357) |

---

### Task 1: Add CHUNK_OUTPUT_PATH to Step B2 subagent prompt

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md:288`
- Modify: `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md:291-292`

- [ ] **Step 1: Update substitution instruction on line 288**

Current (line 288):
```
Each subagent receives this exact prompt (substitute FILE_LIST, CHUNK_NUM, TOTAL_CHUNKS, and DEEP_MODE):
```

Replace with:
```
Each subagent receives this exact prompt (substitute FILE_LIST, CHUNK_NUM, TOTAL_CHUNKS, DEEP_MODE, and CHUNK_OUTPUT_PATH).
CHUNK_OUTPUT_PATH = the literal value of GRAPHIFY_OUT + "/.graphify_chunk_" + zero-padded chunk number + ".json"
Example: if GRAPHIFY_OUT=".graphify" and chunk is 2 of 5 → CHUNK_OUTPUT_PATH = ".graphify/.graphify_chunk_02.json"
Substitute the actual string — NOT the variable name "${GRAPHIFY_OUT}".
```

- [ ] **Step 2: Add write instruction as first two lines of the subagent prompt template**

Current (lines 291–292):
```
You are a graphify extraction subagent. Read the files listed and extract a knowledge graph fragment.
Output ONLY valid JSON matching the schema below - no explanation, no markdown fences, no preamble.
```

Replace with:
```
You are a graphify extraction subagent. Read the files listed and extract a knowledge graph fragment.
Write your JSON output using the Write tool to this exact path: CHUNK_OUTPUT_PATH
Do not write to any other path or directory. Do not create a graphify-out/ directory.
Output ONLY valid JSON matching the schema below — no explanation, no markdown fences, no preamble.
```

- [ ] **Step 3: Verify edit looks correct**

Read lines 286–295 of SKILL.md and confirm:
- Line 288 contains the updated substitution instruction with CHUNK_OUTPUT_PATH example
- First line of prompt still says "You are a graphify extraction subagent..."
- Second line says "Write your JSON output using the Write tool to this exact path: CHUNK_OUTPUT_PATH"
- Third line says "Do not write to any other path..."
- Fourth line says "Output ONLY valid JSON..."

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
git commit -m "fix(graphify): pass explicit chunk output path to subagents to respect GRAPHIFY_OUT"
```

---

### Task 2: Update Step B3 missing-file warning

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md:357`

- [ ] **Step 1: Update the missing-file warning**

Current (line 357):
```
- If the file is missing, the subagent was likely dispatched as read-only (Explore type) — print a warning: "chunk N missing from disk — subagent may have been read-only. Re-run with general-purpose agent." Do not silently skip.
```

Replace with:
```
- If the file is missing, two likely causes: (1) subagent was dispatched as read-only (Explore type), or (2) subagent wrote to wrong path because CHUNK_OUTPUT_PATH was not substituted correctly. Print: "chunk N missing from disk — check that CHUNK_OUTPUT_PATH was substituted with the actual GRAPHIFY_OUT value, not the variable name. Re-run with general-purpose agent." Do not silently skip.
```

- [ ] **Step 2: Verify edit looks correct**

Read lines 352–362 of SKILL.md and confirm the updated warning is present with both causes listed.

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
git commit -m "fix(graphify): improve missing-chunk warning to diagnose wrong GRAPHIFY_OUT substitution"
```

---

### Task 3: Manual verification

- [ ] **Step 1: Confirm no remaining hardcoded `graphify-out` in subagent prompt template**

Run:
```bash
grep -n "graphify-out" .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md | grep -v "^\(82\|103\|104\|106\|117\|123\|151\|168\|174\|180\|184\|211\|219\|225\|228\|262\|263\|268\|369\|379\|383\|401\|403\|408\|428\|432\|433\|442\|462\|476\|485\|499\|509\|529\|538\|554\|556\|657\|665\|672\|675\|676\|679\|686\|691\|692\|726\|728\|732\|739\|749\|758\|774\|799\|804\|808\|831\|843\|849\|858\|868\|873\|879\|909\|997\|998\)"
```

Expected: any remaining hits should be in bash blocks (orchestrator context, not subagent prompt). None should be inside the subagent prompt template block (lines 291–350).

Simpler check — just verify the subagent prompt block itself:
```bash
sed -n '291,350p' .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md | grep "graphify-out"
```

Expected: no output (no hardcoded `graphify-out` inside the subagent prompt).

- [ ] **Step 2: Verify CHUNK_OUTPUT_PATH appears in subagent prompt**

```bash
sed -n '291,295p' .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
```

Expected output (approximately):
```
You are a graphify extraction subagent. Read the files listed and extract a knowledge graph fragment.
Write your JSON output using the Write tool to this exact path: CHUNK_OUTPUT_PATH
Do not write to any other path or directory. Do not create a graphify-out/ directory.
Output ONLY valid JSON matching the schema below — no explanation, no markdown fences, no preamble.
```
