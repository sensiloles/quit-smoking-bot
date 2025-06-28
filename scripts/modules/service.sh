#!/bin/bash
# service.sh - Service and container management utilities
#
# This module provides functions for building, starting, stopping,
# and managing Docker services and containers.

#########################
# Service Management
#########################

# Build and start service
build_and_start_service() {
    local service=${1:-"bot"}  # Default to "bot" if no service specified
    local start_after_build=${2:-1} # Default to starting the service after build

    print_message "=== BUILD_AND_START_SERVICE DEBUG ===" "$BLUE"
    print_message "Service: $service" "$BLUE"
    print_message "Start after build: $start_after_build" "$BLUE"
    print_message "=================================" "$BLUE"

    # Ensure SYSTEM_NAME is properly exported
    check_system_name

    # Always remove images if force rebuild is requested
    if [ "$FORCE_REBUILD" == "1" ]; then
        print_message "Force rebuild requested. Removing existing images..." "$YELLOW"
        docker rmi ${SYSTEM_NAME} ${SYSTEM_NAME}-test >/dev/null 2>&1 || true
        # Also remove all build cache
        docker builder prune -f >/dev/null 2>&1 || true
    fi

    print_message "Building $service service..." "$GREEN"

    # Use --no-cache if force rebuild is requested
    if [ "$FORCE_REBUILD" == "1" ]; then
        print_message "Building from scratch (no cache)..." "$YELLOW"
        if ! execute_docker_compose "build" "$service" "--no-cache"; then
            print_error "Failed to build the $service service."
            return 1
        fi
    else
        if ! execute_docker_compose "build" "$service"; then
            print_error "Failed to build the $service service."
            return 1
        fi
    fi

    print_message "Build completed successfully for $service service." "$GREEN"

    # Start the service if requested
    if [ "$start_after_build" -eq 1 ]; then
        print_message "Starting $service service (start_after_build=$start_after_build)..." "$GREEN"
        
        # Check if service is already running
        if docker-compose ps $service | grep -q "Up"; then
            print_warning "Service $service is already running. Stopping it first..."
            docker-compose stop $service
            sleep 2
        fi
        
        if ! execute_docker_compose "up" "$service" "-d"; then
            print_error "Failed to start the $service service with docker-compose up -d."
            return 1
        fi
        
        # Wait a moment and verify the container actually started
        print_message "Waiting for container to initialize..." "$YELLOW"
        sleep 3
        
        # Verify container is running
        if ! docker-compose ps $service | grep -q "Up"; then
            print_error "Container $service failed to start or immediately stopped!"
            print_message "Container status:" "$YELLOW"
            docker-compose ps $service
            print_message "Container logs:" "$YELLOW"
            docker-compose logs --tail 30 $service
            return 1
        fi
        
        print_message "Service $service started successfully and is running." "$GREEN"
        print_message "Container status:" "$YELLOW"
        docker-compose ps $service
        
    else
        print_message "Build complete. Service not started (start_after_build=$start_after_build)." "$YELLOW"
    fi

    return 0
}

# Stop running instances
stop_running_instances() {
    local conflict_status="${1:-0}"
    
    print_message "=== STOPPING EXISTING INSTANCES ===" "$BLUE"
    
    # Check if there are any running containers for this service
    if docker-compose ps -q bot >/dev/null 2>&1 && [ -n "$(docker-compose ps -q bot)" ]; then
        print_message "Found existing bot containers, stopping them..." "$YELLOW"
        
        print_message "Stopping existing bot container..." "$YELLOW"
        if execute_docker_compose "stop" "bot"; then
            print_message "✅ Container stopped successfully" "$GREEN"
        else
            print_warning "Failed to stop container gracefully, forcing removal..."
        fi
        
        print_message "Removing stopped container..." "$YELLOW"
        if execute_docker_compose "rm" "bot" "-f"; then
            print_message "✅ Container removed successfully" "$GREEN"
        else
            print_warning "Failed to remove container"
        fi

        # If there was a conflict, wait a bit to let Telegram API release connections
        if [ "${conflict_status:-0}" -eq 2 ]; then
            print_message "Waiting for Telegram API connections to release (5 seconds)..." "$YELLOW"
            sleep 5
        fi
        
        print_message "Verifying no containers remain..." "$YELLOW"
        local remaining_count=$(docker-compose ps -q bot 2>/dev/null | wc -l)
        if [ "$remaining_count" -eq 0 ]; then
            print_message "✅ All bot containers successfully removed" "$GREEN"
        else
            print_warning "Warning: $remaining_count containers still remain"
            docker-compose ps bot
        fi
    else
        print_message "No existing bot containers found" "$GREEN"
    fi
    
    print_message "=== END STOPPING INSTANCES ===" "$BLUE"
}

# Check if container is running
is_container_running() {
    local service=${1:-"bot"}  # Default to "bot" if no service specified

    # Ensure SYSTEM_NAME is properly exported
    check_system_name

    docker-compose ps -q $service >/dev/null 2>&1
}

# Function to get service status
get_service_status() {
    if [[ "$(uname)" != "Linux" ]]; then
        print_warning "Systemd service status is only available on Linux."
    else
        print_message "\nCurrent service status:" "$YELLOW"
        systemctl status $SYSTEM_NAME.service --no-pager || true
    fi

    print_message "\nDocker container status:" "$YELLOW"
    docker ps -a --filter "name=$SYSTEM_NAME" || true

    print_message "\nDocker images:" "$YELLOW"
    docker images | grep $SYSTEM_NAME || true
} 