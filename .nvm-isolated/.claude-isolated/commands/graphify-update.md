---
description: Rebuild graphify knowledge graph for the current project
---

Rebuild the graphify knowledge graph for the current project. Run the following bash command and report the result:

```bash
_gfy_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
UV_TOOL_DIR="${GRAPHIFY_TOOL_DIR}" "${GRAPHIFY_UV_BIN}" tool run --from graphifyy graphify \
    update "${_gfy_root}" ${GRAPHIFY_EXTRA_ARGS:+${GRAPHIFY_EXTRA_ARGS}}
```

After the command completes, report: success or failure, output directory (`<project_root>/graphify-out/`), and briefly what was analyzed.
