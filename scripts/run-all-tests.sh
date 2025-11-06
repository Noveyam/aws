#!/bin/bash

# =============================================================================
# Comprehensive Test Runner
# Runs all infrastructure and website tests with reporting
# =============================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$PROJECT_ROOT/tests"
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"
COMPREHENSIVE_LOG="$PROJECT_ROOT/comprehensive-tests.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
TOTAL_TEST_SUITES=0
PASSED_TEST_SUITES=0
FAILED_TEST_SUITES=0

# Logging functions
log() { echo -e "${1}" | tee -a "$COMPREHENSIVE_LOG"; }
info() { log "${BLUE}ℹ $1${NC}"; }
success() { log "${GREEN}✓ $1${NC}"; }
warning() { log "${YELLOW}⚠ $1${NC}"; }
error() { log "${RED}✗ $1${NC}"; }

# Initialize test environment
init_tests() {
    echo "=== Comprehensive Test Suite ===" > "$COMPREHENSIVE_LOG"
    echo "Started at: $(date)" >> "$COMPREHENSIVE_LOG"
    echo "" >> "$COMPREHENSIVE_LOG"
    
    # Create test results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    info "Starting comprehensive test suite..."
    info "Test results will be saved to: $TEST_RESULTS_DIR"
    info "Comprehensive log: $COMPREHENSIVE_LOG"
}

# Run a test suite
run_test_suite() {
    local test_name="$1"
    local test_script="$2"
    local test_description="$3"
    
    ((TOTAL_TEST_SUITES++))
    
    echo ""
    log "=== Running $test_name ==="
    info "$test_description"
    
    if [ ! -f "$test_script" ]; then
        error "Test script not found: $test_script"
        ((FAILED_TEST_SUITES++))
        return 1
    fi
    
    if [ ! -x "$test_script" ]; then
        warning "Making test script executable: $test_script"
        chmod +x "$test_script"
    fi
    
    local test_output_file="$TEST_RESULTS_DIR/${test_name}-results.log"
    local start_time end_time duration
    
    start_time=$(date +%s)
    
    if "$test_script" > "$test_output_file" 2>&1; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        success "$test_name completed successfully (${duration}s)"
        ((PASSED_TEST_SUITES++))
        
        # Extract key metrics from test output
        local test_summary
        test_summary=$(tail -10 "$test_output_file" | grep -E "Tests Run|Tests Passed|Tests Failed|Success Rate" || echo "")
        if [ -n "$test_summary" ]; then
            echo "$test_summary" | while read -r line; do
                info "  $line"
            done
        fi
        
        return 0
    else
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        error "$test_name failed (${duration}s)"
        ((FAILED_TEST_SUITES++))
        
        # Show last few lines of error output
        warning "Last 5 lines of error output:"
        tail -5 "$test_output_file" | while read -r line; do
            log "    $line"
        done
        
        return 1
    fi
}

# Check prerequisites
check_prerequisites() {
    info "Checking test prerequisites..."
    
    local missing_tools=()
    
    # Check for required tools
    local required_tools=("aws" "jq" "curl")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured"
        return 1
    fi
    
    # Check if tests directory exists
    if [ ! -d "$TESTS_DIR" ]; then
        error "Tests directory not found: $TESTS_DIR"
        return 1
    fi
    
    success "Prerequisites check completed"
}

# Run infrastructure tests
run_infrastructure_tests() {
    info "Running infrastructure tests..."
    
    # Terraform configuration tests
    run_test_suite \
        "terraform-config" \
        "$TESTS_DIR/infrastructure/test-terraform-config.sh" \
        "Validates Terraform configuration files for syntax and best practices"
    
    # Terraform resources tests (only if infrastructure is deployed)
    if [ -f "$PROJECT_ROOT/terraform-outputs.json" ]; then
        run_test_suite \
            "terraform-resources" \
            "$TESTS_DIR/infrastructure/test-terraform-resources.sh" \
            "Validates deployed AWS resources and their configuration"
    else
        warning "Skipping resource tests - infrastructure not deployed"
    fi
}

# Run website tests
run_website_tests() {
    info "Running website functionality tests..."
    
    # Responsive design tests
    run_test_suite \
        "responsive-design" \
        "$TESTS_DIR/website/test-responsive-design.sh" \
        "Tests responsive design implementation and mobile compatibility"
    
    # Accessibility tests
    run_test_suite \
        "accessibility" \
        "$TESTS_DIR/website/test-accessibility.sh" \
        "Tests website accessibility and WCAG compliance"
    
    # Performance tests
    run_test_suite \
        "performance" \
        "$TESTS_DIR/website/test-performance.sh" \
        "Tests website performance and optimization"
}

