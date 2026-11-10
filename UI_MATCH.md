# Dark to White interface alignment

## Current reference

As directed by the owner, use **E:\Krackbot products\darkto white mobile apps\mobileapp-darktowhite** as the current design reference. This supersedes the older E:\Krackbot products\Dark-White mobile app folder. Reference reviewed on 5 November 2026.

The reference's screens, styling and assets were inspected. The customer interface is implemented with Flutter widgets. This is not a clean-room or copyright-clearance attestation.

## Implemented appearance and interactions

- Muted looping video login background, chrome logo, phone field with WhatsApp icon, policy pills, Accept & Send OTP and Tectangle credit.
- Floating translucent four-tab navigation: Home, Prices, Orders, Profile. The tabs also provide guest access from login.
- Dark and light gradients, Hello header, theme toggle and notification control.
- Refined Home sphere: a smaller softly lit pearl, subtle text wordmark and evenly spaced service names moving along one circular path. The rear arc fades out; names stay upright and readable. The oversized logo, service icons, label boxes and pagination dots are removed. Horizontal drag, pause/resume and reduced-motion settings are supported.
- Home now shows pickup dates (next seven days plus a calendar up to 30 days ahead) and time-slot choices. Continue requires both choices. Changing the date clears the previous time selection.
- Pickup preview opens in a rounded bottom sheet with services, address, branch and review. The Home schedule carries through, and the review allows date/time changes.
- Pricing screen with branch chips, search and reversible animated cards showing live admin catalogue images, segments, services and branch prices. Only one card opens at a time.
- Guest profile with chrome logo, Welcome, sign-in action, legal card and Tectangle credit.
- Reduced-motion setting disables the background video and card flip animation. Video pauses when the application is inactive.

## Development differences

- OTP request and verification are connected to the customer backend. A real OTP is sent only after a user presses the button. Delivery and native sessions still need device testing.
- Customer order history, payments and notifications are not connected. The preview discloses these limits and never reports a successful live booking or payment.
- Home Continue allows an unauthenticated **sample** booking for UI review. The reference requires sign-in and uses saved addresses. Production must restore that authenticated flow.
- Address entry, branch selection, calendar and time choices are simplified preview controls; they do not verify serviceability, branch capacity or price.
- The Prices tab uses the admin catalogue for the selected Dark to White branch. An unavailable or empty catalogue shows an error or empty state; there are no substitute sample prices. Sample bookings stay in memory until restart.
- The white Tectangle logo is tinted dark on light surfaces to keep the credit readable.
- Published policies and branch directory come from the live public branding endpoint; the returned brand ID is checked. The public carousel returned an empty list during verification on 5 November 2026, the new service sphere now occupies that top area.
- The local browser preview uses a fixed Dark to White API relay because the backend CORS policy does not currently allow X-Brand-Code and X-Brand-Id. Native clients call the backend directly. Production web hosting needs a server-side CORS change or a production relay.
- Logged-in screens, operational order details, native device checks and exact visual comparison against a running reference app remain pending. This is not full functional or pixel-perfect parity.

## Assets and implementation record

The current reference supplies dark-white-chrome-icon.png, tectangle-logo.png, the six service-icons PNGs and service-icons/download.mp4. The previously imported logo files remain in the project but are no longer used in the current screen widgets. UI_ASSETS.json records hashes of the current visible media and their source paths.

No React Native source files were copied into the Flutter project. The source code was inspected to understand visual requirements. Artwork/video ownership and dependency licences remain subject to the parties' agreements; a different programming framework does not itself establish clearance.

The owner's request to match this appearance supersedes the initial instruction to create a different visual identity.



