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
    debug_print "Checking BOT_TOKEN availability"
    
    # First check if BOT_TOKEN is set in environment
    debug_print "Checking if BOT_TOKEN is set in environment"
    if [ -n "$BOT_TOKEN" ]; then
        debug_print "BOT_TOKEN found in environment"
        return 0
    fi
    debug_print "BOT_TOKEN not found in environment"

    # Then check if .env file exists and contains BOT_TOKEN
    debug_print "Checking if .env file exists"
    if [ -f ".env" ]; then
        debug_print ".env file found, checking for BOT_TOKEN"
        if grep -q "BOT_TOKEN=" ".env"; then
            debug_print "BOT_TOKEN entry found in .env file, sourcing file"
            # Source the .env file to get the BOT_TOKEN
            source ".env"
            if [ -n "$BOT_TOKEN" ]; then
                debug_print "BOT_TOKEN successfully loaded from .env file"
                return 0
            fi
            debug_print "BOT_TOKEN found in .env but is empty"
        else
            debug_print "BOT_TOKEN entry not found in .env file"
        fi
    else
        debug_print ".env file not found"
    fi

    # If we get here, BOT_TOKEN is not set
    debug_print "BOT_TOKEN not found in any source"
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

    debug_print "Updating BOT_TOKEN in $env_file"
    debug_print "Token length: ${#token} characters"

    # Create .env file if it doesn't exist
    debug_print "Checking if $env_file exists"
    if [ ! -f "$env_file" ]; then
        debug_print "$env_file does not exist, creating it"
        touch "$env_file"
    else
        debug_print "$env_file exists"
    fi

    # Check if BOT_TOKEN already exists in the file
    debug_print "Checking if BOT_TOKEN entry already exists in $env_file"
    if grep -q "^BOT_TOKEN=" "$env_file"; then
        debug_print "BOT_TOKEN entry found, replacing existing value"
        # Replace existing BOT_TOKEN
        if [ "$(uname)" == "Darwin" ]; then
            debug_print "Using macOS sed syntax"
            # macOS version
            sed -i "" "s|^BOT_TOKEN=.*|BOT_TOKEN=\"$token\"|" "$env_file"
        else
            debug_print "Using Linux sed syntax"
            # Linux version
            sed -i "s|^BOT_TOKEN=.*|BOT_TOKEN=\"$token\"|" "$env_file"
        fi
        debug_print "BOT_TOKEN replaced successfully"
    else
        debug_print "BOT_TOKEN entry not found, adding new entry"
        # Add new BOT_TOKEN entry
        echo "BOT_TOKEN=\"$token\"" >> "$env_file"
        debug_print "BOT_TOKEN added successfully"
    fi

    print_message "Updated BOT_TOKEN in $env_file" "$GREEN"
}

# Automatically export the BOT_TOKEN if it's set
auto_export_bot_token() {
    if [ -n "$BOT_TOKEN" ]; then
        export BOT_TOKEN
    fi
} 