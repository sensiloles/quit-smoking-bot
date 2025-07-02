#!/bin/bash
# health.sh - Health check and status monitoring utilities
#
# This module provides functions for checking container health,
# bot operational status, and system monitoring.

###########################
# Container Status Checks
###########################

# Check if bot is healthy using Docker healthcheck
is_bot_healthy() {
    debug_print "Starting is_bot_healthy check"
    # Ensure SYSTEM_NAME is properly exported before running docker-compose commands
    check_system_name
    local container_id=$(docker-compose ps -q bot)
    debug_print "Container ID: $container_id"

    if [ -z "$container_id" ]; then
        debug_print "Container is not running - no container ID found"
        print_error "Container is not running"
        return 1
    fi

    # Get container health status
    local health_status=$(docker inspect --format '{{.State.Health.Status}}' $container_id 2>/dev/null)
    debug_print "Container health status: $health_status"

    if [ "$health_status" = "healthy" ]; then
        debug_print "Container health check passed"
        print_message "Bot is healthy - container health check passed" "$GREEN"
        # Print the most recent health check log
        print_message "Last health check result:" "$YELLOW"
        docker inspect --format='{{range .State.Health.Log}}{{if eq .ExitCode 0}}{{.Output}}{{end}}{{end}}' $container_id | tail -1
        return 0
    elif [ "$health_status" = "starting" ]; then
        debug_print "Health check is still starting"
        print_message "Bot health check is still initializing" "$YELLOW"
        return 1
    else
        debug_print "Health check failed with status: $health_status"
        print_error "Bot health check failed - status: $health_status"
        # Print the most recent health check log
        print_message "Last health check result:" "$YELLOW"
        docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' $container_id | tail -1
        return 1
    fi
}

# Check if bot is operational
is_bot_operational() {
    debug_print "Starting is_bot_operational check"
    local max_attempts=30
    local attempt=1
    # Ensure SYSTEM_NAME is properly exported before running docker-compose commands
    check_system_name
    local container_id=$(docker-compose ps -q bot)
    debug_print "Container ID for operational check: $container_id"

    if [ -z "$container_id" ]; then
        debug_print "Container is not running for operational check"
        print_error "Container is not running"
        return 1
    fi

    # Check if Python process is running
    debug_print "Checking if Python bot process is running"
    if ! docker exec $container_id pgrep -f "python.*src[/.]bot" >/dev/null 2>&1; then
        debug_print "Bot process is not running inside container"
        print_error "Bot process is not running inside container"
        return 1
    fi
    debug_print "Bot process is running inside container"

    # Check container logs for operational messages
    debug_print "Checking logs for operational status"
    print_message "Checking logs for operational status..." "$YELLOW"
    logs=$(docker logs $container_id --tail 50 2>&1)

    # Check for conflict errors first - if found, report the conflict but don't return yet
    if echo "$logs" | grep -q "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates"; then
        print_error "Telegram API conflict detected - another bot is running with the same token"
        print_message "You will need to stop the other bot instance to use this one properly." "$YELLOW"
    fi

    if echo "$logs" | grep -q "Application started"; then
        print_message "Bot is operational" "$GREEN"
        return 0
    fi

    # Check for API calls - if multiple successful API calls have been made, consider it operational
    api_calls=$(echo "$logs" | grep -c "\"HTTP/1.1 200 OK\"")
    if [ "$api_calls" -ge 2 ]; then
        print_message "Bot is operational ($api_calls successful API calls detected)" "$GREEN"
        return 0
    fi

    # Even with conflicts, the bot might still be partly operational if it's still making API calls
    # If we found conflicts earlier, but the bot is still somewhat operational, return success
    # This allows the finalizeStartupCheck function to handle the conflict appropriately
    if echo "$logs" | grep -q "telegram.error.Conflict\|error_code\":409\|terminated by other getUpdates" && \
       echo "$logs" | grep -q "\"HTTP/1.1 200 OK\""; then
        print_message "Bot is partly operational despite conflicts" "$YELLOW"
        return 0
    fi

    print_error "Bot is not operational"
    return 1
}

