#!/bin/bash
# common.sh - Common utility functions for bot management scripts
# 
# This script provides shared functions for all bot management scripts,
# including Docker checks, environment setup, and service management.

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    source ".env"
fi

###################
# Output Utilities
###################

# ANSI color codes
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Print a formatted message with optional color
print_message() {
    local message="$1"
    local color="${2:-$NC}"
    echo -e "${color}${message}${NC}"
}

# Print a warning message
print_warning() {
    print_message "$1" "$YELLOW"
}

# Print an error message
print_error() {
    print_message "$1" "$RED"
}

# Print a section header
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

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

######################
# Environment Checks
######################

# Check if BOT_TOKEN is set
check_bot_token() {
    # First check if BOT_TOKEN is set in environment
    if [ -n "$BOT_TOKEN" ]; then
        return 0
    fi
    
    # Then check if .env file exists and contains BOT_TOKEN
    if [ -f ".env" ]; then
        if grep -q "BOT_TOKEN=" ".env"; then
            # Source the .env file to get the BOT_TOKEN
            source ".env"
            if [ -n "$BOT_TOKEN" ]; then
                return 0
            fi
        fi
    fi
    
    # If we get here, BOT_TOKEN is not set
    print_error "BOT_TOKEN environment variable is not set."
    print_message "Please set BOT_TOKEN in one of the following ways:" "$YELLOW"
    print_message "1. Export it in your environment: export BOT_TOKEN='your_bot_token_here'" "$YELLOW"
    print_message "2. Add it to .env file: echo 'BOT_TOKEN=your_bot_token_here' > .env" "$YELLOW"
    print_message "3. Pass it as an argument to the script: ./run.sh --token your_bot_token_here" "$YELLOW"
    return 1
}

# Check SYSTEM_NAME
check_system_name() {
    if [ -z "$SYSTEM_NAME" ]; then
        print_error "SYSTEM_NAME is not set"
        print_message "Please set SYSTEM_NAME in .env file" "$YELLOW"
        exit 1
    fi
}

# Check SYSTEM_DISPLAY_NAME
check_system_display_name() {
    if [ -z "$SYSTEM_DISPLAY_NAME" ]; then
        print_error "SYSTEM_DISPLAY_NAME is not set"
        print_message "Please set SYSTEM_DISPLAY_NAME in .env file" "$YELLOW"
        exit 1
    fi
}

#########################
# Service Management
#########################

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

# Build and start service
build_and_start_service() {
    local service=${1:-"bot"}  # Default to "bot" if no service specified
    
    # Ensure SYSTEM_NAME is properly exported
    check_system_name
    
    # Always remove images if force rebuild is requested
    if [ "$FORCE_REBUILD" == "1" ]; then
        print_message "Force rebuild requested. Removing existing images..." "$YELLOW"
        docker rmi ${SYSTEM_NAME} ${SYSTEM_NAME}-test >/dev/null 2>&1 || true
        # Also remove all build cache
        docker builder prune -f >/dev/null 2>&1 || true
    fi

    print_message "Building and starting $service service..." "$GREEN"
    
    # Use --no-cache if force rebuild is requested
    if [ "$FORCE_REBUILD" == "1" ]; then
        print_message "Building from scratch (no cache)..." "$YELLOW"
        if ! docker-compose build --no-cache $service; then
            print_error "Failed to build the $service service. Please check the logs above for details."
            return 1
        fi
        
        if ! docker-compose up -d $service; then
            print_error "Failed to start the $service service. Please check the logs above for details."
            return 1
        fi
    else
        if ! docker-compose up -d --build $service; then
            print_error "Failed to start the $service service. Please check the logs above for details."
            return 1
        fi
    fi
    
    return 0
}

###########################
# Container Status Checks
###########################

# Check if container is running
is_container_running() {
    local service=${1:-"bot"}  # Default to "bot" if no service specified
    
    # Ensure SYSTEM_NAME is properly exported
    check_system_name
    
    docker-compose ps -q $service >/dev/null 2>&1
}

# Check if bot is healthy using Docker healthcheck
is_bot_healthy() {
    # Ensure SYSTEM_NAME is properly exported before running docker-compose commands
    check_system_name
    local container_id=$(docker-compose ps -q bot)
    
    if [ -z "$container_id" ]; then
        print_error "Container is not running"
        return 1
    fi
    
    # Get container health status
    local health_status=$(docker inspect --format '{{.State.Health.Status}}' $container_id 2>/dev/null)
    
    if [ "$health_status" = "healthy" ]; then
        print_message "Bot is healthy - container health check passed" "$GREEN"
        # Print the most recent health check log
        print_message "Last health check result:" "$YELLOW"
        docker inspect --format='{{range .State.Health.Log}}{{if eq .ExitCode 0}}{{.Output}}{{end}}{{end}}' $container_id | tail -1
        return 0
    elif [ "$health_status" = "starting" ]; then
        print_message "Bot health check is still initializing" "$YELLOW"
        return 1
    else
        print_error "Bot health check failed - status: $health_status"
        # Print the most recent health check log
        print_message "Last health check result:" "$YELLOW"
        docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' $container_id | tail -1
        return 1
    fi
}

