# parse_anthropic_data() / get_gemini_context_limit()

> 15 nodes · cohesion 0.17

## Key Concepts

- **create_unified_data()** (6 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/provider-adapter.sh`
- **parse_openai_data()** (5 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/openai.sh`
- **parse_gemini_data()** (4 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/gemini.sh`
- **parse_generic_data()** (3 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/generic.sh`
- **parse_ollama_data()** (3 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/ollama.sh`
- **calculate_cost()** (3 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/pricing-lookup.sh`
- **normalize_model_name()** (3 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/pricing-lookup.sh`
- **get_context_limit_for_model()** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/openai.sh`
- **get_model_display_name()** (2 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/pricing-lookup.sh`
- **parse_anthropic_data()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/anthropic.sh`
- **get_gemini_context_limit()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/gemini.sh`
- **try_extract_model()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/generic.sh`
- **try_extract_tokens()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/generic.sh`
- **get_ollama_context_limit()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/ollama.sh`
- **get_ollama_display_name()** (1 connections) — `.nvm-isolated/.claude-isolated/scripts/lib/adapters/ollama.sh`

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

## Audit Trail

- EXTRACTED: 37 (100%)
- INFERRED: 0 (0%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*