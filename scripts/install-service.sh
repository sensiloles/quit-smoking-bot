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

# Build the bot image first
print_message "Building bot image..." "$YELLOW"
if ! docker-compose build bot; then
    print_error "Failed to build bot image"
    exit 1
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
if ! is_bot_operational; then
    print_error "Bot failed to become operational"
    cleanup_docker bot 1
    systemctl stop ${SYSTEM_NAME}.service
    exit 1
fi

print_message "Service installed and started successfully!" "$GREEN"
show_service_commands 
