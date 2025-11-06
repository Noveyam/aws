#!/bin/bash

# =============================================================================
# Website Accessibility Testing Script
# Tests website for WCAG compliance and accessibility best practices
# =============================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
WEBSITE_DIR="$PROJECT_ROOT/website"
TEST_LOG="$PROJECT_ROOT/accessibility-tests.log"

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
    echo "=== Website Accessibility Tests ===" > "$TEST_LOG"
    echo "Started at: $(date)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    info "Starting accessibility tests..."
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

# Test HTML semantic structure
test_semantic_html() {
    test_start "Checking semantic HTML structure"
    
    local semantic_elements=("header" "nav" "main" "section" "article" "aside" "footer")
    local found_elements=0
    
    for element in "${semantic_elements[@]}"; do
        if grep -q "<$element" "$WEBSITE_DIR/index.html"; then
            ((found_elements++))
            info "Found semantic element: $element"
        fi
    done
    
    if [ $found_elements -ge 4 ]; then
        test_pass "Good semantic HTML structure ($found_elements/7 semantic elements found)"
    else
        test_fail "Insufficient semantic HTML structure ($found_elements/7 semantic elements found)"
        return 1
    fi
}

# Test heading hierarchy
test_heading_hierarchy() {
    test_start "Checking heading hierarchy"
    
    local h1_count h2_count h3_count h4_count h5_count h6_count
    h1_count=$(grep -o "<h1" "$WEBSITE_DIR/index.html" | wc -l || echo "0")
    h2_count=$(grep -o "<h2" "$WEBSITE_DIR/index.html" | wc -l || echo "0")
    h3_count=$(grep -o "<h3" "$WEBSITE_DIR/index.html" | wc -l || echo "0")
    h4_count=$(grep -o "<h4" "$WEBSITE_DIR/index.html" | wc -l || echo "0")
    h5_count=$(grep -o "<h5" "$WEBSITE_DIR/index.html" | wc -l || echo "0")
    h6_count=$(grep -o "<h6" "$WEBSITE_DIR/index.html" | wc -l || echo "0")
    
    info "Heading counts: H1($h1_count) H2($h2_count) H3($h3_count) H4($h4_count) H5($h5_count) H6($h6_count)"
    
    # Check for single H1
    if [ "$h1_count" -eq 1 ]; then
        test_pass "Single H1 element found"
    elif [ "$h1_count" -eq 0 ]; then
        test_fail "No H1 element found"
        return 1
    else
        test_fail "Multiple H1 elements found ($h1_count)"
        return 1
    fi
    
    # Check for logical heading progression
    if [ "$h2_count" -gt 0 ] && [ "$h1_count" -gt 0 ]; then
        test_pass "Logical heading hierarchy (H1 followed by H2)"
    else
        test_fail "Illogical heading hierarchy"
        return 1
    fi
}

