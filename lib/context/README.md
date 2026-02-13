# Context Management Modules (Phase 10)

## Overview

Context Management modules handle Claude Code project context operations including memory management, export/import, synchronization between worktrees, and cleanup.

**Extracted Functions:** 18 (from iclaude-legacy.sh:6766-7459)
**Lines of Code:** 850 (init: 122, operations: 368, memory: 360)
**Risk Level:** LOW (path helpers) to MEDIUM (CRUD operations)

---

## Module: init.sh

**Purpose:** Path helpers and directory initialization

### Functions (7)

#### `init_context_directories()`
Creates context directory structure:
```
$CLAUDE_DIR/contexts/
├── exports/
├── shared/
├── backups/
│   ├── daily/
│   ├── weekly/
│   └── manual/
└── templates/
```

**Usage:**
```bash
init_context_directories
```

#### `get_context_project_name(project_path)`
Returns project basename.

**Example:**
```bash
get_context_project_name /home/user/my-project
# Output: my-project
```

#### `get_context_project_hash(project_path)`
Converts project path to hash by replacing slashes.

**Example:**
```bash
get_context_project_hash /home/user/my-project
# Output: home-user-my-project
```

#### `get_context_project_memory_dir(project_path)`
Returns `.claude/memory` path for project.

#### `get_context_shared_memory_dir(project_path)`
Returns shared memory directory for worktree synchronization.

#### `is_context_worktree(project_path)`
Checks if path is a git worktree (returns 0 if true).

#### `get_context_main_worktree(project_path)`
Resolves main worktree path if current path is a worktree.

### Configuration Variables

```bash
CONTEXT_BASE_DIR="${CLAUDE_DIR:-$HOME/.claude}/contexts"
CONTEXT_EXPORTS_DIR="$CONTEXT_BASE_DIR/exports"
CONTEXT_SHARED_DIR="$CONTEXT_BASE_DIR/shared"
CONTEXT_BACKUPS_DIR="$CONTEXT_BASE_DIR/backups"
CONTEXT_TEMPLATES_DIR="$CONTEXT_BASE_DIR/templates"

# Default settings
CONTEXT_CLEANUP_DAYS=30
CONTEXT_MAX_HISTORY_SIZE=$((5 * 1024 * 1024))  # 5 MB
CONTEXT_AUTO_SYNC=true
```

---

## Module: operations.sh

**Purpose:** CRUD operations for context management

### Functions (6)

#### `context_cmd_export(project_path)`
Exports context to timestamped tar.gz archive.

**Includes:**
- Project memory (`.claude/memory/`)
- Filtered history (project-specific entries from `history.jsonl`)
- Metadata JSON

**Usage:**
```bash
./iclaude.sh --context-export
# Output: ~/.claude/contexts/exports/my-project-20260212-143052.tar.gz
```

#### `context_cmd_import(archive_file, target_project)`
Imports context from archive with user confirmation.

**Usage:**
```bash
./iclaude.sh --context-import /path/to/export.tar.gz
```

**Interactive:** Prompts user before importing.

#### `context_cmd_sync(direction, project_path)`
Synchronizes context between main repo and worktrees.

**Directions:**
- `pull` - Copy from shared to worktree (default)
- `push` - Copy from repo/worktree to shared

**Worktree Workflow:**
```bash
# In main repo
./iclaude.sh --context-sync push

# In worktree
./iclaude.sh --context-sync pull
```

Uses `rsync` for efficient sync, falls back to `cp`.

#### `context_cmd_clean(days)`
Cleans old sessions and trims large history.

**Default:** Removes sessions older than 30 days

**Usage:**
```bash
./iclaude.sh --context-clean      # Use default (30 days)
./iclaude.sh --context-clean 60   # Custom threshold
```

**Actions:**
- Removes old session directories from `$CLAUDE_DIR/session-env/`
- If `history.jsonl` > 5MB: backs up and trims to 50%

#### `context_cmd_backup(mode)`
Creates timestamped backup of history + projects.

**Modes:** `manual` (default), `daily`, `weekly`

**Usage:**
```bash
./iclaude.sh --context-backup
./iclaude.sh --context-backup daily
```

**Backup Location:**
```
$CLAUDE_DIR/contexts/backups/{mode}/{timestamp}/
├── history.jsonl
└── projects/
```

#### `context_cmd_status(project_path)`
Displays comprehensive context status.

**Shows:**
- Memory size and file count
- History size and project-specific entries
- Active sessions count
- Worktree status and shared memory

**Usage:**
```bash
./iclaude.sh --context-status
```

---

## Module: memory.sh

**Purpose:** Auto Memory (MEMORY.md) management following Anthropic best practices

**Documentation:** https://code.claude.com/docs/en/memory

### Functions (5)

#### `context_memory_init(project_path)`
Creates `MEMORY.md` template with best practices structure.

**Template Includes:**
- Project Overview
- Tech Stack
- Code Style & Conventions
- Common Patterns
- Important Decisions
- Common Pitfalls
- References

**Usage:**
```bash
./iclaude.sh --context-memory-init
```

**Important:** First 200 lines loaded into system prompt every session.

#### `context_memory_validate(project_path)`
Validates MEMORY.md against best practices.

**Checks:**
- **Size:** Warns if >150 lines, alerts if >200 lines
- **Structure:** Checks heading count (need 3+)
- **Language:** Detects vague terms (proper, correct, good, bad)
- **Topic Files:** Lists related .md files

**Usage:**
```bash
./iclaude.sh --context-memory-validate
```

