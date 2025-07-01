#!/bin/bash
# bootstrap.sh - Initial project setup for quit-smoking-bot
#
# This script performs the initial setup after cloning the repository.
# It can be run manually or automatically via git hooks.

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Project root directory
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT

# Load all modules (order matters - output.sh first for color constants)
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
MODULES_DIR="${SCRIPT_DIR}/modules"

if [[ -d "$MODULES_DIR" ]]; then
    # Load output.sh first for color constants
    if [[ -f "$MODULES_DIR/output.sh" ]]; then
        source "$MODULES_DIR/output.sh"
    fi
    
    # Load other modules
    for module in "$MODULES_DIR"/*.sh; do
        if [[ -f "$module" && "$module" != "$MODULES_DIR/output.sh" ]]; then
            source "$module"
        fi
    done
fi

print_message() {
    local message="$1"
    local color="${2:-$NC}"
    echo -e "${color}${message}${NC}"
}

main() {
    print_message "🚀 Bootstrapping quit-smoking-bot project..." "$BLUE"
    
    cd "$PROJECT_ROOT"
    
    # Setup secure permissions
    if [[ -f "scripts/setup-permissions.sh" ]]; then
        print_message "🔐 Setting up secure file permissions..." "$YELLOW"
        bash scripts/setup-permissions.sh
    fi
    
    # Create .env template if it doesn't exist
    if [[ ! -f ".env" ]]; then
        print_message "📝 Creating .env template..." "$YELLOW"
        cat > .env << 'EOF'
# Telegram Bot Configuration
BOT_TOKEN="your_telegram_bot_token_here"

# System Configuration
SYSTEM_NAME="quit-smoking-bot"
SYSTEM_DISPLAY_NAME="Quit Smoking Bot"

# Timezone (optional)
TZ="Asia/Novosibirsk"

# Notification Settings (optional)
NOTIFICATION_DAY="23"
NOTIFICATION_HOUR="21"
NOTIFICATION_MINUTE="58"
EOF
        print_message "✅ Created .env template - please update with your bot token" "$GREEN"
    fi
    
    print_message "🎉 Project bootstrap completed!" "$GREEN"
    print_message "📋 Next steps:" "$BLUE"
    print_message "  1. Update .env file with your bot token" "$BLUE"
    print_message "  2. Run: ./scripts/run.sh" "$BLUE"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
