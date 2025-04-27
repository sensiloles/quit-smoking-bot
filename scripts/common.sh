#!/bin/bash

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    source ".env"
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local message="$1"
    local color="${2:-$NC}"
    echo -e "${color}${message}${NC}"
}

print_warning() {
    print_message "$1" "$YELLOW"
}

print_error() {
    print_message "$1" "$RED"
}

# Function to print section header
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to check if Docker is installed and running
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

# Function to check Docker daemon
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

# Function to check Docker Buildx
check_docker_buildx() {
    if ! docker buildx version &> /dev/null; then
        print_warning "Docker Buildx is not installed. Using legacy builder."
        print_message "For better performance, consider installing Docker Buildx:" "$YELLOW"
        print_message "https://docs.docker.com/go/buildx/" "$YELLOW"
    fi
}

# Function to check BOT_TOKEN
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

# Function to check SYSTEM_NAME
check_system_name() {
    if [ -z "$SYSTEM_NAME" ]; then
        print_error "SYSTEM_NAME is not set"
        print_message "Please set SYSTEM_NAME in .env file" "$YELLOW"
        exit 1
    fi
}

# Function to check SYSTEM_DISPLAY_NAME
check_system_display_name() {
    if [ -z "$SYSTEM_DISPLAY_NAME" ]; then
        print_error "SYSTEM_DISPLAY_NAME is not set"
        print_message "Please set SYSTEM_DISPLAY_NAME in .env file" "$YELLOW"
        exit 1
    fi
}

# Function to clean up Docker resources
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

# Function to build and start service
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

# Function to check if container is running
is_container_running() {
    local service=${1:-"bot"}  # Default to "bot" if no service specified
    
    # Ensure SYSTEM_NAME is properly exported
    check_system_name
    
    docker-compose ps -q $service >/dev/null 2>&1
}

# Function to check if bot is operational
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
    
    # Initial delay to let the container start properly
    sleep 5
    
    while [ $attempt -le $max_attempts ]; do
        print_message "Checking bot status (attempt $attempt/$max_attempts)..." "$YELLOW"
        
        # Check if Python process is running
        if docker exec $container_id pgrep -f "python.*src/bot" >/dev/null 2>&1; then
            # Check logs for errors that indicate bot is not functioning
            local logs=$(docker logs $container_id --tail 70 2>&1)
            
            # Check for critical errors that would prevent the bot from functioning
            if echo "$logs" | grep -q "ERROR.*Error in main"; then
                print_error "Bot has critical errors in logs:"
                echo "$logs" | grep "ERROR"
                return 1
            fi
            
            # Check for conflict errors
            if echo "$logs" | grep -q "telegram.error.Conflict: Conflict: terminated by other getUpdates request"; then
                # This could be a remote conflict - warn the user
                print_error "Detected conflict with another bot instance, possibly on a remote machine!"
                print_message "To resolve this conflict:" "$YELLOW"
                print_message "1. Make sure no other instances of this bot are running on any machine" "$YELLOW"
                print_message "2. Wait a few minutes for the Telegram API to release the connection" "$YELLOW"
                print_message "3. Restart this bot" "$YELLOW"
                
                # If this is a later attempt, give up - it's likely a remote conflict that won't resolve
                if [ $attempt -gt 10 ]; then
                    print_error "Conflict persists after multiple attempts. Likely an external bot instance."
                    print_message "Please stop any other bots using the same token and try again." "$YELLOW"
                    return 1
                fi
                
                # Wait longer for a remote conflict
                sleep 15
                ((attempt++))
                continue
            fi
            
            # Count successful API calls
            local successful_api_calls=$(echo "$logs" | grep -c "\"HTTP/1.1 200 OK\"")
            
            # Multiple success criteria - check for any of these patterns
            
            # Success pattern 1: Successful API call to getUpdates
            if echo "$logs" | grep -q "HTTP Request: POST https://api.telegram.org/bot.*getUpdates \"HTTP/1.1 200 OK\""; then
                print_message "Bot is operational - successfully connected to Telegram API" "$GREEN"
                return 0
            fi
            
            # Success pattern 2: Application started message
            if echo "$logs" | grep -q "Application started"; then
                print_message "Bot is operational - Application started" "$GREEN"
                return 0
            fi
            
            # Success pattern 3: Scheduler started
            if echo "$logs" | grep -q "Scheduler started"; then
                print_message "Bot is operational - Scheduler started" "$GREEN"
                return 0
            fi
            
            # Success pattern 4: Bot initialized message
            if echo "$logs" | grep -q "telegram.ext.Application - INFO - Application started"; then
                print_message "Bot is operational - Application initialized" "$GREEN"
                return 0
            fi
            
            # Success pattern 5: Several getUpdates calls with 200 OK
            # This indicates the bot is successfully polling for updates
            if [ "$successful_api_calls" -ge 2 ]; then
                print_message "Bot is operational - multiple successful API calls detected ($successful_api_calls)" "$GREEN"
                return 0
            fi
            
            # Success pattern 6: No errors and running for at least 30 seconds
            local container_uptime=$(docker inspect -f '{{.State.StartedAt}}' $container_id)
            local current_time=$(date +%s)
            local container_start_time=$(date -d "$container_uptime" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$container_uptime" +%s 2>/dev/null)
            
            if [ -n "$container_start_time" ]; then
                local uptime=$((current_time - container_start_time))
                if [ $uptime -gt 30 ] && ! echo "$logs" | grep -q "ERROR"; then
                    print_message "Bot is operational - running for $(($uptime / 60))m $(($uptime % 60))s without errors" "$GREEN"
                    return 0
                fi
            fi
            
            # Check if we've already waited a long time and there are no errors
            # If the bot has been running for a while without errors, consider it operational
            if [ $attempt -gt 15 ] && ! echo "$logs" | grep -q "ERROR"; then
                print_message "Bot appears to be operational - no errors detected after multiple checks" "$GREEN"
                return 0
            fi
        fi
        
        # Increasing delay between attempts
        sleep_time=$((2 + attempt / 5))
        sleep $sleep_time
        ((attempt++))
    done
    
    print_error "Bot failed to become operational after $max_attempts attempts"
    print_message "Last logs:" "$YELLOW"
    docker logs $container_id --tail 50
    return 1
}

