#!/bin/bash
# Tests for .githooks/post-merge — pull-time claude.exe refresh.
# Builds throwaway git repos; mocks the lockfile + claude binary; never touches
# the real isolated environment. The interactive y/N path is verified manually.
set -u

HOOK_SRC="$(git rev-parse --show-toplevel)/.githooks/post-merge"
if [[ ! -f "$HOOK_SRC" ]]; then
  echo "FAIL: hook not found at $HOOK_SRC"; exit 1
fi

pass=0; fail=0
assert_contains() { # <output> <substr> <name>
  if grep -qF "$2" <<<"$1"; then echo "ok: $3"; pass=$((pass+1));
  else echo "FAIL: $3"; echo "--- output ---"; echo "$1"; echo "---"; fail=$((fail+1)); fi
}
assert_empty() { # <output> <name>
  if [[ -z "${1//[[:space:]]/}" ]]; then echo "ok: $2"; pass=$((pass+1));
  else echo "FAIL: $2 (expected no output)"; echo "--- output ---"; echo "$1"; echo "---"; fail=$((fail+1)); fi
}

# make_repo <lockver> <binver|missing> <changed:yes|no> -> prints repo path.
# Builds 3 commits; sets ORIG_HEAD so the lockfile shows changed (yes) or not (no).
make_repo() {
  local lockver="$1" binver="$2" changed="$3" repo
  repo="$(mktemp -d)"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
  echo "1" > "$repo/filler"; git -C "$repo" add filler
  git -C "$repo" commit -qm c1
  local c1; c1="$(git -C "$repo" rev-parse HEAD)"
  printf '{"claudeCodeVersion":"%s"}\n' "$lockver" > "$repo/.nvm-isolated-lockfile.json"
  git -C "$repo" add .nvm-isolated-lockfile.json; git -C "$repo" commit -qm c2
  local c2; c2="$(git -C "$repo" rev-parse HEAD)"
  echo "2" > "$repo/filler"; git -C "$repo" add filler; git -C "$repo" commit -qm c3
  if [[ "$changed" == "yes" ]]; then
    git -C "$repo" update-ref ORIG_HEAD "$c1"   # diff c1..HEAD includes the lockfile
  else
    git -C "$repo" update-ref ORIG_HEAD "$c2"   # diff c2..HEAD = only filler
  fi
  if [[ "$binver" != "missing" ]]; then
    mkdir -p "$repo/.nvm-isolated/npm-global/bin"
    printf '#!/bin/bash\necho "%s (Claude Code)"\n' "$binver" \
      > "$repo/.nvm-isolated/npm-global/bin/claude"
    chmod +x "$repo/.nvm-isolated/npm-global/bin/claude"
  fi
  cp "$HOOK_SRC" "$repo/post-merge"; chmod +x "$repo/post-merge"
  echo "$repo"
}

# run_hook <repo> [env...] -> combined stdout+stderr. setsid drops the controlling
# terminal so /dev/tty is unavailable (the deterministic non-interactive path).
run_hook() {
  local repo="$1"; shift
  ( cd "$repo" && env "$@" setsid bash ./post-merge </dev/null ) 2>&1
}

# Case 1: opt-out → silent exit 0 even with a real mismatch.
r="$(make_repo 9.9.9 1.0.0 yes)"
assert_empty "$(run_hook "$r" ICLAUDE_NO_AUTO_UPDATE=1)" "opt-out is silent"

# Case 2: in-sync (lockver == binver) → silent exit 0.
r="$(make_repo 9.9.9 9.9.9 yes)"
assert_empty "$(run_hook "$r")" "in-sync is silent"

# Case 3: lockfile unchanged in this merge → guard skips, silent even if binary differs.
r="$(make_repo 9.9.9 1.0.0 no)"
assert_empty "$(run_hook "$r")" "unchanged-lockfile guard skips"

# Case 4: mismatch, non-TTY → warn-only with manual hint, never blocks.
r="$(make_repo 9.9.9 1.0.0 yes)"
out="$(run_hook "$r")"
assert_contains "$out" "install-from-lockfile" "mismatch non-TTY warns with manual hint"

# Case 5: binary missing, mismatch, non-TTY → still warns (missing == mismatch).
r="$(make_repo 9.9.9 missing yes)"
out="$(run_hook "$r")"
assert_contains "$out" "install-from-lockfile" "missing binary non-TTY warns"

echo "---"; echo "pass=$pass fail=$fail"
[[ "$fail" -eq 0 ]]
