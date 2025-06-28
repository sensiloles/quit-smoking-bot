#!/bin/bash
# errors.sh - Error handling and debugging utilities
#
# This module provides functions for error logging, debugging,
# and enhanced error handling for Docker operations.

# Function to log detailed docker-compose error information
log_docker_compose_error() {
    local operation="$1" # e.g., "build", "up", "stop"
    local service="$2"   # e.g., "bot"
    
    debug_print "Entering log_docker_compose_error for operation '$operation' on service '$service'"
    print_error "Docker Compose $operation failed for service $service"
    print_message "=== DOCKER COMPOSE ERROR DIAGNOSTICS ===" "$RED"
    
    debug_print "Gathering diagnostic information..."
    print_message "Current working directory: $(pwd)" "$YELLOW"
    print_message "Docker Compose version:" "$YELLOW"
    docker-compose --version 2>&1 || echo "docker-compose command not found"
    
    print_message "Docker version:" "$YELLOW"
    docker --version 2>&1 || echo "docker command not found"
    
    print_message "Docker daemon status:" "$YELLOW"
    debug_print "Testing Docker daemon connectivity"
    if docker info >/dev/null 2>&1; then
        debug_print "Docker daemon is accessible"
        echo "✅ Docker daemon is running"
    else
        debug_print "Docker daemon is not accessible"
        echo "❌ Docker daemon is not accessible"
    fi
    
    print_message "Docker Compose file check:" "$YELLOW"
    debug_print "Checking docker-compose.yml existence and syntax"
    if [ -f "docker-compose.yml" ]; then
        echo "✅ docker-compose.yml exists"
        print_message "Validating docker-compose.yml syntax:" "$YELLOW"
        docker-compose config --quiet 2>&1 || echo "❌ docker-compose.yml has syntax errors"
    else
        debug_print "docker-compose.yml not found in current directory"
        echo "❌ docker-compose.yml not found"
    fi
    
    print_message "Environment variables:" "$YELLOW"
    debug_print "Displaying environment variables (BOT_TOKEN hidden for security)"
    echo "SYSTEM_NAME=${SYSTEM_NAME:-NOT_SET}"
    echo "BOT_TOKEN=${BOT_TOKEN:+SET_BUT_HIDDEN}"
    
    if [ -n "$service" ]; then
        debug_print "Gathering service-specific information for $service"
        print_message "Service $service status:" "$YELLOW"
        docker-compose ps $service 2>&1 || echo "Failed to get service status"
        
        print_message "Recent logs for $service:" "$YELLOW"
        docker-compose logs --tail 10 $service 2>&1 || echo "Failed to get logs"
    fi
    
    debug_print "Docker compose error diagnostics completed"
    print_message "=== END DOCKER COMPOSE DIAGNOSTICS ===" "$RED"
}

# Function to execute docker-compose commands with enhanced error handling
execute_docker_compose() {
    local operation="$1"
    local service="$2"
    shift 2
    local additional_args="$@"
    
    debug_print "Executing docker-compose command: operation='$operation', service='$service', args='$additional_args'"
    print_message "Executing: docker-compose $operation $service $additional_args" "$YELLOW"
    
    debug_print "Running: docker-compose $operation $service $additional_args"
    if docker-compose "$operation" "$service" $additional_args; then
        debug_print "docker-compose command completed successfully"
        print_message "✅ docker-compose $operation $service completed successfully" "$GREEN"
        return 0
    else
        debug_print "docker-compose command failed, initiating error diagnostics"
        log_docker_compose_error "$operation" "$service"
        return 1
    fi
} 