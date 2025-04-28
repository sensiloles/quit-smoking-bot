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
    local start_after_build=${2:-1} # Default to starting the service after build

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
        if ! docker-compose build --no-cache $service; then
            print_error "Failed to build the $service service. Please check the logs above for details."
            return 1
        fi
    else
        if ! docker-compose build $service; then
            print_error "Failed to build the $service service. Please check the logs above for details."
            return 1
        fi
    fi

    # Start the service if requested
    if [ "$start_after_build" -eq 1 ]; then
        print_message "Starting $service service..." "$GREEN"
        if ! docker-compose up -d $service; then
            print_error "Failed to start the $service service. Please check the logs above for details."
            return 1
        fi
    else
        print_message "Build complete. Service not started yet." "$YELLOW"
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

    # Check for conflict errors first - if found, report the conflict but don't return yet
    if echo "$logs" | grep -q "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates"; then
        print_error "Telegram API conflict detected - another bot is running with the same token"
        print_message "You will need to stop the other bot instance to use this one properly." "$YELLOW"
    fi

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

    # Even with conflicts, the bot might still be partly operational if it's still making API calls
    # If we found conflicts earlier, but the bot is still somewhat operational, return success
    # This allows the finalizeStartupCheck function to handle the conflict appropriately
    if echo "$logs" | grep -q "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates" && \
       echo "$logs" | grep -q "\"HTTP/1.1 200 OK\""; then
        print_message "Bot is partly operational despite conflicts" "$YELLOW"
        return 0
    fi

    print_error "Bot is not operational"
    return 1
}

# Check for conflicts with the same bot token
detect_remote_bot_conflict() {
    local bot_token="$1"

    debug_print "Entering detect_remote_bot_conflict"

    if [ -z "$bot_token" ]; then
        print_error "Bot token is empty, cannot check for conflicts"
        debug_print "Bot token is empty, returning 1"
        return 1
    fi

    # Check for existing bot containers or services using the same token
    print_message "Checking for existing bot processes..." "$YELLOW"

    # Try to get bot info using the token
    print_message "Requesting bot info from Telegram API..." "$YELLOW"
    debug_print "Making getMe request to Telegram API"
    local bot_info=$(curl -s "https://api.telegram.org/bot${bot_token}/getMe")
    debug_print "getMe response received"
    print_message "Response received from Telegram API" "$YELLOW"

    # Check if we got a successful response
    debug_print "Checking if response is successful"
    if echo "$bot_info" | grep -q "\"ok\":true"; then
        debug_print "Response is successful"
        # Extract bot username
        local bot_username=$(echo "$bot_info" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        print_message "Connected to bot: @${bot_username}" "$GREEN"

        # Make a getUpdates request to check if someone else is polling
        print_message "Testing Telegram API connection..." "$YELLOW"
        debug_print "Making getUpdates request"
        local getUpdates_response=$(curl -s "https://api.telegram.org/bot${bot_token}/getUpdates?timeout=1&offset=-1&limit=1")
        debug_print "getUpdates response received"
        print_message "GetUpdates response received" "$YELLOW"

        # Check for conflict error
        debug_print "Checking for error_code:409"
        # Store grep result first
        echo "$getUpdates_response" | grep -q "\"error_code\":409"
        local grep_result_409=$?
        if [ $grep_result_409 -eq 0 ]; then # Check the exit status of grep
            debug_print "Found error_code:409"
            print_error "Conflict detected: Another bot instance is already polling updates."
            print_message "Error 409 indicates that another bot with the same token is running elsewhere." "$RED"
            print_message "Please stop the other bot instance before starting this one." "$YELLOW"
            return 1  # Remote conflict
        fi
        
        # Additional check for "terminated by other getUpdates" in error description
        debug_print "Checking for 'terminated by other getUpdates'"
        # Store grep result first
        echo "$getUpdates_response" | grep -q "terminated by other getUpdates"
        local grep_result_term=$?
        if [ $grep_result_term -eq 0 ]; then # Check the exit status of grep
            debug_print "Found 'terminated by other getUpdates'"
            print_error "Conflict detected: Another bot instance is already polling updates."
            print_message "Error message indicates that another bot with the same token is running elsewhere." "$RED"
            print_message "Please stop the other bot instance before starting this one." "$YELLOW"
            return 1  # Remote conflict
        fi

        # Check webhook info
        print_message "Checking webhook info..." "$YELLOW"
        local webhook_info=$(curl -s "https://api.telegram.org/bot${bot_token}/getWebhookInfo")
        print_message "Webhook info received" "$YELLOW"

        # Check if webhook is set
        if echo "$webhook_info" | grep -q '"url":"[^"]*"'; then
            local webhook_url=$(echo "$webhook_info" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)

            if [ -n "$webhook_url" ] && [ "$webhook_url" != "\"\"" ] && [ "$webhook_url" != "" ]; then
                print_error "This bot already has a webhook set: ${webhook_url}"
                print_message "This indicates it is in use by another server." "$RED"
                print_message "Please remove the webhook or use another bot token." "$YELLOW"
                return 1  # Remote conflict
            fi
        fi

        # Check for local processes using docker ps
        print_message "Checking for local Docker containers..." "$YELLOW"
        if [ -z "$SYSTEM_NAME" ]; then
            print_warning "SYSTEM_NAME is not set, skipping local container check"
        else
            if docker ps | grep -q ${SYSTEM_NAME}; then
                print_warning "Found local bot container using the same token."
                return 2  # Local conflict
            fi
        fi

        print_message "No conflicts detected" "$GREEN"
        return 0  # No conflict
    else
        print_error "Could not connect to Telegram API with the provided token"
        echo "$bot_info"
        return 1
    fi
}

# Add a function for debug output
debug_print() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo "DEBUG: $1" >&2
    fi
}

