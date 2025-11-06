#!/bin/bash

# =============================================================================
# Website Performance Testing Script
# Tests website performance, optimization, and loading characteristics
# =============================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
WEBSITE_DIR="$PROJECT_ROOT/website"
TEST_LOG="$PROJECT_ROOT/performance-tests.log"

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

# Performance thresholds
MAX_HTML_SIZE=50000      # 50KB
MAX_CSS_SIZE=100000      # 100KB
MAX_JS_SIZE=100000       # 100KB
MAX_IMAGE_SIZE=1048576   # 1MB
MAX_TOTAL_SIZE=5242880   # 5MB

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
warning() { log "${YELLOW}⚠ $1${NC}"; }

# Initialize test logging
init_tests() {
    echo "=== Website Performance Tests ===" > "$TEST_LOG"
    echo "Started at: $(date)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    info "Starting performance tests..."
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
    
    test_pass "Prerequisites check completed"
}

# Get file size in bytes
get_file_size() {
    local file="$1"
    if [ -f "$file" ]; then
        stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$((bytes / 1024))KB"
    else
        echo "$((bytes / 1048576))MB"
    fi
}

# Test HTML file sizes
test_html_file_sizes() {
    test_start "Checking HTML file sizes"
    
    local html_files
    html_files=$(find "$WEBSITE_DIR" -name "*.html" -type f)
    
    if [ -z "$html_files" ]; then
        test_fail "No HTML files found"
        return 1
    fi
    
    local total_html_size=0
    local oversized_files=0
    
    while IFS= read -r file; do
        local file_size
        file_size=$(get_file_size "$file")
        total_html_size=$((total_html_size + file_size))
        
        local filename
        filename=$(basename "$file")
        
        if [ $file_size -gt $MAX_HTML_SIZE ]; then
            warning "Large HTML file: $filename ($(format_bytes $file_size))"
            ((oversized_files++))
        else
            info "HTML file: $filename ($(format_bytes $file_size))"
        fi
    done <<< "$html_files"
    
    info "Total HTML size: $(format_bytes $total_html_size)"
    
    if [ $oversized_files -eq 0 ]; then
        test_pass "All HTML files within size limits"
    else
        test_fail "$oversized_files HTML files exceed recommended size"
        return 1
    fi
}

# Test CSS file sizes and optimization
test_css_optimization() {
    test_start "Checking CSS optimization"
    
    local css_files
    css_files=$(find "$WEBSITE_DIR" -name "*.css" -type f)
    
    if [ -z "$css_files" ]; then
        test_fail "No CSS files found"
        return 1
    fi
    
    local total_css_size=0
    local oversized_files=0
    local optimization_issues=0
    
    while IFS= read -r file; do
        local file_size
        file_size=$(get_file_size "$file")
        total_css_size=$((total_css_size + file_size))
        
        local filename
        filename=$(basename "$file")
        
        if [ $file_size -gt $MAX_CSS_SIZE ]; then
            warning "Large CSS file: $filename ($(format_bytes $file_size))"
            ((oversized_files++))
        else
            info "CSS file: $filename ($(format_bytes $file_size))"
        fi
        
        # Check for optimization opportunities
        local comments_count
        comments_count=$(grep -c "/\*.*\*/" "$file" || echo "0")
        
        local empty_lines
        empty_lines=$(grep -c "^[[:space:]]*$" "$file" || echo "0")
        
        if [ $comments_count -gt 10 ] || [ $empty_lines -gt 20 ]; then
            warning "CSS file could be minified: $filename (comments: $comments_count, empty lines: $empty_lines)"
            ((optimization_issues++))
        fi
        
    done <<< "$css_files"
    
    info "Total CSS size: $(format_bytes $total_css_size)"
    
    local css_issues=$((oversized_files + optimization_issues))
    
    if [ $css_issues -eq 0 ]; then
        test_pass "CSS files are well optimized"
    else
        test_fail "CSS optimization issues found ($css_issues issues)"
        return 1
    fi
}

