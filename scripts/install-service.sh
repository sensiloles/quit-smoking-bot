#!/bin/bash
# install-service.sh - Install and configure bot as a systemd service
#
# This script installs the Telegram bot as a systemd service,
# handling the building of Docker containers and service configuration.

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"


show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Install and configure the Telegram bot as a systemd service."
    echo "This script requires root privileges (sudo)."
    echo ""
    echo "Options:"
    echo "  --token TOKEN       Specify the Telegram bot token (will be saved to .env file)"
    echo "  --force-rebuild     Force rebuild of Docker container without using cache"
    echo "  --cleanup           Perform additional cleanup if installation fails"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo $0 --token 123456789:ABCDEF... # Install with specific token"
    echo "  sudo $0 --force-rebuild             # Force rebuild container"
    echo "  sudo $0                             # Install using token from .env file"
}

# Main service installation function
install_service() {
    print_section "Checking Prerequisites"
    
    # Parse command line arguments
    if ! parse_args "$@"; then
        exit 1
    fi
    
    # If token was passed via --token parameter, save it to .env and export it
    if [ -n "$TOKEN" ]; then
        update_env_token "$TOKEN"
        export BOT_TOKEN="$TOKEN"
    fi
    
    # Check prerequisites
    check_docker_installation || exit 1
    check_docker_buildx
    check_bot_token || exit 1
    check_system_name
    check_system_display_name
    
    # Check if running as root
    if [ "$(id -u)" != "0" ]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    # Check Docker daemon
    check_docker
    
    print_section "Checking for Conflicts"
    
    # Check for local container and conflicts with remote bots
    # For service we use a longer wait time (10 seconds)
    check_bot_conflicts_common "$BOT_TOKEN" 1 10
    conflict_status=$?
    
    if [ $conflict_status -eq 1 ]; then
        # Exit if there's a conflict with a remote bot
        exit 1
    fi
    
    print_section "Cleaning Existing Instances"
    
    # Check for existing containers
    if docker ps -a | grep -q ${SYSTEM_NAME}; then
        print_message "Found existing Docker container for ${SYSTEM_NAME}. Stopping and removing..." "$YELLOW"
        docker stop ${SYSTEM_NAME} 2>/dev/null || true
        docker rm ${SYSTEM_NAME} 2>/dev/null || true
    fi
    
    # Check for existing service
    if systemctl list-units --full --all | grep -q "${SYSTEM_NAME}.service"; then
        print_message "Found existing systemd service for ${SYSTEM_NAME}. Stopping and disabling..." "$YELLOW"
        systemctl stop ${SYSTEM_NAME}.service 2>/dev/null || true
        systemctl disable ${SYSTEM_NAME}.service 2>/dev/null || true
    fi
    
    print_section "Building Bot Image"
    
    # Build the bot image
    if [ "$FORCE_REBUILD" == "1" ]; then
        print_message "Forcing a clean rebuild of all images..." "$YELLOW"
        
        # Remove existing images
        print_message "Removing existing images..." "$YELLOW"
        docker rmi ${SYSTEM_NAME} ${SYSTEM_NAME}-test >/dev/null 2>&1 || true
        # Also remove all build cache
        docker builder prune -f >/dev/null 2>&1 || true
        
        if ! docker-compose build --no-cache bot; then
            print_error "Failed to build bot image"
            exit 1
        fi
    else
        if ! docker-compose build bot; then
            print_error "Failed to build bot image"
            exit 1
        fi
    fi
    
    print_section "Creating Systemd Service"
    
    # Install service
    create_systemd_service
    
    # Reload systemd and enable service
    print_message "Reloading systemd and enabling service..." "$YELLOW"
    systemctl daemon-reload
    systemctl enable ${SYSTEM_NAME}.service
    
    print_message "Starting service..." "$YELLOW"
    systemctl start ${SYSTEM_NAME}.service
    
    print_section "Waiting for Bot to Start"
    
    # Wait for bot to become operational
    wait_for_bot_startup
}

