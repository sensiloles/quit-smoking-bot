#!/bin/bash
# common.sh - Main entry point for common utilities
#
# This script loads all utility modules and provides shared functions
# for all bot management scripts. It replaces the original monolithic
# common.sh file with a modular approach.

# Get the directory where this script is located
# Handle both direct execution and sourcing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Direct execution
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Being sourced - use the script path
    if [[ -n "${BASH_SOURCE[0]}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    else
        # Fallback: assume we're in scripts directory or being called from project root
        if [[ -d "modules" ]]; then
            SCRIPT_DIR="$(pwd)"
        elif [[ -d "scripts/modules" ]]; then
            SCRIPT_DIR="$(pwd)/scripts"
        else
            echo "ERROR: Cannot determine script directory" >&2
            return 1
        fi
    fi
fi

MODULES_DIR="${SCRIPT_DIR}/modules"

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    source ".env"
fi

# Load all utility modules in the correct order
# Order matters due to dependencies between modules

# 1. Output utilities (no dependencies)
source "${MODULES_DIR}/output.sh"

# 2. Environment utilities (depends on output)
source "${MODULES_DIR}/environment.sh"

# 3. Docker utilities (depends on output and environment)
source "${MODULES_DIR}/docker.sh"

# 4. Error handling utilities (depends on output and docker)
source "${MODULES_DIR}/errors.sh"

# 5. Service management utilities (depends on output, environment, docker, errors)
source "${MODULES_DIR}/service.sh"

# 6. Health check utilities (depends on output, environment, docker)
source "${MODULES_DIR}/health.sh"

# 7. Conflict detection utilities (depends on output, environment, docker)
source "${MODULES_DIR}/conflicts.sh"

# 8. Command line argument parsing (depends on output and environment)
source "${MODULES_DIR}/args.sh"

# 9. File system utilities (depends on output)
source "${MODULES_DIR}/filesystem.sh"

# 10. System utilities (depends on output and environment)
source "${MODULES_DIR}/system.sh"

# 11. Testing utilities (depends on output and errors)
source "${MODULES_DIR}/testing.sh"

# Initialize environment
load_env_file
auto_export_bot_token

# Ensure all modules are loaded successfully
if ! declare -f print_message >/dev/null 2>&1; then
    echo "ERROR: Failed to load output utilities module" >&2
    exit 1
fi

if ! declare -f check_docker_installation >/dev/null 2>&1; then
    echo "ERROR: Failed to load docker utilities module" >&2
    exit 1
fi

if ! declare -f check_bot_token >/dev/null 2>&1; then
    echo "ERROR: Failed to load environment utilities module" >&2
    exit 1
fi

# All modules loaded successfully
debug_print "All common utility modules loaded successfully"
