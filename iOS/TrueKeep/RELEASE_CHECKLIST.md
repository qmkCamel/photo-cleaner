# TrueKeep iOS Release Readiness Checklist

This is the working checklist for reaching a state that can be submitted to App Store review.

## Product

- [x] MVP trust-validation navigation exists.
- [x] Deletion requires Review Bin and second confirmation.
- [x] iCloud Photos deletion risk appears before deletion.
- [x] Privacy & Safety page explains no upload, no collection, no tracking, and user control.
- [x] Real Photos permission flow is wired through `PHPhotoLibrary`.
- [x] Limited Photos Access behavior is designed and implemented.
- [x] Real scan results replace fixture data for metadata-supported screenshot and video categories.
- [x] Fixture-only similar, accidental, and blurry task cards are not exposed on the default launch path.
- [x] Public Photos permission and onboarding copy claims only local review candidates with deletion-safety limits.
- [x] Similar, accidental, and blurry scan results replace fixture placeholders with local low-confidence Vision and explainable visual signals.
- [x] Empty, denied-permission, and no-candidate states are implemented.
- [x] Interrupted-scan state is implemented.
- [ ] TestFlight feedback loop with parent users is complete.

## Technical

- [x] Xcode project builds and tests on iOS Simulator.
- [x] Unit tests cover the Review Bin safety model.
- [x] App has a bundle ID and photo-library usage description.
- [x] App has a 1024 px App Icon asset.
- [x] Photos framework scanner is implemented in a service boundary.
- [x] Scanning supports cancellation, batching, and low-power handling.
- [x] Real thumbnails are loaded efficiently and cached locally.
- [x] Deletion uses Photos APIs safely with error handling.
- [x] Debug deletion safety lock exists for non-destructive manual testing and is active by default unless a destructive-test opt-in is explicitly supplied.
- [x] Simulator smoke test covers onboarding, settings, scan, Home, review groups, Review Bin, and deletion safety-lock flow.
- [x] XCUITest regression target covers tappable settings rows, Home task routing, default no-fixture launch, permission-denied state, interrupted-scan state, Limited Photos Access result warning, review actions, Review Bin safety lock, zero-selection disabled state, Review Bin disabled footer actions, and screenshot capture.
- [x] Critical XCTest accessibility audit covers contrast, Dynamic Type, hit region, labels, traits, element detection, and text clipping across the main MVP screens plus permission-denied, interrupted-scan, Limited Photos Access scan, and Limited Photos Access results states.
- [x] Review and Review Bin item accessibility labels expose selection state, cleanup category, cleanup reason, and estimated storage where relevant.
- [x] Unit tests guard public Photos permission copy against overclaiming visual candidates or deletion safety.
- [x] Release iPhoneOS archive preflight succeeds with code signing disabled.
- [x] Local release preflight script checks required files, plist/build settings, privacy manifest, App Store metadata lengths, App Store Connect metadata packet consistency, screenshot dimensions, static support/privacy links, external submission placeholders, source privacy guardrails, Chinese localized-copy guardrails, and signing blocker state.
- [x] Full local release preflight with Xcode tests and unsigned Release archive passes.
- [x] Automatic development-signing preflight has been attempted and the current Xcode account/profile blocker is documented.
- [x] Physical-device smoke-test runner is prepared with dry-run default and deletion safety-lock launch arguments.
- [x] App Store submission runbook exists with ordered local, signing, physical-device, TestFlight, hosted-URL, and App Store Connect gates.
- [x] Physical-device signed install succeeds after Apple Developer account re-authentication.
- [ ] Physical-device smoke test succeeds with deletion safety lock enabled.
- [x] Primary controls expose stable accessibility identifiers for automation.
- [ ] Full VoiceOver accessibility audit is complete.
- [x] Dynamic Type accessibility pass is complete.
- [x] Release archive and local App Store export succeed with cloud-managed distribution signing.

## Privacy and App Store

- [x] App Store privacy labels are drafted and checked against actual SDK/data collection.
- [x] Privacy manifest is included and declares no tracking, no collection, and no required-reason API usage for the current SDK set.
- [x] No analytics, ads, or crash SDK is added without updating Privacy & Safety copy.
- [x] App Review notes explain local processing and deletion confirmation.
- [x] Native-app marketing screenshot candidates are produced from the test flow.
- [x] Final simulator screenshot set and contact sheet are captured in `MarketingScreenshots/2026-06-13-1811-photo-video-copy/`.
- [x] App Store listing metadata draft and simulator screenshot selection are saved in `APP_STORE_LISTING.md`.
- [x] Copy-paste App Store Connect metadata files are saved in `AppStoreConnect/`.
- [x] Preliminary name, subtitle, keyword-length, domain, App Store web-search, and trademark-search notes are drafted.
- [x] App Store 6.9-inch screenshot exports are generated at `1320 x 2868` in `MarketingScreenshots/2026-06-13-1811-photo-video-copy/app-store-6.9/`.
- [x] Polished 6.9-inch marketing screenshot candidates with value-proposition headers are generated in `MarketingScreenshots/2026-06-13-1811-photo-video-copy/app-store-6.9-marketing/`.
- [x] Current screenshot set passes visual QA for photo/video trust copy, localized `复核箱` tab copy, and Home review-queue card visibility.
- [x] Privacy Policy and Support page content are drafted in `docs/app-store/`.
- [x] Static Privacy Policy and Support page templates are prepared in `docs/app-store/site-template/`.
- [x] Age-rating, export-compliance, content-rights, and category-answer drafts are saved in `docs/app-store/compliance-answers.md`.
- [ ] Final App Store screenshot assets are approved.
- [ ] Privacy Policy URL and Support URL are hosted and verified.
- [ ] Age rating, export compliance, content rights, and category answers are entered and approved in App Store Connect.
- [ ] Final listing metadata is approved in App Store Connect.
- [ ] Trademark, App Store Connect name availability, domain ownership, and legal clearance are confirmed before submission.

## Signing

- [x] Device signing state and cleared blocker evidence are documented in `DEVICE_SIGNING.md`.
- [x] Local Apple Development certificate is present in Keychain.
- [x] Automatic signing preflight failure is recorded with exact Xcode account/profile errors.
- [x] Apple Developer Team `D8BE8WBTV5` is confirmed as the release source of truth.
- [x] Bundle ID `app.truekeep.ios` is registered in the chosen Apple Developer account.
- [x] Development provisioning succeeds for the connected iPhone.
- [x] Cloud-managed Apple Distribution signing and the App Store provisioning profile are confirmed by local export.
