#!/usr/bin/env bash
# lib/context/memory.sh
# Context Management - Auto Memory Functions
#
# Part of Phase 10: Context Management extraction from iclaude-legacy.sh
# Contains 5 MEMORY.md management functions (init/validate/organize/add/status)
# Based on Anthropic best practices: https://code.claude.com/docs/en/memory

#######################################
# Initialize MEMORY.md with best practices template
# Creates structured MEMORY.md following Anthropic guidelines
# Globals:
#   None
# Arguments:
#   $1 - Project path (default: pwd)
# Returns:
#   0 on success
# Outputs:
#   Initialization status and best practices tips
#######################################
context_memory_init() {
    local project_path="${1:-$(pwd)}"
    local project_memory=$(get_context_project_memory_dir "$project_path")
    local memory_file="$project_memory/MEMORY.md"

    echo "🧠 Initializing Auto Memory..."
    echo "   Project: $(get_context_project_name "$project_path")"

    mkdir -p "$project_memory"

    if [[ -f "$memory_file" ]]; then
        echo "   ⚠ MEMORY.md already exists"
        read -p "   Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "   Cancelled"
            return 0
        fi
    fi

    # Create MEMORY.md following Anthropic best practices
    cat > "$memory_file" <<'EOF'
# Auto Memory

**IMPORTANT**: First 200 lines loaded into system prompt every session.
Keep concise - move details to separate topic files.

## Project Overview

<!-- High-level description (2-3 sentences max) -->

## Tech Stack

<!-- Language, framework, key libraries -->

## Code Style & Conventions

<!-- Specific, actionable rules (e.g., "Use 2-space YAML indent", not "proper indent") -->

## Common Patterns

<!-- Recurring solutions used in this project -->

## Important Decisions

<!-- Key architectural choices and why -->

## Common Pitfalls

<!-- Mistakes to avoid -->

## References

<!-- Links to topic files: debugging.md, patterns.md, architecture.md -->

---
*Auto-created by iclaude.sh context-memory-init*
*Best Practices: https://code.claude.com/docs/en/memory*
EOF

    local lines=$(wc -l < "$memory_file")
    echo ""
    echo "✅ MEMORY.md created: $memory_file"
    echo "   Lines: $lines/200 ($(( (lines * 100) / 200 ))% of limit)"
    echo ""
    echo "📚 Best Practices:"
    echo "   - Be specific: \"Use 2-space YAML indent\" not \"proper indent\""
    echo "   - Use headings for organization"
    echo "   - Move details to topic files when >200 lines"
    echo "   - First 200 lines = system prompt"
}

#######################################
# Validate MEMORY.md against best practices
# Checks size, structure, and language clarity
# Globals:
#   None
# Arguments:
#   $1 - Project path (default: pwd)
# Returns:
#   0 on success, 1 if MEMORY.md not found
# Outputs:
#   Validation report with recommendations
#######################################
context_memory_validate() {
    local project_path="${1:-$(pwd)}"
    local project_memory=$(get_context_project_memory_dir "$project_path")
    local memory_file="$project_memory/MEMORY.md"

    echo "🔍 Validating Auto Memory..."
    echo ""

    if [[ ! -f "$memory_file" ]]; then
        echo "❌ MEMORY.md not found"
        echo "   Run: ./iclaude.sh --context-memory-init"
        return 1
    fi

    local lines=$(wc -l < "$memory_file")
    local percent=$(( (lines * 100) / 200 ))

    echo "📊 Size Check:"
    echo "   Lines: $lines/200 ($percent%)"

    if [[ $lines -gt 200 ]]; then
        echo "   ⚠ WARNING: Exceeds 200 line limit!"
        echo "   Only first 200 lines loaded into system prompt"
        echo ""
        echo "   Recommendation: Move details to topic files"
        local excess=$((lines - 200))
        echo "   Need to reduce by: $excess lines"
    elif [[ $lines -gt 150 ]]; then
        echo "   ⚠ Approaching limit (150-200 lines)"
        echo "   Consider organizing into topic files"
    else
        echo "   ✓ Within limit"
    fi

    echo ""
    echo "📋 Structure Check:"

    # Check for headings
    local headings=$(grep -c '^#' "$memory_file" 2>/dev/null || echo 0)
    if [[ $headings -lt 3 ]]; then
        echo "   ⚠ Few headings ($headings) - add organization"
    else
        echo "   ✓ Organized ($headings headings)"
    fi

    # Check for vague language
    local vague_count=$(grep -ciE 'proper|correct|good|bad|better|best' "$memory_file" 2>/dev/null || echo 0)
    if [[ $vague_count -gt 0 ]]; then
        echo "   ⚠ Found $vague_count vague terms (proper, correct, good, etc.)"
        echo "   Be specific: \"Use 2-space indent\" not \"proper indent\""
    else
        echo "   ✓ Specific language"
    fi

    # Check for topic files
    local topic_files=$(find "$project_memory" -name "*.md" ! -name "MEMORY.md" 2>/dev/null | wc -l)
    if [[ $topic_files -gt 0 ]]; then
        echo "   ✓ Topic files: $topic_files"
        find "$project_memory" -name "*.md" ! -name "MEMORY.md" -exec basename {} \; | sed 's/^/     - /'
    else
        echo "   ℹ No topic files yet"
    fi

    echo ""
    echo "✅ Validation complete"
    echo "   Location: $memory_file"
}

