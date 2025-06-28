#!/bin/bash
# run-bot-dev.sh - Simple bot runner for development environment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    local message="$1"
    local color="${2:-$NC}"
    echo -e "${color}${message}${NC}"
}

print_message "🤖 Starting quit-smoking-bot in development mode..." "$BLUE"

# Change to project root
cd /workspace

# Check if .env exists
if [ ! -f ".env" ]; then
    print_message "📝 Creating .env file from template..." "$YELLOW"
    cp .env.example .env
fi

# Check BOT_TOKEN
if ! grep -q "BOT_TOKEN=" .env || grep -q "BOT_TOKEN=$" .env || grep -q "BOT_TOKEN=\"\"" .env; then
    print_message "⚠️  BOT_TOKEN not set in .env file" "$YELLOW"
    read -p "Enter your BOT_TOKEN: " bot_token
    if [ -n "$bot_token" ]; then
        sed -i "s/BOT_TOKEN=.*/BOT_TOKEN=$bot_token/" .env
        print_message "✅ BOT_TOKEN updated in .env" "$GREEN"
    else
        print_message "❌ BOT_TOKEN is required to run the bot" "$RED"
        exit 1
    fi
fi

# Load .env file variables
if [ -f ".env" ]; then
    print_message "📝 Loading environment variables from .env..." "$YELLOW"
    set -a  # automatically export all variables
    source .env
    set +a  # stop automatically exporting
fi

# Set development environment
export DEVELOPMENT=1
export BOT_BASE_DIR="/workspace"
export PYTHONPATH="/workspace/src:$PYTHONPATH"

# Create necessary directories
mkdir -p data logs

# Install Python dependencies if needed
if [ ! -d "venv" ]; then
    print_message "📦 Creating virtual environment..." "$YELLOW"
    python3 -m venv venv
fi

print_message "📦 Installing/updating dependencies..." "$YELLOW"
source venv/bin/activate
pip install -r requirements.txt -q

# Run the bot
print_message "🚀 Starting the bot..." "$GREEN"
print_message "Press Ctrl+C to stop" "$YELLOW"

# Run bot with proper error handling
python3 main.py 