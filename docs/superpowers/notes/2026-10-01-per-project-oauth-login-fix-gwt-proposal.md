# Credential Contract Replacement Proposal

Status: awaiting the human checkpoint required by implementation plan Task 4.1.
The existing scenario identity remains unchanged; only its credential contract changes.
Do not publish this replacement specification until reviewed.

## Shared Asset Credential Exception

```iwiki-gwt
id = "shared-asset-symlink-layer"
title = "Wire non-credential shared assets without destroying project login"
given = [
  { role = "state", name = "ICLAUDE_HOME_MODE is set to per-project" },
  { role = "fact", name = "the shared store contains managed assets and subscription credentials, and the project may contain an independent credential file" }
]
when = { role = "action", name = "iclaude sets up the per-project home" }
then = [
  { role = "outcome", name = "non-credential managed assets are linked and self-repaired using the existing rules" },
  { role = "outcome", name = "generic shared-asset repair neither links nor deletes nor replaces .credentials.json" },
  { role = "outcome", name = "an existing independent credential file remains byte-identical" },
  { role = "outcome", name = "absent non-credential entries are skipped and their stale store links are pruned" }
]
code = [
  { relation = "implements", phase = "when", file = "lib/config/isolated.sh" },
  { relation = "verifies", file = "tests/test_shared_asset_links.sh" }
]
```

## Common Native Authorization

```iwiki-gwt
id = "native-shared-project-authorization"
title = "Share one native subscription login with preserved project state"
given = [
  { role = "state", name = "ICLAUDE_AUTH_MODE is absent or shared in .claude_config, regardless of inherited environment selectors" },
  { role = "fact", name = "the common store contains actual native login and onboarding state, and the project home is fresh or has a compatible managed snapshot" }
]
when = { role = "action", name = "the isolated native launcher starts and the native session exits" }
then = [
  { role = "outcome", name = "the project uses a private common subscription snapshot without another login and without copying common MCP credentials" },
  { role = "outcome", name = "same-account native credential renewal is published only after session exit under fail-closed locks and baseline comparison" },
  { role = "outcome", name = "conflicts, logout and deleted managed credentials are preserved and reported, not silently replaced or resurrected" },
  { role = "outcome", name = "settings and conversation history remain unchanged by authentication reconciliation" },
  { role = "outcome", name = "native failures remain failures; reconciliation failure after native success returns status 73" }
]
code = [
  { relation = "implements", phase = "when", file = "lib/oauth/persistence.sh" },
  { relation = "implements", phase = "given", file = "lib/config/env-map.sh" },
  { relation = "implements", phase = "when", file = "lib/launcher/launch.sh" },
  { relation = "verifies", file = "tests/test_oauth_policy.sh" },
  { relation = "verifies", file = "tests/test_oauth_persistence.sh" },
  { relation = "verifies", file = "tests/test_oauth_launch.sh" }
]
```
