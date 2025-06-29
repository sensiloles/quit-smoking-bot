#!/bin/bash
# uninstall-service.sh - Uninstall bot from Docker Compose service

set -e

# Source bootstrap (loads all modules)
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "${SCRIPT_DIR}/bootstrap.sh"

# Configuration
SYSTEM_NAME="${SYSTEM_NAME:-quit-smoking-bot}"
SYSTEM_DISPLAY_NAME="${SYSTEM_DISPLAY_NAME:-Quit Smoking Bot}"

print_header "Uninstalling $SYSTEM_DISPLAY_NAME from Docker Compose"

show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Uninstall the Telegram bot from Docker Compose service."
    echo ""
    echo "Options:"
    echo "  --keep-data         Keep data directory and logs"
    echo "  --keep-images       Keep Docker images"
    echo "  --full-cleanup      Remove everything including Docker volumes"
    echo "  --remove-systemd    Remove systemd service if exists (legacy)"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                      # Basic uninstall"
    echo "  $0 --keep-data          # Keep data and logs"
    echo "  $0 --full-cleanup       # Remove everything"
}

# Function to stop and remove Docker Compose services
remove_docker_services() {
    print_section "Removing Docker Services"
    
    cd "$PROJECT_ROOT"
    
    # Show current status
    print_message "📊 Current service status:" "$BLUE"
    docker-compose ps || true
    
    # Stop and remove all services including profiles
    print_message "🛑 Stopping all services..." "$YELLOW"
    docker-compose --profile monitoring --profile logging --profile test down --remove-orphans || true
    
    print_message "✅ Docker services stopped and removed" "$GREEN"
}

# Function to remove systemd service
remove_systemd_service() {
    local remove_systemd="$1"
    
    if [[ "$remove_systemd" != "true" ]]; then
        return 0
    fi
    
    print_section "Removing Systemd Service"
    
    # Check if service exists
    if systemctl list-unit-files | grep -q "${SYSTEM_NAME}.service"; then
        print_message "📊 Current systemd service status:" "$BLUE"
        sudo systemctl status ${SYSTEM_NAME} || true
        
        print_message "🛑 Stopping and disabling systemd service..." "$YELLOW"
        sudo systemctl stop ${SYSTEM_NAME} 2>/dev/null || true
        sudo systemctl disable ${SYSTEM_NAME} 2>/dev/null || true
        
        print_message "🗑️  Removing systemd service file..." "$YELLOW"
        sudo rm -f /etc/systemd/system/${SYSTEM_NAME}.service
        
        print_message "🔄 Reloading systemd configuration..." "$YELLOW"
        sudo systemctl daemon-reload
        
        print_message "✅ Systemd service removed" "$GREEN"
    else
        print_message "ℹ️  No systemd service found" "$BLUE"
    fi
}

# Function to remove Docker images
remove_docker_images() {
    local keep_images="$1"
    
    if [[ "$keep_images" == "true" ]]; then
        print_message "ℹ️  Keeping Docker images (--keep-images specified)" "$BLUE"
        return 0
    fi
    
    print_section "Removing Docker Images"
    
    # Remove bot images
    local images=$(docker images -q "${SYSTEM_NAME}*" 2>/dev/null || true)
    if [[ -n "$images" ]]; then
        print_message "🗑️  Removing bot Docker images..." "$YELLOW"
        docker rmi $images || true
        print_message "✅ Docker images removed" "$GREEN"
    else
        print_message "ℹ️  No bot images found" "$BLUE"
    fi
}

# Function to cleanup data and volumes
cleanup_data() {
    local keep_data="$1"
    local full_cleanup="$2"
    
    if [[ "$keep_data" == "true" ]]; then
        print_message "ℹ️  Keeping data directory and logs (--keep-data specified)" "$BLUE"
        return 0
    fi
    
    print_section "Cleaning up Data"
    
    # Remove Docker volumes if full cleanup requested
    if [[ "$full_cleanup" == "true" ]]; then
        print_message "🗑️  Removing Docker volumes..." "$YELLOW"
        docker volume ls -q | grep -i "$SYSTEM_NAME" | xargs -r docker volume rm || true
        print_message "✅ Docker volumes removed" "$GREEN"
    fi
    
    # Remove local directories
    if [[ -d "$PROJECT_ROOT/logs" ]]; then
        print_message "🗑️  Removing logs directory..." "$YELLOW"
        rm -rf "$PROJECT_ROOT/logs"
        print_message "✅ Logs directory removed" "$GREEN"
    fi
    
    if [[ -d "$PROJECT_ROOT/data" ]]; then
        print_message "🗑️  Removing data directory..." "$YELLOW"
        rm -rf "$PROJECT_ROOT/data"
        print_message "✅ Data directory removed" "$GREEN"
    fi
}

# Function to cleanup Docker networks
cleanup_networks() {
    local full_cleanup="$1"
    
    if [[ "$full_cleanup" != "true" ]]; then
        return 0
    fi
    
    print_section "Cleaning up Docker Networks"
    
    # Remove bot-specific networks
    local networks=$(docker network ls -q --filter "name=${SYSTEM_NAME}" 2>/dev/null || true)
    if [[ -n "$networks" ]]; then
        print_message "🗑️  Removing Docker networks..." "$YELLOW"
        docker network rm $networks || true
        print_message "✅ Docker networks removed" "$GREEN"
    else
        print_message "ℹ️  No bot networks found" "$BLUE"
    fi
}

