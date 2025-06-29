#!/bin/bash
# stop.sh - Universal bot stop script
#
# This script can either stop the bot (default) or completely uninstall it (--uninstall).
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
    echo "Universal script to stop or uninstall the Telegram bot."
    echo ""
    echo "Options:"
    echo "  --uninstall         Complete uninstallation (removes images and cleans Docker)"
    echo "  --keep-data         Keep logs when uninstalling (data is always preserved)"
    echo "  --all               Stop all services including monitoring and logging"
    echo "  --dry-run           Show what would be done without executing"
    echo "  --force             Skip confirmation prompts"
    echo "  --quiet             Minimal output (errors only)"
    echo "  --verbose           Detailed output and debugging"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                          # Simple stop"
    echo "  $0 --all                    # Stop all services"
    echo "  $0 --uninstall              # Complete uninstall with confirmation"
    echo "  $0 --uninstall --keep-data  # Uninstall but keep user data"
    echo "  $0 --dry-run --uninstall    # Preview uninstall actions"
    echo "  $0 --force                  # Stop without confirmation prompts"
}

# Stop Docker Compose services
stop_services() {
    local stop_all="$1"
    
    local compose_cmd="docker-compose"
    local stop_args="down --remove-orphans"
    
    if [[ "$stop_all" == "1" ]]; then
        compose_cmd="docker-compose --profile monitoring --profile logging --profile test"
    fi
    
    execute_or_simulate "Stop Docker Compose services" "$compose_cmd $stop_args"
}

# Remove Docker images
remove_images() {
    local remove_images="$1"
    
    if [[ "$remove_images" != "1" ]]; then
        return 0
    fi
    
    execute_or_simulate "Remove bot Docker images" '
        local images=$(docker images -q "${SYSTEM_NAME}*" 2>/dev/null || true)
        if [[ -n "$images" ]]; then
            docker rmi $images || true
        fi
    '
}

# Cleanup data directories
cleanup_data() {
    local keep_data="$1"
    
    if [[ "$keep_data" == "1" ]]; then
        print_message "ℹ️  Keeping data directory and logs (--keep-data specified)" "$BLUE"
        return 0
    fi
    
    # Never remove data directory - it contains the database (users, admins, quotes)
    print_message "📁 Preserving data directory (contains user database)" "$BLUE"
    
    # Only remove logs directory during uninstall
    execute_or_simulate "Remove logs directory" 'rm -rf "$PROJECT_ROOT/logs"'
}

# Cleanup Docker resources
cleanup_docker_resources() {
    local full_cleanup="$1"
    
    if [[ "$full_cleanup" != "1" ]]; then
        return 0
    fi
    
    # Clean up remaining containers
    execute_or_simulate "Remove remaining containers" '
        local containers=$(docker ps -a -q --filter "name=${SYSTEM_NAME}" 2>/dev/null || true)
        if [[ -n "$containers" ]]; then
            docker rm -f $containers || true
        fi
    '
    
    # Clean up networks
    execute_or_simulate "Remove Docker networks" '
        local networks=$(docker network ls -q --filter "name=${SYSTEM_NAME}" 2>/dev/null || true)
        if [[ -n "$networks" ]]; then
            docker network rm $networks || true
        fi
    '
    
    # Clean up volumes
    execute_or_simulate "Remove Docker volumes" '
        local volumes=$(docker volume ls -q | grep -i "$SYSTEM_NAME" || true)
        if [[ -n "$volumes" ]]; then
            docker volume rm $volumes || true
        fi
    '
    
    # General Docker cleanup
    execute_or_simulate "Docker system cleanup" 'docker system prune -f'
}

# Show confirmation dialog
confirm_action() {
    local action="$1"
    local force="$2"
    local dangerous="$3"
    
    if [[ "$force" == "1" || "$DRY_RUN" == "1" ]]; then
        return 0
    fi
    
    print_message ""
    print_message "This will $action $SYSTEM_DISPLAY_NAME." "$YELLOW"
    
    if [[ "$dangerous" == "1" ]]; then
        print_message "⚠️  WARNING: This action may result in data loss!" "$RED"
    fi
    
    print_message ""
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message "❌ Operation cancelled" "$YELLOW"
        exit 0
    fi
}

