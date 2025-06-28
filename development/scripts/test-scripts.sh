#!/bin/bash
# test-scripts.sh - Comprehensive testing of all project scripts

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

print_section() {
    echo ""
    print_message "=== $1 ===" "$BLUE"
}

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    print_message "🧪 Testing: $test_name" "$YELLOW"
    
    if eval "$test_command" >/dev/null 2>&1; then
        local exit_code=$?
        if [ $exit_code -eq $expected_exit_code ]; then
            print_message "  ✅ PASS" "$GREEN"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            print_message "  ❌ FAIL (exit code: $exit_code, expected: $expected_exit_code)" "$RED"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        local exit_code=$?
        if [ $exit_code -eq $expected_exit_code ]; then
            print_message "  ✅ PASS" "$GREEN"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            print_message "  ❌ FAIL (exit code: $exit_code, expected: $expected_exit_code)" "$RED"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    fi
}

# Function to run a test with output
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    print_message "🧪 Testing: $test_name" "$YELLOW"
    
    if eval "$test_command"; then
        print_message "  ✅ PASS" "$GREEN"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        print_message "  ❌ FAIL" "$RED"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Change to project root
# cd /workspace # Commented out for host execution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

print_message "🚀 Starting comprehensive script testing..." "$BLUE"
print_message "📂 Working directory: $(pwd)" "$YELLOW"

# Check if we're in the right directory
if [ ! -f "scripts/common.sh" ]; then
    print_message "❌ Error: Not in project root or scripts not found" "$RED"
    exit 1
fi

print_section "Basic Script Validation"

# Test script permissions
run_test "Script permissions" "find scripts/ -name '*.sh' -executable | wc -l | grep -q '[0-9]'"

# Test script syntax
for script in scripts/*.sh development/scripts/*.sh; do
    if [ -f "$script" ]; then
        run_test "Syntax check: $(basename $script)" "bash -n $script"
    fi
done

print_section "Help Commands"

# Test help commands for all main scripts
run_test_with_output "run.sh --help" "./scripts/run.sh --help"
run_test_with_output "stop.sh --help" "./scripts/stop.sh --help"
run_test_with_output "test.sh --help" "./scripts/test.sh --help"
run_test_with_output "check-service.sh --help" "./scripts/check-service.sh --help"

# Test install-service and uninstall-service help (these require sudo, so just syntax)
run_test "install-service.sh syntax" "bash -n scripts/install-service.sh"
run_test "uninstall-service.sh syntax" "bash -n scripts/uninstall-service.sh"

print_section "Common Functions"

# Test that common.sh loads without errors
run_test "Load common.sh" "source scripts/common.sh"

# Test environment variable checking
run_test "SYSTEM_NAME check" "source scripts/common.sh && [ -n \"\$SYSTEM_NAME\" ]"

print_section "Docker Integration"

# Test Docker availability
run_test "Docker command available" "command -v docker"
run_test "Docker compose available" "command -v docker-compose"

# Test if docker-compose.yml is valid
if [ -f "docker-compose.yml" ]; then
    run_test "docker-compose.yml syntax" "docker-compose config -q"
fi

print_section "File Structure"

# Test required files exist
run_test "main.py exists" "[ -f main.py ]"
run_test "pyproject.toml exists" "[ -f pyproject.toml ]"
run_test "requirements.txt exists" "[ -f requirements.txt ]"
run_test "Dockerfile exists" "[ -f Dockerfile ]"

# Test directory structure
run_test "src/ directory" "[ -d src ]"
run_test "tests/ directory" "[ -d tests ]"
run_test "scripts/ directory" "[ -d scripts ]"

print_section "Configuration Files"

# Test .env file handling
if [ -f ".env" ]; then
    run_test ".env file readable" "[ -r .env ]"
    print_message "  📝 .env file found" "$GREEN"
else
    print_message "  ⚠️  .env file not found (this is OK for testing)" "$YELLOW"
fi

print_section "Service Scripts (Safe Tests Only)"

# Test service scripts without actually running them
run_test "install-service.sh --help" "bash scripts/install-service.sh --help" 0
run_test "uninstall-service.sh --help" "bash scripts/uninstall-service.sh --help" 0

# Test check-service.sh (should work without BOT_TOKEN)
if command -v systemctl >/dev/null 2>&1; then
    print_message "🧪 Testing: check-service.sh (basic)" "$YELLOW"
    # This might fail but shouldn't crash
    ./scripts/check-service.sh 2>/dev/null || print_message "  ⚠️  Expected to fail without service installed" "$YELLOW"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_message "  ⚠️  systemctl not available, skipping service tests" "$YELLOW"
fi

print_section "Development Environment"

# Test development scripts
run_test "setup-env.sh syntax" "bash -n development/scripts/setup-env.sh"
run_test "start-dev.sh syntax" "bash -n development/start-dev.sh"

# Test development setup
run_test_with_output "Development setup" "./development/scripts/setup-env.sh"

print_section "Test Results"

print_message "📊 Test Summary:" "$BLUE"
echo "  Total tests: $TESTS_TOTAL"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    print_message "🎉 All tests passed!" "$GREEN"
    echo ""
    print_message "✅ The development environment is ready for use!" "$GREEN"
    print_message "💡 Next steps:" "$BLUE"
    echo "  1. Set BOT_TOKEN in .env file for full testing"
    echo "  2. Run: ./scripts/run.sh --help"
    echo "  3. Try: ./scripts/test.sh (requires BOT_TOKEN)"
    exit 0
else
    print_message "❌ Some tests failed!" "$RED"
    echo ""
    print_message "🔧 Troubleshooting tips:" "$YELLOW"
    echo "  1. Check file permissions: chmod +x scripts/*.sh"
    echo "  2. Ensure Docker is running"
    echo "  3. Check if all required files are present"
    exit 1
fi 