# Test JavaScript file sizes and optimization
test_javascript_optimization() {
    test_start "Checking JavaScript optimization"
    
    local js_files
    js_files=$(find "$WEBSITE_DIR" -name "*.js" -type f)
    
    if [ -z "$js_files" ]; then
        test_skip "No JavaScript files found"
        return 0
    fi
    
    local total_js_size=0
    local oversized_files=0
    local optimization_issues=0
    
    while IFS= read -r file; do
        local file_size
        file_size=$(get_file_size "$file")
        total_js_size=$((total_js_size + file_size))
        
        local filename
        filename=$(basename "$file")
        
        if [ $file_size -gt $MAX_JS_SIZE ]; then
            warning "Large JavaScript file: $filename ($(format_bytes $file_size))"
            ((oversized_files++))
        else
            info "JavaScript file: $filename ($(format_bytes $file_size))"
        fi
        
        # Check for optimization opportunities
        local comments_count
        comments_count=$(grep -c "//.*\|/\*.*\*/" "$file" || echo "0")
        
        local console_logs
        console_logs=$(grep -c "console\." "$file" || echo "0")
        
        if [ $comments_count -gt 20 ]; then
            warning "JavaScript file has many comments: $filename ($comments_count comments)"
            ((optimization_issues++))
        fi
        
        if [ $console_logs -gt 5 ]; then
            warning "JavaScript file has console statements: $filename ($console_logs console calls)"
            ((optimization_issues++))
        fi
        
    done <<< "$js_files"
    
    info "Total JavaScript size: $(format_bytes $total_js_size)"
    
    local js_issues=$((oversized_files + optimization_issues))
    
    if [ $js_issues -eq 0 ]; then
        test_pass "JavaScript files are well optimized"
    else
        test_fail "JavaScript optimization issues found ($js_issues issues)"
        return 1
    fi
}

# Test image optimization
test_image_optimization() {
    test_start "Checking image optimization"
    
    local image_files
    image_files=$(find "$WEBSITE_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.svg" -o -name "*.webp" \))
    
    if [ -z "$image_files" ]; then
        test_skip "No image files found"
        return 0
    fi
    
    local total_image_size=0
    local oversized_files=0
    local optimization_suggestions=0
    
    while IFS= read -r file; do
        local file_size
        file_size=$(get_file_size "$file")
        total_image_size=$((total_image_size + file_size))
        
        local filename
        filename=$(basename "$file")
        local extension="${filename##*.}"
        
        if [ $file_size -gt $MAX_IMAGE_SIZE ]; then
            warning "Large image file: $filename ($(format_bytes $file_size))"
            ((oversized_files++))
        else
            info "Image file: $filename ($(format_bytes $file_size))"
        fi
        
        # Check for optimization opportunities based on file type
        case "$extension" in
            "png")
                if [ $file_size -gt 100000 ]; then  # 100KB
                    warning "Large PNG file: $filename - consider JPEG for photos or WebP"
                    ((optimization_suggestions++))
                fi
                ;;
            "jpg"|"jpeg")
                if [ $file_size -gt 500000 ]; then  # 500KB
                    warning "Large JPEG file: $filename - consider compression or WebP"
                    ((optimization_suggestions++))
                fi
                ;;
            "gif")
                warning "GIF file found: $filename - consider WebP or MP4 for animations"
                ((optimization_suggestions++))
                ;;
        esac
        
    done <<< "$image_files"
    
    info "Total image size: $(format_bytes $total_image_size)"
    
    # Check for modern image formats
    local webp_count
    webp_count=$(find "$WEBSITE_DIR" -name "*.webp" -type f | wc -l || echo "0")
    
    if [ "$webp_count" -gt 0 ]; then
        test_pass "Modern image formats (WebP) found"
    else
        info "Consider using WebP format for better compression"
    fi
    
    if [ $oversized_files -eq 0 ]; then
        test_pass "Image files are within size limits"
    else
        test_fail "$oversized_files images exceed recommended size"
        return 1
    fi
}

