#!/bin/bash

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

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

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "Please run as root (use sudo)"
        exit 1
    fi
}

# Function to get service status
get_service_status() {
    print_message "\nCurrent service status:" "$YELLOW"
    systemctl status $SYSTEM_NAME.service --no-pager
    
    print_message "\nDocker container status:" "$YELLOW"
    docker ps -a --filter "name=$SYSTEM_NAME"
    
    print_message "\nDocker images:" "$YELLOW"
    docker images | grep $SYSTEM_NAME
}

# Function to stop and remove service
stop_service() {
    print_message "\n1. Stopping service..." "$YELLOW"
    systemctl stop $SYSTEM_NAME.service
    systemctl disable $SYSTEM_NAME.service
    
    print_message "\n2. Removing service file..." "$YELLOW"
    rm -f /etc/systemd/system/$SYSTEM_NAME.service
    
    print_message "\n3. Reloading systemd..." "$YELLOW"
    systemctl daemon-reload
    systemctl reset-failed
}

# Function to clean up Docker artifacts
cleanup_docker() {
    print_message "\n4. Stopping and removing containers..." "$YELLOW"
    docker-compose down
    
    print_message "\n5. Removing Docker images..." "$YELLOW"
    docker rmi ${SYSTEM_NAME} ${SYSTEM_NAME}-test >/dev/null 2>&1 || true
    
    print_message "\n6. Removing Docker volumes..." "$YELLOW"
    docker volume rm $(docker volume ls -q -f name=${SYSTEM_NAME}) >/dev/null 2>&1 || true

    # Additional cleanup from stop.sh
    if [ "$CLEANUP" == "1" ]; then
        print_message "\n7. Cleaning up unused Docker resources..." "$YELLOW"
        docker volume prune -f
        docker network prune -f
    fi
}

# Function to clean up project files
cleanup_files() {
    print_message "\n8. Cleaning up project files..." "$YELLOW"
    # Remove data and logs directories
    rm -rf ./data ./logs
    
    # Remove Docker artifacts
    rm -f .config_hash
    rm -f docker-compose.override.yml
    
    # Remove build artifacts
    rm -rf __pycache__ */__pycache__ .pytest_cache
}

# Main script
print_message "Starting uninstallation of $SYSTEM_DISPLAY_NAME service..." "$YELLOW"

# Check if running as root
check_root

# Parse command line arguments
parse_arguments "$@"

# Show initial status
print_message "\nInitial status:" "$YELLOW"
get_service_status

# Stop and remove service
stop_service

# Clean up Docker artifacts
cleanup_docker bot

# Clean up project files
cleanup_files

# Show final status
print_message "\nFinal status:" "$YELLOW"
get_service_status

print_message "\nUninstallation completed successfully!" "$GREEN"
print_message "\nSummary of actions performed:" "$YELLOW"
print_message "1. Stopped and disabled $SYSTEM_NAME.service" "$GREEN"
print_message "2. Removed service file from /etc/systemd/system/" "$GREEN"
print_message "3. Reloaded systemd daemon" "$GREEN"
print_message "4. Stopped and removed all Docker containers" "$GREEN"
print_message "5. Removed all Docker images" "$GREEN"
print_message "6. Removed all Docker volumes" "$GREEN"
print_message "7. Cleaned up unused Docker resources" "$GREEN"
print_message "8. Cleaned up project files and build artifacts" "$GREEN"

print_message "\nThe $SYSTEM_DISPLAY_NAME service has been completely removed from the system." "$GREEN"
