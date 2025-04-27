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
    # Use common function to check conflicts (don't exit on conflict)
    check_bot_conflicts "$BOT_TOKEN" 0
    conflict_status=$?
    
    if [ $conflict_status -eq 1 ]; then
        # Return error for handling in main
        return 1
    fi
    
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
    
    # Setup data directories with proper permissions
    setup_data_directories
    
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


# ПОПРАВИТЬ, ЗАПУСТИЛ ЛОКАЛЬНО НА MACOS когда на сервере тоже было запущено
# ./scripts/run.sh --token YOUR_BOT_TOKEN_HERE
# Updated BOT_TOKEN in .env
# Checking for conflicts with the same bot token...
# Checking if bot is running locally...
# Waiting longer for existing connections to clear (attempt 2)...
