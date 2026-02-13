#!/bin/bash

#######################################
# Logging Module
# Description: Colored output functions for info, success, warning, and error messages
#######################################

#######################################
# Print colored info message
# Arguments:
#   $1 - Message to print
#######################################
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

#######################################
# Print colored success message
# Arguments:
#   $1 - Message to print
#######################################
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

#######################################
# Print colored warning message
# Arguments:
#   $1 - Message to print
#######################################
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

#######################################
# Print colored error message
# Arguments:
#   $1 - Message to print
#######################################
print_error() {
    echo -e "${RED}✗${NC} $1"
}
