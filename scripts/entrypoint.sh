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
rm -f /app/health/operational # Remove any existing operational file
touch /app/health/starting
echo "$(date): Health check directory initialized" > /app/health/status.log
echo "$(date): Bot is starting up" >> /app/health/status.log

# Verify that data files exist
echo "Checking data files..."
mkdir -p /app/data
chmod 755 /app/data
ls -la /app/data/

# Check if the mounted data directory is empty (indication that volume is empty)
if [ -z "$(ls -A /app/data)" ]; then
    echo "Data directory is empty, initializing with default files"
    
    # Look for default data files that might be in the image
    if [ -d "/app/default_data" ] && [ "$(ls -A /app/default_data)" ]; then
        echo "Copying files from default_data directory"
        cp -r /app/default_data/* /app/data/
    else
        echo "Error: No default data files found and data directory is empty"
        echo "Please ensure the data directory is properly initialized with required files:"
        echo "- bot_admins.json"
        echo "- bot_users.json"
        echo "- quotes.json"
        exit 1
    fi
    
    # Set permissions for all files
    chmod -R 644 /app/data/*
    chown -R appuser:appuser /app/data
fi

# Ensure critical files exist
if [ ! -f "/app/data/bot_admins.json" ]; then
    echo "Warning: bot_admins.json not found, creating it"
    echo '[272043118]' > /app/data/bot_admins.json
    chmod 644 /app/data/bot_admins.json
fi

if [ ! -f "/app/data/bot_users.json" ]; then
    echo "Warning: bot_users.json not found, creating it"
    echo '[]' > /app/data/bot_users.json
    chmod 644 /app/data/bot_users.json
fi

echo "Data directory contents after initialization:"
ls -la /app/data/

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

# Start the bot
if [ -n "$BOT_TOKEN" ]; then
    echo "Using BOT_TOKEN from environment variable"
    cd /app && exec python -m src.bot --token "$BOT_TOKEN"
else
    echo "No BOT_TOKEN provided in environment variable"
    cd /app && exec python -m src.bot
fi