# Test image alt attributes
test_image_alt_attributes() {
    test_start "Checking image alt attributes"
    
    local total_images=0
    local images_with_alt=0
    local images_with_empty_alt=0
    
    while IFS= read -r line; do
        if [[ $line =~ \<img[^>]*src= ]]; then
            ((total_images++))
            if [[ $line =~ alt=\"([^\"]*)\" ]]; then
                ((images_with_alt++))
                local alt_text="${BASH_REMATCH[1]}"
                if [ -z "$alt_text" ]; then
                    ((images_with_empty_alt++))
                fi
            fi
        fi
    done < "$WEBSITE_DIR/index.html"
    
    if [ $total_images -eq 0 ]; then
        test_skip "No images found to test"
        return 0
    fi
    
    info "Found $total_images images, $images_with_alt with alt attributes"
    
    if [ $images_with_alt -eq $total_images ]; then
        test_pass "All images have alt attributes"
        
        if [ $images_with_empty_alt -gt 0 ]; then
            info "Note: $images_with_empty_alt images have empty alt attributes (decorative images)"
        fi
    else
        test_fail "Some images missing alt attributes ($images_with_alt/$total_images)"
        return 1
    fi
}

# Test link accessibility
test_link_accessibility() {
    test_start "Checking link accessibility"
    
    local total_links=0
    local links_with_text=0
    local external_links=0
    local external_links_with_target=0
    
    while IFS= read -r line; do
        if [[ $line =~ \<a[^>]*href= ]]; then
            ((total_links++))
            
            # Check if link has text content or aria-label
            if [[ $line =~ \>[^<]+\< ]] || [[ $line =~ aria-label= ]]; then
                ((links_with_text++))
            fi
            
            # Check external links
            if [[ $line =~ href=\"http ]] || [[ $line =~ href=\"https ]]; then
                ((external_links++))
                if [[ $line =~ target=\"_blank\" ]]; then
                    ((external_links_with_target++))
                    # Check for rel="noopener" or rel="noreferrer"
                    if [[ $line =~ rel=\"[^\"]*noopener ]] || [[ $line =~ rel=\"[^\"]*noreferrer ]]; then
                        info "External link has proper security attributes"
                    else
                        log "${YELLOW}⚠ External link missing security attributes (rel=\"noopener\")${NC}"
                    fi
                fi
            fi
        fi
    done < "$WEBSITE_DIR/index.html"
    
    if [ $total_links -eq 0 ]; then
        test_skip "No links found to test"
        return 0
    fi
    
    info "Found $total_links links, $links_with_text with accessible text"
    
    if [ $links_with_text -eq $total_links ]; then
        test_pass "All links have accessible text"
    else
        test_fail "Some links missing accessible text ($links_with_text/$total_links)"
        return 1
    fi
    
    if [ $external_links -gt 0 ]; then
        info "Found $external_links external links"
        if [ $external_links_with_target -eq $external_links ]; then
            test_pass "External links properly configured with target=\"_blank\""
        else
            test_skip "Some external links don't open in new tab (may be intentional)"
        fi
    fi
}

# Test form accessibility
test_form_accessibility() {
    test_start "Checking form accessibility"
    
    local form_count
    form_count=$(grep -c "<form" "$WEBSITE_DIR/index.html" || echo "0")
    
    if [ "$form_count" -eq 0 ]; then
        test_skip "No forms found to test"
        return 0
    fi
    
    local input_count=0
    local inputs_with_labels=0
    
    while IFS= read -r line; do
        if [[ $line =~ \<input[^>]*type= ]] || [[ $line =~ \<textarea ]] || [[ $line =~ \<select ]]; then
            ((input_count++))
            
            # Check for associated label (by id/for or wrapping label)
            local input_id=""
            if [[ $line =~ id=\"([^\"]*)\" ]]; then
                input_id="${BASH_REMATCH[1]}"
                if grep -q "for=\"$input_id\"" "$WEBSITE_DIR/index.html"; then
                    ((inputs_with_labels++))
                fi
            fi
            
            # Check for aria-label
            if [[ $line =~ aria-label= ]]; then
                ((inputs_with_labels++))
            fi
            
            # Check for placeholder as label (not recommended but counted)
            if [[ $line =~ placeholder= ]]; then
                info "Input uses placeholder (consider proper label instead)"
            fi
        fi
    done < "$WEBSITE_DIR/index.html"
    
    if [ $input_count -gt 0 ]; then
        if [ $inputs_with_labels -eq $input_count ]; then
            test_pass "All form inputs have labels"
        else
            test_fail "Some form inputs missing labels ($inputs_with_labels/$input_count)"
            return 1
        fi
    fi
}

# Test ARIA attributes
test_aria_attributes() {
    test_start "Checking ARIA attributes"
    
    local aria_attributes=("aria-label" "aria-labelledby" "aria-describedby" "aria-expanded" "aria-hidden" "role")
    local found_aria=0
    
    for attr in "${aria_attributes[@]}"; do
        if grep -q "$attr=" "$WEBSITE_DIR/index.html"; then
            ((found_aria++))
            info "Found ARIA attribute: $attr"
        fi
    done
    
    if [ $found_aria -gt 0 ]; then
        test_pass "ARIA attributes found ($found_aria attributes)"
    else
        test_skip "No ARIA attributes found (may not be needed for simple sites)"
    fi
    
    # Check for proper role usage
    if grep -q "role=" "$WEBSITE_DIR/index.html"; then
        # Check for common roles
        local roles=("banner" "navigation" "main" "contentinfo" "button")
        local proper_roles=0
        
        for role in "${roles[@]}"; do
            if grep -q "role=\"$role\"" "$WEBSITE_DIR/index.html"; then
                ((proper_roles++))
            fi
        done
        
        if [ $proper_roles -gt 0 ]; then
            test_pass "Proper ARIA roles found"
        else
            test_skip "ARIA roles found but none of the common landmark roles"
        fi
    fi
}

# Test skip links
test_skip_links() {
    test_start "Checking skip navigation links"
    
    if grep -q "skip.*content\|skip.*main\|skip.*navigation" "$WEBSITE_DIR/index.html"; then
        test_pass "Skip navigation link found"
        
        # Check if skip link is properly positioned
        if grep -q "skip.*content\|skip.*main" "$WEBSITE_DIR/index.html" | head -10; then
            test_pass "Skip link appears early in document"
        else
            test_fail "Skip link not positioned early in document"
            return 1
        fi
    else
        test_fail "Skip navigation link not found"
        return 1
    fi
}

# Test color contrast (basic check)
test_color_contrast() {
    test_start "Checking color contrast considerations"
    
    # This is a basic check - full color contrast testing requires specialized tools
    
    # Check for CSS custom properties for colors
    if grep -q "--.*color\|--.*bg" "$WEBSITE_DIR/css/styles.css"; then
        test_pass "CSS custom properties for colors found (good for theming)"
    else
        test_skip "No CSS custom properties for colors (not required)"
    fi
    
    # Check for high contrast media query support
    if grep -q "prefers-contrast" "$WEBSITE_DIR/css/styles.css"; then
        test_pass "High contrast preference support found"
    else
        test_skip "High contrast preference support not found (recommended)"
    fi
    
    # Check for color-only information warnings
    if grep -q "color.*red\|color.*green" "$WEBSITE_DIR/css/styles.css"; then
        log "${YELLOW}⚠ Consider not relying solely on color to convey information${NC}"
    fi
}

# Test keyboard navigation
test_keyboard_navigation() {
    test_start "Checking keyboard navigation support"
    
    # Check for focus styles
    local focus_styles=0
    
    if grep -q ":focus" "$WEBSITE_DIR/css/styles.css"; then
        focus_styles=$(grep -c ":focus" "$WEBSITE_DIR/css/styles.css")
        test_pass "Focus styles found ($focus_styles declarations)"
    else
        test_fail "No focus styles found"
        return 1
    fi
    
    # Check for focus-visible support
    if grep -q ":focus-visible" "$WEBSITE_DIR/css/styles.css"; then
        test_pass "Modern focus-visible styles found"
    else
        test_skip "Focus-visible styles not found (modern enhancement)"
    fi
    
    # Check for tabindex usage
    if grep -q "tabindex=" "$WEBSITE_DIR/index.html"; then
        local negative_tabindex
        negative_tabindex=$(grep -c "tabindex=\"-1\"" "$WEBSITE_DIR/index.html" || echo "0")
        local positive_tabindex
        positive_tabindex=$(grep -c "tabindex=\"[1-9]" "$WEBSITE_DIR/index.html" || echo "0")
        
        if [ "$positive_tabindex" -gt 0 ]; then
            test_fail "Positive tabindex values found (avoid unless necessary)"
            return 1
        else
            test_pass "Proper tabindex usage (only -1 or 0)"
        fi
    else
        test_skip "No tabindex attributes found (relying on natural tab order)"
    fi
}

# Test motion and animation accessibility
test_motion_accessibility() {
    test_start "Checking motion and animation accessibility"
    
    # Check for reduced motion support
    if grep -q "prefers-reduced-motion" "$WEBSITE_DIR/css/styles.css"; then
        test_pass "Reduced motion preference support found"
        
        # Check if animations are properly disabled
        local reduced_motion_section
        reduced_motion_section=$(sed -n '/@media.*prefers-reduced-motion/,/^}/p' "$WEBSITE_DIR/css/styles.css")
        
        if echo "$reduced_motion_section" | grep -q "animation.*none\|transition.*none"; then
            test_pass "Animations properly disabled for reduced motion"
        else
            test_fail "Reduced motion support found but animations not properly disabled"
            return 1
        fi
    else
        test_fail "Reduced motion preference support not found"
        return 1
    fi
    
    # Check for reasonable animation durations
    if grep -q "animation-duration\|transition-duration" "$WEBSITE_DIR/css/styles.css"; then
        local long_animations
        long_animations=$(grep -c "duration.*[5-9]s\|duration.*[1-9][0-9]s" "$WEBSITE_DIR/css/styles.css" || echo "0")
        
        if [ "$long_animations" -eq 0 ]; then
            test_pass "Animation durations appear reasonable"
        else
            test_fail "Some animations may be too long ($long_animations found)"
            return 1
        fi
    else
        test_skip "No explicit animation durations found"
    fi
}

# Test language and internationalization
test_language_attributes() {
    test_start "Checking language attributes"
    
    # Check for lang attribute on html element
    if grep -q "<html.*lang=" "$WEBSITE_DIR/index.html"; then
        local lang_value
        lang_value=$(grep "<html.*lang=" "$WEBSITE_DIR/index.html" | sed 's/.*lang="\([^"]*\)".*/\1/')
        test_pass "Language attribute found: $lang_value"
    else
        test_fail "Language attribute not found on html element"
        return 1
    fi
    
    # Check for proper charset declaration
    if grep -q "charset.*UTF-8\|charset.*utf-8" "$WEBSITE_DIR/index.html"; then
        test_pass "UTF-8 charset declaration found"
    else
        test_fail "UTF-8 charset declaration not found"
        return 1
    fi
}

# Generate test report
generate_report() {
    echo ""
    log "=== Accessibility Test Results ==="
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
    log "=== Accessibility Recommendations ==="
    log "• Test with screen readers (NVDA, JAWS, VoiceOver)"
    log "• Validate with automated tools (axe, WAVE, Lighthouse)"
    log "• Test keyboard navigation manually"
    log "• Verify color contrast ratios (4.5:1 for normal text, 3:1 for large text)"
    log "• Test with users who have disabilities"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log "${GREEN}🎉 All accessibility tests passed!${NC}"
        return 0
    else
        log "${RED}❌ Some accessibility tests failed. Please review the issues above.${NC}"
        return 1
    fi
}

# Main test execution
main() {
    init_tests
    
    # Run all tests
    check_prerequisites || exit 1
    
    test_semantic_html
    test_heading_hierarchy
    test_image_alt_attributes
    test_link_accessibility
    test_form_accessibility
    test_aria_attributes
    test_skip_links
    test_color_contrast
    test_keyboard_navigation
    test_motion_accessibility
    test_language_attributes
    
    # Generate final report
    generate_report
    
    echo ""
    echo "Completed at: $(date)" >> "$TEST_LOG"
    log "Test results saved to: $TEST_LOG"
}

# Run tests
main "$@"