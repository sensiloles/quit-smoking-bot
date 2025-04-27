#!/bin/bash
set -e

echo "Starting Telegram bot..."

# Function to initialize health system
setup_health_system() {
    mkdir -p /app/health
    chmod 755 /app/health
    rm -f /app/health/operational # Remove any existing operational file
    touch /app/health/starting
    echo "$(date): Health check directory initialized" > /app/health/status.log
    echo "$(date): Bot is starting up" >> /app/health/status.log
}

# Function to initialize data directory
setup_data_directory() {
    echo "Checking data files..."
    mkdir -p /app/data

    # Default JSON files to create if missing
    default_files=("bot_admins.json" "bot_users.json" "quotes.json")
    
    for file in "${default_files[@]}"; do
        if [ ! -f "/app/data/$file" ]; then
            echo "Warning: $file not found, creating it"
            echo '[]' > "/app/data/$file"
            chmod 644 "/app/data/$file"
        fi
    done

    echo "Data directory contents:"
    ls -la /app/data/
}

# Function to run tests if BOT_TOKEN is available
run_tests() {
    if [ -n "$BOT_TOKEN" ]; then
        echo "Running tests..."
        # Run tests and save output to file
        cd /app && python -m tests.integration.test_notifications --token "$BOT_TOKEN" > /app/test_results.txt 2>&1
        
        # Send test results to admins - only if tests succeeded
        if [ -f "/app/test_results.txt" ]; then
            echo "Sending test results to admins..."
            cd /app && python -m src.send_results --token "$BOT_TOKEN"
        fi
    else
        echo "Skipping tests - BOT_TOKEN not provided"
    fi
}

# Function to start health monitor in background
start_health_monitor() {
    (
        # Wait for the bot to start up
        sleep 10
        
        # Check every 20 seconds if the bot is operational
        while true; do
            echo "$(date): Running health check monitoring cycle" >> /app/health/status.log
            
            # Check if the bot process is running
            if pgrep -f "python.*src[/.]bot" > /dev/null; then
                # Mark as operational if running
                touch /app/health/operational
                chmod 644 /app/health/operational
                echo "$(date): Bot process is running, health marker updated" >> /app/health/status.log
            else
                # Remove operational marker if not running
                rm -f /app/health/operational
                echo "$(date): WARNING - Bot process not found, removed health marker" >> /app/health/status.log
            fi
            
            sleep 20
        done
    ) &
}

# Main execution flow
main() {
    # Create logs directory if it doesn't exist
    mkdir -p /app/logs
    # Check if we can write to the log directory
    if [ ! -w "/app/logs" ]; then
        echo "Warning: Cannot write to /app/logs directory"
    fi

    # Set Python path to include the app directory
    export PYTHONPATH="/app:${PYTHONPATH}"

    # Check for existing bot processes and terminate them
    if pgrep -f "python.*src/bot" > /dev/null; then
        echo "Detected existing bot process, terminating it..."
        pkill -f "python.*src/bot"
        # Wait for process to terminate
        sleep 2
    fi

    # Initialize systems
    setup_health_system
    setup_data_directory
    run_tests
    start_health_monitor

    # Start the bot
    if [ -n "$BOT_TOKEN" ]; then
        echo "Using BOT_TOKEN from environment variable"
        cd /app && exec python -m src.bot --token "$BOT_TOKEN"
    else
        echo "No BOT_TOKEN provided in environment variable"
        cd /app && exec python -m src.bot
    fi
}

# Execute main function
main "$@"
