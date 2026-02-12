#!/usr/bin/env bash
# lib/context/operations.sh
# Context Management - CRUD Operations
#
# Part of Phase 10: Context Management extraction from iclaude-legacy.sh
# Contains 6 context operation functions (export/import/sync/clean/backup/status)

#######################################
# Export context to archive
# Creates tar.gz with memory + filtered history
# Globals:
#   CLAUDE_DIR
#   CONTEXT_EXPORTS_DIR
# Arguments:
#   $1 - Project path (default: pwd)
# Returns:
#   0 on success, 1 on failure
# Outputs:
#   Archive path and instructions
#######################################
context_cmd_export() {
    local project_path="${1:-$(pwd)}"
    local project_name=$(get_context_project_name "$project_path")
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local export_name="${project_name}-${timestamp}"
    local export_dir="/tmp/context-export-$$"
    local archive_file="$CONTEXT_EXPORTS_DIR/${export_name}.tar.gz"

    echo "🔄 Exporting context for: $project_name"
    echo "   Project: $project_path"

    init_context_directories
    mkdir -p "$export_dir/$export_name"

    # Export memory
    local memory_dir=$(get_context_project_memory_dir "$project_path")
    if [[ -d "$memory_dir" ]] && [[ -n "$(ls -A "$memory_dir" 2>/dev/null)" ]]; then
        echo "   ✓ Copying memory..."
        cp -r "$memory_dir" "$export_dir/$export_name/memory"
    else
        echo "   ⚠ No memory files"
        mkdir -p "$export_dir/$export_name/memory"
    fi

    # Filter history
    local history_file="${CLAUDE_DIR:-$HOME/.claude}/history.jsonl"
    if [[ -f "$history_file" ]]; then
        echo "   ✓ Filtering history..."
        grep -F "$project_path" "$history_file" > "$export_dir/$export_name/history-filtered.jsonl" 2>/dev/null || true
        local history_count=$(wc -l < "$export_dir/$export_name/history-filtered.jsonl" 2>/dev/null || echo 0)
        echo "     $history_count entries"
    fi

    # Create metadata
    cat > "$export_dir/$export_name/metadata.json" <<EOF
{
  "projectName": "$project_name",
  "projectPath": "$project_path",
  "exportDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "exporter": "iclaude.sh"
}
EOF

    # Create archive
    echo "   ✓ Creating archive..."
    tar -czf "$archive_file" -C "$export_dir" "$export_name" 2>/dev/null
    rm -rf "$export_dir"

    local archive_size=$(du -h "$archive_file" | cut -f1)
    echo ""
    echo "✅ Exported: $archive_file ($archive_size)"
    echo "   Import with: ./iclaude.sh --context-import $archive_file"
}

#######################################
# Import context from archive
# Extracts memory + history to current project
# Globals:
#   CLAUDE_DIR
# Arguments:
#   $1 - Archive file path
#   $2 - Target project path (default: pwd)
# Returns:
#   0 on success, 1 on failure
# Outputs:
#   Import progress and confirmation
#######################################
context_cmd_import() {
    local archive_file="$1"
    local target_project="${2:-$(pwd)}"

    if [[ ! -f "$archive_file" ]]; then
        echo "❌ Archive not found: $archive_file" >&2
        return 1
    fi

    local temp_dir="/tmp/context-import-$$"
    mkdir -p "$temp_dir"

    echo "🔄 Importing: $(basename "$archive_file")"

    tar -xzf "$archive_file" -C "$temp_dir" 2>/dev/null || {
        echo "❌ Failed to extract" >&2
        rm -rf "$temp_dir"
        return 1
    }

    local extracted_dir=$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d | head -1)
    if [[ ! -d "$extracted_dir" ]]; then
        echo "❌ Invalid archive" >&2
        rm -rf "$temp_dir"
        return 1
    fi

    # Show metadata
    if [[ -f "$extracted_dir/metadata.json" ]] && command -v jq &>/dev/null; then
        echo ""
        jq -r '"  Project: \(.projectName)\n  Exported: \(.exportDate)"' "$extracted_dir/metadata.json"
        echo ""
    fi

    # Confirm
    read -p "Import to current project? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        rm -rf "$temp_dir"
        return 0
    fi

    # Import memory
    local target_memory=$(get_context_project_memory_dir "$target_project")
    mkdir -p "$target_memory"
    if [[ -d "$extracted_dir/memory" ]]; then
        echo "✓ Importing memory..."
        cp -r "$extracted_dir/memory/"* "$target_memory/" 2>/dev/null || true
    fi

    # Import history
    if [[ -f "$extracted_dir/history-filtered.jsonl" ]]; then
        local target_history="${CLAUDE_DIR:-$HOME/.claude}/history.jsonl"
        echo "✓ Importing history..."
        cat "$extracted_dir/history-filtered.jsonl" >> "$target_history"
    fi

    rm -rf "$temp_dir"
    echo ""
    echo "✅ Imported to: $target_memory"
}

