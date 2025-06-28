#!/bin/bash
# filesystem.sh - File system and directory management utilities
#
# This module provides functions for setting up directories,
# managing permissions, and file system operations.

# Setup data directories with proper permissions
setup_data_directories() {
    print_message "Setting up data and log directories..." "$YELLOW"

    # Create local data directory
    if [ ! -d "./data" ]; then
        mkdir -p ./data
        print_message "Created data directory" "$GREEN"
    fi

    # Create local logs directory
    if [ ! -d "./logs" ]; then
        mkdir -p ./logs
        print_message "Created logs directory" "$GREEN"
    fi

    # Ensure correct ownership (current user)
    local current_user=$(id -u)
    local current_group=$(id -g)

    # Give liberal permissions temporarily to avoid permission issues during build and startup
    chmod -R 777 ./data ./logs

    print_message "Fixed permissions on data and log directories" "$GREEN"

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