#!/bin/bash
# entrypoint.sh - Docker entrypoint script for the Telegram bot
#
# This script initializes the bot environment, runs startup checks,
# and launches the bot application.

set -e

# Configuration
readonly DATA_DIR="/app/data"
readonly LOGS_DIR="/app/logs"
readonly HEALTH_DIR="/app/health"
readonly DEFAULT_JSON_FILES=("bot_admins.json" "bot_users.json" "quotes.json")

# Log message to console with timestamp
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message"
    
    # Also use debug_print if DEBUG mode is enabled
    if [ "${DEBUG:-0}" = "1" ]; then
        echo "DEBUG: [entrypoint.sh] [$level] $message" >&2
    fi
}

# Initialize the health monitoring system
setup_health_system() {
    log_message "INFO" "Initializing health monitoring system"

    # Create health directory if it doesn't exist
    mkdir -p "$HEALTH_DIR"
    chmod 755 "$HEALTH_DIR"

    # Remove any existing operational file to start fresh
    rm -f "$HEALTH_DIR/operational"
    touch "$HEALTH_DIR/starting"

    # Initialize status log
    echo "$(date): Health check directory initialized" > "$HEALTH_DIR/status.log"
    echo "$(date): Bot is starting up" >> "$HEALTH_DIR/status.log"

    log_message "INFO" "Health monitoring system initialized"
}

# Rotate logs to prevent accumulation of old errors
rotate_logs() {
    log_message "INFO" "Setting up log rotation"

    # Create logs directory if it doesn't exist
    mkdir -p "$LOGS_DIR"

    # If log file exists and is not empty, rotate it
    if [ -s "$LOGS_DIR/bot.log" ]; then
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        local backup_dir="$LOGS_DIR/archive"

        # Create archive directory if it doesn't exist
        mkdir -p "$backup_dir"

        # Move current log to archive with timestamp
        log_message "INFO" "Rotating existing log file to archive"
        cp "$LOGS_DIR/bot.log" "$backup_dir/bot_${timestamp}.log"

        # Reset current log file (create new empty file)
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Log file rotated - new session started" > "$LOGS_DIR/bot.log"

        # Clean up old archives (keep last 5)
        if [ "$(ls -1 "$backup_dir" | wc -l)" -gt 5 ]; then
            log_message "INFO" "Cleaning up old log archives, keeping only the 5 most recent"
            ls -1t "$backup_dir" | tail -n +6 | xargs -I {} rm "$backup_dir/{}"
        fi
    else
        # Create new log file if it doesn't exist
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] New log file created - session started" > "$LOGS_DIR/bot.log"
    fi

    # Ensure proper permissions
    chmod 644 "$LOGS_DIR/bot.log"

    log_message "INFO" "Log rotation completed"
}

# Initialize data directory and create default files if missing
setup_data_directory() {
    log_message "INFO" "Checking data directory and files"

    # Create data directory if it doesn't exist
    mkdir -p "$DATA_DIR"

    # Create default JSON files if they don't exist
    for file in "${DEFAULT_JSON_FILES[@]}"; do
        if [ ! -f "$DATA_DIR/$file" ]; then
            log_message "WARN" "$file not found, creating empty file"
            echo '[]' > "$DATA_DIR/$file"
            chmod 644 "$DATA_DIR/$file"
        fi
    done

    # List data directory contents for logging
    log_message "INFO" "Data directory contents:"
    ls -la "$DATA_DIR/" | sed 's/^/    /'
}


# Start the health monitoring daemon in the background
start_health_monitor() {
    log_message "INFO" "Starting health monitor daemon"

    (
        # Wait for the bot to start up before first check
        sleep 10

        # Check every 20 seconds if the bot is operational
        while true; do
            echo "$(date): Running health check monitoring cycle" >> "$HEALTH_DIR/status.log"

            # Check if the bot process is running
            if pgrep -f "python.*src[/.]bot" > /dev/null; then
                # Mark as operational if running
                touch "$HEALTH_DIR/operational"
                chmod 644 "$HEALTH_DIR/operational"
                echo "$(date): Bot process is running, health marker updated" >> "$HEALTH_DIR/status.log"
            else
                # Remove operational marker if not running
                rm -f "$HEALTH_DIR/operational"
                echo "$(date): WARNING - Bot process not found, removed health marker" >> "$HEALTH_DIR/status.log"
            fi

            sleep 20
        done
    ) &

    log_message "INFO" "Health monitor daemon started"
}

# Start the bot application
start_bot() {
    log_message "INFO" "Starting Telegram bot"

    cd /app

    if [ -n "$BOT_TOKEN" ]; then
        log_message "INFO" "Using BOT_TOKEN from environment variable"
        exec python -m src.bot --token "$BOT_TOKEN"
    else
        log_message "INFO" "No BOT_TOKEN provided in environment, using config from code"
        exec python -m src.bot
    fi
}

# Check for and terminate existing bot processes
terminate_existing_processes() {
    if pgrep -f "python.*src/bot" > /dev/null; then
        log_message "WARN" "Detected existing bot process, terminating it"
        pkill -f "python.*src/bot"

        # Wait for process to terminate
        sleep 2

        # Check if it's still running
        if pgrep -f "python.*src/bot" > /dev/null; then
            log_message "WARN" "Process did not terminate gracefully, sending SIGKILL"
            pkill -9 -f "python.*src/bot"
            sleep 1
        fi

        log_message "INFO" "Existing process terminated"
    fi
}

# Main execution flow
main() {
    log_message "INFO" "Starting bot container initialization"

    # Create logs directory if it doesn't exist
    mkdir -p "$LOGS_DIR"

    # Check if we can write to the log directory
    if [ ! -w "$LOGS_DIR" ]; then
        log_message "WARN" "Cannot write to $LOGS_DIR directory, fixing permissions"
        chmod 755 "$LOGS_DIR"
    fi

    # Set Python path to include the app directory
    export PYTHONPATH="/app:${PYTHONPATH}"

    # Initialize all systems
    terminate_existing_processes
    setup_health_system
    setup_data_directory
    rotate_logs

    start_health_monitor

    # Start the bot (this will exec, replacing the current process)
    start_bot
}

# Execute main function
main "$@"