# Check if bot is operational
is_bot_operational() {
    local max_attempts=30
    local attempt=1
    # Ensure SYSTEM_NAME is properly exported before running docker-compose commands
    check_system_name
    local container_id=$(docker-compose ps -q bot)
    
    if [ -z "$container_id" ]; then
        print_error "Container is not running"
        return 1
    fi
    
    # Check if Python process is running
    if ! docker exec $container_id pgrep -f "python.*src[/.]bot" >/dev/null 2>&1; then
        print_error "Bot process is not running inside container"
        return 1
    fi
    
    # Check container logs for operational messages
    print_message "Checking logs for operational status..." "$YELLOW"
    logs=$(docker logs $container_id --tail 50 2>&1)
    
    if echo "$logs" | grep -q "Application started"; then
        print_message "Bot is operational" "$GREEN"
        return 0
    fi
    
    # Check for API calls - if multiple successful API calls have been made, consider it operational
    api_calls=$(echo "$logs" | grep -c "\"HTTP/1.1 200 OK\"")
    if [ "$api_calls" -ge 2 ]; then
        print_message "Bot is operational ($api_calls successful API calls detected)" "$GREEN"
        return 0
    fi
    
    print_error "Bot is not operational"
    return 1
}

# Check for conflicts with the same bot token
detect_remote_bot_conflict() {
    local bot_token="$1"
    
    if [ -z "$bot_token" ]; then
        print_error "Bot token is empty, cannot check for conflicts"
        return 1
    fi
    
    # Check for existing bot containers or services using the same token
    print_message "Checking for existing bot processes..." "$YELLOW"
    
    # Try to get bot info using the token
    local bot_info=$(curl -s "https://api.telegram.org/bot${bot_token}/getMe")
    
    # Check if we got a successful response
    if echo "$bot_info" | grep -q "\"ok\":true"; then
        # Extract bot username
        local bot_username=$(echo "$bot_info" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        print_message "Connected to bot: @${bot_username}" "$GREEN"
        
        # Check webhook info
        local webhook_info=$(curl -s "https://api.telegram.org/bot${bot_token}/getWebhookInfo")
        
        # Check if webhook is set
        if echo "$webhook_info" | grep -q '"url":"[^"]*"'; then
            local webhook_url=$(echo "$webhook_info" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
            
            if [ -n "$webhook_url" ] && [ "$webhook_url" != "\"\"" ]; then
                print_warning "This bot already has a webhook set: ${webhook_url}"
                return 1  # Remote conflict
            fi
        fi
        
        # Check for local processes using docker ps
        if docker ps | grep -q ${SYSTEM_NAME}; then
            print_warning "Found local bot container using the same token."
            return 2  # Local conflict
        fi
        
        return 0  # No conflict
    else
        print_error "Could not connect to Telegram API with the provided token"
        echo "$bot_info"
        return 1
    fi
}

###########################
# Command Line Arguments
###########################

# Parse command line arguments
parse_arguments() {
    TOKEN_ARG=""
    FORCE_REBUILD=0
    CLEANUP=0
    
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --token)
                TOKEN_ARG="$2"
                if [ -z "$TOKEN_ARG" ]; then
                    print_error "Missing value for --token argument"
                    print_message "Usage: $0 --token YOUR_BOT_TOKEN" "$YELLOW"
                    return 1
                fi
                export BOT_TOKEN="$TOKEN_ARG"
                shift 2
                ;;
            --force-rebuild)
                FORCE_REBUILD=1
                shift
                ;;
            --cleanup)
                CLEANUP=1
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown argument: $1"
                show_help
                return 1
                ;;
        esac
    done
    
    return 0
}

# Show help message
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --token TOKEN       Specify the Telegram bot token"
    echo "  --force-rebuild     Force rebuild of Docker containers"
    echo "  --cleanup           Perform additional cleanup of Docker resources"
    echo "  --help              Show this help message"
}

# Show available service commands
show_service_commands() {
    check_system_name
    
    print_section "Service Commands"
    echo "The following commands can be used to manage the bot service:"
    echo "  sudo systemctl start ${SYSTEM_NAME}.service    - Start the bot service"
    echo "  sudo systemctl stop ${SYSTEM_NAME}.service     - Stop the bot service"
    echo "  sudo systemctl restart ${SYSTEM_NAME}.service  - Restart the bot service"
    echo "  sudo systemctl status ${SYSTEM_NAME}.service   - Check service status"
    echo ""
    echo "To check logs:"
    echo "  sudo journalctl -u ${SYSTEM_NAME}.service      - View service logs"
    echo "  docker logs ${SYSTEM_NAME}                     - View container logs"
}

# Automatically export the BOT_TOKEN if it's set
if [ -n "$BOT_TOKEN" ]; then
    export BOT_TOKEN
fi