#######################################
# Sync context between main repo and worktrees
# Bidirectional sync via shared directory
# Globals:
#   None
# Arguments:
#   $1 - Direction: "pull" or "push" (default: pull)
#   $2 - Project path (default: pwd)
# Returns:
#   0 on success
# Outputs:
#   Sync progress
#######################################
context_cmd_sync() {
    local direction="${1:-pull}"
    local project_path="${2:-$(pwd)}"

    if ! is_context_worktree "$project_path"; then
        local shared_dir=$(get_context_shared_memory_dir "$project_path")
        local project_memory=$(get_context_project_memory_dir "$project_path")

        if [[ "$direction" == "push" ]]; then
            echo "📤 Syncing to shared..."
            mkdir -p "$shared_dir"
            rsync -av --delete "$project_memory/" "$shared_dir/" 2>/dev/null || cp -r "$project_memory/"* "$shared_dir/" 2>/dev/null || true
            echo "✅ Shared: $shared_dir"
        else
            echo "ℹ️  Main repo - use --push to sync"
        fi
        return 0
    fi

    # Worktree sync
    local main_worktree=$(get_context_main_worktree "$project_path")
    local shared_dir=$(get_context_shared_memory_dir "$main_worktree")
    local project_memory=$(get_context_project_memory_dir "$project_path")

    if [[ "$direction" == "pull" ]]; then
        if [[ -d "$shared_dir" ]] && [[ -n "$(ls -A "$shared_dir" 2>/dev/null)" ]]; then
            echo "📥 Pulling from shared..."
            mkdir -p "$project_memory"
            rsync -av "$shared_dir/" "$project_memory/" 2>/dev/null || cp -r "$shared_dir/"* "$project_memory/" 2>/dev/null || true
            echo "✅ Synced from: $shared_dir"
        else
            echo "ℹ️  No shared memory - run from main with --push first"
        fi
    else
        echo "📤 Pushing to shared..."
        mkdir -p "$shared_dir"
        rsync -av --delete "$project_memory/" "$shared_dir/" 2>/dev/null || cp -r "$project_memory/"* "$shared_dir/" 2>/dev/null || true
        echo "✅ Shared: $shared_dir"
    fi
}

