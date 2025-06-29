#!/bin/bash
# testing.sh - Test execution utilities
#
# This module provides functions for running tests within Docker
# and managing test execution.

###################
# Test Execution
###################

# Run tests within Docker
run_tests_in_docker() {
    debug_print "Starting test execution in Docker"
    print_section "Running Tests"
    print_message "Running tests using docker-compose run --rm test..." "$YELLOW"

    # Execute tests directly
    debug_print "Executing: docker-compose run --rm test"
    if docker-compose run --rm test; then
        debug_print "Tests completed successfully"
        print_message "\nTests Passed!" "$GREEN"
        return 0
    else
        debug_print "Tests failed"
        print_error "Tests Failed! Check the output above for details."
        return 1
    fi
} 