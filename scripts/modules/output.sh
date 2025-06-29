#!/bin/bash
# output.sh - Output utilities for formatted messages
#
# This module provides colored output functions and message formatting.

###################
# Output Utilities
###################

# ANSI color codes (only set if not already defined)
if [[ -z "${GREEN:-}" ]]; then
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly RED='\033[0;31m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m' # No Color
fi

# Print a formatted message with optional color
print_message() {
    local message="$1"
    local color="${2:-$NC}"
    echo -e "${color}${message}${NC}"
}

# Print a warning message
print_warning() {
    print_message "$1" "$YELLOW"
}

# Print an error message
print_error() {
    print_message "$1" "$RED"
}

# Print a section header
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Print a main header (like section but more prominent)
print_header() {
    echo -e "\n${GREEN}==============================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}==============================================${NC}\n"
}

# Print a success message
print_success() {
    print_message "$1" "$GREEN"
}

# Add a function for debug output
debug_print() {
    if [ "${DEBUG:-0}" = "1" ] || [ "${VERBOSE:-0}" = "1" ]; then
        echo "DEBUG: $1" >&2
    fi
} 