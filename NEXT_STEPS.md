# Build status and next integration steps

## Implemented

- Flutter project for Android, iOS and web preview.
- Latest reference UI: video login, glass four-tab navigation, Home service sphere and pickup scheduling, pickup sheet, flip pricing cards and guest profile.
- Live public branding, branch directory and policy pages.
- Live branch catalogue and pricing, including current admin item images and service rates.
- Customer OTP request/verification, resend cooldown, session restoration on mobile, and sign-out. Delivery was not triggered during testing.
- Explicitly labeled in-memory preview booking.
- Android release Internet permission.

## Backend integration

Use the latest reference client's API contracts as a starting point, then verify them against the separately deployed Dark to White backend. A base URL alone does not establish authentication, request/response schemas or customer authorization.

1. Check OTP delivery and account creation manually with an authorized phone number. No real message was sent by automated tests.
2. Saved addresses, serviceability and eligible branches; production Continue must require sign-in.
3. Live pickup dates/slots, estimates and backend price revalidation before confirmation.
4. Idempotent booking creation, order history, status and detail views.
5. Invoices, cancellation/rescheduling, notification registration and account deletion.
6. Operational payment integration after its workflow is confirmed.
7. If releasing the web app, allow brand headers on the backend through CORS or deploy a production relay. The included relay is bound to localhost for development only.

No live OTPs, orders or payments were created by the UI work. Preview addresses remain in memory.

## Release work

- Confirm and retain existing store identifiers and Android/Apple signing access if publishing an update.
- Replace generated launcher icons with approved artwork and choose release version numbers.
- Compare the Flutter screens to the running latest reference app on Android and iPhone, including enlarged text, keyboard and safe-area layouts.
- Test native background video and app lifecycle behavior, Android physical devices and iOS on macOS/Xcode.
- Test upgrading from the published app, session migration and notification registration.
- Remove sample booking slots from production flows; validate server authorization, prices, capacity and payment status.
- Verify applicable asset/dependency licences and store privacy disclosures.

## Local checks

```powershell
.\flutter-local.ps1 analyze
.\flutter-local.ps1 test
.\flutter-local.ps1 -FlutterArguments @('build', 'web', '--no-wasm-dry-run')
```

