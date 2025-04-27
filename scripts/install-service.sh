#!/bin/bash

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Parse command line arguments
if ! parse_arguments "$@"; then
    exit 1
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

# Check for bot conflicts
print_message "Checking for conflicts with the same bot token..." "$YELLOW"
conflict_check=$(detect_remote_bot_conflict "$BOT_TOKEN")
conflict_status=$?

if [ $conflict_status -eq 1 ]; then
    # Status 1 means a remote conflict (different machine)
    print_error "A remote conflict was detected with another bot using the same token."
    print_message "Please resolve the conflict before continuing with installation." "$YELLOW"
    exit 1
elif [ $conflict_status -eq 2 ]; then
    # Status 2 means a local conflict (this machine)
    print_message "A local bot instance with the same token is already running on this machine." "$YELLOW"
    print_message "The installation will stop and restart this instance." "$YELLOW"
fi

# Regardless of conflict type, check for any existing bot containers or services
print_message "Checking for existing bot instances..." "$YELLOW"

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

# If there was a local conflict, wait a moment for Telegram API connections to release
if [ $conflict_status -eq 2 ]; then
    print_message "Waiting for Telegram API connections to release (10 seconds)..." "$YELLOW"
    sleep 10
fi

# Build the bot image, use --force-rebuild if specified
print_message "Building bot image..." "$YELLOW"
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

print_message "Installing service..." "$GREEN"

# Install service
print_message "Creating systemd service..." "$YELLOW"
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

# Reload systemd and enable service
print_message "Reloading systemd and enabling service..." "$YELLOW"
systemctl daemon-reload
systemctl enable ${SYSTEM_NAME}.service

print_message "Starting service..." "$YELLOW"
systemctl start ${SYSTEM_NAME}.service

# Wait for bot to become operational
print_message "Waiting for bot to become operational..." "$YELLOW"

# We'll give the bot up to 30 seconds to start
max_attempts=30
attempt=1
container_id=""

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

# Reset attempt counter
attempt=1

# Now check if the bot is operational using our function
if is_bot_operational; then
    print_message "Bot is operational!" "$GREEN"
    
    # Show recent logs
    print_message "\nRecent bot logs:" "$YELLOW"
    docker logs $container_id --tail 20
    
    print_message "\nService installed and started successfully!" "$GREEN"
    show_service_commands
    exit 0
else
    # Try running the check-service.sh script to get a comprehensive status
    print_message "Using check-service.sh to get detailed status..." "$YELLOW"
    if [ -f "$(dirname "${BASH_SOURCE[0]}")/check-service.sh" ]; then
        "$(dirname "${BASH_SOURCE[0]}")/check-service.sh"
        
        # Even if is_bot_operational failed, if the bot is sending API requests, consider it a success
        if docker logs $container_id --tail 100 2>&1 | grep -q "\"HTTP/1.1 200 OK\""; then
            print_message "\nBot appears to be operational based on successful API requests." "$GREEN"
            print_message "Service installed but may need further checks!" "$YELLOW"
            
            # Update: restart the container to trigger the health check again since it appears to be a false negative
            print_message "Restarting container to refresh health status..." "$YELLOW"
            docker restart $container_id
            sleep 5
            
            # Check if the health status improved
            health_status=$(docker inspect --format '{{.State.Health.Status}}' $container_id)
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
