#!/bin/bash
# run-bot-now.sh - One command to rule them all! 
# Start development environment and run the bot instantly

set -e

echo "🚀 QUIT SMOKING BOT - ONE COMMAND LAUNCHER"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Step 1: Check if environment is running
print_step "Checking development environment..."
if docker-compose ps -q dev-env | grep -q .; then
    print_success "Environment is already running"
else
    print_step "Starting development environment..."
    docker-compose up -d dev-env redis
    print_info "Waiting for services to be ready..."
    sleep 15
    print_success "Environment started"
fi

# Step 2: Run the bot
print_step "Starting the bot..."
echo ""
print_info "The bot will start now. Press Ctrl+C to stop."
echo ""

# Execute bot runner script
docker-compose exec dev-env /workspace/development/scripts/run-bot-dev.sh 