# App Store Review Notes (copy into App Store Connect)

## Apple Pay / PassKit (Guideline 2.1)

This app does **not** integrate Apple Pay. Premium is sold only through **In-App Purchase** (StoreKit) on the Premium screen.

The app previously included an unused Apple Pay merchant entitlement; that entitlement has been removed from the build submitted with this version.

**Where to test Premium IAP:**
1. Sign in (Apple, Google, or email).
2. Open **Profile** → **Premium** (or any Premium upsell).
3. Tap **Aylık Premium** / monthly plan.
4. Complete purchase with the sandbox Apple ID when prompted.
5. Use **Satın Alımları Geri Yükle** / Restore Purchases if testing on a device that already bought the product.

**Product ID:** `premium_monthly` (auto-renewable subscription)  
**Bundle ID:** `com.onuranatca.tavlaskor`

Please confirm the **Paid Apps Agreement** is active in App Store Connect → Business, and that `premium_monthly` is **Ready to Submit** and attached to this app version.

## Sandbox test account

Provide your sandbox tester credentials in App Store Connect → App Review Information if reviewers need a signed-in app account (Firebase). The IAP flow itself uses the device sandbox Apple ID at purchase time.
