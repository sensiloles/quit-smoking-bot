#!/bin/bash

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"


show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Uninstall the Telegram bot service completely from the system."
    echo "This script requires root privileges (sudo)."
    echo ""
    echo "Options:"
    echo "  --cleanup           Perform thorough cleanup (remove all Docker resources including volumes)"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo $0                  # Uninstall the bot service"
    echo "  sudo $0 --cleanup        # Uninstall with thorough cleanup"
}

# Ensure SYSTEM_NAME is available for docker-compose
if [ -z "$SYSTEM_NAME" ]; then
    print_error "SYSTEM_NAME is not set"
    exit 1
fi

# Ensure SYSTEM_DISPLAY_NAME is available 
if [ -z "$SYSTEM_DISPLAY_NAME" ]; then
    print_error "SYSTEM_DISPLAY_NAME is not set"
    exit 1
fi

# Function to get service status
get_service_status() {
    print_message "\nCurrent service status:" "$YELLOW"
    systemctl status $SYSTEM_NAME.service --no-pager || true
    
    print_message "\nDocker container status:" "$YELLOW"
    docker ps -a --filter "name=$SYSTEM_NAME" || true
    
    print_message "\nDocker images:" "$YELLOW"
    docker images | grep $SYSTEM_NAME || true
}

# Function to stop and remove service
stop_service() {
    print_message "\n1. Stopping service..." "$YELLOW"
    systemctl stop $SYSTEM_NAME.service || true
    systemctl disable $SYSTEM_NAME.service || true
    
    print_message "\n2. Removing service file..." "$YELLOW"
    rm -f /etc/systemd/system/$SYSTEM_NAME.service
    
    print_message "\n3. Reloading systemd..." "$YELLOW"
    systemctl daemon-reload
    systemctl reset-failed
}

# Main script
print_message "Starting uninstallation of $SYSTEM_DISPLAY_NAME service..." "$YELLOW"

# Check if running as root
check_root

# Parse command line arguments
if ! parse_args "$@"; then
    exit 1
fi

# Display cleanup mode if active
if [ "$CLEANUP" == "1" ]; then
    print_message "Running in thorough cleanup mode (--cleanup flag detected)" "$YELLOW"
fi

# Show initial status
print_message "\nInitial status:" "$YELLOW"
get_service_status

# Stop and remove service
stop_service

# Clean up Docker artifacts using the cleanup_docker function from common.sh
print_message "\n4. Cleaning up Docker resources..." "$YELLOW"
cleanup_docker bot "$CLEANUP"

# Clean up project files
print_message "\n5. Cleaning up project files..." "$YELLOW"
# Remove data and logs directories
rm -rf ./data ./logs
    
# Remove Docker artifacts
rm -f .config_hash
rm -f docker-compose.override.yml
    
# Remove build artifacts
rm -rf __pycache__ */__pycache__ .pytest_cache

# Show final status
print_message "\nFinal status:" "$YELLOW"
get_service_status

print_message "\nUninstallation completed successfully!" "$GREEN"
print_message "\nSummary of actions performed:" "$YELLOW"
print_message "1. Stopped and disabled $SYSTEM_NAME.service" "$GREEN"
print_message "2. Removed service file from /etc/systemd/system/" "$GREEN"
print_message "3. Reloaded systemd daemon" "$GREEN"
print_message "4. Cleaned up Docker resources" "$GREEN"
if [ "$CLEANUP" == "1" ]; then
    print_message "   - Removed all containers, images, volumes, networks (thorough cleanup)" "$GREEN"
else
    print_message "   - Removed containers and images" "$GREEN"
fi
print_message "5. Cleaned up project files and build artifacts" "$GREEN"

print_message "\nThe $SYSTEM_DISPLAY_NAME service has been completely removed from the system." "$GREEN"
