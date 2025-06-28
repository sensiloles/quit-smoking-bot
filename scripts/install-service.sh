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
    echo "  --tests             Run tests after building and before installing the service. If tests fail, installation stops."
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo $0 --token 123456789:ABCDEF... # Install with specific token"
    echo "  sudo $0 --force-rebuild             # Force rebuild container"
    echo "  sudo $0 --tests                     # Build, run tests, then install"
    echo "  sudo $0                             # Install using token from .env file"
}

# Create systemd service file
create_systemd_service() {
    if [[ "$(uname)" != "Linux" ]]; then
        print_warning "Systemd service creation is skipped on non-Linux systems."
        return 0
    fi
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
        if [[ "$(uname)" == "Linux" ]]; then
             systemctl stop ${SYSTEM_NAME}.service
        fi
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
        print_message "Checking bot health (attempt $health_attempt/$max_health_attempts)..." "$YELLOW"

        # Get container health status
        local health_status=$(docker inspect --format '{{.State.Health.Status}}' "$container_id" 2>/dev/null)

        if [ "$health_status" = "healthy" ]; then
            print_message "Bot health check passed!" "$GREEN"
            return 0
        fi

        sleep 5
        ((health_attempt++))
    done

    print_warning "Bot health check did not pass within timeout, but service might still be operational"
    return 0
}

# Check if bot is operational
check_bot_operational() {
    local container_id="$1"
    print_message "\nChecking if bot is operational..." "$YELLOW"
    local max_op_attempts=5
    local op_attempt=1

    while [ $op_attempt -le $max_op_attempts ]; do
        print_message "Operational check (attempt $op_attempt/$max_op_attempts)..." "$YELLOW"

        # Check if Python process is running
        if docker exec "$container_id" pgrep -f "python.*src[/.]bot" >/dev/null 2>&1; then
            print_message "Bot process is running inside container" "$GREEN"

            # Check logs for operational indicators
            logs=$(docker logs "$container_id" --tail 50 2>&1)
            if echo "$logs" | grep -q "Application started"; then
                print_message "Bot is fully operational!" "$GREEN"

                # Check for conflict errors
                if echo "$logs" | grep -q "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates"; then
                    print_warning "Warning: Detected conflict with another bot instance using the same token"
                    print_message "You may need to stop the other bot instance for this one to function properly." "$YELLOW"
                fi

                return 0
            fi
        fi

        sleep 2
        ((op_attempt++))
    done

    print_warning "Could not confirm bot is fully operational yet, but service is installed"
    print_message "Check status later with: systemctl status ${SYSTEM_NAME}.service" "$YELLOW"
    return 0
}

# Main service installation function
install_service() {
    print_section "Checking Prerequisites"

    # Parse command line arguments using common function
    parse_args "$@"

    # If token was passed via --token parameter, save it to .env and export it
    if [ -n "$TOKEN" ]; then
        update_env_token "$TOKEN"
        export BOT_TOKEN="$TOKEN"
    fi

    # Check prerequisites
    check_prerequisites || exit 1
    check_system_display_name

    # Check if running as root
    check_root

    # Check if OS is Linux before proceeding with service-specific steps
    if [[ "$(uname)" != "Linux" ]]; then
        print_warning "Systemd service installation is only supported on Linux."
        print_message "Building image and running tests (if requested), but skipping service setup." "$YELLOW"
        # Set a flag or modify logic if needed based on this warning
    fi

    print_section "Checking for Conflicts"

    # Check for local container and conflicts with remote bots
    # For service we use a longer wait time (10 seconds)
    check_bot_conflicts "$BOT_TOKEN" 1 5
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
    if [[ "$(uname)" == "Linux" ]]; then
        if systemctl list-units --full --all | grep -q "${SYSTEM_NAME}.service"; then
            print_message "Found existing systemd service for ${SYSTEM_NAME}. Stopping and disabling..." "$YELLOW"
            systemctl stop ${SYSTEM_NAME}.service 2>/dev/null || true
            systemctl disable ${SYSTEM_NAME}.service 2>/dev/null || true
        fi
    fi

    # Setup data directories with proper permissions
    setup_data_directories

    print_section "Building Bot Image"

    # Build the bot image
    if [ "$FORCE_REBUILD" == "1" ]; then
        print_message "Forcing a clean rebuild of all images..." "$YELLOW"

        # Remove existing images
        print_message "Removing existing images..." "$YELLOW"
        docker rmi ${SYSTEM_NAME} ${SYSTEM_NAME}-test >/dev/null 2>&1 || true
        # Also remove all build cache
        docker builder prune -f >/dev/null 2>&1 || true

        if ! execute_docker_compose "build" "bot" "--no-cache"; then
            print_error "Failed to build bot image"
            exit 1
        fi
    else
        if ! execute_docker_compose "build" "bot"; then
            print_error "Failed to build bot image"
            exit 1
        fi
    fi

    # Run tests if requested before installing the service
    if [ "$RUN_TESTS" -eq 1 ]; then
        if ! run_tests_in_docker; then
            print_error "Tests failed. Service installation aborted."
            # Optional: Clean up build artifacts if tests fail?
            # cleanup_docker bot $CLEANUP
            exit 1
        fi
        print_message "Tests passed. Proceeding with service installation." "$GREEN"
    fi

    print_section "Creating Systemd Service"

    # Install service
    if [[ "$(uname)" == "Linux" ]]; then
        create_systemd_service
    else
        print_warning "Skipping systemd service creation on non-Linux OS."
    fi

    # Reload systemd and enable service
    if [[ "$(uname)" == "Linux" ]]; then
        print_message "Reloading systemd and enabling service..." "$YELLOW"
        systemctl daemon-reload
        systemctl enable ${SYSTEM_NAME}.service
    fi

    print_message "Starting service..." "$YELLOW"
    # Start using docker-compose directly, as systemd won't manage it on non-Linux
    # We already built the image, now just bring it up.
    if ! execute_docker_compose "up" "bot" "-d"; then
        print_error "Failed to start bot container using docker-compose."
        exit 1
    fi

    print_section "Waiting for Bot to Start"

    # Wait for bot to become operational
    wait_for_bot_startup
}

# Main execution
install_service "$@"
exit $?
