# Graphify

The graphify module (`lib/graphify/`) installs and operates the Graphify knowledge graph tool inside the iclaude isolated environment. Graphify ingests a folder of source files and produces a community-detected HTML graph, a GraphRAG JSON file, and a `GRAPH_REPORT.md`. It is implemented as a Python package (`graphifyy`) managed by `uv`.

## Key Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `GRAPHIFY_UV_BIN` | `$ISOLATED_NVM_DIR/bin/uv` | Path to the isolated uv binary |
| `GRAPHIFY_TOOL_DIR` | `$ISOLATED_NVM_DIR/.claude-isolated/graphify` | `uv tool` installation directory |
| `GRAPHIFY_PYTHON_DIR` | inside `GRAPHIFY_TOOL_DIR` | Python 3.12 managed by uv |
| `GRAPHIFY_OUT` | `graphify-out` | Output directory name (relative to project root) |
| `GRAPHIFY_EXTRA_ARGS` | (empty) | Extra flags forwarded to `graphify update` |

`GRAPHIFY_OUT` is synced into the `env` block of `settings.json` at every launch by `_sync_graphify_env_to_settings()` (see [[launcher#Pre-launch Steps]]) so Bash tool subshells inherit the correct path.

## Detection

`detect_graphify()` (`lib/graphify/detect.sh`) returns 0 when both conditions hold:

1. `uv` is available — either `$GRAPHIFY_UV_BIN` is executable or `command -v uv` succeeds.
2. The graphify binary exists and is executable at `${GRAPHIFY_TOOL_DIR}/graphifyy/bin/graphify`.

This two-condition check ensures that neither a bare `uv` install nor a bare graphify binary without `uv` is considered sufficient.

## Installation

`install_graphify()` (`lib/graphify/install.sh`) is triggered by `./iclaude.sh --install-graphify`. It accepts `--force` to remove and reinstall the tool directory.

Installation steps:

1. **Resolve proxy** (`_graphify_resolve_proxy()`): prefers `HTTPS_PROXY`, then `HTTP_PROXY`, then `PROXY_URL`.
2. **Install uv** (`_graphify_resolve_uv()`): uses `$GRAPHIFY_UV_BIN` if present, system `uv` as fallback. If neither is found, downloads the `uv-x86_64-unknown-linux-gnu.tar.gz` release from GitHub into `$ISOLATED_NVM_DIR/bin/uv`.
3. **Install graphifyy**: runs `uv tool install graphifyy --python 3.12` with `UV_TOOL_DIR=$GRAPHIFY_TOOL_DIR` and `UV_PYTHON_INSTALL_DIR=$GRAPHIFY_PYTHON_DIR`. The `--force` variant adds `--force` to the uv command.
4. **Apply patches**: calls `_patch_graphify_watch()` inline and then runs `lib/graphify/apply_patches.sh` for the portability patch set.
5. **Symlink graphify**: creates `$ISOLATED_NVM_DIR/bin/graphify -> $GRAPHIFY_TOOL_DIR/graphifyy/bin/graphify` so `which graphify` resolves to the managed Python 3.12 shebang rather than a system Python.
6. **Skill setup**: runs `graphify install` (via uv tool run) to write `$CLAUDE_CONFIG_DIR/skills/graphify/SKILL.md`. On reinstall, the existing `SKILL.md` is never overwritten; if the upstream version differs from the local file, a `.new` copy is saved for manual review.

## Patch Application

`apply_patches.sh` (`lib/graphify/apply_patches.sh`) applies `.patch` files from `lib/graphify/patches/` to the installed graphifyy Python package. Each patch is guarded by an idempotency marker comment (`ICLAUDE-PATCHED-v1`) in the target file; already-patched files are skipped. A dry-run check (`patch --dry-run`) is performed before applying to detect upstream changes that would break the patch. Results are reported as `applied=N skipped=N failed=N`.

`_patch_graphify_watch()` (`lib/graphify/install.sh`) is a targeted inline patch for a specific upstream bug: `watch._rebuild_code()` called `save_manifest(detected["files"])` without an explicit `manifest_path`, causing the manifest to be written to the hardcoded path `graphify-out/manifest.json` instead of `$GRAPHIFY_OUT/manifest.json`. The fix uses `sed -i` to add `manifest_path=str(out / "manifest.json")` as a keyword argument. It is idempotent (checks for the unpatched string before running sed) and is called both at install time and before every graph rebuild.

`apply_patches.sh` is re-invoked idempotently by `_graphify_rebuild_graph()` before each build to guard against `uv tool upgrade graphifyy` reverting the patches.

## Graph Rebuild

`_graphify_rebuild_graph()` (`lib/graphify/install.sh`) is called when `./iclaude.sh --graphify` is passed. It:

1. Calls `detect_graphify()`; aborts with an error if not installed.
2. Applies patches (`_patch_graphify_watch()` + `apply_patches.sh`).
3. Determines the project root via `git rev-parse --show-toplevel` (falls back to `$PWD`).
4. Runs `graphify update .` (relative path, not absolute, so manifest keys stay relative and the graph is portable across machines). Extra flags from `GRAPHIFY_EXTRA_ARGS` are appended.
5. Sets `GRAPHIFY_OUT` and proxy variables as a one-shot `env(1)` prefix to the binary invocation.

## Status Check

`check_graphify_status()` (`lib/graphify/status.sh`) is triggered by `./iclaude.sh --check-graphify`. It reports:

- `uv` binary path and version.
- `graphify` binary path and version.
- Python 3.12 path and version (searches `$GRAPHIFY_PYTHON_DIR`, falls back to `uv python find 3.12`).
- Disk usage of `$GRAPHIFY_TOOL_DIR`.
- Expected graph output path (`${git_root}/${GRAPHIFY_OUT:-graphify-out}/`).

## Claude Code Integration

The graphify skill (`/graphify` slash command) invokes the build flow from inside a Claude Code session. The skill reads `GRAPHIFY_OUT` from the environment — which is guaranteed to be set correctly by the `settings.json` sync in [[launcher#Pre-launch Steps]]. See [[architecture]] for the module load order that exposes `GRAPHIFY_UV_BIN` and `GRAPHIFY_TOOL_DIR` before the graphify module is sourced.
