#!/bin/bash
# beforeCompact hook - Auto-save context before Claude Code compaction
# Triggered before /compact command execution
#
# NOTE: This hook is FUTURE functionality - Claude Code doesn't support
# beforeCompact hook yet. When Anthropic adds it, this script will work
# automatically.
#
# Current workaround: Run manually before /compact:
#   bash .nvm-isolated/.claude-isolated/hooks/beforeCompact.hook.sh

# ============================================================================
# Configuration
# ============================================================================

PROJECT_PATH="${PROJECT_PATH:-$(pwd)}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
CONTEXTS_DIR="$CLAUDE_DIR/contexts"
PRE_COMPACT_DIR="$CONTEXTS_DIR/pre-compact"

# ============================================================================
# Pre-Compact Context Snapshot
# ============================================================================

# Create snapshot directory
mkdir -p "$PRE_COMPACT_DIR"

# Generate snapshot filename
PROJECT_NAME=$(basename "$PROJECT_PATH")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAPSHOT_FILE="$PRE_COMPACT_DIR/${PROJECT_NAME}-${TIMESTAMP}.jsonl"

echo "🔄 Creating pre-compact snapshot..." >&2
echo "   Project: $PROJECT_NAME" >&2
echo "   Snapshot: $SNAPSHOT_FILE" >&2

# ============================================================================
# Extract Recent Context
# ============================================================================

# Get last 100 history entries for this project
if [[ -f "$CLAUDE_DIR/history.jsonl" ]]; then
    # Filter by project path and take last 100 entries
    grep -F "$PROJECT_PATH" "$CLAUDE_DIR/history.jsonl" | tail -100 > "$SNAPSHOT_FILE"
    ENTRY_COUNT=$(wc -l < "$SNAPSHOT_FILE")
    echo "   ✓ Saved $ENTRY_COUNT history entries" >&2
fi

# ============================================================================
# Auto-Update MEMORY.md
# ============================================================================

# Get project memory directory (in project, not user home)
MEMORY_DIR="$PROJECT_PATH/.claude/memory"
MEMORY_FILE="$MEMORY_DIR/MEMORY.md"

# Create memory directory if it doesn't exist
mkdir -p "$MEMORY_DIR"

# Check if MEMORY.md has recent updates
if [[ -f "$MEMORY_FILE" ]]; then
    # Check file age
    if [[ -n "$(find "$MEMORY_FILE" -mtime -1 2>/dev/null)" ]]; then
        echo "   ℹ️  MEMORY.md recently updated, skipping auto-update" >&2
    else
        echo "   💡 Reminder: Consider updating MEMORY.md with important patterns" >&2
    fi
else
    # Create initial MEMORY.md template
    cat > "$MEMORY_FILE" <<'EOF'
# Auto Memory - Context Preservation

This file is loaded into every Claude Code session for this project.
Add important patterns, decisions, and learnings here.

## Project Context

<!-- Add high-level project description -->

## Key Patterns

<!-- Document recurring solutions and approaches -->

## Important Decisions

<!-- Record architectural decisions and rationale -->

## Common Pitfalls

<!-- Note mistakes to avoid in future work -->

---
*Auto-created by beforeCompact hook*
EOF

    echo "   ✓ Created MEMORY.md template" >&2
    echo "   💡 Edit $MEMORY_FILE to preserve context across sessions" >&2
fi

# ============================================================================
# Snapshot Metadata
# ============================================================================

# Append metadata to snapshot
cat >> "$SNAPSHOT_FILE" <<EOF

# Snapshot Metadata
# Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Project: $PROJECT_PATH
# Trigger: beforeCompact hook
# Entries: $ENTRY_COUNT
EOF

# ============================================================================
# Cleanup Old Snapshots
# ============================================================================

# Keep only last 10 snapshots per project
SNAPSHOTS_TO_KEEP=10

SNAPSHOT_COUNT=$(find "$PRE_COMPACT_DIR" -name "${PROJECT_NAME}-*.jsonl" -type f | wc -l)

if [[ $SNAPSHOT_COUNT -gt $SNAPSHOTS_TO_KEEP ]]; then
    TO_REMOVE=$((SNAPSHOT_COUNT - SNAPSHOTS_TO_KEEP))

    find "$PRE_COMPACT_DIR" -name "${PROJECT_NAME}-*.jsonl" -type f -printf '%T+ %p\n' | \
        sort | head -n "$TO_REMOVE" | cut -d' ' -f2- | \
        while IFS= read -r old_snapshot; do
            rm -f "$old_snapshot"
            echo "   🗑️  Removed old snapshot: $(basename "$old_snapshot")" >&2
        done
fi

# ============================================================================
# Summary
# ============================================================================

SNAPSHOT_SIZE=$(du -h "$SNAPSHOT_FILE" 2>/dev/null | cut -f1)

echo "" >&2
echo "✅ Pre-compact snapshot complete!" >&2
echo "   File: $SNAPSHOT_FILE" >&2
echo "   Size: $SNAPSHOT_SIZE" >&2
echo "" >&2
echo "To restore from snapshot:" >&2
echo "   cat $SNAPSHOT_FILE >> $CLAUDE_DIR/history.jsonl" >&2
echo "" >&2

# Exit 0 to allow /compact to proceed
exit 0
