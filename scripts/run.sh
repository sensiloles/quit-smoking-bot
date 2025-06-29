#!/bin/bash
set -e

# Source bootstrap (loads all modules)
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/bootstrap.sh"

show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Start the Telegram bot using Docker Compose (no supervisor)."
    echo ""
    echo "Options:"
    echo "  --token TOKEN       Specify the Telegram bot token (will be saved to .env file)"
    echo "  --force-rebuild     Force rebuild of Docker container without using cache"
    echo "  --cleanup           Perform additional cleanup before starting"
    echo "  --tests             Run tests after building and before starting the bot"
    echo "  --monitoring        Enable health monitoring service"
    echo "  --logging           Enable log aggregation service"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --token 123456789:ABCDEF... # Start with specific token"
    echo "  $0 --force-rebuild             # Force rebuild container"
    echo "  $0 --tests --monitoring        # Build, test, start with monitoring"
    echo "  $0                             # Start using token from .env file"
}

# Main function
main() {
    debug_print "Starting main function with arguments: $@"
    
    # Parse command line arguments
    debug_print "Parsing command line arguments"
    parse_args "$@"
    debug_print "Arguments parsed successfully"

    # Set up profiles for docker-compose
    local compose_profiles=""
    if [ "$RUN_TESTS" -eq 1 ]; then
        compose_profiles="test"
    fi
    
    # Check for additional services
    local enable_monitoring=0
    local enable_logging=0
    
    for arg in "$@"; do
        case $arg in
            --monitoring)
                enable_monitoring=1
                ;;
            --logging)
                enable_logging=1
                ;;
        esac
    done
    
    if [ $enable_monitoring -eq 1 ]; then
        compose_profiles="${compose_profiles:+$compose_profiles,}monitoring"
    fi
    
    if [ $enable_logging -eq 1 ]; then
        compose_profiles="${compose_profiles:+$compose_profiles,}logging"
    fi

    # If token was passed via --token parameter, save it to .env and export it
    if [ -n "$TOKEN" ]; then
        debug_print "Token provided via --token parameter, updating .env file"
        update_env_token "$TOKEN"
        export BOT_TOKEN="$TOKEN"
        debug_print "Token updated and exported"
    fi

    # Check prerequisites
    debug_print "Checking prerequisites"
    check_prerequisites || return 1
    debug_print "Prerequisites check passed"

    # Check for conflicts with remote bots
    debug_print "Checking for bot conflicts"
    check_bot_conflicts "$BOT_TOKEN" 0
    conflict_status=$?
    debug_print "Bot conflicts check completed with status: $conflict_status"

    if [ $conflict_status -eq 1 ]; then
        debug_print "Remote conflict detected, stopping execution"
        print_error "Cannot proceed due to remote conflict with another bot instance."
        print_message "Please stop the other bot instance before continuing." "$YELLOW"
        return 1
    fi

    # Stop any existing containers
    debug_print "Stopping any existing containers"
    print_message "Stopping existing containers..." "$YELLOW"
    docker-compose down --remove-orphans 2>/dev/null || true
    debug_print "Existing containers stopped"

    # Setup data directories with proper permissions
    debug_print "Setting up data directories"
    setup_data_directories
    debug_print "Data directories setup completed"

    # Build containers
    print_message "Building containers..." "$BLUE"
    local build_args=""
    if [ "$FORCE_REBUILD" -eq 1 ]; then
        build_args="--no-cache"
        debug_print "Force rebuild requested"
    fi
    
    if ! docker-compose build $build_args; then
        print_error "Failed to build containers"
        return 1
    fi
    
    print_message "✅ Containers built successfully" "$GREEN"

    # Run tests if requested
    if [ "$RUN_TESTS" -eq 1 ]; then
        debug_print "Running tests"
        print_message "Running tests..." "$BLUE"
        
        if ! docker-compose --profile test run --rm test; then
            debug_print "Tests failed"
            print_error "Tests failed. Bot will not be started."
            return 1
        fi
        
        print_message "✅ Tests passed successfully" "$GREEN"
        debug_print "Tests passed successfully"
    fi

    # Start services
    print_message "Starting bot services..." "$GREEN"
    
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
    
    debug_print "Starting services with command: $compose_cmd up -d"
    
    if ! eval "$compose_cmd up -d"; then
        print_error "Failed to start services"
        docker-compose logs --tail 20 bot
        return 1
    fi

    # Wait a moment for services to start
    sleep 3

    # Verify bot container is running
    debug_print "Verifying bot container status"
    if ! docker-compose ps bot | grep -q "Up"; then
        print_error "Bot container failed to start!"
        print_message "Container status:" "$YELLOW"
        docker-compose ps bot
        print_message "Recent logs:" "$YELLOW"
        docker-compose logs --tail 30 bot
        return 1
    fi

    print_message "✅ Container verification passed - bot is running." "$GREEN"

    # Check if bot is healthy and operational
    debug_print "Checking bot health"
    print_message "Waiting for bot to become healthy..." "$YELLOW"
    
    local attempts=0
    local max_attempts=12
    while [ $attempts -lt $max_attempts ]; do
        if docker-compose ps bot | grep -q "healthy"; then
            print_message "✅ Bot is healthy and operational" "$GREEN"
            break
        fi
        attempts=$((attempts + 1))
        if [ $attempts -eq $max_attempts ]; then
            print_message "⚠️  Bot health check timeout, but container is running" "$YELLOW"
            break
        fi
        sleep 5
    done

    # Show service status
    print_message "\n📊 Service Status:" "$BLUE"
    docker-compose ps

    # Show startup success message
    print_message "\n🎉 Bot started successfully! 🎉" "$GREEN"
    print_message "========================================" "$GREEN"
    print_message "Bot is now running and ready to receive messages." "$GREEN"
    
    if [ $enable_monitoring -eq 1 ]; then
        print_message "✅ Health monitoring enabled" "$GREEN"
    fi
    
    if [ $enable_logging -eq 1 ]; then
        print_message "✅ Log aggregation enabled" "$GREEN"
    fi
    
    print_message "\n📋 Management commands:" "$BLUE"
    print_message "  View logs:    docker-compose logs -f bot" "$BLUE"
    print_message "  Stop bot:     docker-compose down" "$BLUE"    
    print_message "  Restart:      docker-compose restart bot" "$BLUE"
    print_message "  Status:       docker-compose ps" "$BLUE"
    print_message "========================================" "$GREEN"
    print_message "Press Ctrl+C to detach from logs (bot will continue running)." "$GREEN"
    
    # Follow logs
    trap 'print_message "\nDetaching from logs..." "$GREEN"; return 0' INT
    docker-compose logs -f --no-color bot 2>/dev/null
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
