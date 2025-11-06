/**
 * Resume Website Interactive Functionality
 * Handles smooth scrolling, mobile navigation, and user interactions
 */

(function() {
    'use strict';

    // DOM elements
    const navLinks = document.querySelectorAll('.nav-link');
    const mobileMenuToggle = document.querySelector('.mobile-menu-toggle');
    const navList = document.querySelector('.nav-list');
    const sections = document.querySelectorAll('.section');
    
    // Configuration
    const config = {
        scrollOffset: 80, // Offset for sticky navigation
        scrollDuration: 800, // Smooth scroll duration in ms
        activeNavClass: 'active',
        mobileMenuActiveClass: 'mobile-menu-active'
    };

    /**
     * Initialize all functionality when DOM is loaded
     */
    function init() {
        setupSmoothScrolling();
        setupMobileMenu();
        setupActiveNavigation();
        setupScrollToTop();
        setupFormValidation();
        setupAccessibility();
        setupPerformanceOptimizations();
    }

    /**
     * Smooth scrolling for navigation links
     */
    function setupSmoothScrolling() {
        navLinks.forEach(link => {
            link.addEventListener('click', function(e) {
                e.preventDefault();
                
                const targetId = this.getAttribute('href').substring(1);
                const targetSection = document.getElementById(targetId);
                
                if (targetSection) {
                    const targetPosition = targetSection.offsetTop - config.scrollOffset;
                    
                    // Close mobile menu if open
                    closeMobileMenu();
                    
                    // Smooth scroll to target
                    window.scrollTo({
                        top: targetPosition,
                        behavior: 'smooth'
                    });
                    
                    // Update URL without triggering scroll
                    history.pushState(null, null, `#${targetId}`);
                }
            });
        });
    }

    /**
     * Mobile menu toggle functionality
     */
    function setupMobileMenu() {
        if (!mobileMenuToggle || !navList) return;

        mobileMenuToggle.addEventListener('click', function() {
            toggleMobileMenu();
        });

        // Close mobile menu when clicking outside
        document.addEventListener('click', function(e) {
            if (!e.target.closest('.navigation')) {
                closeMobileMenu();
            }
        });

        // Close mobile menu on escape key
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                closeMobileMenu();
            }
        });

        // Handle window resize
        window.addEventListener('resize', function() {
            if (window.innerWidth > 768) {
                closeMobileMenu();
            }
        });
    }

    /**
     * Toggle mobile menu state
     */
    function toggleMobileMenu() {
        const isActive = navList.classList.contains(config.mobileMenuActiveClass);
        
        if (isActive) {
            closeMobileMenu();
        } else {
            openMobileMenu();
        }
    }

    /**
     * Open mobile menu
     */
    function openMobileMenu() {
        navList.classList.add(config.mobileMenuActiveClass);
        mobileMenuToggle.classList.add(config.mobileMenuActiveClass);
        mobileMenuToggle.setAttribute('aria-expanded', 'true');
        
        // Animate hamburger menu
        const spans = mobileMenuToggle.querySelectorAll('span');
        spans[0].style.transform = 'rotate(45deg) translate(5px, 5px)';
        spans[1].style.opacity = '0';
        spans[2].style.transform = 'rotate(-45deg) translate(7px, -6px)';
    }

    /**
     * Close mobile menu
     */
    function closeMobileMenu() {
        navList.classList.remove(config.mobileMenuActiveClass);
        mobileMenuToggle.classList.remove(config.mobileMenuActiveClass);
        mobileMenuToggle.setAttribute('aria-expanded', 'false');
        
        // Reset hamburger menu
        const spans = mobileMenuToggle.querySelectorAll('span');
        spans[0].style.transform = '';
        spans[1].style.opacity = '';
        spans[2].style.transform = '';
    }

    /**
     * Active navigation highlighting based on scroll position
     */
    function setupActiveNavigation() {
        let ticking = false;

        function updateActiveNav() {
            const scrollPosition = window.scrollY + config.scrollOffset + 50;
            
            let activeSection = null;
            
            sections.forEach(section => {
                const sectionTop = section.offsetTop;
                const sectionBottom = sectionTop + section.offsetHeight;
                
                if (scrollPosition >= sectionTop && scrollPosition < sectionBottom) {
                    activeSection = section;
                }
            });

            // Update active nav link
            navLinks.forEach(link => {
                link.classList.remove(config.activeNavClass);
                
                if (activeSection) {
                    const targetId = activeSection.getAttribute('id');
                    if (link.getAttribute('href') === `#${targetId}`) {
                        link.classList.add(config.activeNavClass);
                    }
                }
            });

            ticking = false;
        }

        function onScroll() {
            if (!ticking) {
                requestAnimationFrame(updateActiveNav);
                ticking = true;
            }
        }

        window.addEventListener('scroll', onScroll, { passive: true });
    }

    /**
     * Scroll to top functionality
     */
    function setupScrollToTop() {
        // Create scroll to top button
        const scrollToTopBtn = document.createElement('button');
        scrollToTopBtn.innerHTML = '↑';
        scrollToTopBtn.className = 'scroll-to-top';
        scrollToTopBtn.setAttribute('aria-label', 'Scroll to top');
        scrollToTopBtn.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            width: 50px;
            height: 50px;
            border-radius: 50%;
            background: #667eea;
            color: white;
            border: none;
            font-size: 20px;
            cursor: pointer;
            opacity: 0;
            visibility: hidden;
            transition: all 0.3s ease;
            z-index: 1000;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        `;

        document.body.appendChild(scrollToTopBtn);

        // Show/hide scroll to top button
        let scrollTimeout;
        window.addEventListener('scroll', function() {
            clearTimeout(scrollTimeout);
            
            if (window.scrollY > 300) {
                scrollToTopBtn.style.opacity = '1';
                scrollToTopBtn.style.visibility = 'visible';
            } else {
                scrollToTopBtn.style.opacity = '0';
                scrollToTopBtn.style.visibility = 'hidden';
            }
        }, { passive: true });

        // Scroll to top on click
        scrollToTopBtn.addEventListener('click', function() {
            window.scrollTo({
                top: 0,
                behavior: 'smooth'
            });
        });
    }

    /**
     * Form validation (if contact forms are added later)
     */
    function setupFormValidation() {
        const forms = document.querySelectorAll('form');
        
        forms.forEach(form => {
            form.addEventListener('submit', function(e) {
                if (!validateForm(this)) {
                    e.preventDefault();
                }
            });

            // Real-time validation
            const inputs = form.querySelectorAll('input, textarea');
            inputs.forEach(input => {
                input.addEventListener('blur', function() {
                    validateField(this);
                });
            });
        });
    }

    /**
     * Validate individual form field
     */
    function validateField(field) {
        const value = field.value.trim();
        const type = field.type;
        let isValid = true;
        let errorMessage = '';

        // Remove existing error styling
        field.classList.remove('error');
        const existingError = field.parentNode.querySelector('.error-message');
        if (existingError) {
            existingError.remove();
        }

        // Validation rules
        if (field.hasAttribute('required') && !value) {
            isValid = false;
            errorMessage = 'This field is required';
        } else if (type === 'email' && value && !isValidEmail(value)) {
            isValid = false;
            errorMessage = 'Please enter a valid email address';
        }

        // Show error if invalid
        if (!isValid) {
            field.classList.add('error');
            const errorElement = document.createElement('span');
            errorElement.className = 'error-message';
            errorElement.textContent = errorMessage;
            errorElement.style.cssText = 'color: #dc3545; font-size: 0.875rem; margin-top: 5px; display: block;';
            field.parentNode.appendChild(errorElement);
        }

        return isValid;
    }

    /**
     * Validate entire form
     */
    function validateForm(form) {
        const fields = form.querySelectorAll('input, textarea');
        let isFormValid = true;

        fields.forEach(field => {
            if (!validateField(field)) {
                isFormValid = false;
            }
        });

        return isFormValid;
    }

    /**
     * Email validation helper
     */
    function isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    /**
     * Accessibility enhancements
     */
    function setupAccessibility() {
        // Add ARIA attributes to mobile menu
        if (mobileMenuToggle) {
            mobileMenuToggle.setAttribute('aria-expanded', 'false');
            mobileMenuToggle.setAttribute('aria-controls', 'navigation-menu');
        }

        if (navList) {
            navList.setAttribute('id', 'navigation-menu');
        }

        // Keyboard navigation for custom elements
        document.addEventListener('keydown', function(e) {
            // Handle Enter key on buttons
            if (e.key === 'Enter' && e.target.tagName === 'BUTTON') {
                e.target.click();
            }
        });

        // Focus management for mobile menu
        if (mobileMenuToggle) {
            mobileMenuToggle.addEventListener('keydown', function(e) {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    toggleMobileMenu();
                }
            });
        }
    }

    /**
     * Performance optimizations
     */
    function setupPerformanceOptimizations() {
        // Lazy load images when they come into view
        if ('IntersectionObserver' in window) {
            const imageObserver = new IntersectionObserver((entries, observer) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const img = entry.target;
                        if (img.dataset.src) {
                            img.src = img.dataset.src;
                            img.removeAttribute('data-src');
                            observer.unobserve(img);
                        }
                    }
                });
            });

            document.querySelectorAll('img[data-src]').forEach(img => {
                imageObserver.observe(img);
            });
        }

        // Preload critical resources
        const criticalResources = [
            '/css/styles.css',
            '/images/profile.jpg'
        ];

        criticalResources.forEach(resource => {
            const link = document.createElement('link');
            link.rel = 'preload';
            link.href = resource;
            link.as = resource.endsWith('.css') ? 'style' : 'image';
            document.head.appendChild(link);
        });
    }

    /**
     * Add CSS for mobile menu functionality
     */
    function addMobileMenuStyles() {
        const style = document.createElement('style');
        style.textContent = `
            @media (max-width: 767px) {
                .nav-list {
                    position: absolute;
                    top: 100%;
                    left: 0;
                    right: 0;
                    background: white;
                    flex-direction: column;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
                    max-height: 0;
                    overflow: hidden;
                    transition: max-height 0.3s ease;
                }
                
                .nav-list.mobile-menu-active {
                    max-height: 400px;
                    padding: 20px 0;
                }
                
                .mobile-menu-toggle {
                    display: flex;
                    position: absolute;
                    right: 20px;
                    top: 50%;
                    transform: translateY(-50%);
                }
                
                .navigation {
                    position: relative;
                }
                
                .nav-link.active {
                    background: #667eea;
                    color: white;
                }
                
                .error {
                    border-color: #dc3545 !important;
                    box-shadow: 0 0 0 0.2rem rgba(220, 53, 69, 0.25);
                }
            }
        `;
        document.head.appendChild(style);
    }

    /**
     * Handle page load and hash navigation
     */
    function handleInitialHash() {
        const hash = window.location.hash;
        if (hash) {
            setTimeout(() => {
                const target = document.querySelector(hash);
                if (target) {
                    const targetPosition = target.offsetTop - config.scrollOffset;
                    window.scrollTo({
                        top: targetPosition,
                        behavior: 'smooth'
                    });
                }
            }, 100);
        }
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
            init();
            addMobileMenuStyles();
            handleInitialHash();
        });
    } else {
        init();
        addMobileMenuStyles();
        handleInitialHash();
    }

    // Handle browser back/forward navigation
    window.addEventListener('popstate', handleInitialHash);

    // Export functions for potential external use
    window.ResumeWebsite = {
        scrollToSection: function(sectionId) {
            const section = document.getElementById(sectionId);
            if (section) {
                const targetPosition = section.offsetTop - config.scrollOffset;
                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        },
        
        closeMobileMenu: closeMobileMenu,
        
        validateForm: validateForm
    };

})();