#!/bin/bash
# errors.sh - Error handling and debugging utilities
#
# This module provides functions for error logging, debugging,
# and enhanced error handling for Docker operations.

# Function to log detailed docker-compose error information
log_docker_compose_error() {
    local operation="$1" # e.g., "build", "up", "stop"
    local service="$2"   # e.g., "bot"
    
    print_error "Docker Compose $operation failed for service $service"
    print_message "=== DOCKER COMPOSE ERROR DIAGNOSTICS ===" "$RED"
    
    print_message "Current working directory: $(pwd)" "$YELLOW"
    print_message "Docker Compose version:" "$YELLOW"
    docker-compose --version 2>&1 || echo "docker-compose command not found"
    
    print_message "Docker version:" "$YELLOW"
    docker --version 2>&1 || echo "docker command not found"
    
    print_message "Docker daemon status:" "$YELLOW"
    if docker info >/dev/null 2>&1; then
        echo "✅ Docker daemon is running"
    else
        echo "❌ Docker daemon is not accessible"
    fi
    
    print_message "Docker Compose file check:" "$YELLOW"
    if [ -f "docker-compose.yml" ]; then
        echo "✅ docker-compose.yml exists"
        print_message "Validating docker-compose.yml syntax:" "$YELLOW"
        docker-compose config --quiet 2>&1 || echo "❌ docker-compose.yml has syntax errors"
    else
        echo "❌ docker-compose.yml not found"
    fi
    
    print_message "Environment variables:" "$YELLOW"
    echo "SYSTEM_NAME=${SYSTEM_NAME:-NOT_SET}"
    echo "BOT_TOKEN=${BOT_TOKEN:+SET_BUT_HIDDEN}"
    
    if [ -n "$service" ]; then
        print_message "Service $service status:" "$YELLOW"
        docker-compose ps $service 2>&1 || echo "Failed to get service status"
        
        print_message "Recent logs for $service:" "$YELLOW"
        docker-compose logs --tail 10 $service 2>&1 || echo "Failed to get logs"
    fi
    
    print_message "=== END DOCKER COMPOSE DIAGNOSTICS ===" "$RED"
}

# Function to execute docker-compose commands with enhanced error handling
execute_docker_compose() {
    local operation="$1"
    local service="$2"
    shift 2
    local additional_args="$@"
    
    print_message "Executing: docker-compose $operation $service $additional_args" "$YELLOW"
    
    if docker-compose "$operation" "$service" $additional_args; then
        print_message "✅ docker-compose $operation $service completed successfully" "$GREEN"
        return 0
    else
        log_docker_compose_error "$operation" "$service"
        return 1
    fi
} 