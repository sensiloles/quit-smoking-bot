#!/bin/bash
set -e

# Source bootstrap (loads all modules)
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/bootstrap.sh"


show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Stop the Telegram bot and clean up Docker resources."
    echo ""
    echo "Options:"
    echo "  --cleanup           Perform thorough cleanup of resources (containers, images, volumes)"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Stop the bot"
    echo "  $0 --cleanup        # Stop the bot and perform thorough cleanup"
}

# Function to stop and remove containers
stop_containers() {
    print_message "Stopping bot and cleaning up resources..." "$YELLOW"
    docker-compose down
    return $?
}

# Function to clean up Docker resources if requested
cleanup_resources() {
    if [ "$CLEANUP" == "1" ]; then
        cleanup_docker bot 1
    fi
}

# Main function
main() {
    # Parse command line arguments
    if ! parse_args "$@"; then
        return 1
    fi

    # Check prerequisites
    check_prerequisites || return 1

    # Stop and remove containers
    stop_containers || return 1

    # Clean up Docker resources if requested
    cleanup_resources

    print_message "Bot has been stopped successfully." "$GREEN"
    return 0
}

# Execute main function
main "$@"
exit $?