# Function to check bot health and status after startup
check_bot_status() {
    print_message "\n=== BOT STATUS CHECK ===" "$BLUE"
    print_message "Checking bot status after startup..." "$YELLOW"
    local max_attempts=30
    local attempt=1

    # First, verify container is still running
    print_message "Step 1: Verifying container is running..." "$YELLOW"
    if ! docker-compose ps bot | grep -q "Up"; then
        print_error "Container is not running!"
        docker-compose ps bot
        return 1
    fi
    print_message "✅ Container is running" "$GREEN"

    # Wait a moment for the container to initialize
    print_message "Step 2: Waiting for container initialization (5 seconds)..." "$YELLOW"
    sleep 5

    # Show current container logs
    print_message "Step 3: Recent container logs:" "$YELLOW"
    docker-compose logs --tail 10 bot

    print_message "Step 4: Health check loop (max $max_attempts attempts)..." "$YELLOW"
    while [ $attempt -le $max_attempts ]; do
        print_message "Checking bot health (attempt $attempt/$max_attempts)..." "$YELLOW"

        # Check if container is still running (might have crashed)
        if ! docker-compose ps bot | grep -q "Up"; then
            print_error "Container stopped running during health check!"
            print_message "Container status:" "$RED"
            docker-compose ps bot
            print_message "Recent logs:" "$RED"
            docker-compose logs --tail 20 bot
            return 1
        fi

        # Check if bot is healthy using Docker healthcheck
        if is_bot_healthy; then
            print_message "Bot health check: PASSED" "$GREEN"
            break
        else
            if [ $attempt -eq $max_attempts ]; then
                print_message "Bot health check did not pass within timeout, but bot might still be functioning." "$YELLOW"
                print_message "Continuing with operational check..." "$YELLOW"
                # Show recent logs for debugging
                print_message "Recent logs for debugging:" "$YELLOW"
                docker-compose logs --tail 15 bot
            else
                print_message "Bot health check not yet passing, waiting..." "$YELLOW"
                sleep 5
                ((attempt++))
                continue
            fi
        fi

        ((attempt++))
    done

    print_message "Step 5: Operational check..." "$YELLOW"
    # Check if bot is operational
    if is_bot_operational; then
        print_message "Bot operational check: PASSED" "$GREEN"
        print_message "🎉 Bot is fully operational!" "$GREEN"
        
        # Show final status summary
        print_message "\n=== FINAL STATUS SUMMARY ===" "$GREEN"
        print_message "Container status:" "$GREEN"
        docker-compose ps bot
        print_message "Most recent logs:" "$GREEN"
        docker-compose logs --tail 5 bot
        print_message "=== END STATUS SUMMARY ===" "$GREEN"
        
        return 0
    else
        print_message "Bot operational check: NOT PASSED" "$YELLOW"
        print_message "Bot is running but might not be fully operational." "$YELLOW"
        
        # Detailed diagnostic info
        print_message "\n=== DIAGNOSTIC INFORMATION ===" "$YELLOW"
        print_message "Container status:" "$YELLOW"
        docker-compose ps bot
        print_message "Extended logs for diagnostics:" "$YELLOW"
        docker-compose logs --tail 25 bot
        print_message "=== END DIAGNOSTICS ===" "$YELLOW"
        
        print_message "Use './scripts/check-service.sh' for detailed diagnostics." "$YELLOW"
        return 1
    fi
}

######################
# Health Check Functions  
######################

# Configuration - adapt paths based on environment
if [[ -d "/app" && -w "/app" ]]; then
    # Inside container
    readonly HEALTH_DIR="/app/logs"
    readonly LOG_FILE="$HEALTH_DIR/health.log"
else
    # Outside container
    readonly HEALTH_DIR="./logs"
    readonly LOG_FILE="$HEALTH_DIR/health.log"
fi
readonly OPERATIONAL_FILE="$HEALTH_DIR/operational"
readonly MAX_LOG_SIZE=5000

# Initialize health directory
init_health_dir() {
    if [[ ! -d "$HEALTH_DIR" ]]; then
        mkdir -p "$HEALTH_DIR" 2>/dev/null || {
            debug_print "Cannot create health directory: $HEALTH_DIR"
            return 1
        }
        chmod 755 "$HEALTH_DIR" 2>/dev/null
        debug_print "Health directory created: $HEALTH_DIR"
    fi
    
    if [[ ! -w "$HEALTH_DIR" ]]; then
        chmod 755 "$HEALTH_DIR" 2>/dev/null || {
            debug_print "Cannot write to health directory: $HEALTH_DIR"
            return 1
        }
        debug_print "Health directory permissions fixed"
    fi
}

# Health-specific logging
health_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Initialize health dir if needed
    init_health_dir
    
    # Log to health log file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Also use standard logging if available
    if type -t debug_print >/dev/null 2>&1; then
        debug_print "HEALTH: [$level] $message"
    fi
    
    # Console output for health checks
    echo "[$level] $message"
    
    # Truncate log if too big
    if [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
        tail -n $(($MAX_LOG_SIZE / 2)) "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
        health_log "INFO" "Log file truncated due to size limit"
    fi
}

# Check if bot process is running
check_bot_process() {
    if pgrep -f "python.*src.*bot" > /dev/null 2>&1; then
        health_log "INFO" "Bot process is running"
        return 0
    else
        health_log "ERROR" "Bot process is not running"
        return 1
    fi
}

# Check operational marker file
check_operational_marker() {
    if [[ -f "$OPERATIONAL_FILE" ]]; then
        local file_age=$(($(date +%s) - $(date -r "$OPERATIONAL_FILE" +%s 2>/dev/null || echo 0)))
        
        if [[ $file_age -gt 300 ]]; then # 5 minutes
            health_log "WARN" "Operational file is stale (${file_age}s old)"
            
            # Update if process is running
            if pgrep -f "python.*src.*bot" > /dev/null 2>&1; then
                touch "$OPERATIONAL_FILE"
                health_log "INFO" "Updated stale operational file"
                return 0
            else
                return 1
            fi
        fi
        
        health_log "INFO" "Operational marker is valid (age: ${file_age}s)"
        return 0
    else
        health_log "ERROR" "Operational marker file missing"
        
        # Create if process is running
        if pgrep -f "python.*src.*bot" > /dev/null 2>&1; then
            touch "$OPERATIONAL_FILE"
            chmod 644 "$OPERATIONAL_FILE"
            health_log "INFO" "Created missing operational marker"
            return 0
        fi
        
        return 1
    fi
}