# Function to stop local bot instance
stop_local_bot_instance() {
    local wait_time="${1:-5}"  # Wait time after stopping (default 5 seconds)
    
    print_message "Checking if bot is running locally..." "$YELLOW"
    debug_print "Inside stop_local_bot_instance, about to check docker ps | grep..."
    local local_bot_running=0
    
    if docker ps | grep -q "${SYSTEM_NAME}"; then
        debug_print "docker ps | grep found running container."
        print_warning "Bot is already running on this machine."
        
        # Stop existing container
        print_message "Stopping existing bot container..." "$YELLOW"
        docker-compose stop bot
        docker-compose rm -f bot

        # Wait for Telegram API connections to release
        print_message "Waiting for Telegram API connections to release (${wait_time} seconds)..." "$YELLOW"
        sleep $wait_time

        print_message "Local bot instance stopped" "$GREEN"
        return 0  # Container was stopped
    fi
    debug_print "docker ps | grep did NOT find running container. Returning 1."
    return 1  # Container was not found
}

# Reusable function to check for bot conflicts with extended verification
check_bot_conflicts() {
    local token="$1"
    local exit_on_conflict="${2:-1}"  # Default to 1 (exit on conflict)
    local wait_time="${3:-0}"  # Wait time after stopping (default 5 seconds)
    
    print_message "Checking for conflicts with the same bot token..." "$YELLOW"
    debug_print "Entering check_bot_conflicts function."
    
    # First check and stop local container
    local local_stopped=0
    debug_print "Calling stop_local_bot_instance."
    if stop_local_bot_instance "$wait_time"; then
        local_stopped=1
        debug_print "Local bot instance stopped: local_stopped=1"
    else
        debug_print "Local bot instance was not running: local_stopped=0"
    fi
    
    # Make multiple attempts to detect conflicts with increased wait times
    local max_attempts=3
    local attempt=1
    local conflict_status=0
    debug_print "Starting conflict detection loop."
    
    while [ $attempt -le $max_attempts ]; do
        debug_print "Conflict check attempt: $attempt of $max_attempts"
        
        # If we've already tried once, wait longer to ensure any connections have time to release
        if [ $attempt -gt 1 ]; then
            print_message "Waiting longer for existing connections to clear (attempt $attempt)..." "$YELLOW"
            sleep $(( wait_time * attempt ))
        fi
        
        # If there's no local container, check for conflicts via API
        debug_print "Calling detect_remote_bot_conflict"
        detect_remote_bot_conflict "$token" # Call directly
        conflict_status=$? # Capture the actual return code
        debug_print "detect_remote_bot_conflict returned status: $conflict_status"
        
        # If we got a conflict (status 1)
        if [ $conflict_status -eq 1 ]; then
            # Status 1 means a remote conflict (different machine or process)
            # Error messages are printed inside detect_remote_bot_conflict
            if [ "$exit_on_conflict" -eq 1 ]; then
                debug_print "Exiting check_bot_conflicts due to remote conflict (exit_on_conflict=1)"
                return 1 # Exit with error
            else
                 debug_print "Remote conflict detected, but exit_on_conflict != 1, breaking loop."
                 break # Exit the loop but continue script
            fi
        # If no conflict (status 0)
        elif [ $conflict_status -eq 0 ]; then
             debug_print "No conflict detected in this attempt."
             # If we are on the last attempt and status is 0, we are good.
             if [ $attempt -eq $max_attempts ]; then
                 print_message "No conflicts detected after $max_attempts attempts" "$GREEN"
                 break # Exit loop successfully
             fi
        # Handle unexpected return codes?
        else
            print_error "Unexpected return code $conflict_status from detect_remote_bot_conflict"
             if [ "$exit_on_conflict" -eq 1 ]; then
                debug_print "Exiting check_bot_conflicts due to unexpected error (exit_on_conflict=1)"
                 return 1 # Exit on unexpected error if exit_on_conflict is set
             else
                 debug_print "Unexpected error detected, but exit_on_conflict != 1, breaking loop."
                 break # Exit loop otherwise
             fi
        fi
        
        ((attempt++))
    done
    
    debug_print "Exiting check_bot_conflicts function with status: $conflict_status"
    return $conflict_status # Return the final determined status
}

