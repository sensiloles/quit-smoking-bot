#!/bin/bash

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"


show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Run tests for the Telegram bot in a dedicated container."
    echo ""
    echo "Options:"
    echo "  --token TOKEN       Specify the Telegram bot token for integration tests"
    echo "  --force-rebuild     Force rebuild of test container without using cache"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --token 123456789:ABCDEF... # Run tests with specific token"
    echo "  $0                             # Run tests using token from .env file"
}

# Parse command line arguments
if ! parse_args "$@"; then
    exit 1
fi

# Check prerequisites
check_prerequisites || exit 1
check_system_display_name

# Clean up any existing test resources
docker-compose rm -sf test

# Run tests
print_message "Running tests..." "$GREEN"
# Rebuild the test service image without cache to ensure dependencies are updated
print_message "Building test image without cache..." "$YELLOW"
if ! docker-compose build --no-cache test; then
    print_error "Failed to build test image"
    exit 1
fi

# Run the tests using the freshly built image
if ! docker-compose run --rm test; then 
    print_error "Tests failed"
    exit 1
fi
