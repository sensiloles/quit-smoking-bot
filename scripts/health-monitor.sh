#!/bin/bash
# health-monitor.sh - Health monitoring service for the bot
#
# This script monitors the health of the main bot container
# and provides periodic status checks and alerting.

set -euo pipefail

# Configuration
readonly MONITOR_INTERVAL=${MONITOR_INTERVAL:-30}
readonly LOG_FILE="/app/logs/health-monitor.log"
readonly MAIN_CONTAINER_NAME="${SYSTEM_NAME:-quit-smoking-bot}"
readonly CHECK_TIMEOUT=10

# Setup logging
setup_logging() {
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Health monitor started for container: $MAIN_CONTAINER_NAME"
}

# Log message with timestamp
log_message() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message"
}

# Check if main bot container is running
check_container_running() {
    if docker ps --format "table {{.Names}}" | grep -q "^${MAIN_CONTAINER_NAME}$"; then
        return 0
    else
        return 1
    fi
}

# Check container health status
check_container_health() {
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$MAIN_CONTAINER_NAME" 2>/dev/null || echo "no-healthcheck")
    
    case "$health_status" in
        "healthy")
            return 0
            ;;
        "unhealthy")
            return 1
            ;;
        "starting")
            return 2
            ;;
        "no-healthcheck")
            return 3
            ;;
        *)
            return 4
            ;;
    esac
}

# Check if bot process is running inside container
check_bot_process() {
    if docker exec "$MAIN_CONTAINER_NAME" pgrep -f "python.*src[/.]bot" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get container resource usage
get_resource_usage() {
    local stats
    stats=$(docker stats "$MAIN_CONTAINER_NAME" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | tail -n 1)
    echo "$stats"
}

# Main monitoring loop
monitor_loop() {
    log_message "INFO" "Starting monitoring loop with ${MONITOR_INTERVAL}s interval"
    
    while true; do
        local status_ok=true
        local status_msg=""
        
        # Check if container is running
        if check_container_running; then
            status_msg="Container running"
            
            # Check health status
            check_container_health
            local health_code=$?
            
            case $health_code in
                0)
                    status_msg="$status_msg, healthy"
                    ;;
                1)
                    status_msg="$status_msg, UNHEALTHY"
                    status_ok=false
                    ;;
                2)
                    status_msg="$status_msg, starting"
                    ;;
                3)
                    status_msg="$status_msg, no health check"
                    ;;
                *)
                    status_msg="$status_msg, unknown health status"
                    ;;
            esac
            
            # Check bot process
            if check_bot_process; then
                status_msg="$status_msg, bot process active"
            else
                status_msg="$status_msg, bot process NOT found"
                status_ok=false
            fi
            
            # Get resource usage
            local resources
            resources=$(get_resource_usage)
            if [[ -n "$resources" ]]; then
                status_msg="$status_msg, resources: $resources"
            fi
            
        else
            status_msg="Container NOT running"
            status_ok=false
        fi
        
        # Log status
        if $status_ok; then
            log_message "INFO" "$status_msg"
        else
            log_message "WARN" "$status_msg"
        fi
        
        # Sleep until next check
        sleep "$MONITOR_INTERVAL"
    done
}

# Handle graceful shutdown
cleanup() {
    log_message "INFO" "Health monitor shutting down"
    exit 0
}

# Main execution
main() {
    # Setup signal handlers
    trap cleanup SIGTERM SIGINT
    
    # Initialize logging
    setup_logging
    
    log_message "INFO" "Health monitor configuration:"
    log_message "INFO" "  - Monitor interval: ${MONITOR_INTERVAL}s"
    log_message "INFO" "  - Main container: $MAIN_CONTAINER_NAME"
    log_message "INFO" "  - Log file: $LOG_FILE"
    
    # Wait a bit for main container to start
    log_message "INFO" "Waiting for main container to be ready..."
    sleep 10
    
    # Start monitoring
    monitor_loop
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 