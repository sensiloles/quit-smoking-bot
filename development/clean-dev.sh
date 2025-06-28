#!/bin/bash
# clean-dev.sh - Comprehensive cleanup script for development environment
# Based on production cleanup logic from scripts/common.sh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_message() {
    local message="$1"
    local color="${2:-$NC}"
    echo -e "${color}${message}${NC}"
}

# Print error message
print_error() {
    print_message "$1" "$RED"
}

# Print section header
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Show help
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Comprehensive cleanup script for quit-smoking-bot development environment."
    echo ""
    echo "Options:"
    echo "  --all               Perform complete cleanup (containers, images, volumes, networks)"
    echo "  --containers        Remove only containers"
    echo "  --images            Remove only images"
    echo "  --volumes           Remove only volumes"
    echo "  --networks          Remove only networks"
    echo "  --system            Run Docker system prune (removes unused resources)"
    echo "  --build-cache       Remove build cache"
    echo "  --force             Force removal without confirmation"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Interactive cleanup (prompts for confirmation)"
    echo "  $0 --all            # Complete cleanup of all resources"
    echo "  $0 --containers     # Remove only containers"
    echo "  $0 --images         # Remove only images"
    echo "  $0 --force          # Force cleanup without confirmation"
    echo "  $0 --system         # Clean unused Docker resources"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        exit 1
    fi
}

# Check if docker-compose is available
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_error "docker-compose is not installed or not in PATH"
        exit 1
    fi
}

# Get confirmation from user
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    if [ "$FORCE" == "1" ]; then
        return 0
    fi
    
    while true; do
        if [ "$default" == "y" ]; then
            read -p "${message} [Y/n]: " -r
            REPLY=${REPLY:-y}
        else
            read -p "${message} [y/N]: " -r
            REPLY=${REPLY:-n}
        fi
        
        case $REPLY in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Clean up containers
cleanup_containers() {
    print_section "Cleaning up containers"
    
    # Stop and remove containers
    print_message "Stopping and removing development containers..." "$YELLOW"
    
    # Use docker-compose to stop and remove containers
    if docker-compose ps -q | grep -q .; then
        docker-compose down --remove-orphans
        print_message "✅ Containers stopped and removed" "$GREEN"
    else
        print_message "ℹ️  No running containers found" "$YELLOW"
    fi
    
    # Remove any remaining containers with our project names
    local containers=$(docker ps -a --filter "name=quit-smoking-bot-dev" --format "{{.ID}}" 2>/dev/null || true)
    if [ -n "$containers" ]; then
        print_message "Removing additional development containers..." "$YELLOW"
        echo "$containers" | xargs docker rm -f 2>/dev/null || true
        print_message "✅ Additional containers removed" "$GREEN"
    fi
}

# Clean up images
cleanup_images() {
    print_section "Cleaning up images"
    
    print_message "Removing development images..." "$YELLOW"
    
    # Remove images built by docker-compose
    local images=$(docker-compose images -q 2>/dev/null || true)
    if [ -n "$images" ]; then
        echo "$images" | xargs docker rmi -f 2>/dev/null || true
        print_message "✅ Docker-compose images removed" "$GREEN"
    fi
    
    # Remove images with our project names
    local project_images=$(docker images --filter "reference=development*" --filter "reference=quit-smoking-bot-dev*" --format "{{.ID}}" 2>/dev/null || true)
    if [ -n "$project_images" ]; then
        print_message "Removing additional development images..." "$YELLOW"
        echo "$project_images" | xargs docker rmi -f 2>/dev/null || true
        print_message "✅ Additional development images removed" "$GREEN"
    else
        print_message "ℹ️  No development images found" "$YELLOW"
    fi
}

# Clean up volumes
cleanup_volumes() {
    print_section "Cleaning up volumes"
    
    print_message "Removing development volumes..." "$YELLOW"
    
    # Remove volumes using docker-compose
    docker-compose down -v 2>/dev/null || true
    
    # Remove named volumes with our project names
    local volumes=$(docker volume ls --filter "name=development_" --format "{{.Name}}" 2>/dev/null || true)
    if [ -n "$volumes" ]; then
        echo "$volumes" | xargs docker volume rm -f 2>/dev/null || true
        print_message "✅ Development volumes removed" "$GREEN"
    else
        print_message "ℹ️  No development volumes found" "$YELLOW"
    fi
}