**Example Output:**
```
📊 Size Check:
   Lines: 36/200 (18%)
   ✓ Within limit

📋 Structure Check:
   ✓ Organized (8 headings)
   ⚠ Found 2 vague terms
   ℹ No topic files yet
```

#### `context_memory_organize(project_path)`
Suggests topic file organization when MEMORY.md exceeds 150 lines.

**Analyzes Content For:**
- Debugging patterns (→ `debugging.md`)
- Code patterns (→ `patterns.md`)
- Architecture decisions (→ `architecture.md`)
- API design (→ `api.md`)

**Usage:**
```bash
./iclaude.sh --context-memory-organize
```

**Recommendation:** Move detailed content to topic files, keep summaries in MEMORY.md.

#### `context_memory_add(entry, project_path)`
Appends entry to MEMORY.md with auto-validation.

**Usage:**
```bash
./iclaude.sh --context-memory-add "Use 2-space YAML indent"
```

**Auto-Validation:** Warns if adding entry pushes file >200 lines.

#### `context_memory_status(project_path)`
Displays MEMORY.md status.

**Shows:**
- File size and line count
- Usage percentage (of 200-line limit)
- Topic files count
- Last modified timestamp
- Available commands

**Usage:**
```bash
./iclaude.sh --context-memory-status
```

---

## Integration with iclaude.sh

### Loading (iclaude.sh:151-157)

```bash
#######################################
# Load Context Management modules (Phase 10)
#######################################
if [[ -d "$LIB_DIR/context" ]]; then
    source "${LIB_DIR}/context/init.sh"
    source "${LIB_DIR}/context/operations.sh"
    source "${LIB_DIR}/context/memory.sh"
fi
```

### Guard Pattern (iclaude-legacy.sh)

All 18 functions use guard pattern to prevent conflicts:

```bash
if ! declare -F context_cmd_export &>/dev/null; then
context_cmd_export() {
    # Implementation
}
fi
```

**Guard Count:** 83 total (18 added in Phase 10)

---

## CLI Commands

### Context Operations

```bash
--context-status [PATH]              # Show context status
--context-export [ARCHIVE]           # Export context to tar.gz
--context-import ARCHIVE [PATH]      # Import context from archive
--context-sync [pull|push] [PATH]    # Sync between main and worktrees
--context-clean [DAYS]               # Clean old sessions and history
--context-backup [MODE]              # Backup context data
```

### Memory Operations

```bash
--context-memory-init [PATH]         # Initialize MEMORY.md
--context-memory-validate [PATH]     # Validate best practices
--context-memory-organize [PATH]     # Suggest topic files
--context-memory-add "TEXT" [PATH]   # Add entry to MEMORY.md
--context-memory-status [PATH]       # Show MEMORY.md status
```

---

## Best Practices

### MEMORY.md Guidelines

1. **Be Specific:**
   - ✅ "Use 2-space YAML indent"
   - ❌ "Use proper indent"

2. **Use Headings:** Organize content with clear sections

3. **200-Line Limit:** Only first 200 lines loaded into system prompt

4. **Topic Files:** Move details to separate .md files when >200 lines

5. **References:** Link to topic files from MEMORY.md

### Worktree Synchronization

**Main Repo:**
```bash
./iclaude.sh --context-sync push  # Share memory with worktrees
```

**Worktrees:**
```bash
./iclaude.sh --context-sync pull  # Pull shared memory
```

### Export/Import Workflow

**Export from Project A:**
```bash
cd /path/to/project-a
./iclaude.sh --context-export
# Creates: ~/.claude/contexts/exports/project-a-20260212-143052.tar.gz
```

**Import to Project B:**
```bash
cd /path/to/project-b
./iclaude.sh --context-import ~/.claude/contexts/exports/project-a-20260212-143052.tar.gz
```

---

## Testing

### Phase 10 Test Coverage

**init.sh:**
- ✅ Path helper functions return correct values
- ✅ Worktree detection works correctly
- ✅ Main worktree resolution

**operations.sh:**
- ✅ Export creates valid tar.gz
- ✅ Import restores memory + history
- ✅ Sync bidirectional (push/pull)
- ✅ Clean removes old sessions
- ✅ Backup preserves data

**memory.sh:**
- ✅ Init creates template
- ✅ Validate checks size/structure/language
- ✅ Add appends entries with auto-validation
- ✅ Organize suggests topic files
- ✅ Status shows accurate metrics

### Regression Tests

```bash
# Test context operations
./iclaude.sh --context-status
./iclaude.sh --context-memory-init
./iclaude.sh --context-memory-validate
./iclaude.sh --context-memory-add "Test entry"
./iclaude.sh --context-memory-status

# Test export/import roundtrip
cd /tmp && mkdir test-project && cd test-project
/path/to/iclaude.sh --context-memory-init
/path/to/iclaude.sh --context-export
/path/to/iclaude.sh --context-import ~/.claude/contexts/exports/*.tar.gz
```

---

## Next Steps (Phase 11-15)

**Phase 11:** Loop Mode - Task Loading (parser, validator, state)
**Phase 12:** Loop Mode - Sequential Execution (executor, retry, git)
**Phase 13:** Loop Mode - Parallel Execution (parallel, worktree, AI merge)
**Phase 14:** Command Handling (usage, parse, dispatch)
**Phase 15:** Final Cleanup (remove iclaude-legacy.sh, release v4.0)

**Estimated Completion:** Phase 15 (100% modular architecture)
