#!/bin/bash
echo "Starting Telegram bot..."

# Create logs directory if it doesn't exist
mkdir -p /app/logs
# Don't try to change permissions as the volume is already set up in Dockerfile
# Just check if we can write to the log directory
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

# Create a health status directory - used by healthcheck
mkdir -p /app/health
chmod 755 /app/health
touch /app/health/starting
echo "$(date): Health check directory initialized" > /app/health/status.log

# Run tests if BOT_TOKEN is available
if [ -n "$BOT_TOKEN" ]; then
    echo "Running tests..."
    # Run tests and save output to file
    cd /app && python -m tests.integration.test_notifications --token "$BOT_TOKEN" > /app/test_results.txt 2>&1
    
    # Send test results to admins - only if tests succeeded
    if [ -f "/app/test_results.txt" ]; then
        echo "Sending test results to admins..."
        cd /app && python -m src.send_results --token "$BOT_TOKEN"
    fi
fi

# Set up a monitor script to update the health status
(
    # Wait for the bot to start up
    sleep 10
    
    # Check every 20 seconds if the bot is operational
    while true; do
        echo "$(date): Running health check monitoring cycle" >> /app/health/status.log
        
        # Check if the bot process is running
        if pgrep -f "python.*src.bot" > /dev/null; then
            # Mark as operational if running
            touch /app/health/operational
            echo "$(date): Bot process is running, health marker updated" >> /app/health/status.log
        else
            # Remove operational marker if not running
            rm -f /app/health/operational
            echo "$(date): WARNING - Bot process not found, removed health marker" >> /app/health/status.log
        fi
        
        # Make sure permissions are correct
        chmod 644 /app/health/operational 2>/dev/null || true
        
        sleep 20
    done
) &

# Start the bot
if [ -n "$BOT_TOKEN" ]; then
    echo "Using BOT_TOKEN from environment variable"
    cd /app && exec python -m src.bot --token "$BOT_TOKEN"
else
    echo "No BOT_TOKEN provided in environment variable"
    cd /app && exec python -m src.bot
fi
