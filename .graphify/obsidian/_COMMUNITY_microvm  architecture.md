---
type: community
cohesion: 0.10
members: 21
---

# microvm / architecture

**Cohesion:** 0.10 - loosely connected
**Members:** 21 nodes

## Members
- [[Architecture Diagrams README]] - document - docs/architecture/diagrams/README.md
- [[Architecture Overview]] - document - docs/architecture/overview.yaml
- [[Claude Code CLI]] - concept - CLAUDE.md
- [[Firecracker VMM_1]] - document - docs/functions/MICROVM.md
- [[Isolated Installation (NVM)]] - concept - docs/architecture/diagrams/README.md
- [[KVM hypervisor as security boundary]] - rationale - docs/functions/MICROVM.md
- [[NVM Isolated Environment]] - concept - docs/architecture/diagrams/data-flow-isolated-installation.md
- [[Named microVM snapshots]] - rationale - docs/functions/MICROVM.md
- [[OAuth Token Management_2]] - concept - docs/architecture/diagrams/README.md
- [[PII DNAT troubleshooting (MICROVM.md)]] - document - docs/functions/MICROVM.md
- [[Quick Configuration Guide]] - document - docs/functions/QUICK_CONFIG.md
- [[SSH ControlMaster + rsync sync]] - rationale - docs/functions/MICROVM.md
- [[Use Cases Guide]] - document - docs/functions/USE_CASES.md
- [[Workspace sync modes (fullisolated)]] - rationale - docs/functions/MICROVM.md
- [[iclaude Project]] - concept - docs/architecture/diagrams/README.md
- [[iclaude-guest-init (PID 1)]] - code - docs/functions/MICROVM.md
- [[install_microvm()]] - code - docs/functions/MICROVM.md
- [[microVM (Firecracker) sandbox]] - document - README.md
- [[microVM Sandbox (Firecracker v2)]] - document - docs/functions/MICROVM.md
- [[plansDirectory Configuration]] - concept - docs/functions/QUICK_CONFIG.md
- [[start_microvm()]] - code - docs/functions/MICROVM.md

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/microvm_/_architecture
SORT file.name ASC
```

## Connections to other communities
- 1 edge to [[_COMMUNITY_router  deepseek]]
- 1 edge to [[_COMMUNITY_skill  agent-builder]]
- 1 edge to [[_COMMUNITY_caveman  graphify]]

## Top bridge nodes
- [[iclaude Project]] - degree 10, connects to 2 communities
- [[microVM (Firecracker) sandbox]] - degree 2, connects to 1 community