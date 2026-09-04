#!/usr/bin/env bash
# One-shot cleaner for per-project homes created before the migration reduced
# .githubRepoPaths (see migrate_home_from_store in lib/config/isolated.sh).
#
# Those homes carry the shared store's full repository map, so every other
# project the user has ever opened is listed inside an isolated home. This
# re-applies the current reduction to each home's .claude.json and drops the
# .claude.json auto-backups, which hold the same unreduced copy.
#
# Close Claude Code first: a running session keeps .claude.json in memory and
# rewrites it on exit, undoing the cleanup.
#
# Usage:
#   scripts/clean-home-repo-paths.sh [--apply] [homes-dir]
# Dry run by default; --apply writes. Default homes-dir is $ISOLATED_HOMES_DIR
# or <repo>/.claude-homes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/config/isolated.sh
source "$SCRIPT_DIR/../lib/config/isolated.sh"

APPLY=0
HOMES_DIR=""
for arg in "$@"; do
	case "$arg" in
		--apply) APPLY=1 ;;
		*) HOMES_DIR="$arg" ;;
	esac
done
if [[ -z "$HOMES_DIR" ]]; then
	HOMES_DIR="${ISOLATED_HOMES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/.claude-homes}"
fi

command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
[[ -d "$HOMES_DIR" ]] || { echo "No homes directory: $HOMES_DIR" >&2; exit 2; }

(( APPLY )) || echo "DRY RUN — re-run with --apply to write."

cleaned=0
for home_dir in "$HOMES_DIR"/*/; do
	home_dir="${home_dir%/}"
	marker="$home_dir/home.json"
	claude_json="$home_dir/.claude.json"
	[[ -f "$marker" && -f "$claude_json" ]] || continue

	root="$(jq -r '.project_root // empty' "$marker")"
	[[ -n "$root" ]] || { echo "skip $(basename "$home_dir"): no project_root"; continue; }

	before="$(jq -r '(.githubRepoPaths // {}) | keys | length' "$claude_json")"
	after="$(jq -r --arg root "$root" "$CLAUDE_JSON_REDUCE_JQ" "$claude_json" \
		| jq -r '(.githubRepoPaths // {}) | keys | length')"
	backups=("$home_dir"/backups/.claude.json.backup.*)
	[[ -e "${backups[0]}" ]] || backups=()

	echo "$(basename "$home_dir") [$root]: githubRepoPaths $before -> $after, backups ${#backups[@]}"
	(( before == after && ${#backups[@]} == 0 )) && continue
	cleaned=$((cleaned + 1))
	(( APPLY )) || continue

	tmp="$claude_json.tmp.$$"
	jq --arg root "$root" "$CLAUDE_JSON_REDUCE_JQ" "$claude_json" > "$tmp"
	mv "$tmp" "$claude_json"
	chmod 600 "$claude_json"
	(( ${#backups[@]} )) && rm -f "${backups[@]}"
done

if (( APPLY )); then
	echo "Cleaned $cleaned home(s)."
else
	echo "$cleaned home(s) would change."
fi
