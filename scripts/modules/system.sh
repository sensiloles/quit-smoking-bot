#!/bin/bash
# system.sh - System service management utilities
#
# This module provides functions for managing systemd services
# and system-level configuration.

###################
# System Management
###################

# Function to check if running as root
check_root() {
    debug_print "Checking if running as root (EUID: $EUID)"
    if [ "$EUID" -ne 0 ]; then
        debug_print "Not running as root, exiting"
        print_error "Please run as root (use sudo)"
        exit 1
    fi
    debug_print "Running as root, proceeding"
}

# Function to stop and remove service
stop_service() {
    debug_print "Starting stop_service function"
    if [[ "$(uname)" != "Linux" ]]; then
        debug_print "Non-Linux system detected, service management not supported"
        print_error "Service management commands are not supported on this OS ($(uname))."
        return 1
    fi
    debug_print "Linux system detected, proceeding with service stop"
    
    print_message "\n1. Stopping service..." "$YELLOW"
    debug_print "Stopping systemd service: $SYSTEM_NAME.service"
    systemctl stop $SYSTEM_NAME.service || true
    debug_print "Disabling systemd service: $SYSTEM_NAME.service"
    systemctl disable $SYSTEM_NAME.service || true

    print_message "\n2. Removing service file..." "$YELLOW"
    debug_print "Removing service file: /etc/systemd/system/$SYSTEM_NAME.service"
    rm -f /etc/systemd/system/$SYSTEM_NAME.service

    print_message "\n3. Reloading systemd..." "$YELLOW"
    debug_print "Reloading systemd daemon"
    systemctl daemon-reload
    debug_print "Resetting failed services"
    systemctl reset-failed
    debug_print "stop_service function completed"
}

 