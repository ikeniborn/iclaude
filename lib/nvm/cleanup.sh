#!/bin/bash

#######################################
# NVM Cleanup Module
# Description: Cleanup isolated NVM environment
#######################################

#######################################
# Cleanup isolated NVM environment
# Removes the isolated Node.js tree but preserves the lockfile and the shared
# Claude store. The store used to live inside ISOLATED_NVM_DIR, so this command
# destroyed the login, the transcripts and the plugins along with node; since the
# store moved to the repository root it survives a full nvm reinstall.
# Returns:
#   0 - success
# Side effects:
#   - Deletes ISOLATED_NVM_DIR
#   - Preserves ISOLATED_LOCKFILE and ISOLATED_CONFIG_DIR
#######################################
cleanup_isolated_nvm() {
	if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
		print_info "Isolated environment not found, nothing to cleanup"
		return 0
	fi

	print_warning "This will delete the isolated Node.js environment:"
	echo ""
	echo "  Directory: $ISOLATED_NVM_DIR"
	echo "  Size: $(du -sh "$ISOLATED_NVM_DIR" 2>/dev/null | cut -f1)"
	echo ""
	print_info "Preserved — the shared Claude store (login, transcripts, plugins):"
	echo "  $ISOLATED_CONFIG_DIR"
	print_info "Preserved — lockfile:"
	echo "  $ISOLATED_LOCKFILE"
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