#######################################
# Organize MEMORY.md - suggest topic files
# Analyzes content and recommends split into topic files
# Globals:
#   None
# Arguments:
#   $1 - Project path (default: pwd)
# Returns:
#   0 on success, 1 if MEMORY.md not found
# Outputs:
#   Topic file suggestions and reorganization steps
#######################################
context_memory_organize() {
    local project_path="${1:-$(pwd)}"
    local project_memory=$(get_context_project_memory_dir "$project_path")
    local memory_file="$project_memory/MEMORY.md"

    echo "📂 Analyzing MEMORY.md organization..."
    echo ""

    if [[ ! -f "$memory_file" ]]; then
        echo "❌ MEMORY.md not found"
        return 1
    fi

    local lines=$(wc -l < "$memory_file")

    if [[ $lines -le 150 ]]; then
        echo "✅ MEMORY.md size OK ($lines/200 lines)"
        echo "   No reorganization needed yet"
        return 0
    fi

    echo "⚠ MEMORY.md approaching/exceeding limit ($lines/200 lines)"
    echo ""
    echo "💡 Suggested Topic Files:"
    echo ""

    # Analyze sections
    local has_debugging=$(grep -ci 'debug\|error\|fix\|bug' "$memory_file")
    local has_patterns=$(grep -ci 'pattern\|solution\|approach' "$memory_file")
    local has_architecture=$(grep -ci 'architecture\|design\|structure' "$memory_file")
    local has_api=$(grep -ci 'api\|endpoint\|route' "$memory_file")

    if [[ $has_debugging -gt 5 ]]; then
        echo "   📄 debugging.md - Common errors and solutions"
    fi

    if [[ $has_patterns -gt 5 ]]; then
        echo "   📄 patterns.md - Code patterns and practices"
    fi

    if [[ $has_architecture -gt 5 ]]; then
        echo "   📄 architecture.md - System design decisions"
    fi

    if [[ $has_api -gt 5 ]]; then
        echo "   📄 api.md - API design and endpoints"
    fi

    echo ""
    echo "📝 Reorganization Steps:"
    echo "   1. Create topic files (e.g., debugging.md, patterns.md)"
    echo "   2. Move detailed content to topic files"
    echo "   3. Keep only summaries in MEMORY.md"
    echo "   4. Add links: See debugging.md for error handling"
    echo ""
    echo "Example MEMORY.md structure:"
    echo "   ## Debugging"
    echo "   See debugging.md for common errors and solutions."
}

#######################################
# Add entry to MEMORY.md
# Appends new entry with auto-validation
# Globals:
#   None
# Arguments:
#   $1 - Entry text (required)
#   $2 - Project path (default: pwd)
# Returns:
#   0 on success, 1 if entry missing or MEMORY.md not found
# Outputs:
#   Confirmation and auto-validation warning if >200 lines
#######################################
context_memory_add() {
    local entry="$1"
    local project_path="${2:-$(pwd)}"
    local project_memory=$(get_context_project_memory_dir "$project_path")
    local memory_file="$project_memory/MEMORY.md"

    if [[ -z "$entry" ]]; then
        echo "❌ Entry text required"
        echo "   Usage: ./iclaude.sh --context-memory-add \"Use 2-space YAML indent\""
        return 1
    fi

    if [[ ! -f "$memory_file" ]]; then
        echo "❌ MEMORY.md not found - run --context-memory-init first"
        return 1
    fi

    # Add entry under appropriate section or at end
    echo "" >> "$memory_file"
    echo "- $entry" >> "$memory_file"

    echo "✅ Added to MEMORY.md: \"$entry\""
    echo ""

    # Auto-validate after add
    local lines=$(wc -l < "$memory_file")
    if [[ $lines -gt 200 ]]; then
        echo "⚠ MEMORY.md now exceeds 200 lines ($lines/200)"
        echo "   Run: ./iclaude.sh --context-memory-organize"
    fi
}

#######################################
# Auto Memory status
# Shows MEMORY.md size, usage, topic files, commands
# Globals:
#   None
# Arguments:
#   $1 - Project path (default: pwd)
# Returns:
#   0 on success
# Outputs:
#   Detailed MEMORY.md status
#######################################
context_memory_status() {
    local project_path="${1:-$(pwd)}"
    local project_memory=$(get_context_project_memory_dir "$project_path")
    local memory_file="$project_memory/MEMORY.md"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧠 Auto Memory Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ ! -f "$memory_file" ]]; then
        echo "Status:  Not initialized"
        echo ""
        echo "Initialize: ./iclaude.sh --context-memory-init"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 0
    fi

    local lines=$(wc -l < "$memory_file")
    local percent=$(( (lines * 100) / 200 ))
    local size=$(du -h "$memory_file" 2>/dev/null | cut -f1)

    echo "MEMORY.md: $memory_file"
    echo "Size:      $size ($lines lines)"
    echo "Loaded:    First 200 lines → system prompt"
    echo "Usage:     $percent% of limit"

    if [[ $lines -gt 200 ]]; then
        echo "Status:    ⚠ EXCEEDS LIMIT"
    elif [[ $lines -gt 150 ]]; then
        echo "Status:    ⚠ Approaching limit"
    else
        echo "Status:    ✓ OK"
    fi

    # Topic files
    local topic_count=$(find "$project_memory" -name "*.md" ! -name "MEMORY.md" 2>/dev/null | wc -l)
    if [[ $topic_count -gt 0 ]]; then
        echo ""
        echo "Topic Files: $topic_count"
        find "$project_memory" -name "*.md" ! -name "MEMORY.md" -exec basename {} \; | sed 's/^/  - /'
    fi

    # Last modified
    if command -v stat &>/dev/null; then
        local mtime=$(stat -c %y "$memory_file" 2>/dev/null | cut -d'.' -f1 || stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$memory_file" 2>/dev/null)
        echo ""
        echo "Modified:  $mtime"
    fi

    echo ""
    echo "Commands:"
    echo "  --context-memory-validate    Check best practices"
    echo "  --context-memory-organize    Suggest topic files"
    echo "  --context-memory-add TEXT    Add entry"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
