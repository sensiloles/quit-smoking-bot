#!/bin/bash
# health.sh - Universal health check script for the Telegram bot
#
# This script replaces healthcheck.sh, health-monitor.sh and provides health functionality
# Usage modes:
#   --mode docker      # For Docker healthcheck (minimal, fast)
#   --mode monitor     # For continuous monitoring (detailed)
#   --mode diagnostics # For comprehensive diagnostics
#   --mode status      # For status checks

# Source bootstrap to load all modules
source "$(dirname "$0")/bootstrap.sh"

# Script-specific configuration
readonly SCRIPT_NAME="health"
readonly HEALTH_LOG_FILE="/app/logs/health.log"

# Default values
MODE="docker"
CONTINUOUS=false
INTERVAL=30

show_help() {
    cat << EOF
Usage: $0 [options]

Universal health check script for the Telegram bot service.

Modes:
  --mode docker        Docker healthcheck mode (default) - minimal, fast checks
  --mode monitor       Monitoring mode - detailed continuous monitoring
  --mode diagnostics   Diagnostic mode - comprehensive system analysis  
  --mode status        Status mode - current status snapshot

Options:
  --continuous         Run in continuous mode (for monitor mode)
  --interval SECONDS   Monitoring interval in seconds (default: 30)
  --help               Show this help message

Examples:
  $0                                    # Docker healthcheck (default)
  $0 --mode docker                      # Explicit Docker healthcheck
  $0 --mode monitor                     # Single monitoring check
  $0 --mode monitor --continuous        # Continuous monitoring
  $0 --mode diagnostics                 # Full system diagnostics
  $0 --mode status                      # Status snapshot

Environment Variables:
  HEALTH_MODE          Set default mode (docker|monitor|diagnostics|status)
  HEALTH_INTERVAL      Set default monitoring interval
EOF
}

# Parse arguments specific to health script
parse_health_arguments() {
    debug_print "Starting health script argument parsing"
    
    # Use environment variables as defaults
    MODE="${HEALTH_MODE:-$MODE}"
    INTERVAL="${HEALTH_INTERVAL:-$INTERVAL}"
    
    while [[ "$#" -gt 0 ]]; do
        debug_print "Processing health argument: $1"
        case $1 in
            --mode)
                if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                    MODE="$2"
                    shift
                else
                    print_error "Mode requires a value (docker|monitor|diagnostics|status)"
                    exit 1
                fi
                ;;
            --continuous)
                CONTINUOUS=true
                ;;
            --interval)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    INTERVAL="$2"
                    shift
                else
                    print_error "Interval requires a numeric value"
                    exit 1
                fi
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                debug_print "Unknown health argument: $1"
                print_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    # Validate mode
    case "$MODE" in
        docker|monitor|diagnostics|status)
            debug_print "Health mode set to: $MODE"
            ;;
        *)
            print_error "Invalid mode: $MODE. Must be docker|monitor|diagnostics|status"
            exit 1
            ;;
    esac
    
    debug_print "Health argument parsing completed: mode=$MODE, continuous=$CONTINUOUS, interval=$INTERVAL"
}

# Run Docker healthcheck mode
run_docker_mode() {
    debug_print "Running Docker healthcheck mode"
    print_message "🔍 Docker Health Check" "${BLUE:-}"
    
    # Use quick health check for Docker (minimal overhead)
    if quick_health_check; then
        print_message "✅ Health check passed" "${GREEN:-}"
        exit 0
    else
        print_message "❌ Health check failed" "${RED:-}"
        exit 1
    fi
}

# Run monitoring mode
run_monitor_mode() {
    debug_print "Running monitoring mode (continuous=$CONTINUOUS)"
    
    if $CONTINUOUS; then
        print_message "🔄 Starting continuous monitoring (interval: ${INTERVAL}s)" "${BLUE:-}"
        print_message "Press Ctrl+C to stop" "${YELLOW:-}"
        
        while true; do
            local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
            print_message "\n[$timestamp] Health Monitor Check:" "${BLUE:-}"
            
            if monitor_health_check; then
                print_message "✅ System healthy" "${GREEN:-}"
            else
                print_message "⚠️  System issues detected" "${YELLOW:-}"
            fi
            
            sleep "$INTERVAL"
        done
    else
        print_message "🔍 Single Monitoring Check" "${BLUE:-}"
        
        if monitor_health_check; then
            print_message "✅ System healthy" "${GREEN:-}"
            exit 0
        else
            print_message "⚠️  System issues detected" "${YELLOW:-}"
            exit 1
        fi
    fi
}

