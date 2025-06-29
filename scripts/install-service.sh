#!/bin/bash
# install-service.sh - Install and configure bot as a Docker Compose service
#
# This script installs the Telegram bot as a Docker Compose service.
# The bot will automatically restart on failures and system reboots (if Docker starts automatically).

set -e

# Source bootstrap (loads all modules)
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "${SCRIPT_DIR}/bootstrap.sh"

# Configuration
SYSTEM_NAME="${SYSTEM_NAME:-quit-smoking-bot}"
SYSTEM_DISPLAY_NAME="${SYSTEM_DISPLAY_NAME:-Quit Smoking Bot}"

# Display header
print_header "Installing $SYSTEM_DISPLAY_NAME with Docker Compose"

echo ""
echo "Install and configure the Telegram bot as a Docker Compose service."
echo "The bot will be managed by Docker Compose with automatic restart on failures."
echo ""

show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Install and configure the Telegram bot as a Docker Compose service."
    echo ""
    echo "Options:"
    echo "  --token TOKEN       Specify the Telegram bot token (will be saved to .env file)"
    echo "  --force-rebuild     Force rebuild of Docker container without using cache"
    echo "  --tests             Run tests after building and before installing the service"
    echo "  --monitoring        Enable health monitoring service"
    echo "  --logging           Enable log aggregation service"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --token 123456789:ABCDEF... # Install with specific token"
    echo "  $0 --monitoring                # Install with health monitoring"
    echo "  $0 --tests                     # Build, run tests, then install"
}

# Function to install Docker and Docker Compose
install_docker() {
    debug_print "Checking if Docker is installed"
    
    if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
        print_message "✅ Docker and Docker Compose are already installed" "$GREEN"
        return 0
    fi
    
    print_message "📦 Installing Docker and Docker Compose..." "$YELLOW"
    
    # Install Docker based on OS
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Install Docker Compose (standalone)
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Install Docker Compose (standalone)
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
    else
        print_error "Unsupported OS. Please install Docker and Docker Compose manually."
        return 1
    fi
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    # Start and enable Docker service for automatic startup
    sudo systemctl start docker
    sudo systemctl enable docker
    
    print_message "✅ Docker and Docker Compose installed successfully" "$GREEN"
    print_message "✅ Docker service enabled for automatic startup on boot" "$GREEN"
    print_message "ℹ️  You may need to log out and log back in for group changes to take effect" "$YELLOW"
}

# Function to setup logging
setup_logging() {
    print_message "📁 Setting up logging..." "$BLUE"
    
    # Create logs directory
    mkdir -p "$PROJECT_ROOT/logs"
    mkdir -p "$PROJECT_ROOT/data"
    
    # Ensure proper permissions
    chmod 755 "$PROJECT_ROOT/logs"
    chmod 755 "$PROJECT_ROOT/data"
    
    print_message "✅ Logging and data directories created" "$GREEN"
}

# Function to build and start services
build_and_start_services() {
    print_message "🔨 Building and starting services..." "$BLUE"
    
    cd "$PROJECT_ROOT"
    
    # Build arguments
    local build_args=""
    if [ "$FORCE_REBUILD" = true ]; then
        build_args="--no-cache"
    fi
    
    # Build services
    if ! docker-compose build $build_args; then
        print_error "Failed to build services"
        return 1
    fi
    
    # Determine which profiles to start
    local compose_profiles=""
    if [ "$ENABLE_MONITORING" = true ]; then
        compose_profiles="monitoring"
    fi
    
    if [ "$ENABLE_LOGGING" = true ]; then
        compose_profiles="${compose_profiles:+$compose_profiles,}logging"
    fi
    
    # Start services
    local compose_cmd="docker-compose"
    if [ -n "$compose_profiles" ]; then
        # Convert comma-separated profiles to multiple --profile flags
        local profile_flags=""
        IFS=',' read -ra PROFILES <<< "$compose_profiles"
        for profile in "${PROFILES[@]}"; do
            profile_flags="$profile_flags --profile $profile"
        done
        compose_cmd="docker-compose $profile_flags"
    fi
    
    if ! eval "$compose_cmd up -d"; then
        print_error "Failed to start services"
        return 1
    fi
    
    print_message "✅ Services built and started successfully" "$GREEN"
}

