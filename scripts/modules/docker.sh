#!/bin/bash
# docker.sh - Docker management utilities
#
# This module provides functions for Docker installation checks,
# daemon management, and container operations.

###################
# Docker Utilities
###################

# Check if Docker is installed and running
check_docker_installation() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed."
        print_message "Please install Docker first." "$YELLOW"
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running."

        if [[ "$OSTYPE" == "darwin"* ]]; then
            start_docker_macos || return 1
        else
            start_docker_linux || return 1
        fi
    fi

    return 0
}

# Start Docker on macOS
start_docker_macos() {
    print_message "Attempting to start Docker for Mac..." "$YELLOW"

    if [ -f "/Applications/Docker.app/Contents/MacOS/Docker" ]; then
        print_message "Found Docker.app, attempting to start it..." "$YELLOW"
        open -a Docker

        # Wait for Docker to start (up to 60 seconds)
        local max_attempts=30
        local attempt=1
        while [ $attempt -le $max_attempts ]; do
            print_message "Waiting for Docker to start (attempt $attempt/$max_attempts)..." "$YELLOW"
            if docker info >/dev/null 2>&1; then
                print_message "Docker started successfully." "$GREEN"
                return 0
            fi
            sleep 2
            ((attempt++))
        done

        print_error "Failed to start Docker for Mac."
        print_message "Please start Docker for Mac manually and try again." "$YELLOW"
        return 1
    else
        print_error "Docker for Mac is not installed."
        print_message "Please install Docker for Mac and try again." "$YELLOW"
        return 1
    fi
}

# Start Docker on Linux
start_docker_linux() {
    print_message "Attempting to start Docker daemon..." "$YELLOW"

    if systemctl start docker.service; then
        # Wait for Docker to start
        local max_attempts=10
        local attempt=1
        while [ $attempt -le $max_attempts ]; do
            print_message "Waiting for Docker to start (attempt $attempt/$max_attempts)..." "$YELLOW"
            if docker info >/dev/null 2>&1; then
                print_message "Docker started successfully." "$GREEN"
                return 0
            fi
            sleep 2
            ((attempt++))
        done
    fi

    print_error "Failed to start Docker daemon."
    print_message "Please start Docker daemon manually: sudo systemctl start docker" "$YELLOW"
    return 1
}

# Check Docker daemon
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            start_docker_macos || return 1
        else
            start_docker_linux || return 1
        fi
    fi
    return 0
}

# Check Docker Buildx
check_docker_buildx() {
    if ! docker buildx version &> /dev/null; then
        print_warning "Docker Buildx is not installed. Using legacy builder."
        print_message "For better performance, consider installing Docker Buildx:" "$YELLOW"
        print_message "https://docs.docker.com/go/buildx/" "$YELLOW"
    fi
}

# Clean up Docker resources
cleanup_docker() {
    local service=${1:-""}
    local cleanup_all=${2:-0}

    # Ensure SYSTEM_NAME is properly exported
    check_system_name

    print_message "Cleaning up Docker resources..." "$YELLOW"

    # Stop and remove containers
    print_message "Stopping and removing containers..." "$YELLOW"
    if [ -n "$service" ]; then
        docker-compose rm -sf $service
    else
        docker-compose down
    fi

    # Remove images if they exist
    print_message "Removing Docker images..." "$YELLOW"
    if [ -n "$service" ]; then
        docker-compose images -q $service | xargs -r docker rmi
    else
        docker-compose images -q | xargs -r docker rmi
    fi

    # Additional cleanup if requested
    if [ "$cleanup_all" == "1" ]; then
        print_message "Cleaning up unused Docker resources..." "$YELLOW"
        docker-compose down -v --remove-orphans
    fi

    print_message "Docker cleanup completed." "$GREEN"
} 