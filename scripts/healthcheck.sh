#!/bin/bash
set -e

# Script for Docker healthcheck
LOG_FILE="/app/health/status.log"
OPERATIONAL_FILE="/app/health/operational"

# Log health check message with timestamp
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
    echo "[$level] $message"
}

# Check health directory exists and is writable
check_health_directory() {
    if [ ! -d "/app/health" ]; then
        log_message "ERROR" "Health directory does not exist"
        mkdir -p /app/health
        chmod 755 /app/health
        log_message "INFO" "Health directory created by healthcheck"
        return 1
    fi
    return 0
}

# Check if bot process is running
check_bot_process() {
    if pgrep -f "python.*src[/.]bot" > /dev/null; then
        log_message "INFO" "Bot process is running"
        return 0
    else
        log_message "ERROR" "Bot process is not running"
        ps aux | grep python
        return 1
    fi
}

# Check if health operational file exists
check_operational_file() {
    if [ -f "$OPERATIONAL_FILE" ]; then
        log_message "INFO" "Health operational file exists"
        return 0
    else
        log_message "ERROR" "Health operational file does not exist"
        # Try to create it if the process is actually running
        if pgrep -f "python.*src[/.]bot" > /dev/null; then
            touch "$OPERATIONAL_FILE"
            chmod 644 "$OPERATIONAL_FILE"
            log_message "INFO" "Created missing operational file as bot process is running"
            return 0
        else
            return 1
        fi
    fi
}

# Main health check function
main() {
    log_message "INFO" "Health check started"
    
    # Check health directory
    check_health_directory
    
    # Check bot process
    check_bot_process || return 1
    
    # Check operational file
    check_operational_file || return 1
    
    # All checks passed
    log_message "INFO" "All health checks passed"
    return 0
}

# Run main function
main "$@"
exit $? 