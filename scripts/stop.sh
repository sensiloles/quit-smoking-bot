#!/bin/bash

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Parse command line arguments
parse_arguments "$@"

# Check prerequisites
check_docker_installation || exit 1
check_system_name

# Check Docker daemon
check_docker

# Stop and remove containers
print_message "Stopping bot and cleaning up resources..." "$YELLOW"
docker-compose down

# Clean up Docker resources if requested
if [ "$CLEANUP" == "1" ]; then
    cleanup_docker bot 1
fi

print_message "Bot has been stopped successfully." "$GREEN"
