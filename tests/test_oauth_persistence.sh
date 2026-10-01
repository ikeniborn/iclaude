#!/usr/bin/env bash
# Catch credential destruction, MCP leakage, unsafe adoption and stale publishers.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
print_error() { printf '%s\n' "$*" >&2; }
print_warning() { :; }
[[ -f "$ROOT/lib/oauth/persistence.sh" ]] || { echo 'FAIL: auth persistence unavailable'; exit 1; }
source "$ROOT/lib/oauth/persistence.sh"
checks=0
check() { if ! eval "$1"; then echo "FAIL: $2" >&2; exit 1; fi; checks=$((checks+1)); }
store="$tmp/store"
home="$tmp/home"
other="$tmp/other"
mkdir -p "$store" "$home" "$other"
printf '%s\n' '{"claudeAiOauth":{"accessToken":"fixture-A","refreshToken":"refresh-A"},"mcpOAuth":{"common":"never-copy"}}' > "$store/.credentials.json"
printf '%s\n' '{"oauthAccount":{"accountUuid":"account-A"},"hasCompletedOnboarding":true,"lastOnboardingVersion":"fixture"}' > "$store/.claude.json"
printf '%s\n' '{"mcpOAuth":{"local":"keep"}}' > "$home/.credentials.json"
printf '%s\n' '{"custom":{"keep":true},"projects":{"fixture":{}}}' > "$home/.claude.json"
printf '%s\n' 'settings-local' > "$home/settings.json"
printf '%s\n' 'history-local' > "$home/history.jsonl"
cp "$home/settings.json" "$tmp/settings.before"
cp "$home/history.jsonl" "$tmp/history.before"
oauth_prepare_home "$store" "$home"
check '[[ ! -L "$home/.credentials.json" ]]' 'private credential snapshot'
check '[[ "$(stat -c %a "$home/.credentials.json")" == 600 ]]' 'private credential permissions'
check "jq -e '.fingerprint | type == \"string\" and length == 64' '$home/.iclaude-auth-baseline.json' >/dev/null" 'baseline has state fingerprint'
check "jq -e '.claudeAiOauth.accessToken == \"fixture-A\" and .mcpOAuth.local == \"keep\" and .mcpOAuth.common == null' '$home/.credentials.json' >/dev/null" 'subscription only, preserve local MCP'
check "jq -e '.oauthAccount.accountUuid == \"account-A\" and .custom.keep == true and .projects.fixture == {}' '$home/.claude.json' >/dev/null" 'account metadata without project mixing'
check 'cmp "$tmp/settings.before" "$home/settings.json" && cmp "$tmp/history.before" "$home/history.jsonl"' 'settings and history untouched'
before="$(sha256sum "$home/.credentials.json")"
oauth_prepare_home "$store" "$home"
check '[[ "$(sha256sum "$home/.credentials.json")" == "$before" ]]' 'unchanged relaunch keeps bytes'
oauth_prepare_home "$store" "$other"

# Same-account native refresh is published; other project's managed snapshot updates.
jq '.claudeAiOauth.accessToken="fixture-B"' "$home/.credentials.json" > "$tmp/updated"
mv "$tmp/updated" "$home/.credentials.json"
oauth_reconcile_home "$store" "$home"
check "jq -e '.claudeAiOauth.accessToken == \"fixture-B\" and .mcpOAuth.common == \"never-copy\" and .mcpOAuth.local == null' '$store/.credentials.json' >/dev/null" 'publish subscription without home MCP'
oauth_prepare_home "$store" "$other"
check "jq -e '.claudeAiOauth.accessToken == \"fixture-B\"' '$other/.credentials.json' >/dev/null" 'other managed home receives refresh'

# Two different publishers from one baseline cannot both win.
jq '.claudeAiOauth.accessToken="fixture-C"' "$home/.credentials.json" > "$tmp/updated"
mv "$tmp/updated" "$home/.credentials.json"
jq '.claudeAiOauth.accessToken="fixture-D"' "$other/.credentials.json" > "$tmp/updated"
mv "$tmp/updated" "$other/.credentials.json"
oauth_reconcile_home "$store" "$home"
if oauth_reconcile_home "$store" "$other" 2> "$tmp/error"; then echo 'FAIL: divergent publisher accepted'; exit 1; fi
check "jq -e '.claudeAiOauth.accessToken == \"fixture-D\"' '$other/.credentials.json' >/dev/null" 'loser credentials preserved'

# Independent different credentials are not silently relinked or adopted.
independent="$tmp/independent"
mkdir "$independent"
printf '%s\n' '{"claudeAiOauth":{"accessToken":"independent"}}' > "$independent/.credentials.json"
cp "$independent/.credentials.json" "$tmp/independent.before"
if oauth_prepare_home "$store" "$independent" 2> "$tmp/error"; then echo 'FAIL: independent credentials adopted'; exit 1; fi
check 'cmp "$tmp/independent.before" "$independent/.credentials.json"' 'independent conflict byte preservation'

