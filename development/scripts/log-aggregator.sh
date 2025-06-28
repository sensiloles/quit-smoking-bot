#!/bin/bash
# log-aggregator.sh - Simplified log aggregation for development environment

set -e

# Configuration
WORKSPACE_PATH="/workspace"
LOG_DIR="$WORKSPACE_PATH/logs"
AGGREGATED_LOG="$LOG_DIR/development.log"
SUPERVISOR_LOG_DIR="/var/log/supervisor"
AGGREGATION_INTERVAL=30
MAX_LOG_SIZE=10485760  # 10MB (reduced from 50MB)
MAX_LOGS_KEEP=3        # Keep fewer logs

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Simplified log rotation
rotate_aggregated_log() {
    if [ -f "$AGGREGATED_LOG" ] && [ $(stat -c%s "$AGGREGATED_LOG" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]; then
        mv "$AGGREGATED_LOG" "${AGGREGATED_LOG}.1"
        [ -f "${AGGREGATED_LOG}.2" ] && rm -f "${AGGREGATED_LOG}.2"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [SYSTEM] Log aggregation started" > "$AGGREGATED_LOG"
    fi
}

# Log with source identification
log_with_source() {
    local source="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$source] $message" >> "$AGGREGATED_LOG"
}

# Simplified supervisor logs aggregation
aggregate_supervisor_logs() {
    [ ! -d "$SUPERVISOR_LOG_DIR" ] && return
    
    for logfile in "$SUPERVISOR_LOG_DIR"/*.log; do
        [ ! -f "$logfile" ] && continue
        
        local source=$(basename "$logfile" .log)
        local marker="/tmp/last_${source}_line"
        
        if [ -f "$marker" ]; then
            tail -n +$((($(cat "$marker") + 1))) "$logfile" | head -n 50 | while read -r line; do
                [ -n "$line" ] && log_with_source "SUPERVISOR-$source" "$line"
            done
        else
            tail -n 5 "$logfile" | while read -r line; do
                [ -n "$line" ] && log_with_source "SUPERVISOR-$source" "$line"
            done
        fi
        
        wc -l < "$logfile" > "$marker"
    done
}

# Simplified application logs aggregation
aggregate_app_logs() {
    local app_logs=(
        "$WORKSPACE_PATH/logs/quit-smoking-bot.log"
        "$WORKSPACE_PATH/data/bot.log"
    )
    
    for logfile in "${app_logs[@]}"; do
        [ ! -f "$logfile" ] && continue
        
        local source=$(basename "$logfile" .log)
        local marker="/tmp/last_${source}_app_line"
        
        if [ -f "$marker" ]; then
            tail -n +$((($(cat "$marker") + 1))) "$logfile" | head -n 50 | while read -r line; do
                [ -n "$line" ] && log_with_source "APP-$source" "$line"
            done
        else
            tail -n 3 "$logfile" | while read -r line; do
                [ -n "$line" ] && log_with_source "APP-$source" "$line"
            done
        fi
        
        wc -l < "$logfile" > "$marker"
    done
}

# Aggregate system logs
aggregate_system_logs() {
    # CPU and memory stats
    if command -v free >/dev/null 2>&1; then
        local mem_info
        mem_info=$(free -h | grep '^Mem:' | awk '{print "Used: "$3", Free: "$4", Available: "$7}')
        log_with_source "SYSTEM" "Memory - $mem_info"
    fi
    
    # Disk usage
    local disk_info
    disk_info=$(df -h "$WORKSPACE_PATH" | awk 'NR==2 {print "Disk usage: "$5" ("$3"/"$2")"}')
    log_with_source "SYSTEM" "$disk_info"
    
    # Load average
    if [ -f "/proc/loadavg" ]; then
        local load_avg
        load_avg=$(cat /proc/loadavg | cut -d' ' -f1-3)
        log_with_source "SYSTEM" "Load average: $load_avg"
    fi
    
    # Running processes count
    local proc_count
    proc_count=$(ps aux | wc -l)
    log_with_source "SYSTEM" "Running processes: $proc_count"
}

# Generate log summary
generate_summary() {
    local summary_file="$LOG_DIR/summary.log"
    
    {
        echo "=== Development Environment Summary - $(date) ==="
        echo ""
        
        # System information
        echo "System Information:"
        echo "  OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
        echo "  Kernel: $(uname -r)"
        echo "  Uptime: $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
        echo ""
        
        # Resource usage
        echo "Resource Usage:"
        if command -v free >/dev/null 2>&1; then
            echo "  Memory: $(free -h | grep '^Mem:' | awk '{print $3"/"$2" ("$3"/"$2*100"%)"}')"
        fi
        echo "  Disk: $(df -h "$WORKSPACE_PATH" | awk 'NR==2 {print $3"/"$2" ("$5")"}')"
        echo ""
        
        # Recent errors
        echo "Recent Errors (last 10):"
        if [ -f "$AGGREGATED_LOG" ]; then
            grep -i "error\|fail\|exception" "$AGGREGATED_LOG" | tail -n 10 | while read -r line; do
                echo "  $line"
            done
        fi
        echo ""
        
        # Service status
        echo "Services Status:"
        if command -v supervisorctl >/dev/null 2>&1; then
            supervisorctl status 2>/dev/null | while read -r line; do
                echo "  $line"
            done
        fi
        
    } > "$summary_file"
}

# Main aggregation loop
main_loop() {
    log_with_source "SYSTEM" "Log aggregation started (PID: $$)"
    
    while true; do
        # Rotate logs if needed
        rotate_aggregated_log
        
        # Aggregate logs from different sources
        aggregate_supervisor_logs
        aggregate_app_logs
        aggregate_system_logs
        
        # Generate summary every 10 iterations (5 minutes)
        local iteration_file="/tmp/log_aggregator_iteration"
        local iteration=1
        if [ -f "$iteration_file" ]; then
            iteration=$(cat "$iteration_file")
        fi
        
        if [ $((iteration % 10)) -eq 0 ]; then
            generate_summary
            log_with_source "SYSTEM" "Generated log summary"
        fi
        
        echo $((iteration + 1)) > "$iteration_file"
        
        # Log aggregation status
        log_with_source "SYSTEM" "Log aggregation cycle completed"
        
        sleep $AGGREGATION_INTERVAL
    done
}

# Handle signals for graceful shutdown
cleanup() {
    log_with_source "SYSTEM" "Log aggregation stopped"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start log aggregation
main_loop 