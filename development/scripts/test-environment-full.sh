#!/bin/bash
# test-environment.sh - Comprehensive testing script for development environment

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEV_DIR="$PROJECT_ROOT/development"
TEST_RESULTS_DIR="$PROJECT_ROOT/logs/test-results"
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Show help
show_help() {
    cat << EOF
Usage: $0 [options]

Comprehensive testing script for development environment quality assurance.

Options:
  --quick             Run only essential tests (faster)
  --full              Run full test suite (default)
  --security-only     Run only security tests
  --performance-only  Run only performance tests
  --report            Generate detailed HTML report
  --ci                Continuous Integration mode (non-interactive)
  --cleanup           Clean up test artifacts after completion
  --help              Show this help message

Test Categories:
  - Docker Configuration
  - Security & Compliance  
  - Resource Management
  - Health Checks
  - Functionality
  - Networking
  - Monitoring & Logging
  - Performance

Examples:
  $0                  # Run full test suite
  $0 --quick          # Run essential tests only
  $0 --security-only  # Run security tests only
  $0 --report         # Generate HTML report
EOF
}

# Parse command line arguments
QUICK_MODE=false
FULL_MODE=true
SECURITY_ONLY=false
PERFORMANCE_ONLY=false
GENERATE_REPORT=false
CI_MODE=false
CLEANUP_AFTER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_MODE=true
            FULL_MODE=false
            shift
            ;;
        --full)
            FULL_MODE=true
            QUICK_MODE=false
            shift
            ;;
        --security-only)
            SECURITY_ONLY=true
            FULL_MODE=false
            shift
            ;;
        --performance-only)
            PERFORMANCE_ONLY=true
            FULL_MODE=false
            shift
            ;;
        --report)
            GENERATE_REPORT=true
            shift
            ;;
        --ci)
            CI_MODE=true
            shift
            ;;
        --cleanup)
            CLEANUP_AFTER=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Setup test environment
setup_test_environment() {
    log_section "Setting Up Test Environment"
    
    # Create test results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Check prerequisites
    local missing_tools=()
    
    for tool in docker docker-compose python3 pip3; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Install Python test dependencies
    log_info "Installing Python test dependencies..."
    if [ -f "$DEV_DIR/requirements-test.txt" ]; then
        pip3 install -r "$DEV_DIR/requirements-test.txt" --user -q
    else
        pip3 install docker pyyaml requests --user -q
    fi
    
    log_info "Test environment setup completed"
}

# Check if development environment is running
check_environment_status() {
    log_section "Checking Environment Status"
    
    if docker-compose -f "$DEV_DIR/docker-compose.yml" ps -q dev-env | grep -q .; then
        log_info "Development environment is running"
        return 0
    else
        log_warn "Development environment is not running"
        
        if [ "$CI_MODE" = "false" ]; then
            read -p "Start development environment? [y/N]: " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Starting development environment..."
                cd "$DEV_DIR"
                docker-compose up -d dev-env redis
                
                # Wait for services to be healthy
                log_info "Waiting for services to be healthy..."
                sleep 30
                
                # Check health
                local max_wait=120
                local wait_time=0
                while [ $wait_time -lt $max_wait ]; do
                    if docker-compose ps | grep -q "healthy"; then
                        log_info "Services are healthy"
                        break
                    fi
                    sleep 5
                    wait_time=$((wait_time + 5))
                done
                
                if [ $wait_time -ge $max_wait ]; then
                    log_error "Services did not become healthy within timeout"
                    return 1
                fi
            else
                log_error "Development environment must be running for tests"
                return 1
            fi
        else
            log_error "Development environment must be running for CI tests"
            return 1
        fi
    fi
}