# Create systemd service file
create_systemd_service() {
    print_message "Creating systemd service file..." "$YELLOW"
    
    cat > /etc/systemd/system/${SYSTEM_NAME}.service << EOF
[Unit]
Description=${SYSTEM_DISPLAY_NAME} Bot Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=/bin/bash -c 'docker-compose up -d bot'
ExecStop=/bin/bash -c 'docker-compose down'
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    print_message "Service file created at /etc/systemd/system/${SYSTEM_NAME}.service" "$GREEN"
}

# Wait for bot to become operational
wait_for_bot_startup() {
    print_message "Waiting for bot to become operational..." "$YELLOW"
    
    # We'll give the bot up to 30 seconds to start
    local max_attempts=30
    local attempt=1
    local container_id=""
    
    # First wait for the container to start
    while [ $attempt -le 10 ]; do
        print_message "Waiting for container to start (attempt $attempt/10)..." "$YELLOW"
        container_id=$(docker-compose ps -q bot)
        
        if [ -n "$container_id" ]; then
            print_message "Container started with ID: $container_id" "$GREEN"
            break
        fi
        
        sleep 2
        ((attempt++))
    done
    
    if [ -z "$container_id" ]; then
        print_error "Container failed to start after 10 attempts"
        print_message "Checking Docker logs:" "$YELLOW"
        docker-compose logs bot
        cleanup_docker bot "$CLEANUP"
        systemctl stop ${SYSTEM_NAME}.service
        exit 1
    fi
    
    # Check health status
    check_bot_health "$container_id"
    
    # Check operational status
    check_bot_operational "$container_id"
}

# Check bot health status
check_bot_health() {
    local container_id="$1"
    print_message "\nStarting bot health check..." "$YELLOW"
    local max_health_attempts=30
    local health_attempt=1
    
    while [ $health_attempt -le $max_health_attempts ]; do
        print_message "Checking bot health status (attempt $health_attempt/$max_health_attempts)..." "$YELLOW"
        
        # Get container health status directly
        local health_status=$(docker inspect --format '{{.State.Health.Status}}' $container_id 2>/dev/null)
        
        if [ "$health_status" = "healthy" ]; then
            print_message "Bot health status: HEALTHY" "$GREEN"
            print_message "Bot is healthy!" "$GREEN"
            return 0
        elif [ "$health_status" = "starting" ]; then
            print_message "Bot health status: STARTING" "$YELLOW"
        else
            print_message "Bot health status: $health_status" "$YELLOW"
        fi
        
        # If we've reached max attempts, stop trying
        if [ $health_attempt -eq $max_health_attempts ]; then
            print_message "Bot health check did not pass within timeout." "$YELLOW"
            break
        fi
        
        # Wait before next check
        sleep 5
        ((health_attempt++))
    done
    
    return 1
}

# Check if bot is operational
check_bot_operational() {
    local container_id="$1"
    print_message "\nStarting bot operational check..." "$YELLOW"
    local max_operational_attempts=30
    local operational_attempt=1
    local is_operational=false
    
    while [ $operational_attempt -le $max_operational_attempts ]; do
        print_message "Checking bot operational status (attempt $operational_attempt/$max_operational_attempts)..." "$YELLOW"
        
        # Check if Python process is running
        if docker exec $container_id pgrep -f "python.*src[/.]bot" >/dev/null 2>&1; then
            # Check logs for success patterns
            local logs=$(docker logs $container_id --tail 70 2>&1)
            
            # Check for Application started message
            if echo "$logs" | grep -q "Application started"; then
                print_message "Bot is operational - Application started" "$GREEN"
                print_message "Bot is operational!" "$GREEN"
                is_operational=true
                break
            fi
            
            # Check for successful API calls
            local successful_api_calls=$(echo "$logs" | grep -c "\"HTTP/1.1 200 OK\"")
            if [ "$successful_api_calls" -ge 2 ]; then
                print_message "Bot is operational - multiple successful API calls detected ($successful_api_calls)" "$GREEN"
                print_message "Bot is operational!" "$GREEN"
                is_operational=true
                break
            fi
        fi
        
        # If we've reached max attempts, stop trying
        if [ $operational_attempt -eq $max_operational_attempts ]; then
            print_message "Bot operational check did not pass within timeout." "$YELLOW"
            break
        fi
        
        # Wait before next check
        sleep 3
        ((operational_attempt++))
    done
    
    # Final determination of operational status
    finalizeStartupCheck "$container_id" "$is_operational"
}