# Clean up networks
cleanup_networks() {
    print_section "Cleaning up networks"
    
    print_message "Removing development networks..." "$YELLOW"
    
    # Remove networks created by docker-compose
    docker-compose down 2>/dev/null || true
    
    # Remove additional networks with our project names
    local networks=$(docker network ls --filter "name=development_" --format "{{.ID}}" 2>/dev/null || true)
    if [ -n "$networks" ]; then
        echo "$networks" | xargs docker network rm 2>/dev/null || true
        print_message "✅ Development networks removed" "$GREEN"
    else
        print_message "ℹ️  No development networks found" "$YELLOW"
    fi
}

# Clean up build cache
cleanup_build_cache() {
    print_section "Cleaning up build cache"
    
    print_message "Removing Docker build cache..." "$YELLOW"
    docker builder prune -f 2>/dev/null || true
    print_message "✅ Build cache removed" "$GREEN"
}

# Run Docker system prune
cleanup_system() {
    print_section "Cleaning up Docker system"
    
    print_message "Running Docker system prune..." "$YELLOW"
    docker system prune -f 2>/dev/null || true
    print_message "✅ Docker system cleanup completed" "$GREEN"
}

# Complete cleanup
cleanup_all() {
    print_section "Complete Development Environment Cleanup"
    
    if confirm_action "This will remove ALL development containers, images, volumes, and networks. Continue?" "n"; then
        cleanup_containers
        cleanup_images
        cleanup_volumes
        cleanup_networks
        cleanup_build_cache
        cleanup_system
        
        print_message "\n🎉 Complete cleanup finished!" "$GREEN"
        print_message "Development environment has been completely cleaned up." "$GREEN"
    else
        print_message "Cleanup cancelled." "$YELLOW"
        exit 0
    fi
}

# Interactive cleanup
interactive_cleanup() {
    print_section "Interactive Development Environment Cleanup"
    
    print_message "This will help you selectively clean up development resources." "$BLUE"
    echo ""
    
    if confirm_action "Remove containers?" "y"; then
        cleanup_containers
    fi
    
    if confirm_action "Remove images?" "y"; then
        cleanup_images
    fi
    
    if confirm_action "Remove volumes?" "n"; then
        cleanup_volumes
    fi
    
    if confirm_action "Remove networks?" "n"; then
        cleanup_networks
    fi
    
    if confirm_action "Remove build cache?" "y"; then
        cleanup_build_cache
    fi
    
    if confirm_action "Run Docker system prune?" "y"; then
        cleanup_system
    fi
    
    print_message "\n🎉 Cleanup completed!" "$GREEN"
}

# Parse arguments
CLEANUP_ALL=0
CLEANUP_CONTAINERS=0
CLEANUP_IMAGES=0
CLEANUP_VOLUMES=0
CLEANUP_NETWORKS=0
CLEANUP_SYSTEM=0
CLEANUP_BUILD_CACHE=0
FORCE=0

# Change to development directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            CLEANUP_ALL=1
            shift
            ;;
        --containers)
            CLEANUP_CONTAINERS=1
            shift
            ;;
        --images)
            CLEANUP_IMAGES=1
            shift
            ;;
        --volumes)
            CLEANUP_VOLUMES=1
            shift
            ;;
        --networks)
            CLEANUP_NETWORKS=1
            shift
            ;;
        --system)
            CLEANUP_SYSTEM=1
            shift
            ;;
        --build-cache)
            CLEANUP_BUILD_CACHE=1
            shift
            ;;
        --force)
            FORCE=1
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
check_docker
check_docker_compose

# Execute cleanup based on arguments
if [ $CLEANUP_ALL -eq 1 ]; then
    cleanup_all
elif [ $CLEANUP_CONTAINERS -eq 1 ] || [ $CLEANUP_IMAGES -eq 1 ] || [ $CLEANUP_VOLUMES -eq 1 ] || [ $CLEANUP_NETWORKS -eq 1 ] || [ $CLEANUP_SYSTEM -eq 1 ] || [ $CLEANUP_BUILD_CACHE -eq 1 ]; then
    # Selective cleanup
    print_section "Selective Development Environment Cleanup"
    
    [ $CLEANUP_CONTAINERS -eq 1 ] && cleanup_containers
    [ $CLEANUP_IMAGES -eq 1 ] && cleanup_images
    [ $CLEANUP_VOLUMES -eq 1 ] && cleanup_volumes
    [ $CLEANUP_NETWORKS -eq 1 ] && cleanup_networks
    [ $CLEANUP_BUILD_CACHE -eq 1 ] && cleanup_build_cache
    [ $CLEANUP_SYSTEM -eq 1 ] && cleanup_system
    
    print_message "\n🎉 Selective cleanup completed!" "$GREEN"
else
    # Interactive mode
    interactive_cleanup
fi 