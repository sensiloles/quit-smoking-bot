#!/bin/bash
# healthcheck.sh - Comprehensive health check for development environment

set -e

# Exit codes
EXIT_SUCCESS=0
EXIT_FAILURE=1

# Configuration
TIMEOUT=10
WORKSPACE_PATH="/workspace"
REQUIRED_COMMANDS=("python3" "pip3" "git" "curl" "jq")
REQUIRED_DIRS=("$WORKSPACE_PATH" "$WORKSPACE_PATH/src" "$WORKSPACE_PATH/scripts")

# Colors (only if terminal supports it)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    NC=''
fi

log_info() {
    echo -e "${GREEN}[HEALTH]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[HEALTH]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[HEALTH]${NC} $1" >&2
}

# Check if required commands are available
check_commands() {
    local missing_commands=()
    
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return $EXIT_FAILURE
    fi
    
    return $EXIT_SUCCESS
}

# Check if required directories exist and are accessible
check_directories() {
    local missing_dirs=()
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            missing_dirs+=("$dir")
        elif [ ! -r "$dir" ]; then
            log_error "Directory not readable: $dir"
            return $EXIT_FAILURE
        fi
    done
    
    if [ ${#missing_dirs[@]} -gt 0 ]; then
        log_error "Missing required directories: ${missing_dirs[*]}"
        return $EXIT_FAILURE
    fi
    
    return $EXIT_SUCCESS
}

# Check Python environment
check_python() {
    # Check Python version
    if ! python3 --version &> /dev/null; then
        log_error "Python3 not working"
        return $EXIT_FAILURE
    fi
    
    # Check pip
    if ! pip3 --version &> /dev/null; then
        log_error "pip3 not working"
        return $EXIT_FAILURE
    fi
    
    # Check if workspace is in Python path
    if ! python3 -c "import sys; sys.exit(0 if '/workspace/src' in sys.path or 'PYTHONPATH' in os.environ for os in [__import__('os')] else 1)" 2>/dev/null; then
        log_warn "Workspace not in Python path"
    fi
    
    return $EXIT_SUCCESS
}

# Check Git configuration
check_git() {
    if ! git --version &> /dev/null; then
        log_error "Git not working"
        return $EXIT_FAILURE
    fi
    
    # Check if we're in a git repository (workspace should be mounted)
    if [ -d "$WORKSPACE_PATH/.git" ]; then
        if ! git -C "$WORKSPACE_PATH" status &> /dev/null; then
            log_warn "Git repository has issues"
        fi
    else
        log_warn "Not in a git repository"
    fi
    
    return $EXIT_SUCCESS
}

# Check Docker availability (if needed)
check_docker() {
    if command -v docker &> /dev/null; then
        # Check if Docker daemon is accessible
        if ! timeout $TIMEOUT docker info &> /dev/null; then
            log_warn "Docker daemon not accessible"
        else
            log_info "Docker daemon accessible"
        fi
    else
        log_info "Docker not installed (this is fine)"
    fi
    
    return $EXIT_SUCCESS
}

# Check workspace integrity
check_workspace() {
    # Check if main project files exist
    local required_files=("main.py" "pyproject.toml" "scripts/bootstrap.sh")
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$WORKSPACE_PATH/$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "Missing project files: ${missing_files[*]}"
        return $EXIT_FAILURE
    fi
    
    return $EXIT_SUCCESS
}

# Check disk space
check_disk_space() {
    local workspace_usage
    workspace_usage=$(df "$WORKSPACE_PATH" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$workspace_usage" -gt 90 ]; then
        log_error "Workspace disk usage is ${workspace_usage}% (>90%)"
        return $EXIT_FAILURE
    elif [ "$workspace_usage" -gt 80 ]; then
        log_warn "Workspace disk usage is ${workspace_usage}% (>80%)"
    fi
    
    return $EXIT_SUCCESS
}

# Check memory usage
check_memory() {
    if [ -f "/proc/meminfo" ]; then
        local mem_total mem_available mem_usage
        mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        mem_usage=$(( (mem_total - mem_available) * 100 / mem_total ))
        
        if [ "$mem_usage" -gt 90 ]; then
            log_error "Memory usage is ${mem_usage}% (>90%)"
            return $EXIT_FAILURE
        elif [ "$mem_usage" -gt 80 ]; then
            log_warn "Memory usage is ${mem_usage}% (>80%)"
        fi
    fi
    
    return $EXIT_SUCCESS
}

# Main health check function
main() {
    local failed_checks=0
    local total_checks=0
    
    log_info "Starting health check..."
    
    # Run all checks
    local checks=(
        "check_commands:Required commands"
        "check_directories:Required directories"
        "check_python:Python environment"
        "check_git:Git configuration"
        "check_docker:Docker availability"
        "check_workspace:Workspace integrity"
        "check_disk_space:Disk space"
        "check_memory:Memory usage"
    )
    
    for check in "${checks[@]}"; do
        local check_func="${check%%:*}"
        local check_name="${check##*:}"
        
        total_checks=$((total_checks + 1))
        
        if $check_func; then
            log_info "✅ $check_name"
        else
            log_error "❌ $check_name"
            failed_checks=$((failed_checks + 1))
        fi
    done
    
    # Summary
    log_info "Health check completed: $((total_checks - failed_checks))/$total_checks checks passed"
    
    if [ $failed_checks -eq 0 ]; then
        log_info "🎉 Development environment is healthy!"
        return $EXIT_SUCCESS
    else
        log_error "💥 Development environment has issues: $failed_checks failed checks"
        return $EXIT_FAILURE
    fi
}

# Run main function
main "$@" 