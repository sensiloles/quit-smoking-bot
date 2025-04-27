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
    echo "  --tests             Run tests after building and before starting the bot. If tests fail, the bot will not start."
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --token 123456789:ABCDEF... # Start with specific token"
    echo "  $0 --force-rebuild             # Force rebuild container"
    echo "  $0 --tests                     # Build, run tests, then start"
    echo "  $0                             # Start using token from .env file"
}

# Main function
main() {
    # Parse command line arguments using the common function
    parse_args "$@"
    
    # If token was passed via --token parameter, save it to .env and export it
    if [ -n "$TOKEN" ]; then
        update_env_token "$TOKEN"
        export BOT_TOKEN="$TOKEN"
    fi
    
    # Check prerequisites
    check_prerequisites || return 1
    
    # Check for local container and conflicts with remote bots
    # Use common function to check conflicts (don't exit on conflict)
    check_bot_conflicts "$BOT_TOKEN" 0
    conflict_status=$?
    
    if [ $conflict_status -eq 1 ]; then
        # Return error for handling in main
        print_error "Cannot proceed due to remote conflict with another bot instance."
        print_message "Please stop the other bot instance before continuing." "$YELLOW"
        return 1
    fi
    
    # Stop any existing running instances
    stop_running_instances $conflict_status
    
    # Setup data directories with proper permissions
    setup_data_directories
    
    # Determine if we should start the service immediately after building
    local start_immediately=1
    if [ "$RUN_TESTS" -eq 1 ]; then
        start_immediately=0
    fi

    # Build the service (potentially without starting)
    build_and_start_service "bot" $start_immediately || return 1

    # Run tests if requested
    if [ "$RUN_TESTS" -eq 1 ]; then
        if ! run_tests_in_docker; then
            print_error "Tests failed. Bot will not be started."
            return 1
        fi
        # If tests passed, start the service now
        print_message "Starting bot service after successful tests..." "$GREEN"
        if ! docker-compose up -d bot; then
            print_error "Failed to start the bot service after tests."
            return 1
        fi
    fi
    
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


# ПОПРАВИТЬ, ЗАПУСТИЛ ЛОКАЛЬНО НА MACOS когда на сервере тоже было запущено
# ./scripts/run.sh --token YOUR_BOT_TOKEN_HERE
# Updated BOT_TOKEN in .env
# Checking for conflicts with the same bot token...
# Checking if bot is running locally...
# Waiting longer for existing connections to clear (attempt 2)...
