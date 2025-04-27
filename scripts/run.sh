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

# Check Docker daemon
check_docker

# Check for remote bot conflicts
print_message "Checking for remote conflicts with the same bot token..." "$YELLOW"
if ! detect_remote_bot_conflict "$BOT_TOKEN"; then
    print_error "A remote conflict was detected with another bot using the same token."
    print_message "Please resolve the conflict before continuing." "$YELLOW"
    exit 1
fi

# Stop any running instances of the bot
print_message "Checking for existing bot instances..." "$YELLOW"
if docker-compose ps -q bot >/dev/null 2>&1; then
    print_message "Stopping existing bot container..." "$YELLOW"
    docker-compose stop bot
    docker-compose rm -f bot
fi

# Build and start the bot
build_and_start_service || exit 1

# Show logs and handle Ctrl+C gracefully
print_message "Bot started successfully. Press Ctrl+C to detach from logs." "$GREEN"
trap 'print_message "\nDetaching from logs..." "$GREEN"; exit 0' INT
docker-compose logs -f --no-color bot 2>/dev/null
