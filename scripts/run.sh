#!/bin/bash
# run.sh - Universal bot start script
#
# This script can either install and start the bot (--install) or just start it.
# Supports dry-run mode to preview actions before execution.

set -e

# Source bootstrap (loads all modules)
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/bootstrap.sh"

# Configuration
SYSTEM_NAME="${SYSTEM_NAME:-quit-smoking-bot}"
SYSTEM_DISPLAY_NAME="${SYSTEM_DISPLAY_NAME:-Quit Smoking Bot}"

show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Universal script to start the Telegram bot with optional installation."
    echo ""
    echo "Options:"
    echo "  --install           Full installation with Docker setup and auto-restart configuration"
    echo "  --token TOKEN       Specify the Telegram bot token (will be saved to .env file)"
    echo "  --monitoring        Enable health monitoring service"
    echo "  --logging           Enable log aggregation service"
    echo "  --tests             Run tests after building and before starting the bot"
    echo "  --force-rebuild     Force rebuild of Docker container without using cache"
    echo "  --dry-run           Show what would be done without executing"
    echo "  --status            Show current service status and exit"
    echo "  --quiet             Minimal output (errors only)"
    echo "  --verbose           Detailed output and debugging"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Simple start"
    echo "  $0 --status                          # Show current status"
    echo "  $0 --install --monitoring --token xyz # Full installation with monitoring"
    echo "  $0 --dry-run --install               # Preview installation steps"
    echo "  $0 --tests --force-rebuild           # Rebuild and test before starting"
}

# Install Docker and Docker Compose if needed
install_docker_if_needed() {
    if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
        print_message "✅ Docker and Docker Compose are already installed" "$GREEN"
        log_action "Docker check" "SUCCESS" "Already installed"
        return 0
    fi
    
    execute_or_simulate "Install Docker and Docker Compose" '
        if command -v apt-get &> /dev/null; then
            # Ubuntu/Debian
            sudo apt-get update
            sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
            
            # Add Docker GPG key
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
        
        # Start and enable Docker service
        sudo systemctl start docker
        sudo systemctl enable docker
    '
    
    if ! is_dry_run; then
        print_message "✅ Docker and Docker Compose installed successfully" "$GREEN"
        print_message "✅ Docker service enabled for automatic startup on boot" "$GREEN"
        print_message "ℹ️  You may need to log out and log back in for group changes to take effect" "$YELLOW"
    fi
}

# Setup data directories and permissions
setup_data_directories() {
    execute_or_simulate "Create data and logs directories" '
        mkdir -p "$PROJECT_ROOT/logs"
        mkdir -p "$PROJECT_ROOT/data"
        # Use centralized permission setup
        if [ -f "$PROJECT_ROOT/scripts/setup-permissions.sh" ]; then
            bash "$PROJECT_ROOT/scripts/setup-permissions.sh"
        else
            chmod 755 "$PROJECT_ROOT/logs"
            chmod 755 "$PROJECT_ROOT/data"
        fi
    '
}

# Build and start services with proper profiles
build_and_start_services() {
    local build_args=""
    if [[ "$FORCE_REBUILD" == "1" ]]; then
        build_args="--no-cache"
    fi
    
    # Stop existing containers first
    execute_or_simulate "Stop existing containers" 'docker-compose down --remove-orphans 2>/dev/null || true'
    
    # Build containers
    execute_or_simulate "Build Docker containers" "docker-compose build $build_args"
    
    # Run tests if requested
    if [[ "$RUN_TESTS" == "1" ]]; then
        execute_or_simulate "Run tests" 'docker-compose --profile test run --rm test'
    fi
    
    # Determine compose profiles
    local compose_profiles=""
    if [[ "$ENABLE_MONITORING" == "1" ]]; then
        compose_profiles="monitoring"
    fi
    if [[ "$ENABLE_LOGGING" == "1" ]]; then
        compose_profiles="${compose_profiles:+$compose_profiles,}logging"
    fi
    
    # Start services
    local compose_cmd="docker-compose"
    if [[ -n "$compose_profiles" ]]; then
        local profile_flags=""
        IFS=',' read -ra PROFILES <<< "$compose_profiles"
        for profile in "${PROFILES[@]}"; do
            profile_flags="$profile_flags --profile $profile"
        done
        compose_cmd="docker-compose $profile_flags"
    fi
    
    execute_or_simulate "Start bot services" "$compose_cmd up -d"
}

# Wait for bot to become healthy
wait_for_bot_health() {
    if is_dry_run; then
        print_message "🔍 [DRY-RUN] Would wait for bot to become healthy" "$YELLOW"
        return 0
    fi
    
    print_message "Waiting for bot to become healthy..." "$YELLOW"
    
    local attempts=0
    local max_attempts=12
    while [[ $attempts -lt $max_attempts ]]; do
        if docker-compose ps bot | grep -q "healthy"; then
            print_message "✅ Bot is healthy and operational" "$GREEN"
            log_action "Bot health check" "SUCCESS" "Bot is healthy"
            return 0
        fi
        attempts=$((attempts + 1))
        if [[ $attempts -eq $max_attempts ]]; then
            print_message "⚠️  Bot health check timeout, but container is running" "$YELLOW"
            log_action "Bot health check" "WARNING" "Health check timeout"
            return 0
        fi
        sleep 5
    done
}

