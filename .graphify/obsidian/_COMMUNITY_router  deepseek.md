---
type: community
cohesion: 0.12
members: 17
---

# router / deepseek

**Cohesion:** 0.12 - loosely connected
**Members:** 17 nodes

## Members
- [[Anthropic API]] - concept - docs/architecture/diagrams/data-flow-router-launch.md
- [[Claude Code Router (CCR)]] - concept - docs/functions/ROUTER.md
- [[Credential Storage (.claude_proxy_credentials)]] - document - docs/architecture/diagrams/data-flow-proxy-configuration.md
- [[DeepSeek API]] - concept - docs/functions/ROUTER.md
- [[DeepSeek API Provider]] - concept - docs/architecture/diagrams/data-flow-router-launch.md
- [[Google Gemini API]] - concept - docs/architecture/diagrams/data-flow-router-launch.md
- [[HTTPS_PROXY Environment Variable]] - concept - docs/architecture/diagrams/data-flow-proxy-configuration.md
- [[HTTP_PROXY Environment Variable]] - concept - docs/architecture/diagrams/data-flow-proxy-configuration.md
- [[Ollama Local LLM]] - concept - docs/functions/ROUTER.md
- [[Ollama Local Models]] - concept - docs/architecture/diagrams/data-flow-router-launch.md
- [[OpenRouter API]] - concept - docs/functions/ROUTER.md
- [[OpenRouter API Provider]] - concept - docs/architecture/diagrams/data-flow-router-launch.md
- [[Proxy Configuration Flow]] - document - docs/architecture/diagrams/data-flow-proxy-configuration.md
- [[Router Launch Flow]] - document - docs/architecture/diagrams/data-flow-router-launch.md
- [[SiliconFlow API]] - concept - docs/architecture/diagrams/data-flow-router-launch.md
- [[Volcengine ByteDance Cloud]] - concept - docs/architecture/diagrams/data-flow-router-launch.md
- [[router.json Configuration]] - document - docs/architecture/diagrams/data-flow-router-launch.md

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/router_/_deepseek
SORT file.name ASC
```

## Connections to other communities
- 1 edge to [[_COMMUNITY_microvm  architecture]]

## Top bridge nodes
- [[Claude Code Router (CCR)]] - degree 12, connects to 1 community