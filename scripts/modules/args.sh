#!/bin/bash
# args.sh - Command line argument parsing utilities
#
# This module provides functions for parsing command-line arguments
# and handling script options.

###########################
# Command Line Arguments
###########################

# Parse command-line arguments
parse_args() {
    # Initialize variables with default values
    TOKEN=""
    FORCE_REBUILD=0
    CLEANUP=0
    RUN_TESTS=0 # Initialize the new flag
    # Loop through arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --token)
                if [[ -z "$2" || "$2" == --* ]]; then
                    print_error "Token value missing after --token flag"
                    exit 1
                fi
                TOKEN="$2"
                shift 2
                ;;
            --force-rebuild)
                FORCE_REBUILD=1
                shift 1
                ;;
            --cleanup)
                CLEANUP=1
                shift 1
                ;;
            --tests) # Add handling for the new flag
                RUN_TESTS=1
                shift 1
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
} 