# Function to show service status
show_service_status() {
    print_message "📊 Service status:" "$BLUE"
    docker-compose ps
    
    print_message ""
    print_message "📋 Management commands:" "$BLUE"
    print_message "  Start:    docker-compose up -d" "$BLUE"
    print_message "  Stop:     docker-compose down" "$BLUE"
    print_message "  Restart:  docker-compose restart" "$BLUE"
    print_message "  Status:   docker-compose ps" "$BLUE"
    print_message "  Logs:     docker-compose logs -f bot" "$BLUE"
    print_message "  Update:   docker-compose pull && docker-compose up -d" "$BLUE"
    
    print_message ""
    print_message "📋 Alternative script commands:" "$BLUE"
    print_message "  Start:    ./scripts/run.sh" "$BLUE"
    print_message "  Stop:     ./scripts/stop.sh" "$BLUE"
    print_message "  Update:   ./scripts/run.sh --force-rebuild" "$BLUE"
}

# Function to cleanup existing installation
cleanup_existing_service() {
    print_section "Checking for Existing Installation"
    
    # Stop any running containers
    if docker-compose ps bot 2>/dev/null | grep -q "Up"; then
        print_message "Stopping existing bot service..." "$YELLOW"
        docker-compose down || true
    fi
}

# Wait for bot to become operational
wait_for_bot_startup() {
    debug_print "Starting wait_for_bot_startup function"
    print_message "Waiting for bot to become operational..." "$YELLOW"

    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        debug_print "Bot startup check attempt $attempt/$max_attempts"
        
        # Check if container is running
        if docker-compose ps bot | grep -q "Up"; then
            print_message "✅ Bot container is running!" "$GREEN"
            
            # Check if bot is healthy
            if docker-compose ps bot | grep -q "healthy"; then
                print_message "✅ Bot is healthy and operational!" "$GREEN"
                return 0
            fi
            
            # If not healthy yet, continue waiting
            print_message "Bot is starting up... (attempt $attempt/$max_attempts)" "$YELLOW"
        else
            print_message "Bot container is not running yet... (attempt $attempt/$max_attempts)" "$YELLOW"
        fi
        
        sleep 2
        ((attempt++))
    done
    
    print_warning "Could not confirm bot is fully operational yet, but service is installed"
    print_message "Check status with: docker-compose ps" "$YELLOW"
    return 0
}

# Main installation process
main() {
    debug_print "Starting Docker Compose service installation"
    
    # Parse arguments
    local TOKEN=""
    local FORCE_REBUILD=false
    local RUN_TESTS=false
    local ENABLE_MONITORING=false
    local ENABLE_LOGGING=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --token)
                TOKEN="$2"
                shift 2
                ;;
            --force-rebuild)
                FORCE_REBUILD=true
                shift
                ;;
            --tests)
                RUN_TESTS=true
                shift
                ;;
            --monitoring)
                ENABLE_MONITORING=true
                shift
                ;;
            --logging)
                ENABLE_LOGGING=true
                shift
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
    
    # Check prerequisites
    check_prerequisites
    
    # Save token if provided
    if [[ -n "$TOKEN" ]]; then
        print_message "💾 Saving bot token to .env file..." "$BLUE"
        update_env_token "$TOKEN"
        print_message "✅ Token saved" "$GREEN"
    fi
    
    # Cleanup existing installation
    cleanup_existing_service
    
    # Install Docker and Docker Compose
    print_section "Installing Docker"
    install_docker
    
    # Setup environment
    print_section "Setting up Environment"
    setup_logging
    
    # Run tests if requested
    if [[ "$RUN_TESTS" = true ]]; then
        print_section "Running Tests"
        print_message "Running tests..." "$BLUE"
        
        if ! docker-compose --profile test run --rm test; then
            print_error "Tests failed. Installation aborted."
            return 1
        fi
        
        print_message "✅ Tests passed successfully" "$GREEN"
    fi
    
    # Build and start services
    print_section "Building and Starting Services"
    build_and_start_services
    
    # Wait for startup
    wait_for_bot_startup
    
    # Show status
    print_section "Service Information"
    show_service_status
    
    print_success "✅ $SYSTEM_DISPLAY_NAME installed and started with Docker Compose!"
    print_message ""
    print_message "The bot is now running as a Docker Compose service with automatic restart." "$GREEN"
    print_message "Docker service is enabled - the bot will start automatically on system boot." "$GREEN"
    
    if [[ "$ENABLE_MONITORING" = true ]]; then
        print_message "✅ Health monitoring service is enabled." "$GREEN"
    fi
    
    if [[ "$ENABLE_LOGGING" = true ]]; then
        print_message "✅ Log aggregation service is enabled." "$GREEN"
    fi
    
    print_message ""
    print_message "🔄 Automatic Features:" "$BLUE"
    print_message "  • Bot will restart automatically if it crashes" "$BLUE"
    print_message "  • Bot will start automatically when Docker starts" "$BLUE"
    print_message "  • Docker starts automatically on system boot" "$BLUE"
    
    debug_print "Docker Compose service installation completed successfully"
}

# Run main function
main "$@"
