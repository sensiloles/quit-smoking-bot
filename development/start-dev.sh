#!/bin/bash
# start-dev.sh - Quick start script for development environment

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

# Show help
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Quick start script for quit-smoking-bot development environment."
    echo ""
    echo "Options:"
    echo "  --basic             Start lightweight environment without systemd"
    echo "  --build             Force rebuild of development image"
    echo "  --clean             Clean up containers and volumes before starting"
    echo "  --detach            Start in detached mode (background)"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Start interactive development environment (with systemd)"
    echo "  $0 --basic          # Start lightweight environment without systemd"
    echo "  $0 --build          # Rebuild image and start"
    echo "  $0 --detach         # Start in background"
}

# Parse arguments
BASIC_MODE=0
FORCE_BUILD=0
CLEAN_START=0
DETACHED=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --basic)
            BASIC_MODE=1
            shift
            ;;
        --build)
            FORCE_BUILD=1
            shift
            ;;
        --clean)
            CLEAN_START=1
            shift
            ;;
        --detach)
            DETACHED=1
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            print_message "Unknown option: $1" "$RED"
            show_help
            exit 1
            ;;
    esac
done

# Change to development directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_message "🚀 Starting quit-smoking-bot development environment..." "$BLUE"

# Clean up if requested
if [ $CLEAN_START -eq 1 ]; then
    print_message "🧹 Cleaning up existing containers and volumes..." "$YELLOW"
    # Use our comprehensive cleanup script
    if [ -f "./clean-dev.sh" ]; then
        ./clean-dev.sh --containers --images --force
    else
        # Fallback to basic cleanup
        docker-compose down -v --remove-orphans 2>/dev/null || true
        docker system prune -f 2>/dev/null || true
    fi
fi

# Build image if requested or if it doesn't exist
if [ $FORCE_BUILD -eq 1 ] || ! docker images | grep -q "development[-_]dev-env"; then
    print_message "🔨 Building development image..." "$YELLOW"
    docker-compose build dev-env
fi

# Determine service and startup mode
if [ $BASIC_MODE -eq 1 ]; then
    SERVICE="dev-env-basic"
    print_message "🐧 Starting lightweight Linux environment..." "$YELLOW"
    print_message "📝 Note: This mode does not support systemd or service management" "$BLUE"
else
    SERVICE="dev-env"
    print_message "⚙️  Starting full development environment with systemd..." "$YELLOW"
    print_message "📝 Note: This mode supports Docker daemon, service installation and management" "$BLUE"
fi

# Start the environment
if [ $DETACHED -eq 1 ]; then
    print_message "🔧 Starting in detached mode..." "$YELLOW"
    docker-compose up -d "$SERVICE"
    
    print_message "✅ Development environment started!" "$GREEN"
    print_message "🔗 Connect with: docker-compose exec $SERVICE bash" "$BLUE"
    print_message "🛑 Stop with: docker-compose down" "$BLUE"
else
    print_message "🔧 Starting interactive session..." "$YELLOW"
    
    # Trap Ctrl+C to show cleanup message
    trap 'echo ""; print_message "🛑 Stopping development environment..." "$YELLOW"; docker-compose down; exit 0' INT
    
    if [ $BASIC_MODE -eq 1 ]; then
        # For basic mode, run interactively without systemd
        print_message "✅ Development environment ready!" "$GREEN"
        print_message "📂 Project mounted at: /workspace" "$BLUE"
        print_message "🔧 Try: ./scripts/test.sh" "$BLUE"
        docker-compose run --rm "$SERVICE"
    else
        # For full mode with systemd, we need to attach to the running container
        docker-compose up -d "$SERVICE"
        sleep 3  # Wait for systemd to initialize
        print_message "✅ Development environment ready!" "$GREEN"
        print_message "📂 Project mounted at: /workspace" "$BLUE"
        print_message "🔧 Run: ./scripts/run.sh --help" "$BLUE"
        print_message "🔧 Run: sudo ./scripts/install-service.sh --token YOUR_TOKEN" "$BLUE"
        docker-compose exec "$SERVICE" bash
    fi
fi 