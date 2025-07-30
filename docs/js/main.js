document.addEventListener('DOMContentLoaded', function() {
    // Configuration
    const config = {
        production: {
            stripe: Stripe('pk_live_51RJsTJHG3jEF4MbtWkI32NWB3j69lMvPnwlAhH81xKsWwko0vNrj9rTZzsvzaUzmSYqMbSnTGrS7Xs24ymwIoqay008AuEGDQG'),
            priceId: 'price_1RqXaoHG3jEF4MbtgS8HRwXE',
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
    const productionButton = document.getElementById('checkout-button-price_1RclfYHG3jEF4Mbtk53ComY9');
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
        const focusText = document.getElementById('focus-text');

        // Reset animation state
        notifications.forEach(id => {
            const notif = document.getElementById(id);
            notif.classList.remove('show', 'fade-out');
        });
        focusText.style.opacity = '0';

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
            // Step 2: Show focus text (3s)
            focusText.style.opacity = '1';
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
            // Step 4: Hide focus text and restart (7s)
            focusText.style.opacity = '0';
        }, 7000);

        // Loop the animation
        setTimeout(startDemoAnimation, 8000);
    }

    // Start animation when page loads
    window.addEventListener('load', () => {
        setTimeout(startDemoAnimation, 1000);
    });
});