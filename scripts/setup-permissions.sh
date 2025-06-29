#!/bin/bash
# setup-permissions.sh - Secure permission setup for quit-smoking-bot
#
# This script automatically configures secure file permissions for the project
# directories and files. It's designed to be safe, idempotent, and minimal.

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Project directories
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DATA_DIR="${PROJECT_ROOT}/data"
readonly LOGS_DIR="${PROJECT_ROOT}/logs"

# Print colored message
print_message() {
    local message="$1"
    local color="${2:-$NC}"
    echo -e "${color}${message}${NC}"
}

# Setup secure permissions for directories
setup_directory_permissions() {
    local dir="$1"
    local name="$2"
    
    if [[ ! -d "$dir" ]]; then
        print_message "📁 Creating $name directory..." "$YELLOW"
        mkdir -p "$dir"
    fi
    
    # Set secure permissions: owner rwx, group rx, others r
    chmod 755 "$dir"
    print_message "✅ Set secure permissions (755) for $name" "$GREEN"
}

# Setup secure permissions for data files
setup_file_permissions() {
    local file="$1"
    
    if [[ -f "$file" ]]; then
        # Data files: owner rw, group r, others r
        chmod 644 "$file"
        return 0
    fi
    return 1
}

# Initialize default data files if missing
initialize_data_files() {
    local files=("bot_users.json" "bot_admins.json" "quotes.json")
    
    for file in "${files[@]}"; do
        local filepath="${DATA_DIR}/${file}"
        if [[ ! -f "$filepath" ]]; then
            print_message "📄 Creating default $file..." "$YELLOW"
            echo '[]' > "$filepath"
            setup_file_permissions "$filepath"
            print_message "✅ Created $file with secure permissions" "$GREEN"
        else
            setup_file_permissions "$filepath"
        fi
    done
}

# Main setup function
main() {
    print_message "🔐 Setting up secure permissions for quit-smoking-bot..." "$BLUE"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Setup directories
    setup_directory_permissions "$DATA_DIR" "data"
    setup_directory_permissions "$LOGS_DIR" "logs"
    
    # Initialize and secure data files
    initialize_data_files
    
    # Set permissions on any existing log files
    if [[ -f "${LOGS_DIR}/bot.log" ]]; then
        setup_file_permissions "${LOGS_DIR}/bot.log"
        print_message "✅ Set secure permissions for log files" "$GREEN"
    fi
    
    # Make scripts executable
    if [[ -d "${PROJECT_ROOT}/scripts" ]]; then
        find "${PROJECT_ROOT}/scripts" -name "*.sh" -exec chmod 755 {} \;
        print_message "✅ Made scripts executable" "$GREEN"
    fi
    
    print_message "🎉 Permission setup completed successfully!" "$GREEN"
    print_message "📋 Summary:" "$BLUE"
    print_message "  • Directories: 755 (secure access)" "$BLUE"
    print_message "  • Data files: 644 (read-write for owner)" "$BLUE"
    print_message "  • Scripts: 755 (executable)" "$BLUE"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 