# Upstream Issue / PR Tracker

**Repository:** https://github.com/safishamsi/graphify

## Status

- [ ] Issue submitted
- [ ] Issue triaged by maintainer
- [ ] PR submitted
- [ ] PR merged
- [ ] Released in graphifyy>=X.Y.Z
- [ ] Local patches removed (cleanup cycle)

## Issue draft

**Title:** Absolute paths in manifest.json, .graphify_root, and cache/ast/*.json break git-based portability

**Body:**

> ## Problem
>
> When `.graphify/` (or custom `GRAPHIFY_OUT/`) is committed to git for
> incremental cache sharing across machines/CI, three artifacts contain
> absolute paths and break on clone to a different filesystem location:
>
> 1. `manifest.json` — keys are absolute (`/home/alice/proj/foo.py`)
>    → `detect_incremental` cache miss → full rebuild
> 2. `.graphify_root` — absolute project path
>    → `graphify update` (no args) fails on a different machine
> 3. `cache/ast/*.json` — `source_file` field is absolute
>    → not directly fatal but pollutes diffs and leaks user paths
>
> `graph.json` is already correctly relativized via
> `watch._relativize_source_files`, demonstrating the intent.
>
> ## Reproduce
>
> ```bash
> mkdir /tmp/p && cd /tmp/p && git init -q && echo "def f(): pass" > a.py
> graphify update .
> head -3 graphify-out/manifest.json
> # keys: "/tmp/p/a.py" — absolute
> cat graphify-out/.graphify_root
> # /tmp/p — absolute
> ```
>
> ## Proposed fix
>
> Three small changes mirroring existing `_relativize_source_files`:
>
> 1. `detect.save_manifest` — relativize absolute keys against CWD
>    (skip paths outside via `os.path.relpath` ".." check)
> 2. `watch._rebuild_code` — write `str(watch_path)` instead of
>    `str(watch_root)` so user-provided `.` is preserved
> 3. `cache.save_cached` — walk `result["nodes"]` + `result["edges"]`,
>    relativize `source_file` against `root` before serialization
>
> All three are backwards compatible.
>
> ## Workaround
>
> Vendored patches: see iclaude project `lib/graphify/patches/`.
>
> Happy to submit a PR after triage.

## PR (after triage)

- Fork: `<set after fork>`
- Branch: `fix/portable-paths`
- Commits: one per patch point (atomic for review)
- Tests added in upstream test suite:
  - `test_save_manifest_relativizes_keys`
  - `test_save_cached_relativizes_source_file`
  - `test_graphify_root_preserves_relative`
- PR link: `<set after submit>`

## Local notes (out of scope for upstream)

Patch 04 (`04-watch-manifest-path-respect-out.patch`) makes `watch._rebuild_code`
pass `manifest_path=out / "manifest.json"` to `save_manifest` so the manifest
lands inside `GRAPHIFY_OUT/`. This duplicates `_patch_graphify_watch` runtime
shim in `lib/graphify/install.sh` (different runtime envs — uv tool run cache
vs tool dir Python). Consolidate during cleanup cycle.

## Cleanup cycle (after merge + release)

1. Pin `graphifyy>=X.Y.Z` in lockfile
2. Remove `lib/graphify/patches/` + `apply_patches.sh`
3. Remove `tests/test_graphify_patches.py`
4. Remove apply_patches call from `lib/graphify/install.sh`
5. Reconsider `_patch_graphify_watch` shim (Patch 04 redundancy)
6. Update [docs/superpowers/specs/2026-05-07-graphify-c3-patch-graphifyy-design.md](../../docs/superpowers/specs/2026-05-07-graphify-c3-patch-graphifyy-design.md) status