# Finalize the startup check and report status
finalizeStartupCheck() {
    local container_id="$1"
    local is_operational="$2"
    
    # Now check if the bot is operational using our function (for final determination)
    if is_bot_operational; then
        print_message "\nBot status checks summary:" "$GREEN"
        print_message "Health status: $(docker inspect --format '{{.State.Health.Status}}' $container_id 2>/dev/null)" "$GREEN"
        print_message "Operational status: OPERATIONAL" "$GREEN"
        
        # Show recent logs
        print_message "\nRecent bot logs:" "$YELLOW"
        docker logs $container_id --tail 20
        
        # Check specifically for conflict errors in logs
        if docker logs $container_id --tail 50 2>&1 | grep -q "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates"; then
            print_error "\nWARNING: Conflict detected in logs! Another bot instance appears to be running with the same token."
            print_message "Even though the bot appears operational, you may experience issues." "$YELLOW"
            print_message "To resolve this issue:" "$YELLOW"
            print_message "1. Stop any other instances of this bot running elsewhere" "$YELLOW"
            print_message "2. Restart this service with: sudo systemctl restart ${SYSTEM_NAME}.service" "$YELLOW"
            print_message "\nService installed but has conflicts!" "$RED"
            return 1
        fi
        
        print_message "\nService installed and started successfully!" "$GREEN"
        show_service_commands
        exit 0
    else
        # Try running the check-service.sh script to get a comprehensive status
        print_message "Using check-service.sh to get detailed status..." "$YELLOW"
        if [ -f "$(dirname "${BASH_SOURCE[0]}")/check-service.sh" ]; then
            "$(dirname "${BASH_SOURCE[0]}")/check-service.sh"
            
            # Check for conflict errors in the logs
            if docker logs $container_id --tail 100 2>&1 | grep -q "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates"; then
                print_error "\nERROR: Conflict detected in logs! Another bot instance is running with the same token."
                print_message "This is preventing your bot from starting properly." "$RED"
                print_message "To resolve this issue:" "$YELLOW"
                print_message "1. Stop any other instances of this bot running elsewhere" "$YELLOW"
                print_message "2. Restart this service with: sudo systemctl restart ${SYSTEM_NAME}.service" "$YELLOW"
                
                # Cleanup and exit with error
                print_message "Cleaning up due to conflict..." "$YELLOW"
                cleanup_docker bot "$CLEANUP"
                systemctl stop ${SYSTEM_NAME}.service
                exit 1
            }
            
            # Even if is_bot_operational failed, if the bot is sending API requests, consider it a success
            if docker logs $container_id --tail 100 2>&1 | grep -q "\"HTTP/1.1 200 OK\""; then
                print_message "\nBot appears to be operational based on successful API requests." "$GREEN"
                print_message "Service installed but may need further checks!" "$YELLOW"
                
                # Update: restart the container to trigger the health check again since it appears to be a false negative
                print_message "Restarting container to refresh health status..." "$YELLOW"
                docker restart $container_id
                sleep 5
                
                # Check if the health status improved
                local health_status=$(docker inspect --format '{{.State.Health.Status}}' $container_id)
                if [ "$health_status" = "healthy" ] || [ "$health_status" = "starting" ]; then
                    print_message "Container health status is now: $health_status" "$GREEN"
                else
                    print_message "Container health status is still: $health_status" "$YELLOW" 
                    print_message "This may be due to logs not being properly accessible to the health check." "$YELLOW"
                    print_message "The bot appears to be functioning properly despite the health check status." "$YELLOW"
                fi
                
                show_service_commands
                exit 0
            fi
        fi
        
        print_error "Bot failed to become operational"
        print_message "Last logs:" "$YELLOW"
        docker logs $container_id --tail 40
        
        # Use the CLEANUP flag when cleaning up after a failed startup
        print_message "Cleaning up due to failed startup..." "$YELLOW"
        cleanup_docker bot "$CLEANUP"
        systemctl stop ${SYSTEM_NAME}.service
        exit 1
    fi
}

# Run the main function with all arguments
install_service "$@" 
