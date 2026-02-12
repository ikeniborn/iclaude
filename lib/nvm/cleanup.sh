#!/bin/bash

#######################################
# NVM Cleanup Module
# Description: Cleanup isolated NVM environment
#######################################

#######################################
# Cleanup isolated NVM environment
# Removes entire isolated NVM directory but preserves lockfile
# Returns:
#   0 - success
# Side effects:
#   - Deletes ISOLATED_NVM_DIR
#   - Preserves ISOLATED_LOCKFILE
#######################################
cleanup_isolated_nvm() {
	if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
		print_info "Isolated environment not found, nothing to cleanup"
		return 0
	fi

	print_warning "This will delete the entire isolated environment:"
	echo ""
	echo "  Directory: $ISOLATED_NVM_DIR"
	echo "  Size: $(du -sh "$ISOLATED_NVM_DIR" 2>/dev/null | cut -f1)"
	echo ""
	print_info "Lockfile will be preserved: $ISOLATED_LOCKFILE"
	echo ""

	# Confirm deletion
	read -p "Are you sure you want to delete the isolated environment? (y/N): " -n 1 -r
	echo ""

	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		print_info "Cleanup cancelled"
		return 0
	fi

	print_info "Removing isolated environment..."
	rm -rf "$ISOLATED_NVM_DIR"

	if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
		print_success "Isolated environment removed"
		echo ""
		print_info "To reinstall, run: ./iclaude.sh --isolated-install"
		print_info "To install from lockfile, run: ./iclaude.sh --install-from-lockfile"
	else
		print_error "Failed to remove isolated environment"
		return 1
	fi

	return 0
}
