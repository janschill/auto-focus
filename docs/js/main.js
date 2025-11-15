document.addEventListener('DOMContentLoaded', function() {
    // Load version info and update download links
    fetch('/downloads/version.json')
        .then(response => response.json())
        .then(versionInfo => {
            // Update all download links to use versioned filename
            const downloadLinks = document.querySelectorAll('a[href*="downloads/Auto-Focus.zip"]');
            downloadLinks.forEach(link => {
                const currentHref = link.getAttribute('href');
                if (currentHref.includes('downloads/Auto-Focus.zip')) {
                    link.setAttribute('href', `downloads/${versionInfo.app_zip}`);
                    // Add cache-busting query parameter as fallback
                    link.setAttribute('href', link.getAttribute('href') + `?v=${versionInfo.version}`);
                }
            });
            console.log('✅ Updated download links to version:', versionInfo.version);
        })
        .catch(error => {
            console.warn('⚠️ Could not load version.json, using default download links:', error);
        });

    // Configuration
    const config = {
        production: {
            stripe: Stripe('pk_live_51RJsTJHG3jEF4MbtWkI32NWB3j69lMvPnwlAhH81xKsWwko0vNrj9rTZzsvzaUzmSYqMbSnTGrS7Xs24ymwIoqay008AuEGDQG'),
            priceId: 'price_1RqXaoHG3jEF4MbtgS8HRwXE', // Multi-currency price ID
            successUrl: 'https://auto-focus.app/success',
            cancelUrl: 'https://auto-focus.app/canceled'
        },
        staging: {
            stripe: Stripe('pk_test_51RJsTSQnG2sk4c6Rt00Ew1IrNguokLwQkvBcpTwVLsM92rYoQeqBW56MkrE2nZoIRacFMxCf9y9uv2UrxXUN0Cum00tPXy1cEW'),
            priceId: 'price_1RYAKiQnG2sk4c6RQTPMZ6HT',
            successUrl: 'https://auto-focus.app/success?env=staging',
            cancelUrl: 'https://auto-focus.app/canceled?env=staging',
            apiUrl: 'https://staging.auto-focus.app/api/'
        }
    };

    // Currency detection function
    function detectUserCurrency() {
        // Try to get user's locale and determine currency
        const userLocale = navigator.language || navigator.languages[0] || 'en-US';
        const region = userLocale.split('-')[1] || userLocale.split('_')[1];
        const language = userLocale.split('-')[0] || userLocale.split('_')[0];

        // Map regions to currencies (based on the available Stripe prices)
        const regionToCurrency = {
            'DK': 'DKK',    // Denmark
            'NO': 'NOK',    // Norway
            'SE': 'NOK',    // Sweden (use NOK as closest)
            'FI': 'EUR',    // Finland
            'DE': 'EUR',    // Germany
            'FR': 'EUR',    // France
            'ES': 'EUR',    // Spain
            'IT': 'EUR',    // Italy
            'NL': 'EUR',    // Netherlands
            'BE': 'EUR',    // Belgium
            'AT': 'EUR',    // Austria
            'PT': 'EUR',    // Portugal
            'IE': 'EUR',    // Ireland
            'LU': 'EUR',    // Luxembourg
        };

        // Map language codes to currencies (fallback when region is not available)
        const languageToCurrency = {
            'da': 'DKK',    // Danish
            'no': 'NOK',    // Norwegian
            'nb': 'NOK',    // Norwegian Bokmål
            'nn': 'NOK',    // Norwegian Nynorsk
            'sv': 'NOK',    // Swedish (use NOK as closest)
            'fi': 'EUR',    // Finnish
            'de': 'EUR',    // German
            'fr': 'EUR',    // French
            'es': 'EUR',    // Spanish
            'it': 'EUR',    // Italian
            'nl': 'EUR',    // Dutch
            'pt': 'EUR',    // Portuguese
        };

        // If we have a specific mapping for the region, use it first
        if (region && regionToCurrency[region]) {
            return regionToCurrency[region];
        }

        // If no region, try to map based on language code
        if (language && languageToCurrency[language]) {
            return languageToCurrency[language];
        }

        // Default to USD for all other regions (US, Canada, UK, Asia, etc.)
        return 'USD';
    }

    // Get user's detected currency
    const userCurrency = detectUserCurrency();

    // Update pricing display based on detected currency
    function updatePricingDisplay() {
        const priceElement = document.querySelector('.pricing-amount');
        const currencyElement = document.querySelector('.pricing-currency');

        if (priceElement && currencyElement) {
            switch(userCurrency) {
                case 'DKK':
                    priceElement.textContent = '65';
                    currencyElement.textContent = 'DKK ';
                    break;
                case 'EUR':
                    priceElement.textContent = '9';
                    currencyElement.textContent = '€';
                    break;
                case 'NOK':
                    priceElement.textContent = '99';
                    currencyElement.textContent = 'NOK ';
                    break;
                default: // USD
                    priceElement.textContent = '9';
                    currencyElement.textContent = '$';
                    break;
            }
        }
    }

    // Call pricing update
    updatePricingDisplay();

    // Show staging button if URL contains ?staging=1
    const showStaging = window.location.search.includes('staging=1');

    if (showStaging) {
        const stagingButton = document.getElementById('staging-checkout-button');
        if (stagingButton) {
            stagingButton.style.display = 'flex';

            // Add staging indicator to page
            const title = document.querySelector('h1');
            if (title) {
                const stagingBadge = document.createElement('div');
                stagingBadge.innerHTML = '🧪 STAGING MODE - Test payments enabled';
                stagingBadge.className = 'bg-orange-100 border border-orange-300 text-orange-800 px-4 py-2 rounded-lg text-sm font-medium text-center mb-4';
                title.parentNode.insertBefore(stagingBadge, title.nextSibling);
            }
        }
    }

    // Production checkout
    const productionButton = document.getElementById('checkout-button');
    if (productionButton) {
        productionButton.addEventListener('click', function () {
            const prod = config.production;
            prod.stripe.redirectToCheckout({
                lineItems: [{price: prod.priceId, quantity: 1}],
                mode: 'payment',
                successUrl: prod.successUrl,
                cancelUrl: prod.cancelUrl,
            })
            .then(function (result) {
                if (result.error) {
                    const displayError = document.getElementById('error-message');
                    displayError.textContent = result.error.message;
                }
            });
        });
    }

    // Staging checkout
    const stagingButton = document.getElementById('staging-checkout-button');
    if (stagingButton) {
        stagingButton.addEventListener('click', function () {
            const staging = config.staging;

            staging.stripe.redirectToCheckout({
                lineItems: [{price: staging.priceId, quantity: 1}],
                mode: 'payment',
                successUrl: staging.successUrl,
                cancelUrl: staging.cancelUrl,
            })
            .then(function (result) {
                if (result.error) {
                    const displayError = document.getElementById('staging-error-message');
                    displayError.textContent = result.error.message;
                }
            });
        });
    }

    // Demo Animation Logic
    function startDemoAnimation() {
        const notifications = ['notif-1', 'notif-2', 'notif-3'];
        const brainOutline = document.getElementById('brain-outline');
        const brainFilled = document.getElementById('brain-filled');
        const brainText = document.getElementById('brain-text');

        // Reset animation state
        notifications.forEach(id => {
            const notif = document.getElementById(id);
            notif.classList.remove('show', 'fade-out');
        });
        brainOutline.style.opacity = '1';
        brainFilled.style.opacity = '0';
        brainText.style.opacity = '0';

        // Animation sequence
        setTimeout(() => {
            // Step 1: Show notifications one by one (0-2s)
            notifications.forEach((id, index) => {
                setTimeout(() => {
                    document.getElementById(id).classList.add('show');
                }, index * 600);
            });
        }, 500);

        setTimeout(() => {
            // Step 2: Activate brain (transition from outline to filled) (3s)
            brainOutline.style.opacity = '0';
            brainFilled.style.opacity = '1';
            brainText.style.opacity = '1';
        }, 3000);

        setTimeout(() => {
            // Step 3: Fade out notifications (3.5s)
            notifications.forEach((id, index) => {
                setTimeout(() => {
                    const notif = document.getElementById(id);
                    notif.classList.remove('show');
                    notif.classList.add('fade-out');
                }, index * 200);
            });
        }, 3500);

        setTimeout(() => {
            // Step 4: Reset brain to outline and restart (7s)
            brainOutline.style.opacity = '1';
            brainFilled.style.opacity = '0';
            brainText.style.opacity = '0';
        }, 7000);

        // Loop the animation
        setTimeout(startDemoAnimation, 8000);
    }

    // Start animation when page loads
    window.addEventListener('load', () => {
        setTimeout(startDemoAnimation, 1000);
    });

});