# Run monitoring tests
run_monitoring_tests() {
    info "Running monitoring and Free Tier tests..."
    
    # Free Tier monitoring (only if infrastructure is deployed)
    if [ -f "$PROJECT_ROOT/terraform-outputs.json" ]; then
        run_test_suite \
            "free-tier-monitoring" \
            "$SCRIPT_DIR/monitor-free-tier.sh" \
            "Monitors AWS Free Tier usage and compliance"
    else
        warning "Skipping Free Tier monitoring - infrastructure not deployed"
    fi
}

# Run configuration validation
run_configuration_tests() {
    info "Running configuration validation..."
    
    run_test_suite \
        "config-validation" \
        "$SCRIPT_DIR/validate-config.sh" \
        "Validates project configuration and setup"
}

# Generate comprehensive report
generate_comprehensive_report() {
    echo ""
    log "=== Comprehensive Test Results ==="
    log "Total Test Suites: $TOTAL_TEST_SUITES"
    log "Passed Test Suites: $PASSED_TEST_SUITES"
    log "Failed Test Suites: $FAILED_TEST_SUITES"
    
    local success_rate=0
    if [ $TOTAL_TEST_SUITES -gt 0 ]; then
        success_rate=$((PASSED_TEST_SUITES * 100 / TOTAL_TEST_SUITES))
    fi
    
    log "Success Rate: ${success_rate}%"
    
    echo ""
    log "=== Test Results Summary ==="
    
    # List all test result files
    if [ -d "$TEST_RESULTS_DIR" ]; then
        for result_file in "$TEST_RESULTS_DIR"/*.log; do
            if [ -f "$result_file" ]; then
                local test_name
                test_name=$(basename "$result_file" -results.log)
                local file_size
                file_size=$(wc -l < "$result_file")
                log "  $test_name: $file_size lines of output"
            fi
        done
    fi
    
    echo ""
    log "=== Recommendations ==="
    
    if [ $FAILED_TEST_SUITES -gt 0 ]; then
        log "• Review failed test outputs in $TEST_RESULTS_DIR"
        log "• Fix issues identified by failed tests"
        log "• Re-run specific test suites after fixes"
    fi
    
    log "• Run tests regularly during development"
    log "• Set up automated testing in CI/CD pipeline"
    log "• Monitor Free Tier usage to avoid unexpected charges"
    log "• Keep test results for compliance and auditing"
    
    echo ""
    log "=== Next Steps ==="
    
    if [ $FAILED_TEST_SUITES -eq 0 ]; then
        success "🎉 All test suites passed! Your resume website is ready for production."
        log "• Deploy to production environment"
        log "• Set up monitoring and alerting"
        log "• Configure automated backups"
        log "• Plan regular maintenance and updates"
    else
        error "❌ Some test suites failed. Please address the issues before deploying."
        log "• Review detailed test outputs"
        log "• Fix configuration or code issues"
        log "• Re-run tests to verify fixes"
        log "• Consider deploying to staging first"
    fi
}

# Clean up old test results
cleanup_old_results() {
    if [ -d "$TEST_RESULTS_DIR" ]; then
        info "Cleaning up old test results..."
        find "$TEST_RESULTS_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
        success "Old test results cleaned up"
    fi
}

# Main test execution
main() {
    local test_type="${1:-all}"
    
    init_tests
    cleanup_old_results
    
    case "$test_type" in
        "all")
            check_prerequisites
            run_configuration_tests
            run_infrastructure_tests
            run_website_tests
            run_monitoring_tests
            ;;
        "infrastructure")
            check_prerequisites
            run_infrastructure_tests
            ;;
        "website")
            check_prerequisites
            run_website_tests
            ;;
        "monitoring")
            check_prerequisites
            run_monitoring_tests
            ;;
        "config")
            check_prerequisites
            run_configuration_tests
            ;;
        "quick")
            check_prerequisites
            run_configuration_tests
            run_website_tests
            ;;
        *)
            echo "Usage: $0 [all|infrastructure|website|monitoring|config|quick]"
            echo ""
            echo "Test Types:"
            echo "  all            - Run all test suites (default)"
            echo "  infrastructure - Run infrastructure tests only"
            echo "  website        - Run website functionality tests only"
            echo "  monitoring     - Run monitoring and Free Tier tests only"
            echo "  config         - Run configuration validation only"
            echo "  quick          - Run quick tests (config + website)"
            echo ""
            echo "Examples:"
            echo "  $0              # Run all tests"
            echo "  $0 website      # Run only website tests"
            echo "  $0 quick        # Run quick validation"
            exit 1
            ;;
    esac
    
    generate_comprehensive_report
    
    echo ""
    echo "Completed at: $(date)" >> "$COMPREHENSIVE_LOG"
    success "Comprehensive testing completed"
    
    # Exit with appropriate code
    if [ $FAILED_TEST_SUITES -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function with all arguments
main "$@"