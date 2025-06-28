#!/bin/bash
# test-environment-simple.sh - Simplified testing for development environment

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEV_DIR="$PROJECT_ROOT/development"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Check if required commands are available
check_commands() {
    local missing=()
    for cmd in docker docker-compose python3 git; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing commands: ${missing[*]}"
        return 1
    fi
    return 0
}

# Check development environment status
check_dev_environment() {
    log_section "Checking Development Environment"
    
    cd "$DEV_DIR"
    
    if ! docker-compose ps -q dev-env | grep -q .; then
        log_warn "Development environment is not running"
        log_info "Starting development environment..."
        docker-compose up -d dev-env redis
        sleep 10
    fi
    
    # Simple health check
    if docker-compose exec -T dev-env echo "Environment OK" &>/dev/null; then
        log_info "Development environment is healthy"
        return 0
    else
        log_error "Development environment is not responding"
        return 1
    fi
}

# Run basic tests
run_basic_tests() {
    log_section "Running Basic Tests"
    
    # Test Python environment
    if docker-compose exec -T dev-env python3 --version &>/dev/null; then
        log_info "✅ Python environment OK"
    else
        log_error "❌ Python environment failed"
        return 1
    fi
    
    # Test workspace mount
    if docker-compose exec -T dev-env test -d /workspace/src &>/dev/null; then
        log_info "✅ Workspace mount OK"
    else
        log_error "❌ Workspace mount failed"
        return 1
    fi
    
    # Test bot import
    if docker-compose exec -T dev-env python3 -c "import src.bot" &>/dev/null; then
        log_info "✅ Bot import OK"
    else
        log_warn "⚠️ Bot import failed (this may be expected if BOT_TOKEN is not set)"
    fi
    
    return 0
}

# Check resource usage
check_resources() {
    log_section "Checking Resource Usage"
    
    # Memory usage
    local mem_usage=$(docker exec $(docker-compose ps -q dev-env) free | awk 'NR==2{printf "%.1f%%\n", $3*100/$2}')
    log_info "Memory usage: $mem_usage"
    
    # Disk usage
    local disk_usage=$(docker exec $(docker-compose ps -q dev-env) df /workspace | awk 'NR==2{print $5}')
    log_info "Disk usage: $disk_usage"
    
    return 0
}

# Main function
main() {
    log_info "🔍 Starting simplified environment test..."
    
    # Basic checks
    if ! check_commands; then
        exit 1
    fi
    
    if ! check_dev_environment; then
        exit 1
    fi
    
    if ! run_basic_tests; then
        exit 1
    fi
    
    check_resources
    
    log_info "🎉 All basic tests passed!"
    return 0
}

# Show help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0"
    echo "Simplified testing script for development environment"
    echo "Performs basic health checks without complex benchmarking"
    exit 0
fi

# Execute main function
main "$@" 