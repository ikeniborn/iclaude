---
description: Rebuild graphify knowledge graph for the current project
---

Rebuild the graphify knowledge graph for the current project. Run the following bash command and report the result:

```bash
_gfy_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
if [[ -n "${GRAPHIFY_OUTPUT_DIR:-}" ]]; then
    if [[ "${GRAPHIFY_OUTPUT_DIR}" = /* ]]; then
        _gfy_target="${GRAPHIFY_OUTPUT_DIR}"
    else
        _gfy_target="${_gfy_root}/${GRAPHIFY_OUTPUT_DIR}"
    fi
else
    _gfy_target="${_gfy_root}"
fi
mkdir -p "$_gfy_target"
UV_TOOL_DIR="${GRAPHIFY_TOOL_DIR}" "${GRAPHIFY_UV_BIN}" tool run --from graphifyy graphify \
    update "${_gfy_target}" ${GRAPHIFY_EXTRA_ARGS:+${GRAPHIFY_EXTRA_ARGS}}
```

After the command completes, report: success or failure, output directory (`<target>/graphify-out/`), and briefly what was analyzed.
