#!/usr/bin/env bash
# lib/loop/git.sh
# Loop Mode - Git Integration
#
# Part of Phase 12: Loop Mode extraction from iclaude-legacy.sh
# Contains git commit and push operations after task completion

#######################################
# Git commit task changes
# Commits changes after successful task execution with optional auto-push
# Arguments:
#   $1 - Task ID
# Returns:
#   0 - Changes committed successfully or no git config
#   1 - Commit or push failed
# Globals:
#   Reads TASK_NAME, TASK_GIT_COMMIT_MSG, TASK_GIT_BRANCH, TASK_GIT_AUTO_PUSH
# Workflow:
#   1. Check if git config specified (skip if not)
#   2. Verify git repository exists
#   3. Create/checkout branch if specified
#   4. Stage all changes (git add .)
#   5. Commit with Co-Authored-By tag
#   6. Auto-push if TASK_GIT_AUTO_PUSH is "true"
# Default Commit Message:
#   If TASK_GIT_COMMIT_MSG empty: "feat: <task_name>"
# Branch Handling:
#   - Creates branch if doesn't exist
#   - Checks out existing branch
#   - Stays on current branch if TASK_GIT_BRANCH empty
#######################################
git_commit_task_changes() {
	local task_id="$1"
	local task_name="${TASK_NAME[$task_id]}"
	local commit_msg="${TASK_GIT_COMMIT_MSG[$task_id]}"
	local branch="${TASK_GIT_BRANCH[$task_id]}"
	local auto_push="${TASK_GIT_AUTO_PUSH[$task_id]}"

	# Skip if no git config specified
	if [[ -z "$branch" ]] && [[ -z "$commit_msg" ]]; then
		print_info "No git configuration - skipping commit"
		return 0
	fi

	# Check if we're in a git repository
	if ! git rev-parse --git-dir &>/dev/null; then
		print_warning "Not in a git repository - skipping commit"
		return 0
	fi

	print_info "Committing changes for: $task_name"

	# Create/checkout branch if specified
	if [[ -n "$branch" ]]; then
		echo "  Branch: $branch"
		if git show-ref --verify --quiet "refs/heads/$branch"; then
			git checkout "$branch" 2>/dev/null || {
				print_error "Failed to checkout branch: $branch"
				return 1
			}
		else
			git checkout -b "$branch" 2>/dev/null || {
				print_error "Failed to create branch: $branch"
				return 1
			}
		fi
	fi

	# Stage all changes
	git add .

	# Check if there are changes to commit
	if git diff --cached --quiet; then
		print_warning "No changes to commit"
		return 0
	fi

	# Use default commit message if not specified
	if [[ -z "$commit_msg" ]]; then
		commit_msg="feat: $task_name"
	fi

	# Commit with Co-Authored-By
	git commit -m "$commit_msg

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>" || {
		print_error "Git commit failed"
		return 1
	}

	print_success "Changes committed: $commit_msg"

	# Auto-push if configured
	if [[ "$auto_push" == "true" ]]; then
		print_info "Auto-pushing to remote..."
		if git push -u origin "$branch" 2>&1; then
			print_success "Pushed to remote: $branch"
		else
			print_warning "Push failed - you may need to push manually"
			return 1
		fi
	fi

	return 0
}
