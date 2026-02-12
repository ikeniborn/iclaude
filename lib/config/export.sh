#!/bin/bash

#######################################
# Config Export Module
# Description: Export and import Claude Code configuration for backup/restore
#######################################

#######################################
# Export config directory to backup location
# Arguments:
#   $1 - destination directory (required)
# Returns:
#   0 - success
#   1 - error
# Example:
#   export_config /path/to/backup || return 1
#######################################
export_config() {
	local dest_dir=$1

	if [[ -z "$dest_dir" ]]; then
		print_error "Destination directory required"
		echo ""
		echo "Usage: $0 --export-config /path/to/backup"
		return 1
	fi

	# Determine config directory
	local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

	# Check if config directory exists
	if [[ ! -d "$config_dir" ]]; then
		print_error "Config directory does not exist: $config_dir"
		echo ""
		echo "Nothing to export"
		return 1
	fi

	print_info "Exporting configuration..."
	echo "  From: $config_dir"
	echo "  To: $dest_dir"
	echo ""

	# Create destination directory
	mkdir -p "$dest_dir"

	# Copy config directory
	cp -r "$config_dir"/* "$dest_dir/" 2>/dev/null || {
		print_error "Failed to export configuration"
		return 1
	}

	local size=$(du -sh "$dest_dir" 2>/dev/null | cut -f1 || echo "unknown")
	print_success "Configuration exported successfully"
	echo "  Size: $size"
	echo "  Location: $dest_dir"
	echo ""

	return 0
}

#######################################
# Import config directory from backup location
# Arguments:
#   $1 - source directory (required)
# Returns:
#   0 - success
#   1 - error
# Example:
#   import_config /path/to/backup || return 1
#######################################
import_config() {
	local source_dir=$1

	if [[ -z "$source_dir" ]]; then
		print_error "Source directory required"
		echo ""
		echo "Usage: $0 --import-config /path/to/backup"
		return 1
	fi

	# Check if source directory exists
	if [[ ! -d "$source_dir" ]]; then
		print_error "Source directory does not exist: $source_dir"
		return 1
	fi

	# Determine config directory
	local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

	print_info "Importing configuration..."
	echo "  From: $source_dir"
	echo "  To: $config_dir"
	echo ""

	# Warn if config directory exists
	if [[ -d "$config_dir" ]]; then
		print_warning "Config directory already exists"
		echo "  Existing: $config_dir"
		echo ""
		read -p "Overwrite existing configuration? (y/N): " confirm

		if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
			print_info "Import cancelled"
			return 0
		fi
		echo ""
	fi

	# Create config directory
	mkdir -p "$config_dir"

	# Copy configuration
	cp -r "$source_dir"/* "$config_dir/" 2>/dev/null || {
		print_error "Failed to import configuration"
		return 1
	}

	# Fix permissions for credentials file
	if [[ -f "$config_dir/.credentials.json" ]]; then
		chmod 600 "$config_dir/.credentials.json"
	fi

	local size=$(du -sh "$config_dir" 2>/dev/null | cut -f1 || echo "unknown")
	print_success "Configuration imported successfully"
	echo "  Size: $size"
	echo "  Location: $config_dir"
	echo ""

	return 0
}