# Function to show service commands
show_service_commands() {
    print_message "\nService management commands:" "$YELLOW"
    print_message "Start service: sudo systemctl start $SYSTEM_NAME.service" "$GREEN"
    print_message "Stop service: sudo systemctl stop $SYSTEM_NAME.service" "$GREEN"
    print_message "Restart service: sudo systemctl restart $SYSTEM_NAME.service" "$GREEN"
    print_message "Check status: sudo systemctl status $SYSTEM_NAME.service" "$GREEN"
    print_message "View logs: sudo journalctl -u $SYSTEM_NAME.service -f" "$GREEN"
}

# Function to wait for Docker to start
wait_for_docker() {
    local max_attempts=30
    local attempts=0
    
    while ! docker info >/dev/null 2>&1 && [ $attempts -lt $max_attempts ]; do
        print_message "Waiting for Docker to start... ($((attempts + 1))/$max_attempts)" "$YELLOW"
        sleep 2
        ((attempts++))
    done
    
    if [ $attempts -eq $max_attempts ]; then
        return 1
    fi
    return 0
}

# Function to start Docker on macOS
start_docker_macos() {
    print_message "Attempting to start Docker Desktop..." "$YELLOW"
    if open -a Docker; then
        print_message "Docker Desktop is starting. Please wait..." "$GREEN"
        if wait_for_docker; then
            return 0
        else
            print_error "Failed to start Docker daemon. Please start Docker Desktop manually."
            print_message "You can start Docker Desktop from Applications or run: open -a Docker" "$YELLOW"
            return 1
        fi
    else
        print_error "Failed to start Docker Desktop."
        print_message "Please start Docker Desktop manually from Applications or run: open -a Docker" "$YELLOW"
        return 1
    fi
}

# Function to start Docker on Linux
start_docker_linux() {
    print_message "Attempting to start Docker service..." "$YELLOW"
    if command -v systemctl >/dev/null 2>&1; then
        if sudo systemctl start docker; then
            print_message "Docker service is starting. Please wait..." "$GREEN"
            if wait_for_docker; then
                return 0
            else
                print_error "Failed to start Docker daemon. Please start Docker service manually."
                print_message "You can start Docker with: sudo systemctl start docker" "$YELLOW"
                return 1
            fi
        else
            print_error "Failed to start Docker service. Please check your permissions."
            print_message "You can try running: sudo systemctl start docker" "$YELLOW"
            return 1
        fi
    else
        print_error "Systemd is not available on this system."
        print_message "Please start Docker manually using your system's service manager." "$YELLOW"
        return 1
    fi
}

# Function to detect remote bot instances with the same token
detect_remote_bot_conflict() {
    local token="$1"
    
    if [ -z "$token" ]; then
        print_error "Cannot check for conflicts with empty token"
        return 1
    fi
    
    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        print_warning "curl is not installed. Cannot check for remote bot conflicts."
        return 0
    fi
    
    print_message "Checking for bot instances with the same token..." "$YELLOW"
    
    # First check if a local container is running with the same token
    if docker ps -q --filter "name=${SYSTEM_NAME}" | grep -q .; then
        print_message "Found a local bot instance running on this machine" "$YELLOW"
        return 2  # Special return code for local conflict
    fi
    
    # Also check if a systemd service is running
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet ${SYSTEM_NAME}.service; then
            print_message "Found a local systemd service running on this machine" "$YELLOW"
            return 2  # Special return code for local conflict
        fi
    fi
    
    # Try to get updates - if there's a conflict, this will tell us
    local response
    response=$(curl -s "https://api.telegram.org/bot$token/getUpdates")
    
    # Check if the response contains a conflict error
    if echo "$response" | grep -q '"description":"Conflict: terminated by other getUpdates request'; then
        # At this point, we know there's a conflict but not with a local container or service
        # So it must be a remote machine
        print_error "Detected conflict with another bot instance running on a different machine!"
        print_message "To resolve this:" "$YELLOW"
        print_message "1. Shut down the bot on the other machine" "$YELLOW"
        print_message "2. Wait a few minutes for Telegram servers to release the connection" "$YELLOW"
        print_message "3. Try installing this bot again" "$YELLOW"
        return 1
    fi
    
    print_message "No bot conflict detected" "$GREEN"
    return 0
}

