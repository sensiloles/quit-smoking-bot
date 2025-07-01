#!/bin/bash
# actions.sh - Action logging and dry-run utilities
#
# This module provides functions for logging actions and implementing dry-run functionality.

###########################
# Action Logging
###########################

# Initialize action logging
init_action_log() {
    # Ensure PROJECT_ROOT is set
    if [[ -z "$PROJECT_ROOT" ]]; then
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
        export PROJECT_ROOT
    fi
    
    local log_dir="$PROJECT_ROOT/logs"
    local log_file="$log_dir/actions.log"
    
    # Create logs directory if it doesn't exist
    mkdir -p "$log_dir"
    
    # Set log file path globally
    export ACTION_LOG_FILE="$log_file"
    
    debug_print "Action logging initialized: $ACTION_LOG_FILE"
}

# Log an action
log_action() {
    local action="$1"
    local status="$2"  # INFO, SUCCESS, ERROR, WARNING
    local details="$3"
    
    if [[ -z "$ACTION_LOG_FILE" ]]; then
        init_action_log
    fi
    
    # Check if log directory still exists
    local log_dir=$(dirname "$ACTION_LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        # Log directory was deleted, skip logging
        debug_print "Log directory $log_dir no longer exists, skipping log entry"
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="$timestamp [$status] $action"
    
    if [[ -n "$details" ]]; then
        log_entry="$log_entry - $details"
    fi
    
    echo "$log_entry" >> "$ACTION_LOG_FILE"
    debug_print "Action logged: $log_entry"
}

###########################
# Dry Run Functionality
###########################

# Check if in dry-run mode
is_dry_run() {
    [[ "${DRY_RUN:-0}" == "1" ]]
}

# Execute or simulate command based on dry-run mode
execute_or_simulate() {
    local description="$1"
    shift
    local command="$@"
    
    if is_dry_run; then
        print_message "🔍 [DRY-RUN] Would $description" "$YELLOW"
        debug_print "DRY-RUN: Would execute: $command"
        log_action "DRY-RUN: $description" "INFO" "$command"
        return 0
    else
        print_message "▶️ $description..." "$BLUE"
        debug_print "Executing: $command"
        log_action "$description" "INFO" "$command"
        
        if eval "$command"; then
            log_action "$description" "SUCCESS" ""
            return 0
        else
            log_action "$description" "ERROR" "Command failed: $command"
            return 1
        fi
    fi
}

# Show what would be done in dry-run mode
show_dry_run_plan() {
    local operation="$1"  # "install", "start", "stop", "uninstall"
    
    print_header "Dry Run Plan - $operation"
    
    case "$operation" in
        "install")
            print_message "🔍 This would:" "$BLUE"
            print_message "  1. Check and install Docker (if needed)" "$BLUE"
            print_message "  2. Setup data directories and permissions" "$BLUE"
            print_message "  3. Build Docker containers" "$BLUE"
            print_message "  4. Configure auto-restart policies" "$BLUE"
            print_message "  5. Start bot service" "$BLUE"
            if [[ "${ENABLE_MONITORING:-0}" == "1" ]]; then
                print_message "  6. Enable monitoring service" "$BLUE"
            fi
            if [[ "${ENABLE_LOGGING:-0}" == "1" ]]; then
                print_message "  7. Enable logging service" "$BLUE"
            fi
            ;;
        "start")
            print_message "🔍 This would:" "$BLUE"
            print_message "  1. Stop any existing containers" "$BLUE"
            print_message "  2. Build containers (if needed)" "$BLUE"
            print_message "  3. Start bot service" "$BLUE"
            ;;
        "stop")
            print_message "🔍 This would:" "$BLUE"
            print_message "  1. Stop running containers" "$BLUE"
            print_message "  2. Remove containers" "$BLUE"
            if [[ "${STOP_ALL:-0}" == "1" ]]; then
                print_message "  3. Stop monitoring and logging services" "$BLUE"
            fi
            ;;
        "uninstall")
            print_message "🔍 This would:" "$BLUE"
            print_message "  1. Stop all running containers" "$BLUE"
            print_message "  2. Remove containers and images" "$BLUE"
            print_message "  3. Clean up Docker resources" "$BLUE"
            print_message "  4. Remove Docker networks and volumes" "$BLUE"
            print_message "  5. Disable auto-restart configuration" "$BLUE"
            ;;
    esac
    
    print_message "" 
    print_message "Use --force to skip confirmations" "$YELLOW"
    print_message "Remove --dry-run to actually execute these actions" "$YELLOW"
}

###########################
# Status Display
###########################

# Show comprehensive service status
show_service_status() {
    print_header "Service Status"
    
    # Docker containers status
    print_message "📦 Docker Containers:" "$BLUE"
    if docker-compose ps >/dev/null 2>&1; then
        docker-compose ps
    else
        print_message "  No containers found or docker-compose not available" "$YELLOW"
    fi
    
    # Docker images
    print_message "\n🖼️  Docker Images:" "$BLUE"
    local images=$(docker images "${SYSTEM_NAME:-quit-smoking-bot}*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null || true)
    if [[ -n "$images" && "$images" != "REPOSITORY	TAG	SIZE	CREATED AT" ]]; then
        echo "$images"
    else
        print_message "  No bot images found" "$YELLOW"
    fi
    
    # Data directories
    print_message "\n📁 Data Directories:" "$BLUE"
    if [[ -d "$PROJECT_ROOT/data" ]]; then
        local data_size=$(du -sh "$PROJECT_ROOT/data" 2>/dev/null | cut -f1)
        print_message "  data/: $data_size" "$GREEN"
    else
        print_message "  data/: Not found" "$YELLOW"
    fi
    
    if [[ -d "$PROJECT_ROOT/logs" ]]; then
        local logs_size=$(du -sh "$PROJECT_ROOT/logs" 2>/dev/null | cut -f1)
        print_message "  logs/: $logs_size" "$GREEN"
    else
        print_message "  logs/: Not found" "$YELLOW"
    fi
    
    # Recent actions
    if [[ -f "$ACTION_LOG_FILE" ]]; then
        print_message "\n📋 Recent Actions:" "$BLUE"
        tail -5 "$ACTION_LOG_FILE" | while read line; do
            print_message "  $line" "$BLUE"
        done
    fi
}

# Show installation status
show_install_status() {
    print_header "Installation Status"
    
    local all_good=true
    
    # Check Docker
    if command -v docker &> /dev/null; then
        print_message "✅ Docker: Installed" "$GREEN"
    else
        print_message "❌ Docker: Not found" "$RED"
        all_good=false
    fi
    
    # Check Docker Compose
    if command -v docker-compose &> /dev/null; then
        print_message "✅ Docker Compose: Installed" "$GREEN"
    else
        print_message "❌ Docker Compose: Not found" "$RED"
        all_good=false
    fi
    
    # Check if service is configured
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        print_message "✅ Docker Compose config: Found" "$GREEN"
    else
        print_message "❌ Docker Compose config: Not found" "$RED"
        all_good=false
    fi
    
    # Check if bot token is configured
    if [[ -f "$PROJECT_ROOT/.env" ]] && grep -q "BOT_TOKEN=" "$PROJECT_ROOT/.env" 2>/dev/null; then
        print_message "✅ Bot token: Configured" "$GREEN"
    else
        print_message "⚠️  Bot token: Not configured (use --token)" "$YELLOW"
    fi
    
    # Overall status
    print_message ""
    if $all_good; then
        print_message "🎉 System ready for installation/operation!" "$GREEN"
    else
        print_message "⚠️  System needs setup. Use --install flag." "$YELLOW"
    fi
} 