###########################
# Command Line Arguments
###########################

# Parse command-line arguments
parse_args() {
    # Initialize variables with default values
    TOKEN=""
    FORCE_REBUILD=0
    CLEANUP=0
    RUN_TESTS=0 # Initialize the new flag
    # Loop through arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --token)
                if [[ -z "$2" || "$2" == --* ]]; then
                    print_error "Token value missing after --token flag"
                    exit 1
                fi
                TOKEN="$2"
                shift 2
                ;;
            --force-rebuild)
                FORCE_REBUILD=1
                shift 1
                ;;
            --cleanup)
                CLEANUP=1
                shift 1
                ;;
            --tests) # Add handling for the new flag
                RUN_TESTS=1
                shift 1
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Update BOT_TOKEN in .env file
update_env_token() {
    local token="$1"
    local env_file=".env"

    # Create .env file if it doesn't exist
    if [ ! -f "$env_file" ]; then
        touch "$env_file"
    fi

    # Check if BOT_TOKEN already exists in the file
    if grep -q "^BOT_TOKEN=" "$env_file"; then
        # Replace existing BOT_TOKEN
        if [ "$(uname)" == "Darwin" ]; then
            # macOS version
            sed -i "" "s|^BOT_TOKEN=.*|BOT_TOKEN=\"$token\"|" "$env_file"
        else
            # Linux version
            sed -i "s|^BOT_TOKEN=.*|BOT_TOKEN=\"$token\"|" "$env_file"
        fi
    else
        # Add new BOT_TOKEN entry
        echo "BOT_TOKEN=\"$token\"" >> "$env_file"
    fi

    print_message "Updated BOT_TOKEN in $env_file" "$GREEN"
}

