#!/bin/bash
echo "Starting Telegram bot..."

# Create logs directory if it doesn't exist and set permissions
mkdir -p /app/logs
chmod 755 /app/logs

# Run tests if BOT_TOKEN is available
if [ -n "$BOT_TOKEN" ]; then
    echo "Running tests..."
    # Run tests and save output to file
    python tests/integration/test_notifications.py --token "$BOT_TOKEN" > /app/test_results.txt 2>&1
    
    # Send test results to admins
    if [ -f "/app/test_results.txt" ]; then
        echo "Sending test results to admins..."
        python /app/src/send_results.py --token "$BOT_TOKEN"
    fi
fi

# Start the bot
if [ -n "$BOT_TOKEN" ]; then
    echo "Using BOT_TOKEN from environment variable"
    exec python /app/src/bot.py --token "$BOT_TOKEN"
else
    echo "No BOT_TOKEN provided in environment variable"
    exec python /app/src/bot.py
fi
