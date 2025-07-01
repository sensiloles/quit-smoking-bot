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
    INSTALL_MODE=0
    ENABLE_MONITORING=0
    ENABLE_LOGGING=0
    QUIET=0
    FORCE=0
    STATUS_ONLY=0
    
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
            --install)
                debug_print "Install mode flag set"
                INSTALL_MODE=1
                shift 1
                ;;
            --monitoring)
                debug_print "Monitoring flag set"
                ENABLE_MONITORING=1
                shift 1
                ;;
            --logging)
                debug_print "Logging flag set" 
                ENABLE_LOGGING=1
                shift 1
                ;;

            --force-rebuild)
                debug_print "Force rebuild flag set"
                FORCE_REBUILD=1
                shift 1
                ;;
            --force)
                debug_print "Force flag set"
                FORCE=1
                shift 1
                ;;
            --cleanup)
                debug_print "Cleanup flag set"
                CLEANUP=1
                shift 1
                ;;
            --dry-run)
                debug_print "Dry run flag set"
                DRY_RUN=1
                shift 1
                ;;
            --status)
                debug_print "Status only flag set"
                STATUS_ONLY=1
                shift 1
                ;;
            --quiet)
                debug_print "Quiet flag set"
                QUIET=1
                shift 1
                ;;
            --verbose)
                debug_print "Verbose flag set"
                VERBOSE=1
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
    
    # Export all flags for use in other modules
    export TOKEN
    export FORCE_REBUILD
    export CLEANUP

    export INSTALL_MODE
    export ENABLE_MONITORING
    export ENABLE_LOGGING
    export QUIET
    export FORCE
    export STATUS_ONLY
    export DRY_RUN
    export VERBOSE
    
    debug_print "Argument parsing completed successfully"
} 