# Staging Environment Setup Guide

This guide helps you set up a staging environment to test Stripe checkout with test cards.

## 🎯 Overview

**Problem**: You can't test Stripe checkout in production with test cards
**Solution**: Deploy a staging API with Stripe test environment + add staging checkout to website

## 📋 Setup Steps

### 1. **Configure Stripe Test Environment**

1. **Get Stripe Test Keys**:
   - Go to [Stripe Dashboard](https://dashboard.stripe.com/test/apikeys)
   - Copy your Test **Publishable key** (`pk_test_...`)
   - Copy your Test **Secret key** (`sk_test_...`)

2. **Create Test Product & Price**:
   ```bash
   # Using Stripe CLI (install with: brew install stripe/stripe-cli/stripe)
   stripe login
   stripe products create --name "Auto-Focus+ (Test)" --description "Test license for Auto-Focus+"
   stripe prices create --product=prod_XXXXXXXXXX --unit-amount=900 --currency=usd --nickname="Auto-Focus+ Test"
   ```

3. **Create Test Webhook**:
   - Go to [Stripe Webhooks](https://dashboard.stripe.com/test/webhooks)
   - Add endpoint: `https://staging-api.auto-focus.app/api/webhooks/stripe`
   - Select events: `checkout.session.completed`
   - Copy the webhook secret (`whsec_...`)

### 2. **Configure Staging API**

1. **Update `.env.staging`**:
   ```bash
   # Replace with your actual test keys
   STRIPE_SECRET_KEY=sk_test_your_stripe_test_secret_key_here
   STRIPE_WEBHOOK_SECRET=whsec_your_test_webhook_secret_here
   HMAC_SECRET=staging-hmac-secret-different-from-prod
   DATABASE_URL=./auto-focus-staging.db
   ENVIRONMENT=staging
   TEST_MODE=true
   ```

2. **Deploy Staging API**:
   ```bash
   cd auto-focus-cloud
   ./deploy-staging.sh
   ```

### 3. **Configure Website Staging**

1. **Update Stripe Test Keys** in `docs/index.html`:
   ```javascript
   staging: {
       stripe: Stripe('pk_test_your_actual_test_key_here'),
       priceId: 'price_your_actual_test_price_id_here',
       successUrl: 'https://auto-focus.app/success?env=staging',
       cancelUrl: 'https://auto-focus.app/canceled?env=staging'
   }
   ```

### 4. **Test the Setup**

1. **Access Staging Mode**:
   - Visit: `https://auto-focus.app/?staging=1`
   - You'll see a 🧪 orange "TEST CHECKOUT" button

2. **Test with Stripe Test Cards**:
   - **Success**: `4242424242424242`
   - **Declined**: `4000000000000002`
   - **Insufficient funds**: `4000000000009995`
   - Any future expiry date, any CVC

3. **Verify Webhook**:
   - Complete a test purchase
   - Check staging API logs for webhook processing
   - Verify license creation in staging database

## 🚀 **Usage**

### For Testing:
```bash
# 1. Start staging API
cd auto-focus-cloud && ./deploy-staging.sh

# 2. Visit staging website
open "https://auto-focus.app/?staging=1"

# 3. Click "🧪 TEST CHECKOUT (Staging)" button
# 4. Use test card: 4242424242424242
```

### For Production:
- Normal website visitors see only production checkout
- No changes to existing workflow

## 🔍 **Verification Checklist**

- [ ] Staging API responds at staging URL
- [ ] Website shows staging button with `?staging=1`
- [ ] Test card `4242424242424242` works
- [ ] Webhook receives `checkout.session.completed`
- [ ] License email sent to test email
- [ ] License stored in staging database
- [ ] HMAC validation works in staging

## 💡 **Tips**

1. **Database Separation**: Staging uses separate database file
2. **Email Testing**: Configure test SMTP or log emails to console
3. **Webhook Testing**: Use `stripe listen --forward-to localhost:8080/api/webhooks/stripe`
4. **Environment Isolation**: Different HMAC secrets ensure no cross-contamination

## 🐛 **Troubleshooting**

**Staging button not showing?**
- Check URL contains `?staging=1`
- Check browser console for JavaScript errors

**"Staging not configured" error?**
- Update placeholder keys in `docs/index.html`
- Ensure test keys start with `pk_test_` and `sk_test_`

**Webhook not receiving events?**
- Verify webhook URL is accessible
- Check Stripe webhook logs in dashboard
- Ensure endpoint secret matches `.env.staging`

**License email not sent?**
- Check SMTP configuration in `.env.staging`
- Look for error logs in staging API console

---

**🎉 Once configured, you can safely test Stripe checkout without real payments!**