# Function to validate BOT_TOKEN by making a test request
validate_bot_token() {
    local token="$1"
    
    if [ -z "$token" ]; then
        print_error "Cannot validate empty token"
        return 1
    fi
    
    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed. Cannot validate token."
        print_warning "Proceeding without validation, but the token may not work."
        return 0
    fi
    
    print_message "Validating token..." "$YELLOW"
    
    # Use curl to validate the token by querying Telegram's getMe API
    local response
    response=$(curl -s "https://api.telegram.org/bot$token/getMe")
    
    # Check if the response contains "ok":true indicating a valid token
    if echo "$response" | grep -q '"ok":true'; then
        print_message "Token validation successful" "$GREEN"
        
        # Also check for bot conflicts
        local conflict_status
        detect_remote_bot_conflict "$token"
        conflict_status=$?
        
        if [ $conflict_status -eq 1 ]; then
            # Remote conflict
            print_error "Token is valid but a remote conflict was detected"
            return 1
        elif [ $conflict_status -eq 2 ]; then
            # Local conflict - this is ok, we'll handle it in install-service.sh
            print_message "Token is valid but a local bot instance is already running" "$YELLOW"
            print_message "This is OK - the installation will handle it by restarting the service" "$YELLOW"
            return 0
        fi
        
        return 0
    else
        local error_description
        error_description=$(echo "$response" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
        
        if [ -z "$error_description" ]; then
            error_description="Unknown error, API response: $response"
        fi
        
        print_error "Invalid token: $error_description"
        return 1
    fi
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --token)
                local provided_token="$2"
                
                # Validate the token before saving it
                if validate_bot_token "$provided_token"; then
                    BOT_TOKEN="$provided_token"
                    
                    # Update the .env file with the new token
                    if [ -f ".env" ]; then
                        # If .env file exists, update the BOT_TOKEN line or add it if not present
                        if grep -q "BOT_TOKEN=" ".env"; then
                            # Replace the existing BOT_TOKEN line - platform-compatible approach
                            if [[ "$OSTYPE" == "darwin"* ]]; then
                                # macOS version
                                sed -i '' "s|BOT_TOKEN=.*|BOT_TOKEN=\"$BOT_TOKEN\"|" ".env"
                            else
                                # Linux version
                                sed -i "s|BOT_TOKEN=.*|BOT_TOKEN=\"$BOT_TOKEN\"|" ".env"
                            fi
                        else
                            # Add BOT_TOKEN line to .env file
                            echo "BOT_TOKEN=\"$BOT_TOKEN\"" >> ".env"
                        fi
                    else
                        # Create new .env file with BOT_TOKEN
                        echo "BOT_TOKEN=\"$BOT_TOKEN\"" > ".env"
                    fi
                    print_message "Updated BOT_TOKEN in .env file with valid token" "$GREEN"
                else
                    # If there's a remote conflict, the return value will be non-zero
                    if detect_remote_bot_conflict "$provided_token" >/dev/null; then
                        conflict_status=$?
                        if [ $conflict_status -eq 2 ]; then
                            # Local conflict - we'll handle it by updating the token and restarting
                            BOT_TOKEN="$provided_token"
                            
                            # Update the .env file with the new token
                            if [ -f ".env" ]; then
                                if grep -q "BOT_TOKEN=" ".env"; then
                                    if [[ "$OSTYPE" == "darwin"* ]]; then
                                        sed -i '' "s|BOT_TOKEN=.*|BOT_TOKEN=\"$BOT_TOKEN\"|" ".env"
                                    else
                                        sed -i "s|BOT_TOKEN=.*|BOT_TOKEN=\"$BOT_TOKEN\"|" ".env"
                                    fi
                                else
                                    echo "BOT_TOKEN=\"$BOT_TOKEN\"" >> ".env"
                                fi
                            else
                                echo "BOT_TOKEN=\"$BOT_TOKEN\"" > ".env"
                            fi
                            print_message "Updated BOT_TOKEN in .env file. Local instance will be restarted." "$YELLOW"
                        else
                            # Remote conflict or invalid token
                            print_error "The provided token is invalid and will not be saved to .env file"
                            print_message "Please provide a valid Telegram bot token" "$YELLOW"
                            return 1
                        fi
                    else
                        # Invalid token but no conflict
                        print_error "The provided token is invalid and will not be saved to .env file"
                        print_message "Please provide a valid Telegram bot token" "$YELLOW"
                        return 1
                    fi
                fi
                
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
            *)
                shift
                ;;
        esac
    done
    
    return 0
}
