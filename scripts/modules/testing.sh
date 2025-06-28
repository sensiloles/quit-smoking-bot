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
    print_section "Running Tests"
    print_message "Running tests using docker-compose run --rm test..." "$YELLOW"

    # Execute tests directly
    if docker-compose run --rm test; then
        print_message "\nTests Passed!" "$GREEN"
        return 0
    else
        print_error "Tests Failed! Check the output above for details."
        return 1
    fi
} 