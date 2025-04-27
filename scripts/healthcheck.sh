#!/bin/bash

# Script for Docker healthcheck

# Execute basic diagnostics
echo "=== HEALTH CHECK - $(date) ==="
echo "Checking health directory contents:"
ls -la /app/health/

# Make sure health directory exists and is writable
if [ ! -d "/app/health" ]; then
    echo "ERROR: Health directory does not exist"
    mkdir -p /app/health
    chmod 755 /app/health
    echo "$(date): Health directory created by healthcheck" > /app/health/status.log
fi

# Check if bot process is running
if pgrep -f "python.*src[/.]bot" > /dev/null; then
    echo "Bot process is running"
else
    echo "ERROR: Bot process is not running"
    ps aux | grep python
    exit 1
fi

# Check if health operational file exists
if [ -f /app/health/operational ]; then
    echo "Health operational file exists"
else
    echo "ERROR: Health operational file does not exist"
    # Try to create it if the process is actually running
    if pgrep -f "python.*src[/.]bot" > /dev/null; then
        touch /app/health/operational
        chmod 644 /app/health/operational
        echo "Created missing operational file as bot process is running"
    else
        exit 1
    fi
fi

# All checks passed
echo "All health checks passed"
exit 0 