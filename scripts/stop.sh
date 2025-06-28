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
    debug_print "Starting container stop procedure"
    print_message "Stopping bot and cleaning up resources..." "$YELLOW"
    docker-compose down
    local result=$?
    debug_print "docker-compose down completed with status: $result"
    return $result
}

# Function to clean up Docker resources if requested
cleanup_resources() {
    if [ "$CLEANUP" == "1" ]; then
        debug_print "Cleanup requested, performing Docker resource cleanup"
        cleanup_docker bot 1
        debug_print "Docker resource cleanup completed"
    else
        debug_print "No cleanup requested, skipping Docker resource cleanup"
    fi
}

# Main function
main() {
    debug_print "Starting stop.sh main function with arguments: $@"
    
    # Parse command line arguments
    debug_print "Parsing command line arguments"
    if ! parse_args "$@"; then
        debug_print "Failed to parse arguments"
        return 1
    fi
    debug_print "Arguments parsed successfully"

    # Check prerequisites
    debug_print "Checking prerequisites"
    check_prerequisites || return 1
    debug_print "Prerequisites check passed"

    # Stop and remove containers
    debug_print "Stopping and removing containers"
    stop_containers || return 1
    debug_print "Containers stopped successfully"

    # Clean up Docker resources if requested
    debug_print "Processing cleanup resources request"
    cleanup_resources
    debug_print "Cleanup processing completed"

    debug_print "Bot stop procedure completed successfully"
    print_message "Bot has been stopped successfully." "$GREEN"
    return 0
}

# Execute main function
main "$@"
exit $?
