#!/bin/bash
set -e

# Source common functions
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/common.sh"


show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Start the Telegram bot in a Docker container."
    echo ""
    echo "Options:"
    echo "  --token TOKEN       Specify the Telegram bot token (will be saved to .env file)"
    echo "  --force-rebuild     Force rebuild of Docker container without using cache"
    echo "  --cleanup           Perform additional cleanup before starting"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --token 123456789:ABCDEF... # Start with specific token"
    echo "  $0 --force-rebuild             # Force rebuild container"
    echo "  $0                             # Start using token from .env file"
}

# Function to check prerequisites
check_prerequisites() {
    # Check prerequisites
    check_docker_installation || return 1
    check_docker_buildx
    check_bot_token || return 1
    check_system_name
    check_docker || return 1
    return 0
}

# Function to check for bot conflicts
check_bot_conflicts() {
    # Use common function to check conflicts (don't exit on conflict)
    check_bot_conflicts_common "$BOT_TOKEN" 0
    conflict_status=$?
    
    if [ $conflict_status -eq 1 ]; then
        # Return error for handling in main
        return 1
    fi
    
    return $conflict_status
}

# Function to stop any running bot instances
stop_running_instances() {
    print_message "Checking for existing bot instances..." "$YELLOW"
    
    if docker-compose ps -q bot >/dev/null 2>&1; then
        print_message "Stopping existing bot container..." "$YELLOW"
        docker-compose stop bot
        docker-compose rm -f bot
        
        # If there was a conflict, wait a bit to let Telegram API release connections
        if [ $1 -eq 2 ]; then
            print_message "Waiting for Telegram API connections to release (5 seconds)..." "$YELLOW"
            sleep 5
        fi
    fi
}

# Function to check bot health and status after startup
check_bot_status() {
    print_message "\nChecking bot status after startup..." "$YELLOW"
    local max_attempts=10
    local attempt=1
    
    # Wait a moment for the container to initialize
    sleep 5
    
    while [ $attempt -le $max_attempts ]; do
        print_message "Checking bot health (attempt $attempt/$max_attempts)..." "$YELLOW"
        
        # Check if bot is healthy using Docker healthcheck
        if is_bot_healthy; then
            print_message "Bot health check: PASSED" "$GREEN"
            break
        else
            if [ $attempt -eq $max_attempts ]; then
                print_message "Bot health check did not pass within timeout, but bot might still be functioning." "$YELLOW"
                print_message "Continuing with operational check..." "$YELLOW"
            else
                print_message "Bot health check not yet passing, waiting..." "$YELLOW"
                sleep 5
                ((attempt++))
                continue
            fi
        fi
        
        ((attempt++))
    done
    
    # Check if bot is operational
    if is_bot_operational; then
        print_message "Bot operational check: PASSED" "$GREEN"
        print_message "Bot is fully operational!" "$GREEN"
        return 0
    else
        print_message "Bot operational check: NOT PASSED" "$YELLOW"
        print_message "Bot is running but might not be fully operational." "$YELLOW"
        print_message "Use './scripts/check-service.sh' for detailed diagnostics." "$YELLOW"
        return 1
    fi
}

# Main function
main() {
    # Parse command line arguments
    if ! parse_args "$@"; then
        return 1
    fi
    
    # If token was passed via --token parameter, save it to .env and export it
    if [ -n "$TOKEN" ]; then
        update_env_token "$TOKEN"
        export BOT_TOKEN="$TOKEN"
    fi
    
    # Check prerequisites
    check_prerequisites || return 1
    
    # Check for local container and conflicts with remote bots
    check_bot_conflicts
    conflict_status=$?
    
    # If conflict with remote bot (status 1)
    if [ $conflict_status -eq 1 ]; then
        print_error "Cannot proceed due to remote conflict with another bot instance."
        print_message "Please stop the other bot instance before continuing." "$YELLOW"
        return 1
    # In other cases (no conflict or local already stopped)
    else
        # Check if there are running instances (as an additional precaution)
        stop_running_instances $conflict_status
    fi
    
    # Build and start the bot - always executed if there's no conflict with remote bot
    build_and_start_service || return 1
    
    # Check if bot is healthy and operational
    check_bot_status
    
    # Show logs and handle Ctrl+C gracefully
    print_message "\nBot started successfully. Press Ctrl+C to detach from logs." "$GREEN"
    trap 'print_message "\nDetaching from logs..." "$GREEN"; return 0' INT
    docker-compose logs -f --no-color bot 2>/dev/null
}

# Execute main function
main "$@"
exit $?
