# Latest UI verification — 5 November 2026

Reference: E:\Krackbot products\darkto white mobile apps\mobileapp-darktowhite.

Implementation: E:\Krackbot products\New dark to white Mobile app.

## Passed

- Flutter static analysis: no issues.
- Flutter automated tests: 22 passed. Coverage includes branch-scoped live catalogue parsing, decimal rupees, stale response rejection, catalogue failure/retry, brand checks, OTP request/verification, resend timing, sign-out, date/address validation, preview booking and narrow layout.
- Local API relay tests: 5 passed. They verify allowed branches, fixed brand headers, origin restrictions, OTP routing and complete image delivery after an interrupted download, using simulated upstream responses.
- Layout tests at 390 and 320 logical pixels wide; no framework layout exceptions in the tested flows.
- Release web build completed, including Material, Font Awesome and Cupertino icon fonts. The web renderer is bundled locally.
- Live API reads verified 187 catalogue items, 350 price entries and 187 image URLs in each of Gundlapochampally, Secunderabad and Suchitra. Visible catalogue photos and real starting prices were checked in the compiled app; images load as items scroll into view.
- Chrome mobile preview at 390 × 844: login, Home, service selection, pickup sheet, pricing, card back, Profile, light Home and light Profile inspected.
- Background video loaded at 1080 × 1920, played muted and looped. Browser playback was observed rather than assumed from configuration.
- No uncaught browser exceptions during the compiled release preview journey.
- Hashes of the nine visible media assets match the latest reference. See UI_ASSETS.json.

## Known limits

- The backend CORS policy blocks the brand headers needed by web clients. The local preview now uses a fixed, local Dark to White relay. A production web deployment still needs an appropriate server-side solution.
- Video disposal when leaving login cancels its remaining media request, as expected.
- The restarted local debug preview displayed the live catalogue and photos with no failed network requests. Its mobile emulation run recorded one Flutter engine keyboard/viewport assertion during resize; the release run did not reproduce it. This debug-only observation is saved separately.
- No real OTPs, customer bookings or payments were submitted during automated checks. OTP endpoints and authenticated profile state are implemented; address/booking and operational screens remain unfinished.
- Browser checks do not establish Android/iOS device parity, signing readiness, store update compatibility or copyright clearance.
- Visuals were checked against the reference code and artwork, not a running side-by-side reference build; exact pixel parity is not claimed.

Screenshots and browser observations are saved under docs/ui-preview. See NEXT_STEPS.md for remaining integration and release work.



## Home scheduling and service sphere - 6 November 2026

- Home service selection was replaced with date and time-slot controls. Services remain in the next booking step.
- The 3D service sphere uses the six existing service images and labels, perspective scaling, depth ordering and a shaded globe. It rotates automatically and supports horizontal drag, pause/resume and reduced-motion settings.
- Existing widget checks cover required date/time selection, resetting the time after a date change, retaining the schedule across tabs, carrying the selected schedule into review, and clearing it after saving a preview booking at 320-pixel width. All 22 Flutter checks pass across the verification runs; static analysis is clean.
- Release web build passed. Browser inspection at 390 and 320 pixels covered the sphere, calendar, slots, booking sheet and dark/light themes. Frame comparisons verified both movement during rotation and stillness after pausing. No uncaught browser exceptions; the only canceled request was the login video when leaving that screen.
- No real SMS, pickup, order or payment was submitted. Dates and slots remain preview choices without live availability checks.

Current Home screenshots and browser observations: docs/ui-preview/home-scheduling.

## Refined sphere - 6 November 2026

- Replaced the oversized logo and boxed labels with a smaller shaded sphere, understated wordmark and plain service names on a generously spaced circular orbit. All six services appear in order.
- Static analysis and all five existing screen/booking widget checks passed. The release web build completed.
- Browser checks at 390 and 320 pixels verified dark/light presentation, automatic motion, pause, date/time selection and the booking sheet. No uncaught browser exceptions. The canceled login video request is expected when entering Home.
- SHA-256 comparison confirmed that http://127.0.0.1:8780/main.dart.js serves the current compiled build. Refresh the page to load it.
- Screenshots and observations: docs/ui-preview/refined-sphere.
