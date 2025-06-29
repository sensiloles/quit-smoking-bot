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
    debug_print "Starting argument parsing with $# arguments"
    # Initialize variables with default values
    TOKEN=""
    FORCE_REBUILD=0
    CLEANUP=0
    RUN_TESTS=0 # Initialize the new flag
    debug_print "Arguments initialized with defaults"
    # Loop through arguments
    while [[ $# -gt 0 ]]; do
        debug_print "Processing argument: $1"
        case "$1" in
            --token)
                debug_print "Processing --token argument"
                if [[ -z "$2" || "$2" == --* ]]; then
                    debug_print "Token value missing or invalid after --token flag"
                    print_error "Token value missing after --token flag"
                    exit 1
                fi
                TOKEN="$2"
                debug_print "Token set (length: ${#TOKEN} characters)"
                shift 2
                ;;
            --force-rebuild)
                debug_print "Force rebuild flag set"
                FORCE_REBUILD=1
                shift 1
                ;;
            --cleanup)
                debug_print "Cleanup flag set"
                CLEANUP=1
                shift 1
                ;;
            --tests) # Add handling for the new flag
                debug_print "Tests flag set"
                RUN_TESTS=1
                shift 1
                ;;
            --help)
                debug_print "Help requested"
                show_help
                exit 0
                ;;
            *)
                debug_print "Unknown option encountered: $1"
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    debug_print "Argument parsing completed successfully"
} 