#!/bin/bash
# conflicts.sh - Bot conflict detection and resolution utilities
#
# This module provides functions for detecting conflicts with other bot instances,
# stopping local instances, and managing Telegram API conflicts.

# Check for conflicts with the same bot token
detect_remote_bot_conflict() {
    local bot_token="$1"

    debug_print "Entering detect_remote_bot_conflict"

    if [ -z "$bot_token" ]; then
        print_error "Bot token is empty, cannot check for conflicts"
        debug_print "Bot token is empty, returning 1"
        return 1
    fi

    # Check for existing bot containers or services using the same token
    print_message "Checking for existing bot processes..." "$YELLOW"

    # Try to get bot info using the token
    print_message "Requesting bot info from Telegram API..." "$YELLOW"
    debug_print "Making getMe request to Telegram API"
    local bot_info=$(curl -s "https://api.telegram.org/bot${bot_token}/getMe")
    debug_print "getMe response received"
    print_message "Response received from Telegram API" "$YELLOW"

    # Check if we got a successful response
    debug_print "Checking if response is successful"
    if echo "$bot_info" | grep -q "\"ok\":true"; then
        debug_print "Response is successful"
        # Extract bot username
        local bot_username=$(echo "$bot_info" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        print_message "Connected to bot: @${bot_username}" "$GREEN"

        # Make a getUpdates request to check if someone else is polling
        print_message "Testing Telegram API connection..." "$YELLOW"
        debug_print "Making getUpdates request with timeout=1"
        local getUpdates_response=$(curl -s "https://api.telegram.org/bot${bot_token}/getUpdates?timeout=1&offset=-1&limit=1")
        debug_print "getUpdates curl command completed"
        debug_print "getUpdates response received"
        
        # Check for webhook conflicts
        print_message "Checking for webhook conflicts..." "$YELLOW"
        debug_print "Making getWebhookInfo request"
        local webhook_info=$(curl -s "https://api.telegram.org/bot${bot_token}/getWebhookInfo")
        debug_print "getWebhookInfo response received"
        
        if echo "$webhook_info" | grep -q "\"ok\":true"; then
            local webhook_url=$(echo "$webhook_info" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
            debug_print "Found webhook URL: $webhook_url"

            if [ -n "$webhook_url" ] && [ "$webhook_url" != "\"\"" ] && [ "$webhook_url" != "" ]; then
                debug_print "Webhook is set and not empty, this is a conflict"
                print_error "This bot already has a webhook set: ${webhook_url}"
                print_message "This indicates it is in use by another server." "$RED"
                print_message "Please remove the webhook or use another bot token." "$YELLOW"
                return 1  # Remote conflict
            fi
        fi
        debug_print "No active webhook found"

        # Check for local processes using docker ps
        debug_print "Starting local Docker container check"
        print_message "Checking for local Docker containers..." "$YELLOW"
        if [ -z "$SYSTEM_NAME" ]; then
            debug_print "SYSTEM_NAME is not set"
            print_warning "SYSTEM_NAME is not set, skipping local container check"
        else
            debug_print "Checking for containers with exact name: ${SYSTEM_NAME}"
            # Use docker-compose ps instead of docker ps to check for the specific service
            if docker-compose ps bot | grep -q "Up"; then
                debug_print "Found running bot service via docker-compose"
                print_warning "Found local bot container using the same token."
                return 2  # Local conflict
            fi
            # Also check for exact container name match (not partial)
            if docker ps --format "table {{.Names}}" | grep -q "^${SYSTEM_NAME}$"; then
                debug_print "Found exact container name match"
                print_warning "Found local bot container using the same token."
                return 2  # Local conflict
            fi
            debug_print "No conflicting local containers found"
        fi

        debug_print "All conflict checks passed, returning 0"
        print_message "No conflicts detected" "$GREEN"
        return 0  # No conflict
    else
        print_error "Could not connect to Telegram API with the provided token"
        echo "$bot_info"
        return 1
    fi
}

# Function to stop local bot instance
stop_local_bot_instance() {
    local wait_time="${1:-5}"  # Wait time after stopping (default 5 seconds)
    
    print_message "Checking if bot is running locally..." "$YELLOW"
    debug_print "Inside stop_local_bot_instance, about to check docker ps | grep..."
    local local_bot_running=0
    
    # Check for running bot service via docker-compose (more precise)
    if docker-compose ps bot | grep -q "Up"; then
        debug_print "docker-compose ps found running bot service."
        print_warning "Bot is already running on this machine."
        
        # Stop existing container
        print_message "Stopping existing bot container..." "$YELLOW"
        docker-compose stop bot
        docker-compose rm -f bot

        # Wait for Telegram API connections to release
        print_message "Waiting for Telegram API connections to release (${wait_time} seconds)..." "$YELLOW"
        sleep $wait_time

        print_message "Local bot instance stopped" "$GREEN"
        return 0  # Container was stopped
    # Also check for exact container name match (fallback)
    elif docker ps --format "table {{.Names}}" | grep -q "^${SYSTEM_NAME}$"; then
        debug_print "docker ps found exact container name match."
        print_warning "Bot container with exact name is running."
        
        # Stop existing container
        print_message "Stopping existing bot container..." "$YELLOW"
        docker stop "${SYSTEM_NAME}" || true
        docker rm -f "${SYSTEM_NAME}" || true

        # Wait for Telegram API connections to release
        print_message "Waiting for Telegram API connections to release (${wait_time} seconds)..." "$YELLOW"
        sleep $wait_time

        print_message "Local bot instance stopped" "$GREEN"
        return 0  # Container was stopped
    fi
    debug_print "docker ps | grep did NOT find running container. Returning 1."
    return 1  # Container was not found
}

# Reusable function to check for bot conflicts with extended verification
check_bot_conflicts() {
    local token="$1"
    local exit_on_conflict="${2:-1}"  # Default to 1 (exit on conflict)
    local wait_time="${3:-0}"  # Wait time after stopping (default 5 seconds)
    
    print_message "Checking for conflicts with the same bot token..." "$YELLOW"
    debug_print "Entering check_bot_conflicts function."
    
    # First check and stop local container
    local local_stopped=0
    debug_print "Calling stop_local_bot_instance."
    if stop_local_bot_instance "$wait_time"; then
        local_stopped=1
        debug_print "Local bot instance stopped: local_stopped=1"
    else
        debug_print "Local bot instance was not running: local_stopped=0"
    fi
    
    # Make multiple attempts to detect conflicts with increased wait times
    local max_attempts=3
    local attempt=1
    local conflict_status=0
    debug_print "Starting conflict detection loop."
    
    while [ $attempt -le $max_attempts ]; do
        debug_print "Conflict check attempt: $attempt of $max_attempts"
        
        # If we've already tried once, wait longer to ensure any connections have time to release
        if [ $attempt -gt 1 ]; then
            print_message "Waiting longer for existing connections to clear (attempt $attempt)..." "$YELLOW"
            sleep $(( wait_time * attempt ))
        fi
        
        # If there's no local container, check for conflicts via API
        debug_print "Calling detect_remote_bot_conflict"
        detect_remote_bot_conflict "$token" # Call directly
        conflict_status=$? # Capture the actual return code
        debug_print "detect_remote_bot_conflict returned status: $conflict_status"
        
        # If we got a conflict (status 1)
        if [ $conflict_status -eq 1 ]; then
            # Status 1 means a remote conflict (different machine or process)
            # Error messages are printed inside detect_remote_bot_conflict
            if [ "$exit_on_conflict" -eq 1 ]; then
                debug_print "Exiting check_bot_conflicts due to remote conflict (exit_on_conflict=1)"
                return 1 # Exit with error
            else
                 debug_print "Remote conflict detected, but exit_on_conflict != 1, breaking loop."
                 break # Exit the loop but continue script
            fi
        # If no conflict (status 0)
        elif [ $conflict_status -eq 0 ]; then
             debug_print "No conflict detected in this attempt."
             # If we are on the last attempt and status is 0, we are good.
             if [ $attempt -eq $max_attempts ]; then
                 debug_print "This was the last attempt and no conflict found"
                 print_message "No conflicts detected after $max_attempts attempts" "$GREEN"
                 break # Exit loop successfully
             else
                 debug_print "No conflict in attempt $attempt, but not the last attempt yet"
             fi
        # Handle unexpected return codes?
        else
            print_error "Unexpected return code $conflict_status from detect_remote_bot_conflict"
             if [ "$exit_on_conflict" -eq 1 ]; then
                debug_print "Exiting check_bot_conflicts due to unexpected error (exit_on_conflict=1)"
                 return 1 # Exit on unexpected error if exit_on_conflict is set
             else
                 debug_print "Unexpected error detected, but exit_on_conflict != 1, breaking loop."
                 break # Exit loop otherwise
             fi
        fi
        
        debug_print "Incrementing attempt from $attempt to $((attempt + 1))"
        ((attempt++))
    done
    
    debug_print "Exited conflict detection loop"
    debug_print "Final conflict_status: $conflict_status"
    debug_print "Exiting check_bot_conflicts function with status: $conflict_status"
    return $conflict_status # Return the final determined status
} 