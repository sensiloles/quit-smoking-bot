#!/bin/bash
# health.sh - Health check and status monitoring utilities
#
# This module provides functions for checking container health,
# bot operational status, and system monitoring.

###########################
# Container Status Checks
###########################

# Check if bot is healthy using Docker healthcheck
is_bot_healthy() {
    debug_print "Starting is_bot_healthy check"
    # Ensure SYSTEM_NAME is properly exported before running docker-compose commands
    check_system_name
    local container_id=$(docker-compose ps -q bot)
    debug_print "Container ID: $container_id"

    if [ -z "$container_id" ]; then
        debug_print "Container is not running - no container ID found"
        print_error "Container is not running"
        return 1
    fi

    # Get container health status
    local health_status=$(docker inspect --format '{{.State.Health.Status}}' $container_id 2>/dev/null)
    debug_print "Container health status: $health_status"

    if [ "$health_status" = "healthy" ]; then
        debug_print "Container health check passed"
        print_message "Bot is healthy - container health check passed" "$GREEN"
        # Print the most recent health check log
        print_message "Last health check result:" "$YELLOW"
        docker inspect --format='{{range .State.Health.Log}}{{if eq .ExitCode 0}}{{.Output}}{{end}}{{end}}' $container_id | tail -1
        return 0
    elif [ "$health_status" = "starting" ]; then
        debug_print "Health check is still starting"
        print_message "Bot health check is still initializing" "$YELLOW"
        return 1
    else
        debug_print "Health check failed with status: $health_status"
        print_error "Bot health check failed - status: $health_status"
        # Print the most recent health check log
        print_message "Last health check result:" "$YELLOW"
        docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' $container_id | tail -1
        return 1
    fi
}

# Check if bot is operational
is_bot_operational() {
    debug_print "Starting is_bot_operational check"
    local max_attempts=30
    local attempt=1
    # Ensure SYSTEM_NAME is properly exported before running docker-compose commands
    check_system_name
    local container_id=$(docker-compose ps -q bot)
    debug_print "Container ID for operational check: $container_id"

    if [ -z "$container_id" ]; then
        debug_print "Container is not running for operational check"
        print_error "Container is not running"
        return 1
    fi

    # Check if Python process is running
    debug_print "Checking if Python bot process is running"
    if ! docker exec $container_id pgrep -f "python.*src[/.]bot" >/dev/null 2>&1; then
        debug_print "Bot process is not running inside container"
        print_error "Bot process is not running inside container"
        return 1
    fi
    debug_print "Bot process is running inside container"

    # Check container logs for operational messages
    debug_print "Checking logs for operational status"
    print_message "Checking logs for operational status..." "$YELLOW"
    logs=$(docker logs $container_id --tail 50 2>&1)

    # Check for conflict errors first - if found, report the conflict but don't return yet
    if echo "$logs" | grep -q "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates"; then
        print_error "Telegram API conflict detected - another bot is running with the same token"
        print_message "You will need to stop the other bot instance to use this one properly." "$YELLOW"
    fi

    if echo "$logs" | grep -q "Application started"; then
        print_message "Bot is operational" "$GREEN"
        return 0
    fi

    # Check for API calls - if multiple successful API calls have been made, consider it operational
    api_calls=$(echo "$logs" | grep -c "\"HTTP/1.1 200 OK\"")
    if [ "$api_calls" -ge 2 ]; then
        print_message "Bot is operational ($api_calls successful API calls detected)" "$GREEN"
        return 0
    fi

    # Even with conflicts, the bot might still be partly operational if it's still making API calls
    # If we found conflicts earlier, but the bot is still somewhat operational, return success
    # This allows the finalizeStartupCheck function to handle the conflict appropriately
    if echo "$logs" | grep -q "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates" && \
       echo "$logs" | grep -q "\"HTTP/1.1 200 OK\""; then
        print_message "Bot is partly operational despite conflicts" "$YELLOW"
        return 0
    fi

    print_error "Bot is not operational"
    return 1
}

# Function to check bot health and status after startup
check_bot_status() {
    print_message "\n=== BOT STATUS CHECK ===" "$BLUE"
    print_message "Checking bot status after startup..." "$YELLOW"
    local max_attempts=30
    local attempt=1

    # First, verify container is still running
    print_message "Step 1: Verifying container is running..." "$YELLOW"
    if ! docker-compose ps bot | grep -q "Up"; then
        print_error "Container is not running!"
        docker-compose ps bot
        return 1
    fi
    print_message "✅ Container is running" "$GREEN"

    # Wait a moment for the container to initialize
    print_message "Step 2: Waiting for container initialization (5 seconds)..." "$YELLOW"
    sleep 5

    # Show current container logs
    print_message "Step 3: Recent container logs:" "$YELLOW"
    docker-compose logs --tail 10 bot

    print_message "Step 4: Health check loop (max $max_attempts attempts)..." "$YELLOW"
    while [ $attempt -le $max_attempts ]; do
        print_message "Checking bot health (attempt $attempt/$max_attempts)..." "$YELLOW"

        # Check if container is still running (might have crashed)
        if ! docker-compose ps bot | grep -q "Up"; then
            print_error "Container stopped running during health check!"
            print_message "Container status:" "$RED"
            docker-compose ps bot
            print_message "Recent logs:" "$RED"
            docker-compose logs --tail 20 bot
            return 1
        fi

        # Check if bot is healthy using Docker healthcheck
        if is_bot_healthy; then
            print_message "Bot health check: PASSED" "$GREEN"
            break
        else
            if [ $attempt -eq $max_attempts ]; then
                print_message "Bot health check did not pass within timeout, but bot might still be functioning." "$YELLOW"
                print_message "Continuing with operational check..." "$YELLOW"
                # Show recent logs for debugging
                print_message "Recent logs for debugging:" "$YELLOW"
                docker-compose logs --tail 15 bot
            else
                print_message "Bot health check not yet passing, waiting..." "$YELLOW"
                sleep 5
                ((attempt++))
                continue
            fi
        fi

        ((attempt++))
    done

    print_message "Step 5: Operational check..." "$YELLOW"
    # Check if bot is operational
    if is_bot_operational; then
        print_message "Bot operational check: PASSED" "$GREEN"
        print_message "🎉 Bot is fully operational!" "$GREEN"
        
        # Show final status summary
        print_message "\n=== FINAL STATUS SUMMARY ===" "$GREEN"
        print_message "Container status:" "$GREEN"
        docker-compose ps bot
        print_message "Most recent logs:" "$GREEN"
        docker-compose logs --tail 5 bot
        print_message "=== END STATUS SUMMARY ===" "$GREEN"
        
        return 0
    else
        print_message "Bot operational check: NOT PASSED" "$YELLOW"
        print_message "Bot is running but might not be fully operational." "$YELLOW"
        
        # Detailed diagnostic info
        print_message "\n=== DIAGNOSTIC INFORMATION ===" "$YELLOW"
        print_message "Container status:" "$YELLOW"
        docker-compose ps bot
        print_message "Extended logs for diagnostics:" "$YELLOW"
        docker-compose logs --tail 25 bot
        print_message "=== END DIAGNOSTICS ===" "$YELLOW"
        
        print_message "Use './scripts/check-service.sh' for detailed diagnostics." "$YELLOW"
        return 1
    fi
} 