# Test total website size
test_total_website_size() {
    test_start "Checking total website size"
    
    local total_size=0
    
    # Calculate total size of all website files
    while IFS= read -r file; do
        local file_size
        file_size=$(get_file_size "$file")
        total_size=$((total_size + file_size))
    done < <(find "$WEBSITE_DIR" -type f)
    
    info "Total website size: $(format_bytes $total_size)"
    
    if [ $total_size -le $MAX_TOTAL_SIZE ]; then
        test_pass "Total website size within limits"
    else
        test_fail "Total website size exceeds recommended limit ($(format_bytes $MAX_TOTAL_SIZE))"
        return 1
    fi
}

# Test HTML optimization
test_html_optimization() {
    test_start "Checking HTML optimization"
    
    local html_files
    html_files=$(find "$WEBSITE_DIR" -name "*.html" -type f)
    
    local optimization_issues=0
    
    while IFS= read -r file; do
        local filename
        filename=$(basename "$file")
        
        # Check for minification opportunities
        local empty_lines
        empty_lines=$(grep -c "^[[:space:]]*$" "$file" || echo "0")
        
        local html_comments
        html_comments=$(grep -c "<!--.*-->" "$file" || echo "0")
        
        if [ $empty_lines -gt 20 ]; then
            warning "HTML file has many empty lines: $filename ($empty_lines empty lines)"
            ((optimization_issues++))
        fi
        
        if [ $html_comments -gt 5 ]; then
            info "HTML file has comments: $filename ($html_comments comments) - consider removing for production"
        fi
        
        # Check for inline styles and scripts
        local inline_styles
        inline_styles=$(grep -c "style=" "$file" || echo "0")
        
        local inline_scripts
        inline_scripts=$(grep -c "<script>" "$file" || echo "0")
        
        if [ $inline_styles -gt 3 ]; then
            warning "HTML file has many inline styles: $filename ($inline_styles inline styles)"
            ((optimization_issues++))
        fi
        
        if [ $inline_scripts -gt 1 ]; then
            warning "HTML file has inline scripts: $filename ($inline_scripts inline scripts)"
            ((optimization_issues++))
        fi
        
    done <<< "$html_files"
    
    if [ $optimization_issues -eq 0 ]; then
        test_pass "HTML files are well optimized"
    else
        test_fail "HTML optimization issues found ($optimization_issues issues)"
        return 1
    fi
}

# Test resource loading optimization
test_resource_loading() {
    test_start "Checking resource loading optimization"
    
    local html_file="$WEBSITE_DIR/index.html"
    local loading_issues=0
    
    # Check for CSS in head
    if grep -q "<link.*stylesheet" "$html_file"; then
        local css_in_head
        css_in_head=$(sed -n '/<head>/,/<\/head>/p' "$html_file" | grep -c "stylesheet" || echo "0")
        
        if [ $css_in_head -gt 0 ]; then
            test_pass "CSS loaded in head section"
        else
            warning "CSS not loaded in head section"
            ((loading_issues++))
        fi
    fi
    
    # Check for JavaScript at end of body
    if grep -q "<script" "$html_file"; then
        local js_before_body_end
        js_before_body_end=$(sed -n '/<\/body>/,$p' "$html_file" | head -20 | grep -c "<script" || echo "0")
        
        if [ $js_before_body_end -gt 0 ]; then
            test_pass "JavaScript loaded before closing body tag"
        else
            warning "Consider moving JavaScript to end of body"
            ((loading_issues++))
        fi
    fi
    
    # Check for preload/prefetch hints
    if grep -q "rel=\"preload\"\|rel=\"prefetch\"" "$html_file"; then
        test_pass "Resource hints (preload/prefetch) found"
    else
        info "Consider adding resource hints for critical resources"
    fi
    
    # Check for async/defer on scripts
    if grep -q "async\|defer" "$html_file"; then
        test_pass "Async/defer attributes found on scripts"
    else
        info "Consider using async/defer on non-critical scripts"
    fi
    
    if [ $loading_issues -eq 0 ]; then
        test_pass "Resource loading is optimized"
    else
        test_fail "Resource loading optimization issues found ($loading_issues issues)"
        return 1
    fi
}