# Show available service commands
show_service_commands() {
    if [[ "$(uname)" != "Linux" ]]; then
        print_warning "Service commands are only available on Linux systems with systemd."
        return
    fi
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

# Function to check prerequisites (common across scripts)
check_prerequisites() {
    # Check prerequisites
    check_docker_installation || return 1
    check_docker_buildx
    check_bot_token || return 1
    check_system_name
    check_docker || return 1
    return 0
}


# Function to stop any running bot instances
stop_running_instances() {
    print_message "Checking for existing bot instances..." "$YELLOW"

    if docker-compose ps -q bot >/dev/null 2>&1; then
        print_message "Stopping existing bot container..." "$YELLOW"
        docker-compose stop bot
        docker-compose rm -f bot

        # If there was a conflict, wait a bit to let Telegram API release connections
        if [ $1 -eq 2 ]; then
            print_message "Waiting for Telegram API connections to release (5 seconds)..." "$YELLOW"
            sleep 5
        fi
    fi
}

# Function to check bot health and status after startup
check_bot_status() {
    print_message "\nChecking bot status after startup..." "$YELLOW"
    local max_attempts=30
    local attempt=1

    # Wait a moment for the container to initialize
    sleep 5

    while [ $attempt -le $max_attempts ]; do
        print_message "Checking bot health (attempt $attempt/$max_attempts)..." "$YELLOW"

        # Check if bot is healthy using Docker healthcheck
        if is_bot_healthy; then
            print_message "Bot health check: PASSED" "$GREEN"
            break
        else
            if [ $attempt -eq $max_attempts ]; then
                print_message "Bot health check did not pass within timeout, but bot might still be functioning." "$YELLOW"
                print_message "Continuing with operational check..." "$YELLOW"
            else
                print_message "Bot health check not yet passing, waiting..." "$YELLOW"
                sleep 5
                ((attempt++))
                continue
            fi
        fi

        ((attempt++))
    done

    # Check if bot is operational
    if is_bot_operational; then
        print_message "Bot operational check: PASSED" "$GREEN"
        print_message "Bot is fully operational!" "$GREEN"
        return 0
    else
        print_message "Bot operational check: NOT PASSED" "$YELLOW"
        print_message "Bot is running but might not be fully operational." "$YELLOW"
        print_message "Use './scripts/check-service.sh' for detailed diagnostics." "$YELLOW"
        return 1
    fi
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root (use sudo)"
        exit 1
    fi
}

# Setup data directories with proper permissions
setup_data_directories() {
    print_message "Setting up data and log directories..." "$YELLOW"

    # Create local data directory
    if [ ! -d "./data" ]; then
        mkdir -p ./data
        print_message "Created data directory" "$GREEN"
    fi

    # Create local logs directory
    if [ ! -d "./logs" ]; then
        mkdir -p ./logs
        print_message "Created logs directory" "$GREEN"
    fi

    # Ensure correct ownership (current user)
    local current_user=$(id -u)
    local current_group=$(id -g)

    # Give liberal permissions temporarily to avoid permission issues during build and startup
    chmod -R 777 ./data ./logs

    print_message "Fixed permissions on data and log directories" "$GREEN"

    # Ensure docker-compose.yml exists and has correct volume mappings
    if [ -f "docker-compose.yml" ]; then
        # Check if volumes are correctly mapped
        if ! grep -q "./data:/app/data" docker-compose.yml || ! grep -q "./logs:/app/logs" docker-compose.yml; then
            print_warning "Your docker-compose.yml may not have correct volume mappings"
            print_message "Please ensure you have these mappings in your docker-compose.yml:" "$YELLOW"
            print_message "volumes:" "$YELLOW"
            print_message "  - ./data:/app/data" "$YELLOW"
            print_message "  - ./logs:/app/logs" "$YELLOW"
        fi
    fi
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

###################
# Test Execution
###################

# Run tests within Docker
run_tests_in_docker() {
    print_section "Running Tests"
    print_message "Running tests using docker-compose run --rm test..." "$YELLOW"

    # Execute tests directly
    if docker-compose run --rm test; then
        print_message "\nTests Passed!" "$GREEN"
        return 0
    else
        print_error "Tests Failed! Check the output above for details."
        return 1
    fi
}

# Automatically export the BOT_TOKEN if it's set
if [ -n "$BOT_TOKEN" ]; then
    export BOT_TOKEN
fi