# Known legacy link is backed up and detached; unknown targets fail closed.
legacy="$tmp/legacy"
mkdir "$legacy"
ln -s "$store/.credentials.json" "$legacy/.credentials.json"
oauth_prepare_home "$store" "$legacy"
check '[[ ! -L "$legacy/.credentials.json" ]] && find "$legacy" -type l | read -r retained' 'legacy link retained as backup'
unknown="$tmp/unknown"
mkdir "$unknown"
ln -s "$independent/.credentials.json" "$unknown/.credentials.json"
if oauth_prepare_home "$store" "$unknown" 2> "$tmp/error"; then echo 'FAIL: unknown link followed'; exit 1; fi
check '[[ -L "$unknown/.credentials.json" ]]' 'unknown link unchanged'

# A deleted managed credential cannot resurrect a logged-out session.
rm "$legacy/.credentials.json"
if oauth_prepare_home "$store" "$legacy" 2> "$tmp/error"; then echo 'FAIL: logout resurrected'; exit 1; fi
check '[[ ! -e "$legacy/.credentials.json" ]]' 'deleted credential not restored'

# Equal independent credentials must not be reformatted while metadata is seeded.
equal="$tmp/equal"
mkdir "$equal"
printf '%s' '{ "claudeAiOauth" : {"accessToken":"fixture-C","refreshToken":"refresh-A"} }' > "$equal/.credentials.json"
cp "$equal/.credentials.json" "$tmp/equal.before"
oauth_prepare_home "$store" "$equal"
check 'cmp "$tmp/equal.before" "$equal/.credentials.json"' 'equal independent credential bytes unchanged'

# A live reader can write native refresh state while an exclusive writer waits.
waiting="$tmp/waiting"
oauth_prepare_home "$store" "$equal"
cp -a "$equal" "$waiting"
(
    exec {reader}>"$waiting/.iclaude-auth.lock"
    flock -s "$reader"
    : > "$tmp/reader-ready"
    while [[ ! -e "$tmp/write-reader" ]]; do sleep 0.01; done
    jq '.claudeAiOauth.accessToken="reader-refresh"' "$waiting/.credentials.json" > "$tmp/reader-update"
    mv "$tmp/reader-update" "$waiting/.credentials.json"
) &
reader_pid=$!
while [[ ! -e "$tmp/reader-ready" ]]; do sleep 0.01; done
jq '.claudeAiOauth.accessToken="store-refresh"' "$store/.credentials.json" > "$tmp/store-update"
mv "$tmp/store-update" "$store/.credentials.json"
(oauth_prepare_home "$store" "$waiting" 2> "$tmp/error") &
writer_pid=$!
sleep 0.1
: > "$tmp/write-reader"
wait "$reader_pid"
if wait "$writer_pid"; then echo 'FAIL: native reader change overwritten after lock upgrade'; exit 1; fi
check "jq -e '.claudeAiOauth.accessToken == \"reader-refresh\"' '$waiting/.credentials.json' >/dev/null" 're-read state after exclusive lock acquired'

# Failed pair publication restores exact old files; failed restoration quarantines.
failure_home="$tmp/failure"
mkdir "$failure_home"
oauth_prepare_home "$store" "$failure_home"
cp "$failure_home/.credentials.json" "$tmp/failure-credentials.before"
cp "$failure_home/.claude.json" "$tmp/failure-metadata.before"
jq '.claudeAiOauth.accessToken="next-refresh"' "$store/.credentials.json" > "$tmp/store-update"
mv "$tmp/store-update" "$store/.credentials.json"
(
    mv() {
        [[ "$1" != *'/new-metadata' ]] || return 1
        command mv "$@"
    }
    if oauth_prepare_home "$store" "$failure_home" 2> "$tmp/error"; then exit 1; fi
)
check 'cmp "$tmp/failure-credentials.before" "$failure_home/.credentials.json" && cmp "$tmp/failure-metadata.before" "$failure_home/.claude.json"' 'pair rollback preserves exact original bytes'
(
    mv() {
        [[ "$1" != *'/new-metadata' && "$1" != *'/restore' ]] || return 1
        command mv "$@"
    }
    if oauth_prepare_home "$store" "$failure_home" 2> "$tmp/error"; then exit 1; fi
)
check '[[ -f "$failure_home/.iclaude-auth-recovery" ]]' 'failed rollback creates recovery marker'
if oauth_prepare_home "$store" "$failure_home" 2> "$tmp/error"; then echo 'FAIL: quarantined home accepted'; exit 1; fi
checks=$((checks+1))

lock_home="$tmp/no-lock"
mkdir "$lock_home"
(
    flock() { return 1; }
    if oauth_prepare_home "$store" "$lock_home" 2> "$tmp/error"; then exit 1; fi
)
check '[[ ! -e "$lock_home/.credentials.json" ]]' 'lock failure never falls through to auth write'
check '! rg -q "fixture-|refresh-|never-copy" "$tmp/error"' 'no credential values in diagnostics'

printf 'oauth-persistence: PASS=%s FAIL=0\n' "$checks"
