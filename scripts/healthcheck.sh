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
        # Get container startup time (or file creation time as fallback)
        local container_start_time=$(stat -c %Y /proc/1/cmdline 2>/dev/null || stat -c %Y "$OPERATIONAL_FILE")
        local current_time=$(date +%s)
        
        # Only check for errors in the current session (using timestamp filtering)
        local critical_errors=$(grep -a "ERROR.*bot crashed" /app/logs/bot.log | grep -a -v "^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9].*" | wc -l)
        
        if [[ $critical_errors -gt 0 ]]; then
            log_message "ERROR" "Found critical errors in bot logs ($critical_errors occurrences)"
            return 1
        fi
        
        # For conflict errors, we'll check only the last minute (60 seconds) of logs
        # This is sufficient because conflict errors would be ongoing if there's a real issue
        local recent_log_file="/tmp/recent_logs.txt"
        tail -n 200 /app/logs/bot.log > "$recent_log_file"
        
        # Check for conflict errors with other bot instances only in recent logs
        local conflict_errors=$(grep -c "Conflict: terminated by other getUpdates request" "$recent_log_file")
        
        if [[ $conflict_errors -gt 3 ]]; then
            # Verify that these are recent conflicts by checking if they occurred after startup
            local recent_conflicts=$(grep -a "Conflict: terminated by other getUpdates request" "$recent_log_file" | tail -n 5)
            
            # Only fail health check if conflicts are from the current session
            if [[ -n "$recent_conflicts" ]]; then
                log_message "ERROR" "Found multiple conflict errors in logs: another bot instance is running with the same token"
                log_message "ERROR" "Please stop the other bot instance before running this one"
                
                # Write a summary of the errors
                echo "Conflict detected - Multiple instances using the same token" > /app/health/conflict_detected
                return 1
            else
                log_message "INFO" "Found old conflict errors in logs, but they are not from the current session"
            fi
        fi
        
        # Clean up
        rm -f "$recent_log_file"
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
