#!/bin/bash
set -e

# Source common functions
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/common.sh"

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
    print_message "Checking for conflicts with the same bot token..." "$YELLOW"
    conflict_check=$(detect_remote_bot_conflict "$BOT_TOKEN")
    conflict_status=$?

    if [ $conflict_status -eq 1 ]; then
        # Status 1 means a remote conflict (different machine)
        print_error "A remote conflict was detected with another bot using the same token."
        print_message "Please resolve the conflict before continuing." "$YELLOW"
        return 1
    elif [ $conflict_status -eq 2 ]; then
        # Status 2 means a local conflict (this machine)
        print_message "A local bot instance with the same token is already running on this machine." "$YELLOW"
        print_message "The existing instance will be stopped and restarted." "$YELLOW"
    fi
    return 0
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
    if ! parse_arguments "$@"; then
        return 1
    fi
    
    # Check prerequisites
    check_prerequisites || return 1
    
    # Check for bot conflicts
    check_bot_conflicts
    conflict_status=$?
    if [ $conflict_status -ne 0 ]; then
        return 1
    fi
    
    # Stop any running instances of the bot
    stop_running_instances $conflict_status
    
    # Build and start the bot
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
