#!/bin/bash
set -e

# Source bootstrap (loads all modules)
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/bootstrap.sh"


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
    print_message "=== CALLING BUILD_AND_START_SERVICE ===" "$BLUE"
    if ! build_and_start_service "bot" $start_immediately; then
        print_error "build_and_start_service failed. Stopping execution."
        return 1
    fi
    print_message "=== BUILD_AND_START_SERVICE COMPLETED ===" "$BLUE"

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
        
        # Verify container started after tests
        print_message "Verifying container started after tests..." "$YELLOW"
        sleep 3
        if ! docker-compose ps bot | grep -q "Up"; then
            print_error "Container failed to start after tests!"
            docker-compose ps bot
            docker-compose logs --tail 20 bot
            return 1
        fi
    fi

    # Final verification that container is actually running
    print_message "=== FINAL CONTAINER STATUS VERIFICATION ===" "$BLUE"
    if ! docker-compose ps bot | grep -q "Up"; then
        print_error "CRITICAL: Bot container is not running despite successful build process!"
        print_message "Container status:" "$YELLOW"
        docker-compose ps bot
        print_message "Recent logs:" "$YELLOW"
        docker-compose logs --tail 30 bot
        print_error "This indicates a problem with the container startup process."
        return 1
    fi
    print_message "✅ Container verification passed - bot is running." "$GREEN"
    print_message "=== END VERIFICATION ===" "$BLUE"

    # Check if bot is healthy and operational
    check_bot_status

    # Show logs and handle Ctrl+C gracefully
    print_message "\n🎉 Bot started successfully! 🎉" "$GREEN"
    print_message "=== STARTUP COMPLETED SUCCESSFULLY ===" "$GREEN"
    print_message "Bot is now running and ready to receive messages." "$GREEN"
    print_message "Press Ctrl+C to detach from logs (bot will continue running)." "$GREEN"
    print_message "========================================" "$GREEN"
    
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
