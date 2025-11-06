#!/bin/bash

# =============================================================================
# Responsive Design Testing Script
# Tests website responsiveness across different screen sizes and devices
# =============================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
WEBSITE_DIR="$PROJECT_ROOT/website"
TEST_LOG="$PROJECT_ROOT/responsive-design-tests.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Device breakpoints to test
declare -A BREAKPOINTS=(
    ["mobile-small"]="320"
    ["mobile-large"]="480"
    ["tablet"]="768"
    ["desktop-small"]="1024"
    ["desktop-large"]="1440"
)

# Logging functions
log() { echo -e "${1}" | tee -a "$TEST_LOG"; }
test_start() { 
    ((TESTS_RUN++))
    log "${BLUE}[TEST $TESTS_RUN] $1${NC}"
}
test_pass() { 
    ((TESTS_PASSED++))
    log "${GREEN}✓ PASS: $1${NC}"
}
test_fail() { 
    ((TESTS_FAILED++))
    log "${RED}✗ FAIL: $1${NC}"
}
test_skip() { 
    log "${YELLOW}⚠ SKIP: $1${NC}"
}
info() { log "${BLUE}ℹ $1${NC}"; }

# Initialize test logging
init_tests() {
    echo "=== Responsive Design Tests ===" > "$TEST_LOG"
    echo "Started at: $(date)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    info "Starting responsive design tests..."
    info "Test log: $TEST_LOG"
}

# Check prerequisites
check_prerequisites() {
    test_start "Checking prerequisites"
    
    if [ ! -d "$WEBSITE_DIR" ]; then
        test_fail "Website directory not found: $WEBSITE_DIR"
        return 1
    fi
    
    if [ ! -f "$WEBSITE_DIR/index.html" ]; then
        test_fail "index.html not found in website directory"
        return 1
    fi
    
    if [ ! -f "$WEBSITE_DIR/css/styles.css" ]; then
        test_fail "styles.css not found in website directory"
        return 1
    fi
    
    test_pass "Prerequisites check completed"
}

# Test viewport meta tag
test_viewport_meta() {
    test_start "Checking viewport meta tag"
    
    if grep -q '<meta name="viewport"' "$WEBSITE_DIR/index.html"; then
        local viewport_content
        viewport_content=$(grep '<meta name="viewport"' "$WEBSITE_DIR/index.html" | sed 's/.*content="\([^"]*\)".*/\1/')
        
        if [[ $viewport_content == *"width=device-width"* ]]; then
            test_pass "Viewport meta tag is properly configured"
        else
            test_fail "Viewport meta tag missing width=device-width"
            return 1
        fi
    else
        test_fail "Viewport meta tag not found"
        return 1
    fi
}

# Test CSS media queries
test_media_queries() {
    test_start "Checking CSS media queries"
    
    local media_query_count
    media_query_count=$(grep -c "@media" "$WEBSITE_DIR/css/styles.css" || echo "0")
    
    if [ "$media_query_count" -gt 0 ]; then
        test_pass "Found $media_query_count media queries in CSS"
        
        # Check for common breakpoints
        local common_breakpoints=("768px" "1024px")
        local found_breakpoints=0
        
        for breakpoint in "${common_breakpoints[@]}"; do
            if grep -q "$breakpoint" "$WEBSITE_DIR/css/styles.css"; then
                ((found_breakpoints++))
                info "Found breakpoint: $breakpoint"
            fi
        done
        
        if [ $found_breakpoints -gt 0 ]; then
            test_pass "Common responsive breakpoints found"
        else
            test_fail "No common responsive breakpoints found"
            return 1
        fi
    else
        test_fail "No media queries found in CSS"
        return 1
    fi
}

# Test mobile-first approach
test_mobile_first() {
    test_start "Checking mobile-first CSS approach"
    
    # Check if base styles are mobile-friendly (no media query)
    # and desktop styles are in min-width media queries
    local min_width_queries
    min_width_queries=$(grep -c "min-width" "$WEBSITE_DIR/css/styles.css" || echo "0")
    
    local max_width_queries
    max_width_queries=$(grep -c "max-width" "$WEBSITE_DIR/css/styles.css" || echo "0")
    
    if [ "$min_width_queries" -gt "$max_width_queries" ]; then
        test_pass "Mobile-first approach detected (more min-width than max-width queries)"
    else
        test_fail "Mobile-first approach not clearly implemented"
        return 1
    fi
}