# Run basic health checks
run_basic_health_checks() {
    log_section "Running Basic Health Checks"
    
    local checks_passed=0
    local total_checks=0
    
    # Check container is running
    total_checks=$((total_checks + 1))
    if docker ps | grep -q "quit-smoking-bot-dev"; then
        log_info "✅ Container is running"
        checks_passed=$((checks_passed + 1))
    else
        log_error "❌ Container is not running"
    fi
    
    # Check container is healthy
    total_checks=$((total_checks + 1))
    if docker inspect quit-smoking-bot-dev | grep -q '"Status": "healthy"'; then
        log_info "✅ Container is healthy"
        checks_passed=$((checks_passed + 1))
    else
        log_error "❌ Container is not healthy"
    fi
    
    # Check Redis connectivity
    total_checks=$((total_checks + 1))
    if docker exec quit-smoking-bot-dev nc -z redis-dev 6379 &>/dev/null; then
        log_info "✅ Redis connectivity"
        checks_passed=$((checks_passed + 1))
    else
        log_error "❌ Redis connectivity failed"
    fi
    
    # Check workspace mount
    total_checks=$((total_checks + 1))
    if docker exec quit-smoking-bot-dev test -f /workspace/main.py &>/dev/null; then
        log_info "✅ Workspace properly mounted"
        checks_passed=$((checks_passed + 1))
    else
        log_error "❌ Workspace mount failed"
    fi
    
    log_info "Basic health checks: $checks_passed/$total_checks passed"
    
    if [ $checks_passed -lt $total_checks ]; then
        log_error "Basic health checks failed"
        return 1
    fi
    
    return 0
}

# Run Python test suite
run_python_tests() {
    log_section "Running Python Test Suite"
    
    local test_file="$DEV_DIR/tests/test_dev_environment.py"
    local results_file="$TEST_RESULTS_DIR/python_tests_$TIMESTAMP.xml"
    
    if [ ! -f "$test_file" ]; then
        log_error "Python test file not found: $test_file"
        return 1
    fi
    
    # Run tests with different options based on mode
    local test_args=""
    if [ "$QUICK_MODE" = "true" ]; then
        test_args="-k 'not Performance'"
    elif [ "$SECURITY_ONLY" = "true" ]; then
        test_args="-k 'Security'"
    elif [ "$PERFORMANCE_ONLY" = "true" ]; then
        test_args="-k 'Performance'"
    fi
    
    log_info "Running Python tests..."
    cd "$PROJECT_ROOT"
    
    if python3 -m pytest "$test_file" $test_args --junitxml="$results_file" --verbose; then
        log_info "✅ Python tests passed"
        return 0
    else
        log_error "❌ Python tests failed"
        return 1
    fi
}

# Run security audit
run_security_audit() {
    log_section "Running Security Audit"
    
    local audit_results="$TEST_RESULTS_DIR/security_audit_$TIMESTAMP.txt"
    
    {
        echo "=== Security Audit Report - $(date) ==="
        echo ""
        
        # Check container security
        echo "Container Security:"
        echo "  Privileged: $(docker inspect quit-smoking-bot-dev --format '{{.HostConfig.Privileged}}')"
        echo "  User: $(docker exec quit-smoking-bot-dev id)"
        echo "  Capabilities: $(docker inspect quit-smoking-bot-dev --format '{{.HostConfig.CapDrop}}')"
        echo ""
        
        # Check exposed ports
        echo "Exposed Ports:"
        docker port quit-smoking-bot-dev || echo "  None"
        echo ""
        
        # Check mounted volumes
        echo "Volume Mounts:"
        docker inspect quit-smoking-bot-dev --format '{{range .Mounts}}{{.Source}}:{{.Destination}} ({{.Mode}}){{"\n"}}{{end}}'
        echo ""
        
        # Check running processes
        echo "Running Processes:"
        docker exec quit-smoking-bot-dev ps aux
        echo ""
        
    } > "$audit_results"
    
    log_info "Security audit completed: $audit_results"
}

# Run performance benchmarks
run_performance_benchmarks() {
    log_section "Running Performance Benchmarks"
    
    local perf_results="$TEST_RESULTS_DIR/performance_$TIMESTAMP.txt"
    
    {
        echo "=== Performance Benchmark Report - $(date) ==="
        echo ""
        
        # Container resource usage
        echo "Resource Usage:"
        docker stats quit-smoking-bot-dev --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
        echo ""
        
        # Memory info inside container
        echo "Memory Info (inside container):"
        docker exec quit-smoking-bot-dev free -h
        echo ""
        
        # Disk usage
        echo "Disk Usage:"
        docker exec quit-smoking-bot-dev df -h
        echo ""
        
        # Python import speed test
        echo "Python Import Speed Test:"
        time_result=$(docker exec quit-smoking-bot-dev bash -c "time python3 -c 'import sys, os, json, subprocess'" 2>&1)
        echo "$time_result"
        echo ""
        
        # Container startup time test
        echo "Container Startup Time Test:"
        start_time=$(date +%s.%N)
        docker-compose -f "$DEV_DIR/docker-compose.yml" restart dev-env >/dev/null 2>&1
        end_time=$(date +%s.%N)
        restart_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "N/A")
        echo "Restart time: ${restart_time}s"
        
    } > "$perf_results"
    
    log_info "Performance benchmarks completed: $perf_results"
}

