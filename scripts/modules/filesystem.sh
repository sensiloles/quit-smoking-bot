#!/bin/bash
# filesystem.sh - File system and directory management utilities
#
# This module provides functions for setting up directories,
# managing permissions, and file system operations.

# Setup data directories with proper permissions
setup_data_directories() {
    debug_print "Starting data directories setup"
    print_message "Setting up data and log directories..." "$YELLOW"

    # Create local data directory
    debug_print "Checking if ./data directory exists"
    if [ ! -d "./data" ]; then
        debug_print "Creating ./data directory"
        mkdir -p ./data
        print_message "Created data directory" "$GREEN"
    else
        debug_print "./data directory already exists"
    fi

    # Create local logs directory
    debug_print "Checking if ./logs directory exists"
    if [ ! -d "./logs" ]; then
        debug_print "Creating ./logs directory"
        mkdir -p ./logs
        print_message "Created logs directory" "$GREEN"
    else
        debug_print "./logs directory already exists"
    fi

    # Setup secure permissions using dedicated script
    debug_print "Setting up secure permissions"
    if [ -f "./scripts/setup-permissions.sh" ]; then
        bash ./scripts/setup-permissions.sh
    else
        # Fallback: set basic secure permissions
        chmod 755 ./data ./logs 2>/dev/null || true
        find ./data -type f -name "*.json" -exec chmod 644 {} \; 2>/dev/null || true
        print_message "Applied basic secure permissions" "$GREEN"
    fi

    # Ensure docker-compose.yml exists and has correct volume mappings
    if [ -f "docker-compose.yml" ]; then
        # Check if volumes are correctly mapped
        if ! grep -q "./data:/app/data" docker-compose.yml || ! grep -q "./logs:/app/logs" docker-compose.yml; then
            print_warning "Your docker-compose.yml may not have correct volume mappings"
            print_message "Please ensure you have these mappings in your docker-compose.yml:" "$YELLOW"
            print_message "volumes:" "$YELLOW"
            print_message "  - ./data:/app/data" "$YELLOW"
            print_message "  - ./logs:/app/logs" "$YELLOW"
        fi
    fi
} 