#!/bin/bash

# Source bootstrap (loads all modules)
source "$(dirname "${BASH_SOURCE[0]}")/bootstrap.sh"


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
debug_print "Parsing command line arguments for test script"
if ! parse_args "$@"; then
    debug_print "Failed to parse arguments"
    exit 1
fi
debug_print "Arguments parsed successfully"

# Check prerequisites
debug_print "Checking prerequisites"
check_prerequisites || exit 1
check_system_display_name
debug_print "Prerequisites check passed"

# Clean up any existing test resources
debug_print "Cleaning up existing test resources"
docker-compose rm -sf test
debug_print "Test resources cleanup completed"

# Run tests
debug_print "Starting tests execution"
print_message "Running tests..." "$GREEN"
# Rebuild the test service image without cache to ensure dependencies are updated
debug_print "Building test image without cache"
print_message "Building test image without cache..." "$YELLOW"
if ! docker-compose build --no-cache test; then
    debug_print "Failed to build test image"
    print_error "Failed to build test image"
    exit 1
fi
debug_print "Test image built successfully"

# Run the tests using the freshly built image
debug_print "Running tests using docker-compose"
if ! docker-compose run --rm test; then
    debug_print "Tests failed"
    print_error "Tests failed"
    exit 1
fi
debug_print "Tests completed successfully"
