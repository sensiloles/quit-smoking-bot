#!/bin/bash
# health-monitor.sh - Continuous health monitoring for development environment

set -e

# Configuration
MONITOR_INTERVAL=60
LOG_FILE="/workspace/logs/health-monitor.log"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=80
ALERT_THRESHOLD_DISK=85
MAX_LOG_SIZE=10485760  # 10MB

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Rotate log if too large
rotate_log() {
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Log rotated" > "$LOG_FILE"
    fi
}

# Log with timestamp
log_message() {
    local level="$1"
    local message="$2"
    rotate_log
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a "$LOG_FILE"
}

# Check CPU usage (simplified)
check_cpu_usage() {
    if [ -f "/proc/loadavg" ]; then
        local load_avg=$(cat /proc/loadavg | cut -d' ' -f1)
        local cpu_count=$(nproc 2>/dev/null || echo 1)
        local load_percent=$(echo "$load_avg * 100 / $cpu_count" | bc -l 2>/dev/null | cut -d'.' -f1 || echo 0)
        
        if [ "$load_percent" -gt $ALERT_THRESHOLD_CPU ]; then
            log_message "WARN" "High system load: ${load_avg} (${load_percent}%)"
            return 1
        else
            log_message "INFO" "System load: ${load_avg}"
        fi
    fi
    return 0
}

# Check memory usage
check_memory_usage() {
    if [ -f "/proc/meminfo" ]; then
        local mem_total mem_available mem_usage
        mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        mem_usage=$(( (mem_total - mem_available) * 100 / mem_total ))
        
        if [ "$mem_usage" -gt $ALERT_THRESHOLD_MEMORY ]; then
            log_message "WARN" "High memory usage: ${mem_usage}%"
            return 1
        else
            log_message "INFO" "Memory usage: ${mem_usage}%"
        fi
    fi
    return 0
}

# Check disk usage
check_disk_usage() {
    local workspace_usage
    workspace_usage=$(df /workspace | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$workspace_usage" -gt $ALERT_THRESHOLD_DISK ]; then
        log_message "WARN" "High disk usage: ${workspace_usage}%"
        return 1
    else
        log_message "INFO" "Disk usage: ${workspace_usage}%"
    fi
    return 0
}

# Check Docker daemon
check_docker_status() {
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            log_message "INFO" "Docker daemon is running"
        else
            log_message "WARN" "Docker daemon is not accessible"
            return 1
        fi
    else
        log_message "INFO" "Docker not installed"
    fi
    return 0
}

# Check workspace integrity
check_workspace_health() {
    local required_files=("main.py" "pyproject.toml" "scripts/bootstrap.sh")
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "/workspace/$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_message "ERROR" "Missing project files: ${missing_files[*]}"
        return 1
    else
        log_message "INFO" "Workspace integrity OK"
    fi
    return 0
}

# Send alert (placeholder for future integration)
send_alert() {
    local message="$1"
    log_message "ALERT" "$message"
    # TODO: Integrate with notification system (email, Slack, etc.)
}

# Main monitoring loop
main_loop() {
    log_message "INFO" "Health monitoring started (PID: $$)"
    
    while true; do
        local alerts=0
        
        # Run health checks
        check_cpu_usage || alerts=$((alerts + 1))
        check_memory_usage || alerts=$((alerts + 1))
        check_disk_usage || alerts=$((alerts + 1))
        check_docker_status || alerts=$((alerts + 1))
        check_workspace_health || alerts=$((alerts + 1))
        
        # Log summary
        if [ $alerts -eq 0 ]; then
            log_message "INFO" "All health checks passed"
        else
            log_message "WARN" "$alerts health check(s) failed"
            send_alert "Development environment has $alerts issues"
        fi
        
        # Wait for next check
        sleep $MONITOR_INTERVAL
    done
}

# Handle signals for graceful shutdown
cleanup() {
    log_message "INFO" "Health monitoring stopped"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start monitoring
main_loop 