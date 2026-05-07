# Upstream Issue / PR Tracker

**Repository:** https://github.com/safishamsi/graphify

## Submitted issues by iclaude (ikeniborn)

| # | Title | State | Resolution | Verified |
|---|-------|-------|------------|----------|
| [#756](https://github.com/safishamsi/graphify/issues/756) | bug: query/path/explain commands ignore GRAPHIFY_OUT env var, hardcode 'graphify-out/graph.json' | CLOSED (completed) | Fixed via PR [#758](https://github.com/safishamsi/graphify/pull/758) by `nyldn`, merged 2026-05-07 into `v7` | 2026-05-07 |
| [#777](https://github.com/safishamsi/graphify/issues/777) | bug: absolute paths in manifest.json, .graphify_root, and cache/ast/*.json break git-shared graphify-out/ across machines | OPEN | Awaiting triage. References #722. PR offered (3 atomic patches in detect/watch/cache + 3 tests). | 2026-05-07 |

## Related upstream issues (not authored by us)

| # | Title | State | Relevance |
|---|-------|-------|-----------|
| [#722](https://github.com/safishamsi/graphify/issues/722) | Question — manifest.json absolute paths + missing graphify-out/.gitignore | OPEN | Overlaps with the portability draft below; reuse comment thread instead of filing duplicate |

## Portability — Status (#777)

Subject: absolute paths in `manifest.json`, `.graphify_root`, `cache/ast/*.json`.

- [x] Issue submitted — [#777](https://github.com/safishamsi/graphify/issues/777) (2026-05-07)
- [ ] Issue triaged by maintainer
- [ ] PR submitted
- [ ] PR merged
- [ ] Released in graphifyy>=X.Y.Z
- [ ] Local patches removed (cleanup cycle: `normalize-paths.py` hook + `_patch_graphify_watch` shim)

## Issue draft (v2 — sharpened, references #722)

**Title:** bug: absolute paths in `manifest.json`, `.graphify_root`, and `cache/ast/*.json` break git-shared `graphify-out/` across machines

**Note before submit:** [#722](https://github.com/safishamsi/graphify/issues/722) is open ("Question" form, 0 comments) covering manifest.json + .gitignore. This draft is broader (adds `cache/ast/*.json` gap, concrete fix + PR offer) and bug-framed. Decision pending: comment on #722 vs new bug. If new — link #722 explicitly to avoid duplicate.

**Body:**

> ## Problem
>
> Committing `graphify-out/` (or `$GRAPHIFY_OUT`) to git is the
> documented way to share incremental cache + graph artifacts across a
> team / CI. Today three artifacts contain absolute paths and break on
> clone to a different filesystem location:
>
> 1. `manifest.json` — keys are absolute (`/home/alice/proj/foo.py`).
>    `detect_incremental` cache miss → full rebuild on every other
>    machine. Same observation as #722 (filed as "question").
> 2. `.graphify_root` — absolute project path.
>    `graphify update` with no args fails (or scans the wrong tree)
>    after clone.
> 3. `cache/ast/*.json` — `source_file` field on cached nodes/edges is
>    absolute. Not directly fatal but pollutes diffs and leaks user
>    paths into commits. **Not covered by #722.**
>
> `graph.json` is already correctly relativized via
> `watch._relativize_source_files` (since 0.5.0) — proves the intent
> and the pattern.
>
> ## Reproduce
>
> ```bash
> mkdir /tmp/p && cd /tmp/p && git init -q && echo "def f(): pass" > a.py
> graphify update .
>
> # 1) absolute keys in manifest
> python3 -c 'import json; print(list(json.load(open("graphify-out/manifest.json")).keys())[:1])'
> # ['/tmp/p/a.py']  ← absolute
>
> # 2) absolute project root
> cat graphify-out/.graphify_root
> # /tmp/p  ← absolute
>
> # 3) absolute source_file in cache/ast
> python3 -c 'import json,glob; f=glob.glob("graphify-out/cache/ast/*.json")[0]; d=json.load(open(f)); print({n.get("source_file") for n in d.get("nodes",[])})'
> # {'/tmp/p/a.py'}  ← absolute
> ```
>
> Move `/tmp/p` to `/tmp/q` (or clone the committed `graphify-out/` on
> another host): incremental detection misses, root resolution breaks,
> diffs churn.
>
> ## Proposed fix
>
> Three small changes mirroring existing `_relativize_source_files`,
> each backwards compatible (relpath fallback to abspath when target
> escapes root):
>
> 1. `graphify/detect.py::save_manifest` — relativize keys against
>    `root` before serialization. Skip entries where
>    `os.path.relpath(...).startswith("..")` (paths outside the root)
>    and write them absolute, matching `_relativize_source_files`.
> 2. `graphify/watch.py::_rebuild_code` — write the user-provided
>    `watch_path` (often `.`) to `.graphify_root` instead of the
>    resolved absolute `watch_root`.
> 3. `graphify/cache.py::save_cached` — walk `result["nodes"]` +
>    `result["edges"]`, relativize `source_file` fields against `root`
>    using the same helper, before JSON dump.
>
> Symmetric loaders (`load_manifest`, `load_cached`, `__main__` root
> resolution) re-anchor relative paths against CWD / `--root` —
> matches the pattern that already works for `graph.json`.
>
> ## Workaround in iclaude
>
> Two-way `normalize-paths.py` PreToolUse/PostToolUse hook flips
> manifest, root, and cache/ast paths abs↔rel around every `graphify`
> invocation. Plus a small runtime shim that patches `watch.py` to
> pass `manifest_path` explicitly. See
> `lib/graphify/install.sh::_patch_graphify_watch` and
> `.nvm-isolated/.claude-isolated/hooks/normalize-paths.py` in
> [iclaude](https://github.com/ikeniborn/iclaude). Brittle — would
> rather drop both once upstream lands.
>
> ## PR offer
>
> Happy to submit a single PR with the three changes + tests
> (`test_save_manifest_relativizes_keys`,
> `test_save_cached_relativizes_source_file`,
> `test_graphify_root_preserves_relative`) after triage / scope
> confirmation.
>
> ## Environment
>
> - graphifyy `0.7.7`
> - Python 3.12 (uv-managed)
> - Project: `iclaude` (`GRAPHIFY_OUT=.graphify` committed to git)

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
