# Dark to White Android release

The Flutter Android app uses the existing listing's package `com.darktowhite`.
Version is `2.0.19`, version code `33`, incremented from the supplied reference
project's `2.0.18` / `32`. Confirm code 33 is unused in Play Console before upload.
The existing approved app artwork is used for Android launcher icons.

## Signing

Use the existing Android upload key for this Play listing. Copy
`android/key.properties.example` to `android/key.properties` and fill in the
existing keystore path, alias and passwords locally. Alternatively, set
`D2W_KEY_PROPERTIES` to an existing populated properties file. These private
files and keystores are ignored by version control. A regular release build
fails if signing is missing; it never falls back to the debug key.

Build with `./build-android-release.ps1`. The Android build
uses the live HTTPS API configured in `lib/brand_api.dart`; do not pass the
local browser API override to an Android release build.

For compilation validation only, `D2W_ALLOW_UNSIGNED_RELEASE=true` permits
an unsigned release bundle. An unsigned bundle is not upload-ready. Signing
must be verified against Play Console's upload certificate before submission.

The existing upload key was retrieved from the authenticated `krackbotstudio`
Expo project on 7 November 2026. Its latest completed Android production build
is `2.0.18` / `32` (build ID `33a4b7e7-7ce0-461f-ba9e-4eb419036bbd`).
Expected upload certificate SHA-256:
`A8:14:69:14:80:A7:98:F3:EA:34:43:77:B1:FD:CE:53:54:90:F5:E5:CD:4C:E6:0A:65:5F:DB:D0:77:DC:B2:B4`.
No new signing key was created.

## Local browser

Compile with `./flutter-local.ps1 build web --no-wasm-dry-run --dart-define=API_BASE_URL=http://127.0.0.1:8781/api`.
Then `node tool/serve_local.mjs` serves http://127.0.0.1:8780 with the local API
relay on port 8781. Android contacts the production API directly.

Building a bundle does not certify every customer flow. Test the upgrade from
the installed app and real sign-in, addresses, bookings, orders, payments and
notifications before production rollout. The Flutter session store is separate
from the old React Native store, so existing users may need to sign in again.