# Run diagnostics mode
run_diagnostics_mode() {
    debug_print "Running diagnostics mode"
    print_message "🔬 Comprehensive System Diagnostics" "${BLUE:-}"
    
    local total_checks=0
    local failed_checks=0
    
    # Health checks
    print_section "Health Status"
    ((total_checks++))
    if comprehensive_health_check; then
        print_message "✅ Health checks passed" "${GREEN:-}"
    else
        print_message "❌ Health checks failed" "${RED:-}"
        ((failed_checks++))
    fi
    
    # Container diagnostics
    if command -v docker >/dev/null 2>&1; then
        print_section "Container Status"
        ((total_checks++))
        
        local container_name="${SYSTEM_NAME:-quit-smoking-bot}"
        if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            print_message "✅ Container is running" "${GREEN:-}"
            
            # Show container details
            print_message "\nContainer Details:" "${YELLOW:-}"
            docker ps --filter "name=$container_name" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"
            
            # Show resource usage
            local resources=$(get_container_resources "$container_name")
            if [[ "$resources" != "N/A" ]]; then
                print_message "\nResource Usage:" "${YELLOW:-}"
                echo -e "CPU\tMemory"
                echo -e "$resources"
            fi
            
            # Show logs (last 10 lines)
            print_message "\nRecent Logs:" "${YELLOW:-}"
            docker logs "$container_name" --tail 10 2>/dev/null || print_message "Unable to get logs" "${RED:-}"
            
        else
            print_message "❌ Container is not running" "${RED:-}"
            ((failed_checks++))
        fi
    else
        print_message "⚠️  Docker not available for container diagnostics" "${YELLOW:-}"
    fi
    
    # File system checks
    print_section "File System"
    ((total_checks++))
    
    local fs_issues=0
    
    # Check data directory
    if [[ -d "./data" ]]; then
        local data_size=$(du -sh ./data 2>/dev/null | cut -f1 || echo "Unknown")
        local data_files=$(find ./data -type f 2>/dev/null | wc -l || echo "Unknown")
        print_message "✅ Data directory: $data_size, $data_files files" "${GREEN:-}"
    else
        print_message "⚠️  Data directory not found" "${YELLOW:-}"
        ((fs_issues++))
    fi
    
    # Check logs directory
    if [[ -d "./logs" ]]; then
        local logs_size=$(du -sh ./logs 2>/dev/null | cut -f1 || echo "Unknown")
        local log_files=$(find ./logs -name "*.log" 2>/dev/null | wc -l || echo "Unknown")
        print_message "✅ Logs directory: $logs_size, $log_files log files" "${GREEN:-}"
    else
        print_message "⚠️  Logs directory not found" "${YELLOW:-}"
        ((fs_issues++))
    fi
    
    if [[ $fs_issues -eq 0 ]]; then
        print_message "✅ File system checks passed" "${GREEN:-}"
    else
        print_message "⚠️  File system issues detected" "${YELLOW:-}"
        ((failed_checks++))
    fi
    
    # Summary
    print_section "Diagnostics Summary"
    print_message "Total checks: $total_checks" "${BLUE:-}"
    print_message "Failed checks: $failed_checks" "${BLUE:-}"
    
    if [[ $failed_checks -eq 0 ]]; then
        print_message "✅ All diagnostics passed" "${GREEN:-}"
        exit 0
    else
        print_message "⚠️  $failed_checks/$total_checks checks failed" "${YELLOW:-}"
        exit 1
    fi
}

# Run status mode
run_status_mode() {
    debug_print "Running status mode"
    print_message "📊 System Status Snapshot" "${BLUE:-}"
    
    # Quick overview
    local status_summary=""
    local status_ok=true
    
    # Check bot process
    if check_bot_process >/dev/null 2>&1; then
        status_summary="Bot process: ✅ Running"
    else
        status_summary="Bot process: ❌ Not running"
        status_ok=false
    fi
    
    # Check container
    if command -v docker >/dev/null 2>&1; then
        local container_name="${SYSTEM_NAME:-quit-smoking-bot}"
        if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            status_summary="$status_summary | Container: ✅ Running"
            
            # Check health
            local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")
            case "$health_status" in
                "healthy")
                    status_summary="$status_summary | Health: ✅ Healthy"
                    ;;
                "unhealthy")
                    status_summary="$status_summary | Health: ❌ Unhealthy"
                    status_ok=false
                    ;;
                "starting")
                    status_summary="$status_summary | Health: 🔄 Starting"
                    ;;
                *)
                    status_summary="$status_summary | Health: ⚠️  $health_status"
                    ;;
            esac
            
            # Add resources
            local resources=$(get_container_resources "$container_name")
            if [[ "$resources" != "N/A" ]]; then
                status_summary="$status_summary | Resources: $resources"
            fi
        else
            status_summary="$status_summary | Container: ❌ Not running"
            status_ok=false
        fi
    fi
    
    # Print status
    print_message "$status_summary" "$($status_ok && echo "${GREEN:-}" || echo "${YELLOW:-}")"
    
    if $status_ok; then
        exit 0
    else
        exit 1
    fi
}

# Main function
main() {
    debug_print "Starting health.sh script with arguments: $@"
    
    # Parse arguments
    parse_health_arguments "$@"
    
    # Run based on mode
    case "$MODE" in
        docker)
            run_docker_mode
            ;;
        monitor)
            run_monitor_mode
            ;;
        diagnostics)
            run_diagnostics_mode
            ;;
        status)
            run_status_mode
            ;;
        *)
            print_error "Invalid mode: $MODE"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 