# Generate HTML report
generate_html_report() {
    log_section "Generating HTML Report"
    
    local html_report="$TEST_RESULTS_DIR/test_report_$TIMESTAMP.html"
    
    cat > "$html_report" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Development Environment Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .pass { color: green; }
        .fail { color: red; }
        .warn { color: orange; }
        pre { background: #f5f5f5; padding: 10px; border-radius: 3px; overflow-x: auto; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Development Environment Test Report</h1>
        <p>Generated: $(date)</p>
        <p>Environment: quit-smoking-bot development</p>
    </div>
EOF
    
    # Add test results sections
    for result_file in "$TEST_RESULTS_DIR"/*_"$TIMESTAMP".*; do
        if [ -f "$result_file" ]; then
            filename=$(basename "$result_file")
            cat >> "$html_report" << EOF
    <div class="section">
        <h2>$filename</h2>
        <pre>$(cat "$result_file")</pre>
    </div>
EOF
        fi
    done
    
    echo "</body></html>" >> "$html_report"
    
    log_info "HTML report generated: $html_report"
    
    if command -v open >/dev/null 2>&1; then
        log_info "Opening report in browser..."
        open "$html_report"
    fi
}

# Cleanup test artifacts
cleanup_test_artifacts() {
    log_section "Cleaning Up Test Artifacts"
    
    if [ "$CLEANUP_AFTER" = "true" ]; then
        # Clean up old test results (keep last 5)
        find "$TEST_RESULTS_DIR" -name "*.txt" -o -name "*.xml" -o -name "*.html" | \
            sort -r | tail -n +21 | xargs rm -f 2>/dev/null || true
        
        log_info "Cleaned up old test artifacts"
    fi
}

# Main execution
main() {
    log_info "Starting development environment testing..."
    log_info "Mode: $([ "$QUICK_MODE" = "true" ] && echo "Quick" || echo "Full")"
    
    # Setup
    setup_test_environment
    
    # Check environment status
    if ! check_environment_status; then
        exit 1
    fi
    
    # Run basic health checks
    if ! run_basic_health_checks; then
        log_error "Basic health checks failed, aborting further tests"
        exit 1
    fi
    
    local overall_success=true
    
    # Run Python test suite
    if [ "$SECURITY_ONLY" = "false" ] && [ "$PERFORMANCE_ONLY" = "false" ]; then
        if ! run_python_tests; then
            overall_success=false
        fi
    elif [ "$SECURITY_ONLY" = "true" ]; then
        if ! run_python_tests; then
            overall_success=false
        fi
    elif [ "$PERFORMANCE_ONLY" = "true" ]; then
        if ! run_python_tests; then
            overall_success=false
        fi
    fi
    
    # Run security audit
    if [ "$PERFORMANCE_ONLY" = "false" ]; then
        run_security_audit
    fi
    
    # Run performance benchmarks
    if [ "$SECURITY_ONLY" = "false" ]; then
        run_performance_benchmarks
    fi
    
    # Generate report
    if [ "$GENERATE_REPORT" = "true" ]; then
        generate_html_report
    fi
    
    # Cleanup
    cleanup_test_artifacts
    
    # Final result
    if [ "$overall_success" = "true" ]; then
        log_info "🎉 All tests completed successfully!"
        log_info "Test results available in: $TEST_RESULTS_DIR"
        exit 0
    else
        log_error "💥 Some tests failed!"
        log_info "Check test results in: $TEST_RESULTS_DIR"
        exit 1
    fi
}

# Execute main function
main "$@" 