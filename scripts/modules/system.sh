#!/bin/bash
# system.sh - System service management utilities
#
# This module provides functions for managing systemd services,
# checking root permissions, and system-level operations.

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root (use sudo)"
        exit 1
    fi
}

# Function to stop and remove service
stop_service() {
    if [[ "$(uname)" != "Linux" ]]; then
        print_error "Service management commands are not supported on this OS ($(uname))."
        return 1
    fi
    print_message "\n1. Stopping service..." "$YELLOW"
    systemctl stop $SYSTEM_NAME.service || true
    systemctl disable $SYSTEM_NAME.service || true

    print_message "\n2. Removing service file..." "$YELLOW"
    rm -f /etc/systemd/system/$SYSTEM_NAME.service

    print_message "\n3. Reloading systemd..." "$YELLOW"
    systemctl daemon-reload
    systemctl reset-failed
} 