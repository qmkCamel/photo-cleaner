# TrueKeep App Store Review Notes

This document is the current draft for App Store Connect privacy answers and App Review notes. It must be updated before submission if analytics, crash reporting, subscriptions, networking, or third-party SDKs are added.

## App Privacy Draft

- Data collection: No data collected in the current build.
- Tracking: No tracking.
- Third-party SDKs: None.
- Account data: No account system.
- Photos and videos: Accessed locally through the system Photos permission. The app reads metadata and thumbnails for on-device review only.
- Uploads: No photo or video upload.
- Storage: Thumbnails are requested through Photos and cached in memory only. The app does not copy the user's photos or videos into its own container.
- Networking: No app feature currently requires network access.
- Analytics, ads, and crash SDKs: None in the current build.

## Review Notes Draft

TrueKeep / 留真 helps users review cleanup candidates from their local photo library. The app explains its local-processing promise before requesting Photos permission.

Current real scan coverage:

- Screenshots and screen captures identified from Photos metadata.
- Long or large videos identified from Photos metadata and duration estimates.
- Similar-photo candidates identified on device from local thumbnail perceptual hashes inside a short time window.
- Accidental-shot and blurry-photo candidates identified on device from local thumbnail brightness, saturation, and edge-sharpness heuristics.
- Visual classifications are treated as low-confidence review candidates, not automatic deletion decisions.
- The scan does not allow network-backed iCloud thumbnail downloads for visual classification.

Sample/demo coverage:

- Fixture/sample groups remain isolated behind the internal `-TrueKeepUseSampleCleanupData` launch argument for UI automation and design review only.
- The default launch path uses real metadata and local visual heuristics instead of placeholder task cards.

Deletion safety:

- Items must first be added to Review Bin.
- Deletion requires a second confirmation sheet.
- The confirmation copy explains iCloud Photos and Recently Deleted recovery risk.
- Debug builds keep the deletion safety lock active by default so internal manual testing can verify the deletion flow without deleting photo or video items.
- Internal manual testing can also launch with `-TrueKeepDisablePhotoDeletion` or `TRUEKEEP_DISABLE_PHOTO_DELETION=1` as explicit extra guards.
- Destructive debug testing requires a separate approved plan and the explicit opt-in `-TrueKeepEnableDestructivePhotoDeletion` or `TRUEKEEP_ENABLE_DESTRUCTIVE_PHOTO_DELETION=1`.

No account, upload, analytics, advertising, or cross-app tracking behavior is present in the current build.

## Validation Status

2026-06-11 simulator validation:

