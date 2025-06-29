#!/bin/bash
set -e

# Source bootstrap (loads all modules)
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/bootstrap.sh"

show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Stop the Telegram bot and related services using Docker Compose."
    echo ""
    echo "Options:"
    echo "  --all               Stop all services including monitoring and logging"
    echo "  --volumes           Remove volumes (WARNING: this will delete data)"
    echo "  --images            Remove bot images after stopping"
    echo "  --cleanup           Perform thorough cleanup of Docker resources"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Stop main bot service"
    echo "  $0 --all            # Stop all services"
    echo "  $0 --all --volumes  # Stop all and remove data volumes (DANGEROUS)"
    echo "  $0 --cleanup        # Stop and cleanup Docker resources"
}

# Main function
main() {
    debug_print "Starting stop.sh main function with arguments: $@"
    
    print_header "Stopping $SYSTEM_DISPLAY_NAME"
    
    local stop_all=0
    local remove_volumes=0
    local remove_images=0
    local cleanup=0
    
    # Parse arguments
    debug_print "Parsing command line arguments"
    for arg in "$@"; do
        case $arg in
            --help)
                show_help
                exit 0
                ;;
            --all)
                stop_all=1
                ;;
            --volumes)
                remove_volumes=1
                ;;
            --images)
                remove_images=1
                ;;
            --cleanup)
                cleanup=1
                ;;
        esac
    done
    debug_print "Arguments parsed successfully"
    
    # Warn about volume removal
    if [ $remove_volumes -eq 1 ]; then
        print_message "⚠️  WARNING: This will remove all bot data!" "$RED"
        print_message "Are you sure you want to continue? (y/N)" "$YELLOW"
        read -r confirmation
        if [[ ! $confirmation =~ ^[Yy]$ ]]; then
            print_message "Operation cancelled" "$BLUE"
            exit 0
        fi
    fi
    
    # Check prerequisites
    debug_print "Checking prerequisites"
    check_prerequisites || return 1
    debug_print "Prerequisites check passed"
    
    # Determine which profiles to stop
    local compose_cmd="docker-compose"
    if [ $stop_all -eq 1 ]; then
        compose_cmd="docker-compose --profile monitoring --profile logging --profile test"
        print_message "Stopping all services..." "$YELLOW"
    else
        print_message "Stopping main bot service..." "$YELLOW"
    fi
    
    # Stop services
    debug_print "Stopping services"
    local stop_args="down --remove-orphans"
    if [ $remove_volumes -eq 1 ]; then
        stop_args="$stop_args --volumes"
    fi
    
    if eval "$compose_cmd $stop_args"; then
        print_message "✅ Services stopped successfully" "$GREEN"
        debug_print "Services stopped successfully"
    else
        print_message "⚠️  Some services may not have stopped cleanly" "$YELLOW"
        debug_print "Some services may not have stopped cleanly"
    fi
    
    # Remove images if requested
    if [ $remove_images -eq 1 ]; then
        debug_print "Removing bot images"
        print_message "Removing bot images..." "$YELLOW"
        
        local images=$(docker images -q "${SYSTEM_NAME:-quit-smoking-bot}*" 2>/dev/null || true)
        if [ -n "$images" ]; then
            docker rmi $images || true
            print_message "✅ Images removed" "$GREEN"
        else
            print_message "ℹ️  No bot images found to remove" "$BLUE"
        fi
    fi
    
    # Perform cleanup if requested
    if [ $cleanup -eq 1 ]; then
        debug_print "Performing Docker cleanup"
        print_message "Performing Docker cleanup..." "$YELLOW"
        
        # Remove unused containers, networks, images
        docker system prune -f || true
        print_message "✅ Docker cleanup completed" "$GREEN"
    fi
    
    # Check for any remaining containers
    local remaining_containers=$(docker ps -a -q --filter "name=${SYSTEM_NAME:-quit-smoking-bot}" 2>/dev/null || true)
    if [ -n "$remaining_containers" ]; then
        print_message "Found remaining containers, cleaning up..." "$YELLOW"
        docker rm -f $remaining_containers || true
        print_message "✅ Remaining containers cleaned up" "$GREEN"
    fi
    
    # Show final status
    print_message "\n📊 Final Status:" "$BLUE"
    local running_containers=$(docker ps --filter "name=${SYSTEM_NAME:-quit-smoking-bot}" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || true)
    
    if [ -n "$running_containers" ] && [ "$running_containers" != "NAMES	STATUS" ]; then
        print_message "Still running:" "$YELLOW"
        echo "$running_containers"
    else
        print_message "✅ All bot services stopped" "$GREEN"
    fi
    
    print_message "\n📋 Next steps:" "$BLUE"
    print_message "  Start bot:    ./scripts/run.sh" "$BLUE"
    print_message "  View logs:    docker-compose logs bot" "$BLUE"
    print_message "  Clean up all: docker system prune" "$BLUE"
    
    debug_print "Bot stop procedure completed successfully"
    return 0
}

# Execute main function
main "$@"
exit $?