# Show final status
show_final_status() {
    local uninstall_mode="$1"
    local keep_data="$2"
    
    if is_dry_run; then
        return 0
    fi
    
    print_message "\n📊 Final Status:" "$BLUE"
    
    # Check for remaining containers
    local running_containers=$(docker ps --filter "name=${SYSTEM_NAME}" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || true)
    
    if [[ -n "$running_containers" && "$running_containers" != "NAMES	STATUS" ]]; then
        print_message "Still running:" "$YELLOW"
        echo "$running_containers"
    else
        print_message "✅ All bot services stopped" "$GREEN"
    fi
    
    if [[ "$uninstall_mode" == "1" ]]; then
        print_message "\n🗑️  Uninstall Summary:" "$GREEN"
        print_message "  ✓ Docker Compose services removed" "$GREEN"
        print_message "  ✓ Docker images removed" "$GREEN"
        
        if [[ "$keep_data" == "1" ]]; then
            print_message "  📁 Data and logs preserved" "$BLUE"
        else
            print_message "  📁 Data preserved, logs removed" "$BLUE"
        fi
        
        print_message "  ✓ Docker resources cleaned up" "$GREEN"
        print_message ""
        print_message "ℹ️  Note: Project source code remains in $PROJECT_ROOT" "$BLUE"
        print_message "ℹ️  You can reinstall with: ./scripts/run.sh --install" "$BLUE"
    else
        print_message "\n📋 Next steps:" "$BLUE"
        print_message "  Start bot:    ./scripts/run.sh" "$BLUE"
        print_message "  View logs:    docker-compose logs bot" "$BLUE"
        print_message "  Full cleanup: ./scripts/stop.sh --uninstall" "$BLUE"
    fi
}

# Main function
main() {
    debug_print "Starting universal stop script with arguments: $@"
    
    # Initialize default variables
    local UNINSTALL_MODE=0
    local KEEP_DATA=0
    local STOP_ALL=0
    local DRY_RUN=0
    local FORCE=0
    local QUIET=0
    local VERBOSE=0
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --uninstall)
                UNINSTALL_MODE=1
                shift
                ;;
            --keep-data)
                KEEP_DATA=1
                shift
                ;;
            --all)
                STOP_ALL=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --force)
                FORCE=1
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
    export UNINSTALL_MODE KEEP_DATA STOP_ALL DRY_RUN FORCE QUIET VERBOSE
    
    # Initialize action logging
    init_action_log
    log_action "Stop script start" "INFO" "Arguments: $*"
    
    # Show dry run plan if requested
    if [[ "$DRY_RUN" == "1" ]]; then
        if [[ "$UNINSTALL_MODE" == "1" ]]; then
            show_dry_run_plan "uninstall"
        else
            show_dry_run_plan "stop"
        fi
        echo ""
    fi
    
    # Show header
    if [[ "$UNINSTALL_MODE" == "1" ]]; then
        print_header "Uninstalling $SYSTEM_DISPLAY_NAME"
    else
        print_header "Stopping $SYSTEM_DISPLAY_NAME"
    fi
    
    # Check prerequisites
    execute_or_simulate "Check prerequisites" "check_prerequisites"
    
    # Confirm dangerous operations
    if [[ "$UNINSTALL_MODE" == "1" ]]; then
        local dangerous=0
        if [[ "$KEEP_DATA" != "1" ]]; then
            dangerous=1
        fi
        confirm_action "completely uninstall" "$FORCE" "$dangerous"
    fi
    
    # Stop services
    stop_services "$STOP_ALL" "0"
    
    # Remove images and cleanup if in uninstall mode
    if [[ "$UNINSTALL_MODE" == "1" ]]; then
        remove_images "1"
        cleanup_docker_resources "1"
    fi
    
    # Log completion before cleanup (in case logs directory gets deleted)
    if [[ "$UNINSTALL_MODE" == "1" ]]; then
        log_action "Uninstall completion" "SUCCESS" "Bot completely uninstalled"
    else
        log_action "Stop completion" "SUCCESS" "Bot stopped successfully"
    fi
    
    # Cleanup data if in uninstall mode
    if [[ "$UNINSTALL_MODE" == "1" ]]; then
        cleanup_data "$KEEP_DATA"
    fi
    
    # Show final status
    show_final_status "$UNINSTALL_MODE" "$KEEP_DATA"
    
    # Show completion message
    if [[ "$UNINSTALL_MODE" == "1" ]]; then
        print_message "\n✅ $SYSTEM_DISPLAY_NAME successfully uninstalled!" "$GREEN"
    else
        print_message "\n✅ $SYSTEM_DISPLAY_NAME stopped successfully!" "$GREEN"
    fi
}

# Execute main function
main "$@"
exit $?
