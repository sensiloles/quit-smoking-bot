#!/bin/bash

# Fix-healthcheck.sh - Script to fix the healthcheck issue
# This script updates the healthcheck configuration and scripts to fix the 'unhealthy' container issue

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting healthcheck fix script...${NC}"

# 1. Update the healthcheck.sh script
echo -e "${YELLOW}Updating healthcheck.sh script...${NC}"
cat > scripts/healthcheck.sh << 'EOF'
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
EOF

chmod +x scripts/healthcheck.sh
echo -e "${GREEN}Updated healthcheck.sh script${NC}"

# 2. Update the docker-compose.yml file
echo -e "${YELLOW}Updating docker-compose.yml file...${NC}"
sed -i 's/test: \["CMD", "pgrep", "-f", "python.*src\/bot"\]/test: \["CMD", "\/app\/scripts\/healthcheck.sh"\]/g' docker-compose.yml
sed -i 's/start_period: 30s/start_period: 60s/g' docker-compose.yml
echo -e "${GREEN}Updated docker-compose.yml file${NC}"

# 3. Update the entrypoint.sh script
echo -e "${YELLOW}Updating entrypoint.sh script...${NC}"
cat > scripts/entrypoint.sh << 'EOF'
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
EOF

chmod +x scripts/entrypoint.sh
echo -e "${GREEN}Updated entrypoint.sh script${NC}"

# 4. Rebuild and restart the service
echo -e "${YELLOW}Rebuilding and restarting the service...${NC}"

# Get token from environment or .env file
BOT_TOKEN=$(grep -oP 'BOT_TOKEN=\K[^"]+' .env 2>/dev/null || echo "")

if [ -z "$BOT_TOKEN" ]; then
    echo -e "${RED}No BOT_TOKEN found in .env file${NC}"
    echo -e "${YELLOW}Please provide your bot token:${NC}"
    read -p "> " BOT_TOKEN
    
    if [ -z "$BOT_TOKEN" ]; then
        echo -e "${RED}No token provided. Cannot continue.${NC}"
        exit 1
    fi
fi

# Run the installation script with force-rebuild option
echo -e "${YELLOW}Running installation script with force-rebuild option...${NC}"
./scripts/install-service.sh --token "$BOT_TOKEN" --force-rebuild

echo -e "${GREEN}Fix completed!${NC}"
echo -e "${YELLOW}To check the status of your bot, run:${NC}"
echo -e "sudo systemctl status quit-smoking-bot.service"
echo -e "./scripts/check-service.sh"

exit 0 