#######################################
# Clean old context data
# Removes old sessions and trims history
# Globals:
#   CLAUDE_DIR
#   CONTEXT_CLEANUP_DAYS
#   CONTEXT_MAX_HISTORY_SIZE
# Arguments:
#   $1 - Days threshold (default: CONTEXT_CLEANUP_DAYS)
# Returns:
#   0 on success
# Outputs:
#   Cleanup progress
#######################################
context_cmd_clean() {
    local days="${1:-$CONTEXT_CLEANUP_DAYS}"
    local claude_dir="${CLAUDE_DIR:-$HOME/.claude}"

    echo "🧹 Cleaning context..."
    echo "   Removing sessions older than $days days"

    local removed=0
    if [[ -d "$claude_dir/session-env" ]]; then
        while IFS= read -r -d '' session_dir; do
            local mtime=$(stat -c %Y "$session_dir" 2>/dev/null || stat -f %m "$session_dir" 2>/dev/null)
            local age_days=$(( ($(date +%s) - mtime) / 86400 ))
            if [[ $age_days -gt $days ]]; then
                rm -rf "$session_dir"
                ((removed++))
            fi
        done < <(find "$claude_dir/session-env" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
        echo "   ✓ Removed $removed sessions"
    fi

    # Clean history
    local history_file="$claude_dir/history.jsonl"
    if [[ -f "$history_file" ]]; then
        local history_size=$(stat -c %s "$history_file" 2>/dev/null || stat -f %z "$history_file" 2>/dev/null || echo 0)
        if [[ $history_size -gt $CONTEXT_MAX_HISTORY_SIZE ]]; then
            echo "   ⚠ History large ($(numfmt --to=iec-i --suffix=B $history_size 2>/dev/null || echo "${history_size}B"))"
            echo "   Creating backup..."
            cp "$history_file" "$history_file.backup-$(date +%Y%m%d)"
            local total=$(wc -l < "$history_file")
            local keep=$((total / 2))
            tail -n "$keep" "$history_file" > "$history_file.tmp"
            mv "$history_file.tmp" "$history_file"
            local new_size=$(stat -c %s "$history_file" 2>/dev/null || stat -f %z "$history_file" 2>/dev/null || echo 0)
            echo "   ✓ Trimmed: $(numfmt --to=iec-i --suffix=B $history_size 2>/dev/null || echo "${history_size}B") → $(numfmt --to=iec-i --suffix=B $new_size 2>/dev/null || echo "${new_size}B")"
        fi
    fi

    echo ""
    echo "✅ Cleanup complete"
}

#######################################
# Backup context data
# Creates timestamped backup of history + projects
# Globals:
#   CLAUDE_DIR
#   CONTEXT_BACKUPS_DIR
# Arguments:
#   $1 - Backup mode: "manual", "daily", "weekly" (default: manual)
# Returns:
#   0 on success
# Outputs:
#   Backup location and size
#######################################
context_cmd_backup() {
    local mode="${1:-manual}"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="$CONTEXT_BACKUPS_DIR/$mode/$timestamp"
    local claude_dir="${CLAUDE_DIR:-$HOME/.claude}"

    echo "💾 Creating backup..."
    echo "   Mode: $mode"

    init_context_directories
    mkdir -p "$backup_dir"

    # Backup history
    if [[ -f "$claude_dir/history.jsonl" ]]; then
        cp "$claude_dir/history.jsonl" "$backup_dir/history.jsonl"
        echo "   ✓ History"
    fi

    # Backup projects
    if [[ -d "$claude_dir/projects" ]]; then
        cp -r "$claude_dir/projects" "$backup_dir/projects"
        echo "   ✓ Projects"
    fi

    local size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1 || echo "unknown")
    echo ""
    echo "✅ Backup: $backup_dir ($size)"
}

#######################################
# Show context status
# Displays memory, history, sessions, worktree info
# Globals:
#   CLAUDE_DIR
# Arguments:
#   $1 - Project path (default: pwd)
# Returns:
#   0 on success
# Outputs:
#   Detailed context status
#######################################
context_cmd_status() {
    local project_path="${1:-$(pwd)}"
    local project_name=$(get_context_project_name "$project_path")
    local project_memory=$(get_context_project_memory_dir "$project_path")
    local claude_dir="${CLAUDE_DIR:-$HOME/.claude}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Context Status: $project_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Project: $project_path"
    echo ""

    # Memory
    if [[ -d "$project_memory" ]] && [[ -n "$(ls -A "$project_memory" 2>/dev/null)" ]]; then
        local mem_size=$(du -sh "$project_memory" 2>/dev/null | cut -f1 || echo "unknown")
        local mem_files=$(find "$project_memory" -type f 2>/dev/null | wc -l)
        echo "Memory:  $mem_size ($mem_files files)"
        if [[ -f "$project_memory/MEMORY.md" ]]; then
            local lines=$(wc -l < "$project_memory/MEMORY.md")
            echo "         └─ MEMORY.md ($lines lines)"
        fi
    else
        echo "Memory:  Empty"
    fi

    # History
    if [[ -f "$claude_dir/history.jsonl" ]]; then
        local hist_size=$(du -sh "$claude_dir/history.jsonl" 2>/dev/null | cut -f1 || echo "unknown")
        local total=$(wc -l < "$claude_dir/history.jsonl" 2>/dev/null || echo 0)
        local project_entries=$(grep -c -F "$project_path" "$claude_dir/history.jsonl" 2>/dev/null || echo 0)
        echo "History: $hist_size ($project_entries/$total entries)"
    fi

    # Sessions
    local sessions=0
    if [[ -d "$claude_dir/session-env" ]]; then
        sessions=$(find "$claude_dir/session-env" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    fi
    echo "Sessions: $sessions active"

    # Worktree
    if is_context_worktree "$project_path"; then
        local main=$(get_context_main_worktree "$project_path")
        echo "Worktree: Yes (main: $main)"
        local shared=$(get_context_shared_memory_dir "$main")
        if [[ -d "$shared" ]]; then
            local shared_size=$(du -sh "$shared" 2>/dev/null | cut -f1 || echo "unknown")
            echo "Shared:   $shared_size"
        fi
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
