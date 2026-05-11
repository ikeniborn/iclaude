# CCR Reasoning Transformer Plugin — Design

**Date:** 2026-05-11  
**Status:** Approved  
**Scope:** Custom CCR transformer plugin mapping `delta.reasoning` → `delta.content` for Ollama reasoning models

---

## Problem Statement

`kimi-k2.6:cloud` (and other reasoning models via Ollama) outputs response tokens in `delta.reasoning`, leaving `delta.content` empty. CCR's built-in `reasoning` transformer maps these tokens to Anthropic thinking blocks — which Claude Code does not use as response text. Result: Claude Code receives empty content and cannot process the model's output.

Fix: copy `delta.reasoning` to `delta.content` so Claude Code sees the response as text.

---

## Architecture

No new modules. One JS plugin file + one config entry.

```
.nvm-isolated/.claude-isolated/
  router.json                            ← add "transformers": [{"path": "..."}]
  .claude-code-router/
    config.json                          ← copy of router.json (written at CCR start)
    plugins/
      ollama-reasoning.js                ← new file
```

---

## Components

### `ollama-reasoning.js`

Implements `transformResponseOut`. Handles two formats depending on execution order relative to built-in `reasoning` transformer:

**Format A — raw Ollama SSE** (plugin runs before built-in transformer):
- Input: `choice.delta.reasoning = "..."`, `choice.delta.content = ""`
- Action: set `choice.delta.content = reasoning`

**Format B — Anthropic format** (plugin runs after built-in transformer):
- Input: `response.content = [{type: "thinking", thinking: "..."}]`, no text block
- Action: push `{type: "text", text: thinking.thinking}` into content array

```js
module.exports = {
  name: 'ollama-reasoning',

  transformResponseOut(response) {
    // Format A: raw Ollama streaming delta
    for (const choice of response?.choices ?? []) {
      if (choice.delta !== undefined) {
        const r = choice.delta.reasoning || choice.delta.reasoning_content || '';
        if (r && !choice.delta.content) choice.delta.content = r;
      }
      if (choice.message !== undefined) {
        const r = choice.message.reasoning || choice.message.reasoning_content || '';
        if (r && !choice.message.content) choice.message.content = r;
      }
    }

    // Format B: Anthropic content array (after built-in reasoning transformer)
    if (Array.isArray(response?.content)) {
      const hasText = response.content.some(b => b.type === 'text' && b.text);
      if (!hasText) {
        const thinking = response.content.find(b => b.type === 'thinking');
        if (thinking?.thinking) {
          response.content.push({type: 'text', text: thinking.thinking});
        }
      }
    }

    return response;
  }
};
```

### `router.json` registration

```json
{
  "transformers": [
    {"path": "./plugins/ollama-reasoning.js"}
  ]
}
```

Path is relative to `$CCR_HOME/.claude-code-router/` where `CCR_HOME = .nvm-isolated/.claude-isolated`.

---

## Data Flow

```
Claude Code
  → CCR :3456
    → Ollama :11434 → kimi-k2.6:cloud
    ← SSE stream: delta.reasoning="...", delta.content=""
    ← transformResponseOut (ollama-reasoning plugin):
         delta.content = delta.reasoning   (copy, not move)
    ← re-encode as Anthropic SSE
  ← content="..." (visible to Claude Code)
```

Thinking blocks remain in the stream (copy, not move) — visible in extended output.

---

## Error Handling

| Situation | Behavior |
|-----------|----------|
| `choices` absent | `?? []` guard → passthrough unchanged |
| `delta.content` non-empty | skip copy (preserve real content) |
| Non-reasoning model (deepseek, etc.) | `delta.reasoning` empty → condition false → passthrough |
| Plugin load failure | CCR logs error at startup; continues without plugin |
| Both formats produce empty | response unchanged → Claude Code sees empty (original behavior) |

---

## Testing

1. CCR startup log — no plugin load error
2. `bash tests/test_ccr_integration.sh` — response contains `"content"` key
3. Manual: launch iclaude with `--router`, verify kimi-k2.6:cloud returns text

---

## Out of Scope

- Suppressing thinking blocks (move vs copy — chosen: copy)
- Model-specific scoping (universal for all Ollama models — safe: passthrough for non-reasoning models)
- Modifying CCR source (`cli.js`)