# Test flexible layouts
test_flexible_layouts() {
    test_start "Checking flexible layout properties"
    
    local flex_properties=("display: flex" "flex-direction" "flex-wrap" "justify-content" "align-items")
    local grid_properties=("display: grid" "grid-template" "grid-gap" "gap")
    local responsive_properties=("max-width" "width: 100%" "box-sizing: border-box")
    
    local flexible_layout_count=0
    
    # Check for flexbox usage
    for property in "${flex_properties[@]}"; do
        if grep -q "$property" "$WEBSITE_DIR/css/styles.css"; then
            ((flexible_layout_count++))
        fi
    done
    
    # Check for grid usage
    for property in "${grid_properties[@]}"; do
        if grep -q "$property" "$WEBSITE_DIR/css/styles.css"; then
            ((flexible_layout_count++))
        fi
    done
    
    # Check for responsive properties
    for property in "${responsive_properties[@]}"; do
        if grep -q "$property" "$WEBSITE_DIR/css/styles.css"; then
            ((flexible_layout_count++))
        fi
    done
    
    if [ $flexible_layout_count -gt 3 ]; then
        test_pass "Flexible layout properties found ($flexible_layout_count properties)"
    else
        test_fail "Insufficient flexible layout properties ($flexible_layout_count found)"
        return 1
    fi
}

# Test responsive images
test_responsive_images() {
    test_start "Checking responsive image implementation"
    
    # Check for responsive image CSS
    if grep -q "max-width.*100%" "$WEBSITE_DIR/css/styles.css" && grep -q "height.*auto" "$WEBSITE_DIR/css/styles.css"; then
        test_pass "Responsive image CSS found"
    else
        test_fail "Responsive image CSS not found"
        return 1
    fi
    
    # Check for proper image attributes in HTML
    local images_with_alt=0
    local total_images=0
    
    while IFS= read -r line; do
        if [[ $line =~ \<img[^>]*src= ]]; then
            ((total_images++))
            if [[ $line =~ alt= ]]; then
                ((images_with_alt++))
            fi
        fi
    done < "$WEBSITE_DIR/index.html"
    
    if [ $total_images -gt 0 ]; then
        if [ $images_with_alt -eq $total_images ]; then
            test_pass "All images have alt attributes ($images_with_alt/$total_images)"
        else
            test_fail "Some images missing alt attributes ($images_with_alt/$total_images)"
            return 1
        fi
    else
        test_skip "No images found to test"
    fi
}

# Test navigation responsiveness
test_responsive_navigation() {
    test_start "Checking responsive navigation"
    
    # Check for mobile menu toggle
    if grep -q "mobile-menu-toggle\|hamburger\|menu-toggle" "$WEBSITE_DIR/index.html"; then
        test_pass "Mobile menu toggle found in HTML"
    else
        test_fail "Mobile menu toggle not found"
        return 1
    fi
    
    # Check for mobile navigation CSS
    if grep -q "mobile-menu\|@media.*nav\|navigation.*@media" "$WEBSITE_DIR/css/styles.css"; then
        test_pass "Mobile navigation CSS found"
    else
        test_fail "Mobile navigation CSS not found"
        return 1
    fi
    
    # Check for JavaScript mobile menu functionality
    if [ -f "$WEBSITE_DIR/js/main.js" ]; then
        if grep -q "mobile.*menu\|menu.*toggle\|hamburger" "$WEBSITE_DIR/js/main.js"; then
            test_pass "Mobile menu JavaScript functionality found"
        else
            test_fail "Mobile menu JavaScript functionality not found"
            return 1
        fi
    else
        test_skip "JavaScript file not found"
    fi
}

# Test typography responsiveness
test_responsive_typography() {
    test_start "Checking responsive typography"
    
    # Check for responsive font sizes
    local responsive_font_count=0
    
    # Look for font-size in media queries
    while IFS= read -r line; do
        if [[ $line =~ font-size.*rem|font-size.*em|font-size.*vw ]]; then
            ((responsive_font_count++))
        fi
    done < "$WEBSITE_DIR/css/styles.css"
    
    if [ $responsive_font_count -gt 2 ]; then
        test_pass "Responsive typography found ($responsive_font_count responsive font declarations)"
    else
        test_fail "Insufficient responsive typography ($responsive_font_count found)"
        return 1
    fi
    
    # Check for relative units usage
    if grep -q "rem\|em\|%" "$WEBSITE_DIR/css/styles.css"; then
        test_pass "Relative units used for scalable typography"
    else
        test_fail "No relative units found for typography"
        return 1
    fi
}

