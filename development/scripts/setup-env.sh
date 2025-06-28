#!/bin/bash
# setup-env.sh - Setup development environment inside container

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_message() {
    local message="$1"
    local color="${2:-$NC}"
    echo -e "${color}${message}${NC}"
}

print_message "🔧 Setting up development environment..." "$BLUE"

# Create .env file with default values if it doesn't exist
if [ ! -f "/workspace/.env" ]; then
    print_message "📝 Creating default .env file..." "$YELLOW"
    cat > /workspace/.env << 'EOF'
# Telegram Bot Configuration
# BOT_TOKEN="YOUR_BOT_TOKEN_HERE"

# System Configuration
SYSTEM_NAME=quit-smoking-bot
SYSTEM_DISPLAY_NAME=Quit Smoking Bot

# Development mode
DEVELOPMENT=1
DEBUG=0
EOF
    print_message "✅ Created .env file. Please set your BOT_TOKEN for testing." "$GREEN"
else
    print_message "✅ .env file already exists" "$GREEN"
fi

# Ensure proper permissions on scripts
print_message "🔐 Setting executable permissions on scripts..." "$YELLOW"
chmod +x /workspace/scripts/*.sh 2>/dev/null || true
chmod +x /workspace/development/scripts/*.sh 2>/dev/null || true

# Create test data directories
print_message "📁 Creating test data directories..." "$YELLOW"
mkdir -p /workspace/data
mkdir -p /workspace/logs

# Set proper ownership
if [ "$(id -u)" = "0" ]; then
    # If running as root, change ownership to developer user
    chown -R developer:developer /workspace/data /workspace/logs 2>/dev/null || true
else
    # If running as developer, just ensure directories exist
    touch /workspace/data/.gitkeep
    touch /workspace/logs/.gitkeep
fi

# Test Docker installation
print_message "🐳 Testing Docker installation..." "$YELLOW"
if command -v docker &> /dev/null; then
    docker version --format "Docker: {{.Server.Version}}" || print_message "⚠️  Docker daemon not accessible (normal in some setups)" "$YELLOW"
    print_message "✅ Docker CLI available" "$GREEN"
else
    print_message "❌ Docker not found" "$RED"
fi

# Test docker-compose installation
print_message "🔗 Testing Docker Compose installation..." "$YELLOW"
if command -v docker-compose &> /dev/null; then
    docker-compose version --short
    print_message "✅ Docker Compose available" "$GREEN"
else
    print_message "❌ Docker Compose not found" "$RED"
fi

# Check systemd availability
print_message "⚙️  Checking systemd availability..." "$YELLOW"
if command -v systemctl &> /dev/null; then
    if systemctl is-system-running &> /dev/null || [ "$?" = "1" ]; then
        print_message "✅ systemd available" "$GREEN"
    else
        print_message "⚠️  systemd not running (use --systemd mode for full systemd support)" "$YELLOW"
    fi
else
    print_message "❌ systemd not available" "$RED"
fi

# Display useful information
print_message "\n📋 Development Environment Info:" "$BLUE"
echo "  OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
echo "  Kernel: $(uname -r)"
echo "  User: $(whoami)"
echo "  Workspace: /workspace"
echo "  Project: $(basename /workspace)"

# Show available commands
print_message "\n🚀 Available Commands:" "$BLUE"
echo "  ./scripts/run.sh --help              # Start bot in development mode"
echo "  ./scripts/check-service.sh           # Check bot status"
echo "  ./scripts/test.sh                    # Run tests"
echo "  ./development/scripts/test-scripts.sh # Test all scripts"

if command -v systemctl &> /dev/null; then
    echo "  sudo ./scripts/install-service.sh    # Install as systemd service"
    echo "  sudo ./scripts/uninstall-service.sh  # Uninstall service"
fi

print_message "\n✅ Development environment setup complete!" "$GREEN"
print_message "💡 Tip: Run './development/scripts/test-scripts.sh' to test all scripts" "$BLUE" 