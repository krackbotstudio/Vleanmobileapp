# Dark to White customer mobile app

Status: working product specification. Owner: Tectangle LLP. Platforms: Android and iOS, with web preview for review.

## Objective

Build a new Flutter application allowing customers to discover garment-care services, check availability, book pickup and follow orders. Use a separate Flutter implementation and match the latest reference at E:\Krackbot products\darkto white mobile apps\mobileapp-darktowhite, as requested by the owner. Integrate the separately deployed authorized brand backend; do not rebuild or assign backend/admin ownership through this mobile project.

## First release scope

Guest catalogue; phone OTP authentication; profile and address management; serviceability; branch-aware prices and pickup slots; review and confirm booking; order tracking/history; invoices; payment status; cancellation/rescheduling according to backend policy; notifications; support; privacy/terms; account deletion request.

Subscriptions, wallets, referral programmes, live driver tracking and staff tools are outside the first release unless separately approved.

## Customer journey

Home → service → address → eligible branch → available date/window → estimate and terms → authenticated confirmation → order detail.

No login is simulated. Anonymous previews must never be represented as confirmed orders. The backend must authorize every resource and determine serviceability, capacity, pricing, state transitions and payment status.

## Design

Match the latest app: muted video login, chrome logo and Tectangle credit; dark/light gradients; floating Home / Prices / Orders / Profile menu; six service tiles in a three-column Home grid; Continue opens the authenticated address/date/time/confirmation sheet; branch-aware search and flip pricing cards; guest profile and legal card. See UI_MATCH.md for reference, asset provenance and preview differences. Use accessible labels and contrast, enlarged-text support, reduced-motion behavior, loading/retry/empty states. Customer copy must distinguish sample rates, estimates and final invoices. Branch directory presence does not establish pickup coverage.

## API and data

API: https://apibubbler.krackbot.com/api

Brand slug/code: dark-to-white. Brand ID: 226641ad-a50b-4a6f-934f-c7e7cd3f0010.

Public branding endpoint is verified. Remaining schemas and auth contracts require documentation. Do not guess mutating endpoints, send OTPs, create live orders or initiate payments while investigating the contract.

Use monetary minor units, explicit currencies, business-local scheduling, server-side validation, secure credential storage and idempotent booking/payment operations. Never embed privileged keys.

## Acceptance criteria

- Guest can browse without an account.
- Unsupported addresses cannot produce confirmed bookings.
- Expired OTPs and sessions fail safely and allow recovery.
- Stale prices or slots are revalidated before confirmation.
- Repeated submission creates at most one production booking through server idempotency.
- Customers cannot retrieve another customer's data.
- Payment success is verified by the backend.
- Denied location/notification permissions do not block core manual flows.
- Existing-app upgrade, login migration and notification setup are tested before store release.
- Loading, offline, empty and API error states are understandable.

## Delivery milestones

1. Flutter interface following the latest reference, live public brand information and explicitly labeled preview booking.
2. Verified API contracts, secure authentication, catalogue/prices and serviceability.
3. Real booking, orders, invoices and operational policies.
4. Notifications, account privacy/deletion, accessibility and production hardening.
5. Existing store identity/signing verification, upgrade tests, internal distribution and store submission.

## Decisions pending

Confirm production service catalogue, taxes/fees, branch assignment, operational timezone, slot rules, final-price approval, payment provider, cancellation/refunds, support channels, minimum OS versions and existing store identifiers. Do not replace pending decisions with hardcoded sample policies.

## Ownership and evidence

Keep repository history, design decisions and dependency licences. Assignments and reusable-component reservations belong in signed contracts. Flutter alone does not establish copyright clearance.
