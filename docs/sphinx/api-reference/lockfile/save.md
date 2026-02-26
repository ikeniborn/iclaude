# save

> **Module:** `lockfile` | **File:** `lib/lockfile/save.sh`

Lockfile Save Module
Description: Save current installation state to lockfile for reproducibility

---

## `save_isolated_lockfile`

Save isolated environment versions to lockfile Captures: Node.js, Claude Code, Router, GH CLI, LSP servers, LSP plugins, Sandbox, StatusLine, Oh-My-Posh

**Returns:**

-   0 - success
-   1 - error

**Example:**

```bash
  save_isolated_lockfile || return 1
```

## `compute_lockfile_hash`

Compute SHA-256 hash of the lockfile Portable: sha256sum (Linux) → shasum -a 256 (macOS) → md5sum (fallback)

**Returns:**

-   Hash string on stdout
-   Exit code: 0 on success, 1 if lockfile missing

**Example:**

```bash
  current_hash=$(compute_lockfile_hash) || return 1
```

## `update_lockfile_hash`

Write current lockfile hash to LOCKFILE_HASH_FILE Called after install_from_lockfile() and save_isolated_lockfile()

**Returns:**

-   0 - hash written successfully
-   1 - failed (lockfile missing or hash empty)

**Example:**

```bash
  update_lockfile_hash || print_warning "Could not update lockfile hash"
```

## `check_lockfile_changes`

Check if lockfile has changed since last applied hash Compares current lockfile hash with stored hash in LOCKFILE_HASH_FILE If changed: warns user and offers to run --install-from-lockfile If no stored hash: silently initialises hash file (first run) If not interactive (CI/CD): prints warning only, does not prompt

**Returns:**

-   0 - no change detected or user declined update or first-run init
-   0 - even when changed (non-blocking: launch continues regardless)

**Example:**

```bash
  check_lockfile_changes
```

