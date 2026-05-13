# adapters/anthropic.sh / adapters/gemini.sh

> 31 nodes · cohesion 0.09

## Key Concepts

- **parse_with_adapter()** (11 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/provider-adapter.sh`
- **provider-adapter.sh** (9 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/provider-adapter.sh`
- **parse_streaming_chunk()** (7 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-parser.sh`
- **get_provider_adapter()** (6 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/provider-adapter.sh`
- **get_chunk_type()** (4 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-detector.sh`
- **adapters/gemini.sh** (3 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/gemini.sh`
- **adapters/openai.sh** (3 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/openai.sh`
- **adapters/anthropic.sh** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/anthropic.sh`
- **adapters/generic.sh** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/generic.sh`
- **adapters/ollama.sh** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/ollama.sh`
- **pricing-lookup.sh** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/pricing-lookup.sh`
- **get_streaming_provider()** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-detector.sh`
- **streaming-detector.sh** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-detector.sh`
- **parse_anthropic_chunk()** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-parser.sh`
- **parse_ollama_chunk()** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-parser.sh`
- **parse_openai_chunk()** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-parser.sh`
- **streaming-parser.sh** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-parser.sh`
- **get_state_dir()** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-state.sh`
- **get_state_file()** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-state.sh`
- **get_streaming_state()** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-state.sh`
- **init_streaming_state()** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-state.sh`
- **is_streaming_active()** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-state.sh`
- **update_streaming_state()** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-state.sh`
- **detect_provider_type()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/provider-adapter.sh`
- **is_final_chunk()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/streaming-detector.sh`
- *... and 6 more nodes in this community*

## Relationships

- No strong cross-community connections detected

## Source Files

- `.nvm-isolated/.claude-isolated/scripts/lib/adapters/anthropic.sh`
- `.nvm-isolated/.claude-isolated/scripts/lib/adapters/gemini.sh`
- `.nvm-isolated/.claude-isolated/scripts/lib/adapters/generic.sh`
- `.nvm-isolated/.claude-isolated/scripts/lib/adapters/ollama.sh`
- `.nvm-isolated/.claude-isolated/scripts/lib/adapters/openai.sh`
- `.nvm-isolated/.claude-isolated/scripts/lib/pricing-lookup.sh`
- `.nvm-isolated/.claude-isolated/scripts/lib/provider-adapter.sh`
- `.nvm-isolated/.claude-isolated/scripts/lib/streaming-detector.sh`
- `.nvm-isolated/.claude-isolated/scripts/lib/streaming-parser.sh`
- `.nvm-isolated/.claude-isolated/scripts/lib/streaming-state.sh`

## Audit Trail

- EXTRACTED: 73 (88%)
- INFERRED: 10 (12%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*