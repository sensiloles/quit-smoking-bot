#!/bin/bash

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Parse command line arguments
if ! parse_arguments "$@"; then
    exit 1
fi

# Check prerequisites
check_docker_installation || exit 1
check_docker_buildx
check_bot_token || exit 1
check_system_name
check_system_display_name

# Check Docker daemon
check_docker

# Clean up any existing test resources
docker-compose rm -sf test

# Run tests
print_message "Running tests..." "$GREEN"
if ! docker-compose run --rm test; then
    print_error "Tests failed"
    exit 1
fi