# Function to cleanup remaining containers
cleanup_containers() {
    print_section "Cleaning up Remaining Containers"
    
    # Remove any remaining containers
    local containers=$(docker ps -a -q --filter "name=${SYSTEM_NAME}" 2>/dev/null || true)
    if [[ -n "$containers" ]]; then
        print_message "🗑️  Removing remaining containers..." "$YELLOW"
        docker rm -f $containers || true
        print_message "✅ Remaining containers removed" "$GREEN"
    else
        print_message "ℹ️  No remaining containers found" "$BLUE"
    fi
}

# Function to show final status
show_final_status() {
    local keep_data="$1"
    local keep_images="$2"
    local remove_systemd="$3"
    local full_cleanup="$4"
    
    print_section "Uninstall Summary"
    
    local items_removed=()
    local items_kept=()
    
    # Check what was removed
    items_removed+=("Docker Compose services")
    
    if [[ "$remove_systemd" == "true" && ! -f "/etc/systemd/system/${SYSTEM_NAME}.service" ]]; then
        items_removed+=("Systemd service")
    fi
    
    if [[ "$keep_images" != "true" ]]; then
        items_removed+=("Docker images")
    else
        items_kept+=("Docker images")
    fi
    
    if [[ "$keep_data" != "true" ]]; then
        items_removed+=("Data and logs directories")
        if [[ "$full_cleanup" == "true" ]]; then
            items_removed+=("Docker volumes and networks")
        fi
    else
        items_kept+=("Data and logs directories")
    fi
    
    # Show what was removed
    if [[ ${#items_removed[@]} -gt 0 ]]; then
        print_message "🗑️  Removed:" "$GREEN"
        for item in "${items_removed[@]}"; do
            print_message "  ✓ $item" "$GREEN"
        done
    fi
    
    # Show what was kept  
    if [[ ${#items_kept[@]} -gt 0 ]]; then
        print_message "📁 Kept:" "$BLUE"
        for item in "${items_kept[@]}"; do
            print_message "  • $item" "$BLUE"
        done
    fi
    
    print_message ""
    print_message "ℹ️  Note: Project source code remains in $PROJECT_ROOT" "$BLUE"
    print_message "ℹ️  You can still run manually with: ./scripts/run.sh" "$BLUE"
    
    # Check if Docker is still running other containers
    local running_containers=$(docker ps -q 2>/dev/null | wc -l)
    if [[ $running_containers -eq 0 ]]; then
        print_message "ℹ️  No other Docker containers running. You can stop Docker daemon if not needed." "$BLUE"
    fi
}

# Main uninstall process
main() {
    debug_print "Starting Docker Compose service uninstall"
    
    # Parse arguments
    local KEEP_DATA=false
    local KEEP_IMAGES=false
    local REMOVE_SYSTEMD=false
    local FULL_CLEANUP=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep-data)
                KEEP_DATA=true
                shift
                ;;
            --keep-images)
                KEEP_IMAGES=true
                shift
                ;;
            --remove-systemd)
                REMOVE_SYSTEMD=true
                shift
                ;;
            --full-cleanup)
                FULL_CLEANUP=true
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
    
    # Confirm uninstall
    echo ""
    print_message "This will uninstall $SYSTEM_DISPLAY_NAME from Docker Compose." "$YELLOW"
    if [[ "$KEEP_DATA" != "true" ]]; then
        print_message "⚠️  This will also remove logs and data directories!" "$RED"
    fi
    if [[ "$FULL_CLEANUP" == "true" ]]; then
        print_message "⚠️  Full cleanup will remove all Docker volumes and networks!" "$RED"
    fi
    if [[ "$REMOVE_SYSTEMD" == "true" ]]; then
        print_message "⚠️  This will also remove the systemd service!" "$RED"
    fi
    echo ""
    
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message "❌ Uninstall cancelled" "$YELLOW"
        exit 0
    fi
    
    # Remove Docker services
    remove_docker_services
    
    # Remove systemd service if requested
    remove_systemd_service "$REMOVE_SYSTEMD"
    
    # Cleanup remaining containers
    cleanup_containers
    
    # Remove Docker images
    remove_docker_images "$KEEP_IMAGES"
    
    # Cleanup data and volumes
    cleanup_data "$KEEP_DATA" "$FULL_CLEANUP"
    
    # Cleanup networks if full cleanup
    cleanup_networks "$FULL_CLEANUP"
    
    # Show final status
    show_final_status "$KEEP_DATA" "$KEEP_IMAGES" "$REMOVE_SYSTEMD" "$FULL_CLEANUP"
    
    print_success "✅ $SYSTEM_DISPLAY_NAME successfully uninstalled from Docker Compose!"
    
    debug_print "Docker Compose service uninstall completed"
}

# Run main function
main "$@"