# Test caching headers preparation
test_caching_preparation() {
    test_start "Checking caching preparation"
    
    # This test checks if files are organized for proper caching
    local cache_friendly_structure=0
    
    # Check for versioned assets or organized structure
    if [ -d "$WEBSITE_DIR/css" ] && [ -d "$WEBSITE_DIR/js" ]; then
        ((cache_friendly_structure++))
        test_pass "Assets organized in separate directories"
    fi
    
    if [ -d "$WEBSITE_DIR/images" ]; then
        ((cache_friendly_structure++))
        test_pass "Images organized in separate directory"
    fi
    
    # Check for fingerprinting or versioning in filenames
    local versioned_files
    versioned_files=$(find "$WEBSITE_DIR" -name "*-v*.*" -o -name "*.[0-9]*.*" | wc -l || echo "0")
    
    if [ "$versioned_files" -gt 0 ]; then
        test_pass "Versioned files found (good for cache busting)"
    else
        info "Consider file versioning for cache busting"
    fi
    
    if [ $cache_friendly_structure -ge 2 ]; then
        test_pass "Website structure is cache-friendly"
    else
        test_fail "Website structure could be more cache-friendly"
        return 1
    fi
}

# Test performance best practices
test_performance_best_practices() {
    test_start "Checking performance best practices"
    
    local best_practices_score=0
    
    # Check for favicon
    if grep -q "favicon" "$WEBSITE_DIR/index.html" || [ -f "$WEBSITE_DIR/favicon.ico" ]; then
        ((best_practices_score++))
        test_pass "Favicon found"
    else
        warning "Favicon not found"
    fi
    
    # Check for meta description
    if grep -q "meta.*description" "$WEBSITE_DIR/index.html"; then
        ((best_practices_score++))
        test_pass "Meta description found"
    else
        warning "Meta description not found"
    fi
    
    # Check for viewport meta tag
    if grep -q "viewport" "$WEBSITE_DIR/index.html"; then
        ((best_practices_score++))
        test_pass "Viewport meta tag found"
    else
        warning "Viewport meta tag not found"
    fi
    
    # Check for charset declaration
    if grep -q "charset" "$WEBSITE_DIR/index.html"; then
        ((best_practices_score++))
        test_pass "Charset declaration found"
    else
        warning "Charset declaration not found"
    fi
    
    # Check for title tag
    if grep -q "<title>" "$WEBSITE_DIR/index.html"; then
        ((best_practices_score++))
        test_pass "Title tag found"
    else
        warning "Title tag not found"
    fi
    
    if [ $best_practices_score -ge 4 ]; then
        test_pass "Good performance best practices implementation"
    else
        test_fail "Performance best practices need improvement ($best_practices_score/5)"
        return 1
    fi
}

# Generate performance report
generate_performance_report() {
    echo ""
    log "=== Performance Test Results ==="
    log "Tests Run: $TESTS_RUN"
    log "Tests Passed: $TESTS_PASSED"
    log "Tests Failed: $TESTS_FAILED"
    log "Tests Skipped: $((TESTS_RUN - TESTS_PASSED - TESTS_FAILED))"
    
    local success_rate=0
    if [ $TESTS_RUN -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    
    log "Success Rate: ${success_rate}%"
    
    echo ""
    log "=== Performance Recommendations ==="
    log "• Use WebP format for images when possible"
    log "• Minify CSS and JavaScript for production"
    log "• Implement proper caching headers on server"
    log "• Consider using a CDN (CloudFront is already configured)"
    log "• Test with Google PageSpeed Insights and Lighthouse"
    log "• Monitor Core Web Vitals (LCP, FID, CLS)"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log "${GREEN}🎉 All performance tests passed!${NC}"
        return 0
    else
        log "${RED}❌ Some performance tests failed. Please review the issues above.${NC}"
        return 1
    fi
}

# Main test execution
main() {
    init_tests
    
    # Run all tests
    check_prerequisites || exit 1
    
    test_html_file_sizes
    test_css_optimization
    test_javascript_optimization
    test_image_optimization
    test_total_website_size
    test_html_optimization
    test_resource_loading
    test_caching_preparation
    test_performance_best_practices
    
    # Generate final report
    generate_performance_report
    
    echo ""
    echo "Completed at: $(date)" >> "$TEST_LOG"
    log "Test results saved to: $TEST_LOG"
}

# Run tests
main "$@"