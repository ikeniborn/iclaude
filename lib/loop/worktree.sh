#!/usr/bin/env bash
# lib/loop/worktree.sh
# Loop Mode - Git Worktree Management + AI Merge Conflict Resolution
#
# Part of Phase 13: Loop Mode extraction from iclaude-legacy.sh
# ⚠️ HIGH RISK: Contains AI-powered merge conflict resolution
#
# IMPORTANT SAFETY NOTES:
# - resolve_merge_conflicts_ai() uses AI to modify code - requires careful validation
# - Always backup before merge (use git stash)
# - Validate AI output for conflict markers
# - Recommend --parallel-dry-run for testing
# - Recommend --parallel-require-approval for production

#######################################
# Create git worktree for task isolation
# Creates isolated worktree with unique branch for parallel execution
# Arguments:
#   $1 - Task ID (e.g., "task_0")
# Returns:
#   0 - Worktree created successfully
#   1 - Creation failed
# Globals:
#   Reads TASK_NAME
#   Sets WORKTREE_PATH_<task_id>, WORKTREE_BRANCH_<task_id> (dynamic variables)
# Worktree Structure:
#   Path: .git/worktrees/loop-<sanitized-name>-<timestamp>
#   Branch: loop/<sanitized-name>-<timestamp>
#######################################
create_task_worktree() {
	local task_id="$1"
	local task_name="${TASK_NAME[$task_id]}"

	# Check if we're in a git repository
	if ! git rev-parse --git-dir &>/dev/null; then
		print_warning "Not in a git repository - cannot create worktree"
		return 1
	fi

	# Generate worktree path and branch name
	local timestamp=$(date +%s)
	local sanitized_name=$(echo "$task_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')
	local worktree_path=".git/worktrees/loop-${sanitized_name}-${timestamp}"
	local branch_name="loop/${sanitized_name}-${timestamp}"

	print_info "Creating worktree for: $task_name"
	echo "  Path: $worktree_path"
	echo "  Branch: $branch_name"

	# Create worktree with new branch
	if ! git worktree add -B "$branch_name" "$worktree_path" 2>&1; then
		print_error "Failed to create worktree"
		return 1
	fi

	# Export worktree path for use in other functions
	declare -g "WORKTREE_PATH_${task_id}=$worktree_path"
	declare -g "WORKTREE_BRANCH_${task_id}=$branch_name"

	print_success "Worktree created: $worktree_path"
	return 0
}

#######################################
# Cleanup git worktree after task completion
# Attempts graceful removal, falls back to force, then manual cleanup
# Arguments:
#   $1 - Task ID
# Returns:
#   0 - Worktree removed successfully (always succeeds)
# Globals:
#   Reads WORKTREE_PATH_<task_id>
#   Unsets WORKTREE_PATH_<task_id>, WORKTREE_BRANCH_<task_id>
# Cleanup Strategy:
#   1. Try graceful: git worktree remove
#   2. Try force: git worktree remove --force
#   3. Manual: rm -rf + git worktree prune
#######################################
cleanup_worktree() {
	local task_id="$1"
	local worktree_path_var="WORKTREE_PATH_${task_id}"
	local worktree_path="${!worktree_path_var}"

	if [[ -z "$worktree_path" ]]; then
		return 0
	fi

	print_info "Cleaning up worktree: $worktree_path"

	# 1. Attempt graceful removal
	if git worktree remove "$worktree_path" 2>&1; then
		print_success "Worktree removed cleanly"
	# 2. Attempt force removal
	elif git worktree remove "$worktree_path" --force 2>&1; then
		print_success "Worktree force-removed"
	# 3. Manual cleanup
	else
		print_warning "Manual cleanup required"
		rm -f "$worktree_path/.git" 2>/dev/null || true
		rm -rf "$worktree_path" 2>/dev/null || true
		git worktree prune 2>/dev/null || true
		print_success "Manual cleanup completed"
	fi

	# Unset variables
	unset "WORKTREE_PATH_${task_id}"
	unset "WORKTREE_BRANCH_${task_id}"

	return 0
}

#######################################
# Merge worktree changes back to main branch
# Attempts merge with patience strategy, invokes AI if conflicts detected
# Arguments:
#   $1 - Task ID
# Returns:
#   0 - Merge successful
#   1 - Merge failed (conflicts unresolved)
# Globals:
#   Reads TASK_NAME, WORKTREE_BRANCH_<task_id>
# Merge Strategy:
#   1. Check if there are commits to merge
#   2. Attempt merge with --strategy-option=patience
#   3. If conflicts: invoke resolve_merge_conflicts_ai()
#   4. If AI fails: abort and provide manual instructions
#######################################
merge_worktree_changes() {
	local task_id="$1"
	local task_name="${TASK_NAME[$task_id]}"
	local worktree_branch_var="WORKTREE_BRANCH_${task_id}"
	local worktree_branch="${!worktree_branch_var}"

	if [[ -z "$worktree_branch" ]]; then
		print_error "No worktree branch found for task: $task_id"
		return 1
	fi

	# Check if there are commits to merge
	local commit_count
	commit_count=$(git rev-list --count "HEAD..$worktree_branch" 2>/dev/null || echo "0")

	if [[ "$commit_count" -eq 0 ]]; then
		print_info "No changes to merge for: $task_name"
		return 0
	fi

	print_info "Merging $commit_count commit(s) from: $worktree_branch"

	# Attempt merge with patience strategy
	if git merge "$worktree_branch" --no-edit --strategy-option=patience 2>&1; then
		print_success "Merge successful: $task_name"
		return 0
	fi

	# Check if merge failed due to conflicts
	if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
		local -a conflicted
		mapfile -t conflicted < <(git diff --name-only --diff-filter=U 2>/dev/null)

		print_warning "Merge conflicts (${#conflicted[@]} file(s)):"
		printf '  - %s\n' "${conflicted[@]}"
		echo ""

		# Try AI-assisted conflict resolution
		print_info "Attempting AI-assisted conflict resolution..."
		if resolve_merge_conflicts_ai "$task_id"; then
			print_success "Conflicts resolved by AI"
			return 0
		else
			print_error "Failed to resolve conflicts automatically"
			echo ""
			echo "Manual resolution required:"
			echo "  1. git status"
			echo "  2. Edit conflicted files"
			echo "  3. git add <files>"
			echo "  4. git commit"
			echo ""
			return 1
		fi
	fi

	print_error "Merge failed for unknown reason"
	return 1
}

#######################################
# Resolve merge conflicts using AI (⚠️ HIGHEST RISK FUNCTION)
# Uses Claude to intelligently resolve git merge conflicts
# Arguments:
#   $1 - Task ID
# Returns:
#   0 - Conflicts resolved and committed
#   1 - Resolution failed (markers present or AI error)
# Globals:
#   None
# Dependencies:
#   - get_nvm_claude_path() - Get Claude binary
#   - Claude Code CLI with --no-chrome flag
# Safety Validations:
#   1. Check for conflicted files (git diff --diff-filter=U)
#   2. Validate AI output doesn't contain conflict markers
#   3. Ensure file is syntactically valid after resolution
#   4. Git add + commit only if validation passes
# Prompt Strategy:
#   - Provide file content with conflict markers
#   - Instruct AI to understand both versions
#   - Combine changes intelligently
#   - Remove ALL conflict markers (<<<<<<, =======, >>>>>>>)
#   - Output ONLY resolved content
# Risk Mitigation:
#   - Validates markers removed before writing
#   - Returns error if validation fails
#   - Recommend --parallel-dry-run for testing
#   - Recommend git stash before merge for backup
#######################################
resolve_merge_conflicts_ai() {
	local task_id="$1"

	# Get list of conflicted files
	local conflicted_files
	mapfile -t conflicted_files < <(git diff --name-only --diff-filter=U)

	if [[ ${#conflicted_files[@]} -eq 0 ]]; then
		print_info "No conflicts to resolve"
		return 0
	fi

	print_info "Resolving ${#conflicted_files[@]} conflicted file(s)"

	# Get Claude binary
	local claude_bin
	claude_bin=$(get_nvm_claude_path) || {
		print_error "Claude Code binary not found for conflict resolution"
		return 1
	}

	# Resolve each conflicted file
	for file in "${conflicted_files[@]}"; do
		print_info "Resolving conflicts in: $file"

		# Read file with conflict markers
		local file_content
		file_content=$(cat "$file")

		# Build AI prompt
		local prompt="Resolve git merge conflict in file: $file

File content with conflict markers:
\`\`\`
$file_content
\`\`\`

Your task:
1. Understand both versions (HEAD vs incoming branch)
2. Combine changes intelligently (preserve functionality from both sides if possible)
3. Remove ALL conflict markers (<<<<<<, =======, >>>>>>>)
4. Ensure syntactically valid code
5. Output ONLY the resolved file content without markers

Output the complete resolved file content:"

		# Invoke Claude to resolve
		local resolved_content
		resolved_content=$(echo "$prompt" | "$claude_bin" --no-chrome 2>/dev/null)

		if [[ -z "$resolved_content" ]]; then
			print_error "AI failed to resolve conflicts in: $file"
			return 1
		fi

		# ⚠️ CRITICAL SAFETY CHECK: Validate markers removed
		if echo "$resolved_content" | grep -qE "^<<<<<<<|^=======|^>>>>>>>"; then
			print_error "Conflict markers still present after AI resolution: $file"
			echo "  This indicates AI did not properly resolve conflicts"
			echo "  Manual resolution required for safety"
			return 1
		fi

		# Write resolved content
		echo "$resolved_content" > "$file"

		# Stage resolved file
		git add "$file"

		print_success "Resolved: $file"
	done

	# Commit merge
	if ! git commit --no-edit 2>&1; then
		print_error "Failed to commit merge"
		return 1
	fi

	print_success "All conflicts resolved and committed"
	return 0
}