# Check for critical errors in logs
check_logs_for_errors() {
    if [[ ! -f "/app/logs/bot.log" ]]; then
        health_log "WARN" "Bot log file not found"
        return 0
    fi
    
    # Check for critical errors
    local critical_errors=$(grep -c "ERROR.*bot crashed" /app/logs/bot.log 2>/dev/null || echo 0)
    if [[ $critical_errors -gt 0 ]]; then
        health_log "ERROR" "Found $critical_errors critical errors in logs"
        return 1
    fi
    
    # Check for conflict errors (recent only)
    local recent_conflicts=$(tail -n 200 /app/logs/bot.log | grep -c "Conflict: terminated by other getUpdates request" 2>/dev/null || echo 0)
    if [[ $recent_conflicts -gt 3 ]]; then
        health_log "ERROR" "Found multiple conflict errors: another bot instance detected"
        return 1
    fi
    
    health_log "INFO" "Log analysis passed"
    return 0
}

# Check container health status (Docker)
check_container_health() {
    local container_name="${1:-${SYSTEM_NAME:-quit-smoking-bot}}"
    
    if ! command -v docker >/dev/null 2>&1; then
        health_log "WARN" "Docker not available for container health check"
        return 0
    fi
    
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-container")
    
    case "$health_status" in
        "healthy")
            health_log "INFO" "Container health: healthy"
            return 0
            ;;
        "unhealthy")
            health_log "ERROR" "Container health: unhealthy"
            return 1
            ;;
        "starting")
            health_log "INFO" "Container health: starting"
            return 0
            ;;
        "no-healthcheck")
            health_log "WARN" "Container has no health check configured"
            return 0
            ;;
        "no-container")
            health_log "WARN" "Container not found or not accessible"
            return 0
            ;;
        *)
            health_log "WARN" "Unknown container health status: $health_status"
            return 0
            ;;
    esac
}

# Check if container is running
check_container_running() {
    local container_name="${1:-${SYSTEM_NAME:-quit-smoking-bot}}"
    
    if ! command -v docker >/dev/null 2>&1; then
        health_log "WARN" "Docker not available for container check"
        return 0
    fi
    
    if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        health_log "INFO" "Container is running"
        return 0
    else
        health_log "ERROR" "Container is not running"
        return 1
    fi
}

# Get container resource usage
get_container_resources() {
    local container_name="${1:-${SYSTEM_NAME:-quit-smoking-bot}}"
    
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker not available"
        return 1
    fi
    
    local stats=$(docker stats "$container_name" --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "N/A")
    echo "$stats"
}

# Comprehensive health check
comprehensive_health_check() {
    local failed_checks=0
    
    health_log "INFO" "Starting comprehensive health check"
    
    # Check bot process
    if ! check_bot_process; then
        ((failed_checks++))
    fi
    
    # Check operational marker
    if ! check_operational_marker; then
        ((failed_checks++))
    fi
    
    # Check logs for errors
    if ! check_logs_for_errors; then
        ((failed_checks++))
    fi
    
    # Check container health if available
    check_container_health
    
    # Report results
    if [[ $failed_checks -eq 0 ]]; then
        health_log "INFO" "All health checks passed"
        return 0
    else
        health_log "ERROR" "$failed_checks health checks failed"
        return 1
    fi
}

# Quick health check (for Docker healthcheck)
quick_health_check() {
    # Just the essential checks
    if ! check_bot_process; then
        return 1
    fi
    
    if ! check_operational_marker; then
        return 1
    fi
    
    health_log "INFO" "Quick health check passed"
    return 0
}

# Monitor health check (for monitoring service)
monitor_health_check() {
    local container_name="${1:-${SYSTEM_NAME:-quit-smoking-bot}}"
    local status_msg=""
    local status_ok=true
    
    # Check container running
    if check_container_running "$container_name"; then
        status_msg="Container running"
        
        # Check container health
        if check_container_health "$container_name"; then
            status_msg="$status_msg, healthy"
        else
            status_msg="$status_msg, unhealthy"
            status_ok=false
        fi
        
        # Check bot process
        if check_bot_process; then
            status_msg="$status_msg, bot process active"
        else
            status_msg="$status_msg, bot process NOT found"
            status_ok=false
        fi
        
        # Get resources
        local resources=$(get_container_resources "$container_name")
        if [[ "$resources" != "N/A" ]]; then
            status_msg="$status_msg, resources: $resources"
        fi
        
    else
        status_msg="Container NOT running"
        status_ok=false
    fi
    
    if $status_ok; then
        health_log "INFO" "$status_msg"
        return 0
    else
        health_log "WARN" "$status_msg"
        return 1
    fi
} 