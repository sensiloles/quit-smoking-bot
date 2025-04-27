#!/bin/bash

# Script for Docker healthcheck

# Execute basic diagnostics
echo "=== HEALTH CHECK - $(date) ==="
echo "Checking health directory contents:"
ls -la /app/health/

# Check if bot process is running
if pgrep -f "python.*src.bot" > /dev/null; then
    echo "Bot process is running"
else
    echo "ERROR: Bot process is not running"
    exit 1
fi

# Check if health operational file exists
if [ -f /app/health/operational ]; then
    echo "Health operational file exists"
else
    echo "ERROR: Health operational file does not exist"
    exit 1
fi

# All checks passed
echo "All health checks passed"
exit 0 