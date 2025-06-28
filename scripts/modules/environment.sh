#!/bin/bash
# environment.sh - Environment validation utilities
#
# This module provides functions for checking and validating
# environment variables and configuration.

######################
# Environment Checks
######################

# Check if BOT_TOKEN is set
check_bot_token() {
    # First check if BOT_TOKEN is set in environment
    if [ -n "$BOT_TOKEN" ]; then
        return 0
    fi

    # Then check if .env file exists and contains BOT_TOKEN
    if [ -f ".env" ]; then
        if grep -q "BOT_TOKEN=" ".env"; then
            # Source the .env file to get the BOT_TOKEN
            source ".env"
            if [ -n "$BOT_TOKEN" ]; then
                return 0
            fi
        fi
    fi

    # If we get here, BOT_TOKEN is not set
    print_error "BOT_TOKEN environment variable is not set."
    print_message "Please set BOT_TOKEN in one of the following ways:" "$YELLOW"
    print_message "1. Export it in your environment: export BOT_TOKEN='your_bot_token_here'" "$YELLOW"
    print_message "2. Add it to .env file: echo 'BOT_TOKEN=your_bot_token_here' > .env" "$YELLOW"
    print_message "3. Pass it as an argument to the script: ./run.sh --token your_bot_token_here" "$YELLOW"
    return 1
}

# Check SYSTEM_NAME
check_system_name() {
    if [ -z "$SYSTEM_NAME" ]; then
        print_error "SYSTEM_NAME is not set"
        print_message "Please set SYSTEM_NAME in .env file" "$YELLOW"
        exit 1
    fi
}

# Check SYSTEM_DISPLAY_NAME
check_system_display_name() {
    if [ -z "$SYSTEM_DISPLAY_NAME" ]; then
        print_error "SYSTEM_DISPLAY_NAME is not set"
        print_message "Please set SYSTEM_DISPLAY_NAME in .env file" "$YELLOW"
        exit 1
    fi
}

# Check prerequisites (combined check)
check_prerequisites() {
    check_docker_installation || return 1
    check_bot_token || return 1
    check_system_name
    return 0
}

# Load environment variables from .env file if it exists
load_env_file() {
    if [ -f ".env" ]; then
        source ".env"
    fi
}

# Update BOT_TOKEN in .env file
update_env_token() {
    local token="$1"
    local env_file=".env"

    # Create .env file if it doesn't exist
    if [ ! -f "$env_file" ]; then
        touch "$env_file"
    fi

    # Check if BOT_TOKEN already exists in the file
    if grep -q "^BOT_TOKEN=" "$env_file"; then
        # Replace existing BOT_TOKEN
        if [ "$(uname)" == "Darwin" ]; then
            # macOS version
            sed -i "" "s|^BOT_TOKEN=.*|BOT_TOKEN=\"$token\"|" "$env_file"
        else
            # Linux version
            sed -i "s|^BOT_TOKEN=.*|BOT_TOKEN=\"$token\"|" "$env_file"
        fi
    else
        # Add new BOT_TOKEN entry
        echo "BOT_TOKEN=\"$token\"" >> "$env_file"
    fi

    print_message "Updated BOT_TOKEN in $env_file" "$GREEN"
}

# Automatically export the BOT_TOKEN if it's set
auto_export_bot_token() {
    if [ -n "$BOT_TOKEN" ]; then
        export BOT_TOKEN
    fi
} 