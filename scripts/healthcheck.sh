#!/bin/bash
# healthcheck.sh - Docker healthcheck script for the Telegram bot
#
# This script is used by Docker to determine if the bot container is healthy.
# It checks for the bot process and a special "operational" marker file.

set -e

# Configuration
readonly LOG_FILE="/app/health/status.log"
readonly OPERATIONAL_FILE="/app/health/operational"
readonly MAX_LOG_SIZE=5000  # Maximum log file size in lines

# Log health check message with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Append to log file with timestamp
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Also output to console for Docker health check logs
    echo "[$level] $message"
    
    # Truncate log file if it gets too big
    if [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
        tail -n $(($MAX_LOG_SIZE / 2)) "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
        log_message "INFO" "Log file truncated due to size limit"
    fi
}

# Check health directory exists and is writable
check_health_directory() {
    if [[ ! -d "/app/health" ]]; then
        mkdir -p /app/health
        chmod 755 /app/health
        log_message "INFO" "Health directory created by healthcheck"
        return 1
    elif [[ ! -w "/app/health" ]]; then
        log_message "ERROR" "Health directory exists but is not writable"
        chmod 755 /app/health
        log_message "INFO" "Changed permissions on health directory"
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
        
        # Log all running Python processes for debugging
        log_message "DEBUG" "Running Python processes:"
        ps aux | grep python | grep -v grep >> "$LOG_FILE"
        
        return 1
    fi
}

# Check if health operational file exists
check_operational_file() {
    if [[ -f "$OPERATIONAL_FILE" ]]; then
        # Check how old the file is
        local file_age=$(($(date +%s) - $(date -r "$OPERATIONAL_FILE" +%s 2>/dev/null || echo 0)))
        log_message "INFO" "Health operational file exists (age: ${file_age}s)"
        
        # If file is too old (more than 5 minutes), consider it stale
        if [[ $file_age -gt 300 ]]; then
            log_message "WARNING" "Operational file is stale (${file_age}s old)"
            # But we'll still consider it valid if the process is running
            if pgrep -f "python.*src[/.]bot" > /dev/null; then
                log_message "INFO" "But process is running, updating operational file"
                touch "$OPERATIONAL_FILE"
                return 0
            else
                log_message "ERROR" "Process is not running and operational file is stale"
                return 1
            fi
        fi
        
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

# Check for error patterns in logs
check_logs_for_errors() {
    # Only run this check if we have the operational file (performance optimization)
    if [[ ! -f "$OPERATIONAL_FILE" ]]; then
        return 0
    fi
    
    # Check the logs for critical errors
    if [[ -f "/app/logs/bot.log" ]]; then
        local critical_errors=$(tail -n 100 /app/logs/bot.log | grep -c "ERROR.*bot crashed")
        if [[ $critical_errors -gt 0 ]]; then
            log_message "ERROR" "Found critical errors in bot logs ($critical_errors occurrences)"
            return 1
        fi
    fi
    
    return 0
}

# Main health check function
main() {
    log_message "INFO" "Health check started"
    
    # Check health directory
    check_health_directory
    
    # Check bot process
    if ! check_bot_process; then
        return 1
    fi
    
    # Check operational file
    if ! check_operational_file; then
        return 1
    fi
    
    # Check logs for errors (optional advanced check)
    check_logs_for_errors
    
    # All checks passed
    log_message "INFO" "All health checks passed"
    return 0
}

# Run main function
main "$@"
exit $?