# Show final status and management commands
show_final_status() {
    if is_dry_run; then
        return 0
    fi
    
    print_message "\n📊 Service Status:" "$BLUE"
    docker-compose ps
    
    print_message "\n🎉 Bot operation completed! 🎉" "$GREEN"
    print_message "========================================" "$GREEN"
    
    if [[ "$INSTALL_MODE" == "1" ]]; then
        print_message "✅ Bot installed and started with auto-restart" "$GREEN"
        print_message "✅ Docker service enabled for automatic startup" "$GREEN"
        if [[ "$ENABLE_MONITORING" == "1" ]]; then
            print_message "✅ Health monitoring enabled" "$GREEN"
        fi
        if [[ "$ENABLE_LOGGING" == "1" ]]; then
            print_message "✅ Log aggregation enabled" "$GREEN"
        fi
    else
        print_message "✅ Bot started successfully" "$GREEN"
    fi
    
    print_message "\n📋 Management commands:" "$BLUE"
    print_message "  View logs:    docker-compose logs -f bot" "$BLUE"
    print_message "  Stop bot:     ./scripts/stop.sh" "$BLUE"
    print_message "  Restart:      docker-compose restart bot" "$BLUE"
    print_message "  Status:       ./scripts/run.sh --status" "$BLUE"
    print_message "========================================" "$GREEN"
}

# Main function
main() {
    debug_print "Starting universal run script with arguments: $@"
    
    # Initialize default variables
    local INSTALL_MODE=0
    local TOKEN=""
    local ENABLE_MONITORING=0
    local ENABLE_LOGGING=0
    local RUN_TESTS=0
    local FORCE_REBUILD=0
    local DRY_RUN=0
    local SHOW_STATUS=0
    local QUIET=0
    local VERBOSE=0
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install)
                INSTALL_MODE=1
                shift
                ;;
            --token)
                TOKEN="$2"
                shift 2
                ;;
            --monitoring)
                ENABLE_MONITORING=1
                shift
                ;;
            --logging)
                ENABLE_LOGGING=1
                shift
                ;;
            --tests)
                RUN_TESTS=1
                shift
                ;;
            --force-rebuild)
                FORCE_REBUILD=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --status)
                SHOW_STATUS=1
                shift
                ;;
            --quiet)
                QUIET=1
                shift
                ;;
            --verbose)
                VERBOSE=1
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
    
    # Export variables for use in functions
    export INSTALL_MODE TOKEN ENABLE_MONITORING ENABLE_LOGGING RUN_TESTS FORCE_REBUILD DRY_RUN QUIET VERBOSE
    
    # Initialize action logging
    init_action_log
    log_action "Script start" "INFO" "Arguments: $*"
    
    # Handle status request
    if [[ "$SHOW_STATUS" == "1" ]]; then
        show_service_status
        show_install_status
        exit 0
    fi
    
    # Show dry run plan if requested
    if [[ "$DRY_RUN" == "1" ]]; then
        if [[ "$INSTALL_MODE" == "1" ]]; then
            show_dry_run_plan "install"
        else
            show_dry_run_plan "start"
        fi
        echo ""
    fi
    
    # Show header
    if [[ "$INSTALL_MODE" == "1" ]]; then
        print_header "Installing and Starting $SYSTEM_DISPLAY_NAME"
    else
        print_header "Starting $SYSTEM_DISPLAY_NAME"
    fi
    
    # Save token if provided
    if [[ -n "$TOKEN" ]]; then
        execute_or_simulate "Save bot token to .env file" "update_env_token '$TOKEN'"
        export BOT_TOKEN="$TOKEN"
    fi
    
    # Check prerequisites
    execute_or_simulate "Check prerequisites" "check_prerequisites"
    
    # Install Docker if in install mode
    if [[ "$INSTALL_MODE" == "1" ]]; then
        install_docker_if_needed
    fi
    
    # Check for bot conflicts
    if [[ -n "$BOT_TOKEN" ]] && ! is_dry_run; then
        debug_print "Checking for bot conflicts"
        check_bot_conflicts "$BOT_TOKEN" 0
        if [[ $? -eq 1 ]]; then
            print_error "Cannot proceed due to remote conflict with another bot instance."
            print_message "Please stop the other bot instance before continuing." "$YELLOW"
            exit 1
        fi
    fi
    
    # Setup data directories
    setup_data_directories
    
    # Build and start services
    build_and_start_services
    
    # Wait for bot to become healthy
    wait_for_bot_health
    
    # Show final status
    show_final_status
    
    log_action "Script completion" "SUCCESS" "Bot operation completed successfully"
    
    # Follow logs if not in quiet mode and not dry run
    if [[ "$QUIET" != "1" && "$DRY_RUN" != "1" ]]; then
        print_message "\nPress Ctrl+C to detach from logs (bot will continue running)." "$GREEN"
        trap 'print_message "\nDetaching from logs..." "$GREEN"; exit 0' INT
        docker-compose logs -f --no-color bot 2>/dev/null || true
    fi
}

# Execute main function
main "$@"
exit $?


# ПОПРАВИТЬ, ЗАПУСТИЛ ЛОКАЛЬНО НА MACOS когда на сервере тоже было запущено
# ./scripts/run.sh --token YOUR_BOT_TOKEN_HERE
# Updated BOT_TOKEN in .env
# Checking for conflicts with the same bot token...
# Checking if bot is running locally...
# Waiting longer for existing connections to clear (attempt 2)...