- Latest full local release preflight passed with 15 pass/info checks and 0 failures.
- Latest full regression result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_11-08-12-+0800.xcresult`.
- Latest full regression test summary: 59 tests passed, 0 failures, 0 skipped.
- Latest full preflight unsigned Release archive passed at `/tmp/TrueKeepReleasePreflightUnsigned.xcarchive`.
- Debug deletion safety policy regression passed on 2026-06-13 with 8 deletion-policy tests, 0 failures. Result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.13_17-31-16-+0800.xcresult`.
- Photo/video trust-copy and large-video preview regressions passed on 2026-06-13 with 8 focused unit tests and 3 focused UI tests, 0 failures. Result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.13_18-09-20-+0800.xcresult`.
- Critical screen accessibility audit passed after the photo/video copy refresh on 2026-06-13. Result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.13_18-10-15-+0800.xcresult`.
- Marketing screenshot capture passed on 2026-06-13 with 8 kept screenshot attachments and no deletion confirmation. Result bundle: `/tmp/TrueKeepMarketingScreenshots-1811.xcresult`.
- UI regression now covers permission-denied, interrupted-scan, and Limited Photos Access warning states through deterministic launch scenarios.
- Critical XCTest accessibility audit now also covers permission-denied, interrupted-scan, Limited Photos Access completed-scan, and Limited Photos Access results states.
- Permission and scan recovery screens were fixed for accessibility-size Dynamic Type, text clipping, and decorative-icon accessibility exposure.
- Previous full local release preflight passed with 12 pass/info checks and 0 failures.
- Previous full simulator regression passed with 54 tests, 0 failures, and 0 skipped tests.
- Previous full regression result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_09-29-42-+0800.xcresult`.
- Previous full simulator regression passed with 44 unit tests and 10 UI tests.
- Critical XCTest accessibility audit passed across onboarding, permission rationale, Privacy & Safety, Home, review, Review Bin, and delete confirmation screens.
- Accessibility audit covered contrast, Dynamic Type, element detection, hit region, sufficient element description, text clipping, and traits.
- App source tests guard against reintroducing fixed-size SwiftUI text fonts in app screens.
- Review Bin VoiceOver semantics are covered by UI regression: item labels expose delete-selection state, cleanup category, cleanup reason, and estimated storage; toggling an item updates the selected/unselected announcement.
- Local visual-classifier unit tests cover similar-photo grouping, sharpest-item keep recommendation, time-window isolation, accidental-shot marking, blurry-photo marking, and low-power classification limits.
- Fast local release preflight passed with 0 failed checks. It covered required release files, Info.plist/project build settings, privacy manifest, App Store metadata lengths, App Store Connect metadata packet consistency, screenshot dimensions, static support/privacy links, source privacy guardrails, and current signing blocker state.
- Current fast local release preflight also covers Chinese localized-copy guardrails for App Swift sources, zh-Hans metadata, the zh-Hans listing section, and marketing screenshot copy.
- iPhoneOS generic compile passed with code signing disabled.
- Physical-device smoke-test runner is prepared but not executed; it defaults to dry-run and launches with deletion disabled when `--execute` is used.
- Automatic development-signing preflight was attempted with `DEVELOPMENT_TEAM=KTTVMPA76Y` supplied only on the command line. It failed because Xcode reported no usable Accounts session and no matching `app.truekeep.ios` development provisioning profile.
- 2026-06-11 09:45 CST device recheck still found three physical iPhone entries as `unavailable`, no real iPhone destination in `xcodebuild -showdestinations`, and 0 local provisioning profiles.
- Release iPhoneOS unsigned archive preflight passed at `/tmp/TrueKeepUnsignedArchive-20260611-voiceover.xcarchive`.
- Latest full local preflight unsigned archive passed at `/tmp/TrueKeepReleasePreflightUnsigned.xcarchive`.
- The unsigned archive contains bundle ID `app.truekeep.ios`, version `0.1.0`, build `1`, the Photos permission usage string, and `PrivacyInfo.xcprivacy`.
- Final simulator screenshot candidates are in `MarketingScreenshots/2026-06-13-1811-photo-video-copy/`.
- App Store 6.9-inch screenshot exports are in `MarketingScreenshots/2026-06-13-1811-photo-video-copy/app-store-6.9/`.
- Polished 6.9-inch marketing screenshot candidates are in `MarketingScreenshots/2026-06-13-1811-photo-video-copy/app-store-6.9-marketing/`.
- Current screenshot set was regenerated from `/tmp/TrueKeepMarketingScreenshots-1811.xcresult`; visual QA checked photo/video trust copy, localized `复核箱` tab copy, and full Home task-card visibility.
- Listing metadata and screenshot-selection notes are drafted in `APP_STORE_LISTING.md`.
- Copy-paste App Store Connect metadata files are saved in `AppStoreConnect/`.
- Privacy Policy and Support page content are drafted in `docs/app-store/`; ready-to-host static templates are in `docs/app-store/site-template/`; final hosted URLs and monitored support contact are still pending.
- Age-rating, export-compliance, content-rights, and category-answer drafts are saved in `docs/app-store/compliance-answers.md`.
- Ordered submission runbook is saved in `SUBMISSION_RUNBOOK.md`; it separates local preflight, signing, physical-device smoke, TestFlight, hosted URL, and App Store Connect gates.
- No test flow confirmed deletion, and no photo or video items were deleted.

## Remaining Submission Blockers

- Physical-device signed install still needs a refreshed Apple Developer account session, confirmed release Team, available device destination, and a matching development provisioning profile.
- TestFlight smoke testing on a real device is not complete.
- Full manual VoiceOver accessibility pass is not complete.
- Privacy Policy URL and Support URL are not hosted and verified.
- Age rating, export compliance, content rights, and category answers are not entered in App Store Connect.
- Native-app raw screenshots, 6.9-inch raw exports, and polished 6.9-inch marketing candidates are captured in `MarketingScreenshots/2026-06-13-1811-photo-video-copy/`; final human screenshot approval and App Store Connect listing approval are not complete.
- Distribution-signed archive and export validation are not complete.