// Make screenshots data available globally for the changeScreenshot function
const screenshots = [
    {
        src: 'images/auto-focus-menubar-window-in-focus-2.png',
        title: 'Active Focus Mode',
        description: 'When in focus, see your current session time and manual controls right from your menu bar.'
    },
    {
        src: 'images/auto-focus-menubar-window-out-of-focus-2.png',
        title: 'Menu Bar Overview',
        description: 'Quick glance at your daily focus stats and easy access to app settings when not in focus.'
    },
    {
        src: 'images/auto-focus-configuration-view-2.png',
        title: 'Configuration',
        description: 'Configure your focus apps, set custom thresholds, and manage browser integration with an intuitive interface.'
    },
    {
        src: 'images/auto-focus-browser-view-2.png',
        title: 'Browser Integration',
        description: 'Chrome extension tracks focus on web apps like GitHub, Linear, Figma, and other productivity tools.'
    },
    {
        src: 'images/auto-focus-insights-view-2.png',
        title: 'Focus Insights',
        description: 'Track your focus sessions, analyze productivity patterns, and visualize your deep work habits over time.'
    },
    {
        src: 'images/auto-focus-data-view-2.png',
        title: 'Data Management',
        description: 'Export your focus data in CSV or JSON format for analysis, backup, or integration with other tools.'
    },
    {
        src: 'images/auto-focus-license-view-2.png',
        title: 'License Management',
        description: 'Manage your Auto-Focus+ license, view purchase details, and access premium features.'
    }
];

// Global function for screenshot changes
window.changeScreenshot = function(index) {
    // Update featured image
    document.getElementById('featured-screenshot').src = screenshots[index].src;
    document.getElementById('screenshot-title').textContent = screenshots[index].title;
    document.getElementById('screenshot-description').textContent = screenshots[index].description;

    // Update thumbnail borders
    document.querySelectorAll('.screenshot-thumb').forEach((thumb, i) => {
        if (i === index) {
            thumb.classList.add('border-primary-color');
            thumb.classList.remove('border-transparent');
        } else {
            thumb.classList.remove('border-primary-color');
            thumb.classList.add('border-transparent');
        }
    });
};