# Test container and spacing responsiveness
test_responsive_spacing() {
    test_start "Checking responsive spacing and containers"
    
    # Check for container max-width
    if grep -q "max-width.*container\|container.*max-width" "$WEBSITE_DIR/css/styles.css"; then
        test_pass "Container max-width found"
    else
        test_fail "Container max-width not found"
        return 1
    fi
    
    # Check for responsive padding/margin
    local responsive_spacing_count=0
    
    while IFS= read -r line; do
        if [[ $line =~ @media.*padding|@media.*margin|padding.*@media|margin.*@media ]]; then
            ((responsive_spacing_count++))
        fi
    done < "$WEBSITE_DIR/css/styles.css"
    
    if [ $responsive_spacing_count -gt 0 ]; then
        test_pass "Responsive spacing found"
    else
        test_fail "No responsive spacing found"
        return 1
    fi
}

# Test print styles
test_print_styles() {
    test_start "Checking print styles"
    
    if grep -q "@media print" "$WEBSITE_DIR/css/styles.css"; then
        test_pass "Print styles found"
        
        # Check for print-specific optimizations
        local print_optimizations=("display: none" "color: black" "background: white")
        local found_optimizations=0
        
        # Extract print media query content
        local print_section
        print_section=$(sed -n '/@media print/,/^}/p' "$WEBSITE_DIR/css/styles.css")
        
        for optimization in "${print_optimizations[@]}"; do
            if echo "$print_section" | grep -q "$optimization"; then
                ((found_optimizations++))
            fi
        done
        
        if [ $found_optimizations -gt 0 ]; then
            test_pass "Print optimizations found ($found_optimizations)"
        else
            test_fail "No print optimizations found"
            return 1
        fi
    else
        test_fail "Print styles not found"
        return 1
    fi
}

# Test accessibility in responsive design
test_responsive_accessibility() {
    test_start "Checking responsive accessibility features"
    
    # Check for focus styles
    if grep -q ":focus" "$WEBSITE_DIR/css/styles.css"; then
        test_pass "Focus styles found"
    else
        test_fail "Focus styles not found"
        return 1
    fi
    
    # Check for reduced motion support
    if grep -q "prefers-reduced-motion" "$WEBSITE_DIR/css/styles.css"; then
        test_pass "Reduced motion support found"
    else
        test_fail "Reduced motion support not found"
        return 1
    fi
    
    # Check for high contrast support
    if grep -q "prefers-contrast" "$WEBSITE_DIR/css/styles.css"; then
        test_pass "High contrast support found"
    else
        test_skip "High contrast support not found (optional)"
    fi
}

# Generate test report
generate_report() {
    echo ""
    log "=== Responsive Design Test Results ==="
    log "Tests Run: $TESTS_RUN"
    log "Tests Passed: $TESTS_PASSED"
    log "Tests Failed: $TESTS_FAILED"
    log "Tests Skipped: $((TESTS_RUN - TESTS_PASSED - TESTS_FAILED))"
    
    local success_rate=0
    if [ $TESTS_RUN -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    
    log "Success Rate: ${success_rate}%"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log "${GREEN}🎉 All responsive design tests passed!${NC}"
        return 0
    else
        log "${RED}❌ Some responsive design tests failed. Please review the issues above.${NC}"
        return 1
    fi
}

# Main test execution
main() {
    init_tests
    
    # Run all tests
    check_prerequisites || exit 1
    
    test_viewport_meta
    test_media_queries
    test_mobile_first
    test_flexible_layouts
    test_responsive_images
    test_responsive_navigation
    test_responsive_typography
    test_responsive_spacing
    test_print_styles
    test_responsive_accessibility
    
    # Generate final report
    generate_report
    
    echo ""
    echo "Completed at: $(date)" >> "$TEST_LOG"
    log "Test results saved to: $TEST_LOG"
}

# Run tests
main "$@"