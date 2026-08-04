# TrueKeep Manual QA

## 2026-06-10 Simulator Smoke Test

Environment:

- Project: `iOS/TrueKeep/TrueKeep.xcodeproj`
- Scheme: `TrueKeep`
- Simulator: iPhone 17, `0157BFC9-C9C9-48DC-845E-AABED7B2DCE9`
- Launch safety: `-TrueKeepDisablePhotoDeletion`
- Fixture mode for prototype-only Home task review: `-TrueKeepUseSampleCleanupData`
- Result: pass for the flows listed below.

Verified flows:

- Welcome screen:
  - `继续` opens the photo-permission rationale screen.
  - `了解更多` opens the main app on the Privacy & Safety tab.
- Photo permission rationale:
  - Back returns to Welcome.
  - `暂不` returns to Welcome.
  - `允许访问照片` enters the scan flow when simulator Photos access is available.
  - Public rationale copy describes local review candidates and keeps deletion-safety limits explicit.
- Scan flow:
  - Completed scan state renders.
  - `重新扫描` reruns the scan and returns to completed state.
  - `查看结果` opens the Home tab.
  - Empty scan result state renders when the simulator has no eligible Photos items.
- Privacy & Safety:
  - `留真如何工作` opens a detail page and returns.
  - `数据与隐私细节` opens a detail page and returns.
  - `帮助与支持` opens a detail page and returns.
- Home:
  - In sample fixture mode, all five cleanup task cards open a review group: similar, screenshots, accidental, blurry, and large videos.
  - In default launch mode, fixture task cards are not exposed; Home shows only real scan results or the real empty state.
  - Task cards open their review groups directly, without a fixed footer covering the list content.
- Review group:
  - Candidate selection toggles update the add-to-Review-Bin count.
  - `复核本组全部` selects all non-recommended candidates and no longer switches tabs by mistake.
  - `上一组` and `下一组` move between review groups and refresh default selections.
  - When zero candidates are selected, the add-to-Review-Bin button is disabled and not exposed as a tappable target.
- Review Bin:
  - Adding selected candidates moves to the Review Bin tab.
  - `删除选中` opens the confirmation sheet.
  - Confirmation sheet shows the iCloud Photos risk copy.
  - Confirming deletion with the debug safety lock shows `删除未完成` and `真机调试删除安全锁已开启，未删除任何照片或视频。`
  - `恢复选中` clears the Review Bin.

Issues found and fixed during this pass:

- Privacy & Safety rows looked tappable but did not navigate.
- Review group bottom actions overlapped the tab bar hit area.
- The sample Home list exposed task cards that had no matching review group.
- A zero-selection review group showed an enabled-looking `加入 Review Bin（0）` action.
- Promise rows on Welcome, Photos permission, and Privacy & Safety screens used centered intrinsic row widths, which made the icon/text columns visibly misaligned across rows.
- Public Photos permission copy previously claimed visual-review categories beyond the scanner capability available in that pass.

Not verified yet:

- Physical-device signed install, because the local Apple Developer account/provisioning profile is not ready.
- Real deletion on a physical device. Manual testing used `-TrueKeepDisablePhotoDeletion`, so no photo or video items were deleted.
- Full VoiceOver audit. Primary controls have stable accessibility identifiers and labels for automation, but a complete assistive-technology pass is still required.

## 2026-06-10 UI Automation Regression

Environment:

- Target: `TrueKeepUITests`
- Simulator: iPhone 17, `0157BFC9-C9C9-48DC-845E-AABED7B2DCE9`
- Launch safety: `-TrueKeepDisablePhotoDeletion`
- Fixture mode for sample-data tests: `-TrueKeepUseSampleCleanupData`
- Command: `xcodebuild test -project TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepUITests`
- Result: 8 UI tests passed, 0 failures.

Automated coverage:

- Welcome -> Permission rationale -> Back / Not now.
- Settings rows open all three detail pages and return.
- Default launch without sample-data argument does not expose internal fixture task cards.
- All five Home cleanup cards open matching review groups.
- Marketing screenshot capture flow produces native-app screenshot attachments without confirming deletion.
- Review group select-all, add to Review Bin, delete confirmation, deletion safety lock, and restore flow.
- Review Bin disables restore and delete actions when no items are selected.
- Zero-selection review group disables the add-to-Review-Bin action until a candidate is selected.

## 2026-06-11 Final Simulator Regression and Accessibility Audit

Environment:

- Project: `iOS/TrueKeep/TrueKeep.xcodeproj`
- Scheme: `TrueKeep`
- Simulator: iPhone 17, `0157BFC9-C9C9-48DC-845E-AABED7B2DCE9`
- Launch safety: `-TrueKeepDisablePhotoDeletion`
- Fixture mode for sample-data tests: `-TrueKeepUseSampleCleanupData`

Automated verification:

- Fixed-font source guard command: `xcodebuild test -project TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepTests/TrueKeepAccessibilityTests/testAppSourcesDoNotUseFixedSizeTextFonts`
- Fixed-font source guard result: 1 unit test passed, 0 failures.
- Fixed-font source guard result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_05-34-42-+0800.xcresult`
- Critical accessibility audit command: `xcodebuild test -project TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepUITests/TrueKeepUITests/testCriticalScreensPassAccessibilityAudit`
- Critical accessibility audit result: 1 UI test passed, 0 failures.
- Critical audit result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_05-40-13-+0800.xcresult`
- Full regression command: `xcodebuild test -project TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9'`
- Historical full regression result: all tests passed at that point; this result is superseded by the later 44-unit-test regression below.
- Full regression result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_05-52-27-+0800.xcresult`
- iPhoneOS generic compile command: `xcodebuild build -project TrueKeep.xcodeproj -scheme TrueKeep -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/TrueKeepDeviceCompile CODE_SIGNING_ALLOWED=NO`
- iPhoneOS generic compile result: build succeeded without signing.

Critical accessibility audit scope:

- Welcome, Photos permission rationale, Privacy & Safety, Home review queue, screenshot review, Review Bin, and delete confirmation.
- XCTest audit types: contrast, Dynamic Type, element detection, hit region, sufficient element description, text clipped, and trait.
- App sources are guarded against new fixed `.font(.system(size: ...))` text usage by `TrueKeepAccessibilityTests/testAppSourcesDoNotUseFixedSizeTextFonts`.

Issues found and fixed during this pass:

- Welcome, Photos permission, and Privacy & Safety promise rows were visually misaligned because row content used centered intrinsic widths.
- App text used fixed `.system(size:)` font calls that did not participate in Dynamic Type scaling. Text now uses centralized semantic typography tokens.
- Back and inline text actions had insufficient hit regions in the accessibility audit.
- Several green and muted text colors failed automated contrast checks.
- Decorative promise-row SF Symbols were exposed as separate accessibility elements.
- Home task-card secondary descriptions could collide with the tab bar and failed contrast/text audit checks; the descriptions are now retained in accessibility labels instead of rendered as cramped secondary card text.
- The delete confirmation sheet clipped content at fixed and medium heights. It now uses a scrollable large detent to keep confirmation copy and actions accessible.
- Accessibility-size Dynamic Type clipped the Welcome brand text and Privacy & Safety promise-row subtitles. The affected text surfaces now wrap vertically instead of relying on fixed row heights.
- The Home task-card confidence label used a caption-sized style that the Dynamic Type audit flagged as partially unsupported. It now uses a scalable status-label token.

Screenshots produced:

- Earlier Dynamic Type screenshot set was captured during this pass.
- Superseded for current marketing review by `iOS/TrueKeep/MarketingScreenshots/2026-06-11-0955-localized-review-bin/`.
- The screenshot flow stops at delete confirmation and did not confirm deletion.

Still not verified:

- Physical-device signed install, because the local Apple Developer account/provisioning profile is still not ready.
- TestFlight smoke testing on a real device.
- Real deletion on a physical device. Automated and manual simulator flows kept the debug deletion safety lock enabled and did not delete photo or video items.
- Full VoiceOver pass.

## 2026-06-11 Local Visual Classifier Pass

Automated verification:

- Visual result-builder command: `xcodebuild test -project TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepTests/PhotoScanResultBuilderTests -only-testing:TrueKeepTests/PhotoLibraryScanPolicyTests`
- Visual result-builder result: 13 unit tests passed, 0 failures.
- Visual result-builder result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_06-07-38-+0800.xcresult`
- Public copy command: `xcodebuild test -project TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepTests/PhotoLibraryAuthorizationTests/testPhotoPermissionCopyDescribesOnDeviceVisualCandidatesWithSafetyLimits -only-testing:TrueKeepTests/PublicScanCapabilityCopyTests/testPhotoPermissionCopyClaimsOnlyOnDeviceReviewCandidatesWithSafetyLimits`
- Public copy result: 2 unit tests passed, 0 failures.
- Public copy result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_06-10-10-+0800.xcresult`

Implemented coverage:

- Similar-photo candidates are generated from local Vision feature prints inside a short time window, with pHash fallback when feature prints are unavailable.
- Similar groups use Vision aesthetics quality as the primary recommended-keep signal and face capture quality as a bounded assist; the recommended item is not selected for deletion by default.
- Accidental-shot candidates conservatively combine extremely low non-utility Vision aesthetics scores with local thumbnail brightness, saturation, and edge-sharpness heuristics.
- Blurry-photo candidates are generated from local thumbnail edge-sharpness heuristics.
- Low Power Mode uses a smaller visual-classification limit to keep local scanning bounded.
- Public permission and Info.plist copy now describe visual results as local review candidates and do not claim automatic deletion or upload behavior.

Still not verified:

- Physical-device signed install and TestFlight.
- Real deletion on a physical device.
- Full VoiceOver pass.

## 2026-06-11 Visual Classifier Full Regression and Screenshot Refresh

Automated verification:

- Full regression command: `xcodebuild test -project TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9'`
- Full regression result: 44 unit tests and 9 UI tests passed, 0 failures.
- Full regression result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_06-32-13-+0800.xcresult`
- iPhoneOS generic compile command: `xcodebuild build -project TrueKeep.xcodeproj -scheme TrueKeep -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/TrueKeepDeviceCompile CODE_SIGNING_ALLOWED=NO`
- iPhoneOS generic compile result: build succeeded without signing.

Issues found and fixed during this pass:

- The longer Photos permission safety message caused a `Text clipped` accessibility audit failure on the permission rationale screen.
- The permission rationale content is now scrollable, and the safety copy is shorter while retaining the local-candidate, no-upload, and deletion-confirmation promises.

Screenshots produced:

- Latest screenshot set at that point: `iOS/TrueKeep/MarketingScreenshots/2026-06-11-0628-visual-classifier/`
- Current screenshot set is superseded by `iOS/TrueKeep/MarketingScreenshots/2026-06-11-0955-localized-review-bin/`.
- Contact sheet at that point: `iOS/TrueKeep/MarketingScreenshots/2026-06-11-0628-visual-classifier/contact-sheet.png`
- Source map at that point: `iOS/TrueKeep/MarketingScreenshots/2026-06-11-0628-visual-classifier/source-map.json`
- The screenshot flow stops at delete confirmation and did not confirm deletion.

Still not verified:

- Physical-device signed install and TestFlight.
- Real deletion on a physical device.
- Full VoiceOver pass.

## 2026-06-11 VoiceOver Semantics Regression

Automated verification:

- Red-path command: `xcodebuild test -project TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepUITests/TrueKeepUITests/testReviewBinItemsExposeReasonAndSelectionStateForVoiceOver`
- Red-path result: failed as expected because Review Bin items did not expose selection state and cleanup reason in the accessibility label.
- Red-path result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_08-46-29-+0800.xcresult`
- Targeted rerun result: 1 UI test passed, 0 failures.
- Targeted rerun result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_08-47-49-+0800.xcresult`
- Full regression command: `xcodebuild test -project TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9'`
- Full regression result: 44 unit tests and 10 UI tests passed, 0 failures.
- Full regression result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_08-48-29-+0800.xcresult`
- Release iPhoneOS unsigned archive command: `xcodebuild archive -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -configuration Release -destination 'generic/platform=iOS' -archivePath /tmp/TrueKeepUnsignedArchive-20260611-voiceover.xcarchive -derivedDataPath /tmp/TrueKeepUnsignedArchiveDerivedData-20260611-voiceover CODE_SIGNING_ALLOWED=NO SKIP_INSTALL=NO`
- Release iPhoneOS unsigned archive result: archive succeeded.
- Archive plist validation: `Info.plist` and `PrivacyInfo.xcprivacy` linted successfully in `/tmp/TrueKeepUnsignedArchive-20260611-voiceover.xcarchive`.

Implemented coverage:

- Review Bin item accessibility labels now include delete-selection state, cleanup category, cleanup reason, and estimated storage.
- Review Bin item hints now distinguish canceling a selected deletion item from reselecting an unselected item.
- Review Bin selected items expose the selected accessibility trait.
- Review-group candidate labels now include recommended-keep, selected-delete, or unselected-delete state plus cleanup category and reason.

Still not verified:

- Full manual VoiceOver pass. The new UI test protects the most obvious Review Bin semantic regression, but it is not a replacement for device-level VoiceOver navigation.
- Physical-device signed install and TestFlight.
- Real deletion on a physical device.

## 2026-06-11 Marketing Screenshot Packaging Pass

Automated verification:

- Generator command: `python3 iOS/TrueKeep/Scripts/build_marketing_screenshots.py`
- Syntax check command: `python3 -m py_compile iOS/TrueKeep/Scripts/build_marketing_screenshots.py`
- Dimension check result: all six marketing candidates are `1320 x 2868`.
- Output folder: `iOS/TrueKeep/MarketingScreenshots/2026-06-11-0628-visual-classifier/app-store-6.9-marketing/`
- Contact sheet: `iOS/TrueKeep/MarketingScreenshots/2026-06-11-0628-visual-classifier/app-store-6.9-marketing/contact-sheet.png`
- Manifest: `iOS/TrueKeep/MarketingScreenshots/2026-06-11-0628-visual-classifier/app-store-6.9-marketing/manifest.json`

Visual check:

- The first generated version exposed a visible empty green eyebrow capsule in the contact sheet.
- The generator was revised to use a text eyebrow plus a short underline.
- The revised contact sheet was inspected visually and did not show title overflow, clipped marketing text, or an empty label treatment.
- The raw simulator screenshots and the earlier `app-store-6.9/` export were not overwritten.

Still not verified:

- Human approval of final App Store screenshots.
- App Store Connect upload validation for the composed screenshot set.
- Localized screenshot copy for any non-Chinese store listing.

## 2026-06-11 Localized Screenshot Refresh and Visual QA

Automated verification:

- Red-path command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepUITests/TrueKeepUITests/testMainTabsUseLocalizedChineseLabels`
- Red-path result: failed as expected because the main tab bar still showed `Review Bin` instead of `复核箱`.
- Green-path result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_09-53-06-+0800.xcresult`
- Green-path result: `testMainTabsUseLocalizedChineseLabels` passed with 1 UI test, 0 failures.
- Screenshot capture command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepUITests/TrueKeepUITests/testMarketingScreenshotCaptureFlow -resultBundlePath /tmp/TrueKeepMarketingScreenshots-0955.xcresult`
- Screenshot capture result: 1 UI test passed, 0 failures, 8 kept screenshot attachments.
- Attachment export command: `xcrun xcresulttool export attachments --path /tmp/TrueKeepMarketingScreenshots-0955.xcresult --output-path /tmp/TrueKeepMarketingAttachments-0955`
- Current screenshot set: `iOS/TrueKeep/MarketingScreenshots/2026-06-11-0955-localized-review-bin/`
- Current 6.9-inch export: `iOS/TrueKeep/MarketingScreenshots/2026-06-11-0955-localized-review-bin/app-store-6.9/`
- Current marketing export: `iOS/TrueKeep/MarketingScreenshots/2026-06-11-0955-localized-review-bin/app-store-6.9-marketing/`
- Current marketing contact sheet: `iOS/TrueKeep/MarketingScreenshots/2026-06-11-0955-localized-review-bin/app-store-6.9-marketing/contact-sheet.png`

Visual check:

- The main tab bar uses `复核箱` instead of `Review Bin` in current Chinese screenshots.
- The Home review-queue marketing screenshot shows all five sample task cards without the previous bottom blank-area cut-off.
- The composed marketing contact sheet did not show title overflow, clipped marketing text, or obvious row alignment problems in the six current candidates.
- Previous screenshot sets were preserved.

Still not verified:

- Human approval of final App Store screenshots.
- App Store Connect upload validation for the composed screenshot set.
- Localized screenshot copy for any non-Chinese store listing.

## 2026-06-11 Automatic Signing Preflight

Automated verification:

- Certificate command: `security find-identity -v -p codesigning`
- Certificate result: Keychain contains `Apple Development: Meikai Qu (KTTVMPA76Y)`.
- Profile command: `find "$HOME/Library/MobileDevice/Provisioning Profiles" -maxdepth 1 -type f \( -name '*.mobileprovision' -o -name '*.provisionprofile' \) -print`
- Profile result: no local provisioning profiles were found.
- Device command: `xcrun devicectl list devices`
- Device result: three physical iPhone entries were detected, all `unavailable`.
- Signed generic preflight command: `xcodebuild build -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/TrueKeepSignedGenericBuild-20260611-0904 -allowProvisioningUpdates DEVELOPMENT_TEAM=KTTVMPA76Y CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY='Apple Development'`
- Signed generic preflight result: build reached app compilation and packaging, then failed during signing with `No Accounts: Add a new account in Accounts settings` and `No profiles for 'app.truekeep.ios' were found`.

Still not verified:

- Physical-device signed install.
- Physical-device smoke test with deletion safety lock enabled.
- TestFlight upload or real-device TestFlight smoke.

## 2026-06-11 Support and Privacy Static Page Template

Static page verification:

- Output folder: `docs/app-store/site-template/`
- Files: `index.html`, `privacy.html`, `support.html`, `styles.css`, and `README.md`.
- Internal-link check result: `index.html`, `privacy.html`, and `support.html` only reference existing local files.
- Placeholder check result: support contact and public hosting URLs are still intentionally marked as not final.

Still not verified:

- Monitored support email address or support form URL.
- Hosted Support URL and Privacy Policy URL.
- App Store Connect URL validation.

## 2026-06-11 Local Release Preflight Script

Automated verification:

- Fast preflight command: `python3 iOS/TrueKeep/Scripts/release_preflight.py`
- Fast preflight result at that point: 11 pass/info checks, 0 failures.
- Current fast preflight result: 13 pass/info checks, 0 failures.
- Covered checks: required release files, Info.plist placeholders plus project build settings, privacy manifest, App Store metadata lengths, App Store Connect metadata packet consistency, App Store screenshot dimensions, marketing screenshot dimensions, static support/privacy links, source privacy guardrails, Chinese localized-copy guardrails, empty committed `DEVELOPMENT_TEAM`, and local provisioning-profile state.
- Full Xcode mode: `python3 iOS/TrueKeep/Scripts/release_preflight.py --run-xcode`
- Full Xcode mode result: 12 pass/info checks, 0 failures.
- Full Xcode mode result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_09-29-42-+0800.xcresult`
- Full Xcode mode test summary: 54 tests passed, 0 failures, 0 skipped.
- Full Xcode mode unsigned archive: `/tmp/TrueKeepReleasePreflightUnsigned.xcarchive`
- Full Xcode mode archive plist validation: `Info.plist` and `PrivacyInfo.xcprivacy` linted successfully.
- Full Xcode mode archive identity: bundle ID `app.truekeep.ios`, version `0.1.0`, build `1`, Photos usage string present.

Still not verified:

- Physical-device signed install.
- TestFlight upload or real-device smoke.
- Hosted Support URL and Privacy Policy URL.
- App Store Connect submission validation.

## 2026-06-11 Chinese Localized-Copy Preflight Guardrail

Automated verification:

- Red-path command: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight`
- Red-path result: failed before implementation because `check_localized_copy_guardrails` did not exist.
- Binary-skip red path: failed before implementation because the guard tried to read PNG assets as UTF-8.
- Bilingual-listing red path: failed before implementation because English App Store listing text with `Review Bin` incorrectly failed the Chinese guardrail.
- Green-path command: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight`
- Green-path result: 3 tests passed, 0 failures.
- Fast preflight command: `python3 iOS/TrueKeep/Scripts/release_preflight.py`
- Fast preflight result: 12 pass/info checks, 0 failures.

Implemented coverage:

- Fails if App Swift sources, zh-Hans App Store Connect metadata, the zh-Hans section of `APP_STORE_LISTING.md`, or marketing screenshot copy reintroduce `Review Bin`.
- Ignores binary assets and allows English App Store/support copy to keep the `Review Bin` concept.

Still not verified:

- App Store Connect upload validation for the final localized screenshot set.

## 2026-06-11 App Store Metadata Packet Consistency Guardrail

Automated verification:

- Red-path command: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight.ReleasePreflightScriptTests.test_metadata_packet_guard_fails_when_copy_paste_file_differs_from_listing`
- Red-path result: failed before implementation because `check_metadata_packet_matches_listing` did not exist.
- Green-path command: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight.ReleasePreflightScriptTests.test_metadata_packet_guard_fails_when_copy_paste_file_differs_from_listing iOS.TrueKeep.Scripts.tests.test_release_preflight.ReleasePreflightScriptTests.test_metadata_packet_guard_passes_when_copy_paste_files_match_listing`
- Green-path result: 2 tests passed, 0 failures.
- Fast preflight command: `python3 iOS/TrueKeep/Scripts/release_preflight.py`
- Fast preflight result: 13 pass/info checks, 0 failures.

Implemented coverage:

- Compares `AppStoreConnect/metadata/en-US/*.txt` and `AppStoreConnect/metadata/zh-Hans/*.txt` against the corresponding fields in `APP_STORE_LISTING.md`.
- Covers app name, subtitle, keywords, promotional text, and description for both current localizations.

Still not verified:

- Manual paste into App Store Connect.
- App Store Connect server-side validation after final URLs and account setup are complete.

## 2026-06-11 Physical Device Smoke Runner

Automated verification:

- Unit test command: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_device_smoke`
- Unit test result: 3 tests passed, 0 failures.
- Dry-run command: `python3 iOS/TrueKeep/Scripts/device_smoke.py --team-id KTTVMPA76Y --device-id 00000000-0000-0000-0000-000000000000`
- Dry-run result: printed build, install, and launch commands without executing them.
- Safety assertion: launch command includes `TRUEKEEP_DISABLE_PHOTO_DELETION=1` and `-TrueKeepDisablePhotoDeletion`.
- Team policy: `DEVELOPMENT_TEAM` is passed only on the command line; `project.yml` remains empty until the release Team is confirmed.

Still not verified:

- Real physical-device execution with `--execute`.
- Signed install on a connected iPhone.
- Real-device smoke flow.

## 2026-06-11 App Store Submission Runbook

Documentation verification:

- Runbook file: `iOS/TrueKeep/SUBMISSION_RUNBOOK.md`
- Scope: local candidate freeze, signing and physical-device validation, TestFlight, hosted Support/Privacy URLs, App Store Connect data entry, distribution archive, and final submit gate.
- Safety coverage: Apple ID secrets are excluded, `DEVELOPMENT_TEAM` stays out of committed project settings until confirmed, and physical-device smoke keeps deletion disabled with both launch controls.

Still not verified:

- Execution of the signing, physical-device, TestFlight, hosted-URL, and App Store Connect phases.

## 2026-06-11 09:45 Physical Device Availability Recheck

Read-only verification:

- `xcrun devicectl list devices` still shows three physical iPhone entries, all `unavailable`.
- `xcodebuild -showdestinations -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep` still does not list a real physical iPhone destination.
- Local provisioning profile count under `~/Library/MobileDevice/Provisioning Profiles` is `0`.

Still not verified:

- Signed physical-device install.
- Real-device smoke execution.
- TestFlight install or smoke.

## 2026-06-11 10:03 Localized UI Full Release Preflight

Automated verification:

- Command: `python3 iOS/TrueKeep/Scripts/release_preflight.py --run-xcode`
- Result: 12 pass/info checks, 0 failures.
- Xcode result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_09-59-18-+0800.xcresult`
- Test summary: 55 tests passed, 0 failures, 0 skipped.
- Unsigned Release archive: `/tmp/TrueKeepReleasePreflightUnsigned.xcarchive`
- Fast/static checks covered required files, plist/build settings, privacy manifest, App Store metadata lengths, current screenshot dimensions, static support/privacy links, source privacy guardrails, empty committed `DEVELOPMENT_TEAM`, and provisioning-profile state.

Still not verified:

- Physical-device signed install.
- Real-device smoke execution.
- Distribution-signed archive and App Store export.
- TestFlight install or smoke.

## 2026-06-11 10:24 Chinese Design/Prototype Copy Guardrail

Automated verification:

- Red-path command: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight.ReleasePreflightScriptTests.test_localized_copy_guard_checks_chinese_design_docs_and_prototype`
- Red-path result: failed before implementation because Chinese design docs and the MVP prototype were not covered by `check_localized_copy_guardrails`.
- Green-path command: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight.ReleasePreflightScriptTests.test_localized_copy_guard_checks_chinese_design_docs_and_prototype`
- Green-path result: 1 test passed, 0 failures.
- Fast preflight command: `python3 iOS/TrueKeep/Scripts/release_preflight.py`
- Fast preflight result: localized-copy guardrail passes and now covers Chinese UI, zh-Hans metadata, listing, design docs, prototype, and marketing screenshot copy.

Implemented coverage:

- Chinese product docs and the high-fidelity prototype now use `复核箱`.
- The guard fails if `Review Bin` is reintroduced into the Chinese MVP design doc or interactive prototype.

## 2026-06-11 10:28 External Submission Placeholder Guardrail

Automated verification:

- Red-path command: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight.ReleasePreflightScriptTests.test_external_submission_placeholders_report_info_until_final_urls_exist`
- Red-path result: failed before implementation because `check_external_submission_placeholders` did not exist.
- Green-path command: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight.ReleasePreflightScriptTests.test_external_submission_placeholders_report_info_until_final_urls_exist`
- Green-path result: 1 test passed, 0 failures.
- Fast preflight command: `python3 iOS/TrueKeep/Scripts/release_preflight.py`
- Fast preflight result: 14 pass/info checks, 0 failures.
- New info line: `external-submission-placeholders` lists `APP_STORE_LISTING.md`, support/privacy drafts, and static templates until hosted URLs and a monitored support contact are finalized.

Still not verified:

- Hosted Support URL and Privacy Policy URL.
- Monitored support email or support form URL.
- App Store Connect server-side URL validation.

## 2026-06-11 10:34 Full Local Release Preflight After Copy Guards

Automated verification:

- Full preflight command: `python3 iOS/TrueKeep/Scripts/release_preflight.py --run-xcode`
- Full preflight result: 15 pass/info checks, 0 failures.
- Xcode result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_10-27-17-+0800.xcresult`
- Test summary: 55 tests passed, 0 failures, 0 skipped.
- Unsigned Release archive: `/tmp/TrueKeepReleasePreflightUnsigned.xcarchive`
- Script unit tests: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight iOS.TrueKeep.Scripts.tests.test_device_smoke` passed 10 tests, 0 failures.
- Python compile check passed for release preflight, device smoke, screenshot builder, and script tests.
- Whitespace check and `git diff --check` passed.

Visual QA:

- Current composed screenshot contact sheet inspected at `MarketingScreenshots/2026-06-11-0955-localized-review-bin/app-store-6.9-marketing/contact-sheet.png`.
- The current marketing sheet shows localized `复核箱` copy and the Home review-queue screenshot exposes all five task cards without the prior bottom cut-off.

Still not verified:

- Physical-device signed install.
- Real-device smoke execution.
- Distribution-signed archive and App Store export.
- TestFlight install or smoke.
- Hosted Support/Privacy URLs and App Store Connect approval.

## 2026-07-31 15:05 Signing Chain And Safe Device Launch

Verified configuration:

- Confirmed release Team: `D8BE8WBTV5`.
- Confirmed Bundle ID: `app.truekeep.ios`; Apple Developer Services returned the explicit identifier under Team `D8BE8WBTV5`.
- Connected device: iPhone 16 Plus, iOS 26.2.1; the destination identifier is intentionally not committed to this public repository.
- `project.yml` now commits the confirmed Team and the generated Xcode project uses it for application and test targets.

Development signing and device evidence:

- Automatic signed Debug device build succeeded with application identifier `D8BE8WBTV5.app.truekeep.ios`.
- Xcode used `iOS Team Provisioning Profile: *`; the profile UUID is intentionally not committed.
- `app.truekeep.ios` installed successfully on the connected iPhone.
- The app launched successfully with `TRUEKEEP_DISABLE_PHOTO_DELETION=1` and `-TrueKeepDisablePhotoDeletion`.
- No destructive Photos test was run and no photo or video deletion was requested.

Distribution evidence:

- Release archive succeeded: `/tmp/TrueKeepDistribution-20260731-1504.xcarchive`.
- Local App Store Connect export succeeded: `/tmp/TrueKeepAppStoreExport-20260731-1505/TrueKeep.ipa`.
- Export used `Cloud Managed Apple Distribution`, Team `D8BE8WBTV5`, application identifier `D8BE8WBTV5.app.truekeep.ios`, and `get-task-allow = 0`.
- App Store profile: `iOS Team Store Provisioning Profile: app.truekeep.ios`, expiring 2027-07-31; the profile UUID is intentionally not committed.

Automation verification:

- `device_smoke.py` now inserts `--` before the app launch argument for current `devicectl` parsing.
- End-to-end runner command: `python3 iOS/TrueKeep/Scripts/device_smoke.py --team-id D8BE8WBTV5 --device-id <DEVICE_ID> --execute`.
- End-to-end runner result: signed build, install, and deletion-safe launch all succeeded.
- Script unit tests: 12 tests passed, 0 failures.
- Fast release preflight: 14 pass/info checks, 0 failures.

Still not verified:

- Full real-library physical-device smoke criteria after launch.
- TestFlight upload, install, and smoke.
- Hosted Support/Privacy URLs and App Store Connect approval.

## 2026-06-13 17:31 Debug Deletion Safety Default

Automated verification:

- Red-path command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepTests/PhotoDeletionResultTests/testCurrentDebugSafetyPolicyDisablesDeletionByDefault`
- Red-path result: failed before implementation because `PhotoDeletionSafetyPolicy.current` did not disable deletion by default in a Debug test build.
- Red-path result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.13_17-29-29-+0800.xcresult`
- Green-path command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepTests/PhotoDeletionResultTests`
- Green-path result: 8 deletion-policy tests passed, 0 failures.
- Green-path result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.13_17-31-16-+0800.xcresult`
- Review Bin UI safety command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepUITests/TrueKeepUITests/testReviewFlowDeleteSafetyLockAndRestoreSelection`
- Review Bin UI safety result: 1 UI test passed, 0 failures. The flow reached delete confirmation, tapped confirm, and asserted `删除未完成` plus `真机调试删除安全锁已开启，未删除任何照片或视频。`
- Review Bin UI safety result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.13_17-33-52-+0800.xcresult`
- Fast preflight command: `python3 iOS/TrueKeep/Scripts/release_preflight.py`
- Fast preflight result: 14 pass/info checks, 0 failures.
- Script unit tests: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight iOS.TrueKeep.Scripts.tests.test_device_smoke` passed 10 tests, 0 failures.
- Python compile check, trailing-whitespace check, and `git diff --check` passed.

Implemented coverage:

- Debug builds disable Photos deletion by default, including normal Xcode Run with no launch arguments.
- `-TrueKeepDisablePhotoDeletion` and `TRUEKEEP_DISABLE_PHOTO_DELETION=1` still explicitly force the safety lock.
- Debug builds can only opt into destructive deletion with the intentionally verbose `-TrueKeepEnableDestructivePhotoDeletion` launch argument or `TRUEKEEP_ENABLE_DESTRUCTIVE_PHOTO_DELETION=1` environment variable.
- Explicit disable wins over destructive opt-in.
- Release safety policy still allows real Photos deletion unless an explicit disable control is supplied.

Still not verified:

- A separate approved destructive test on physical-device Photos data.
- Physical-device signed install and smoke execution.

## 2026-06-13 18:13 Photo/Video Copy And Large Video Preview

Automated verification:

- Red-path deletion-copy command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepTests/PhotoDeletionResultTests/testDeletionServiceHonorsDebugSafetyLockBeforeTouchingPhotos`
- Red-path deletion-copy result: failed before implementation because the debug safety-lock message still said it had not deleted photos only.
- Red-path deletion-copy result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.13_17-57-25-+0800.xcresult`
- Red-path video-preview command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepUITests/TrueKeepUITests/testLargeVideoReviewShowsVideoPreviewMetadata`
- Red-path video-preview result: failed before implementation because the large-video review page did not expose the expected video count and storage badge.
- Red-path video-preview result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.13_17-59-05-+0800.xcresult`
- Focused green command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepTests/PhotoLibraryAuthorizationTests -only-testing:TrueKeepTests/PublicScanCapabilityCopyTests -only-testing:TrueKeepUITests/TrueKeepUITests/testLimitedCompletedScanShowsAccessWarningBeforeResults -only-testing:TrueKeepUITests/TrueKeepUITests/testInterruptedScanStateIsReachableForAutomation -only-testing:TrueKeepUITests/TrueKeepUITests/testLargeVideoReviewShowsVideoPreviewMetadata`
- Focused green result: 8 unit tests and 3 UI tests passed, 0 failures.
- Focused green result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.13_18-09-20-+0800.xcresult`
- Critical accessibility command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepUITests/TrueKeepUITests/testCriticalScreensPassAccessibilityAudit`
- Critical accessibility result: 1 UI test passed, 0 failures.
- Critical accessibility result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.13_18-10-15-+0800.xcresult`
- Screenshot capture command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepUITests/TrueKeepUITests/testMarketingScreenshotCaptureFlow -resultBundlePath /tmp/TrueKeepMarketingScreenshots-1811.xcresult`
- Screenshot capture result: 1 UI test passed, 0 failures, 8 kept screenshot attachments. The flow stopped at delete confirmation and did not confirm deletion.
- Current screenshot set: `iOS/TrueKeep/MarketingScreenshots/2026-06-13-1811-photo-video-copy/`
- Current 6.9-inch export: `iOS/TrueKeep/MarketingScreenshots/2026-06-13-1811-photo-video-copy/app-store-6.9/`
- Current marketing export: `iOS/TrueKeep/MarketingScreenshots/2026-06-13-1811-photo-video-copy/app-store-6.9-marketing/`
- Current marketing contact sheet: `iOS/TrueKeep/MarketingScreenshots/2026-06-13-1811-photo-video-copy/app-store-6.9-marketing/contact-sheet.png`
- Fast preflight command: `python3 iOS/TrueKeep/Scripts/release_preflight.py`
- Fast preflight result: 14 pass/info checks, 0 failures.
- Script unit tests: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight iOS.TrueKeep.Scripts.tests.test_device_smoke` passed 10 tests, 0 failures.
- Python compile check, trailing-whitespace check, stale photo-only copy search, and `git diff --check` passed.

Implemented coverage:

- Trust, permission, limited-access, scan, privacy, deletion-confirmation, App Store listing, prototype, and marketing-screenshot copy now consistently says photos and videos where the feature scope includes both.
- Large-video review pages now show video count text and storage labels while still using Photos-backed thumbnails for preview.
- Review Bin deletion safety copy and debug safety-lock failures now say no photos or videos were deleted.
- Debug deletion remains safety-locked by default; no test confirmed deletion and no photo or video items were deleted.

Visual QA:

- `MarketingScreenshots/2026-06-13-1811-photo-video-copy/contact-sheet.png` was inspected for native app screens.
- `MarketingScreenshots/2026-06-13-1811-photo-video-copy/app-store-6.9-marketing/contact-sheet.png` was inspected for composed marketing screenshots.
- The current contact sheets show photo/video trust copy and no obvious row misalignment, clipped marketing title, or broken bottom bar state.

Still not verified:

- Video playback inside the preview page. Current support is thumbnail preview plus storage metadata for video candidates, not an inline video player.
- Physical-device signed install and real Photos library smoke.
- A separately approved destructive test on physical-device Photos data.

## 2026-06-11 11:05 Permission And Scan State Accessibility Audit

Automated verification:

- Red-path command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepUITests/TrueKeepUITests/testPermissionAndScanStateScreensPassAccessibilityAudit`
- Red-path result 1: failed with `Text clipped` on the permission-denied recovery copy.
- Red-path result 1 bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_10-58-25-+0800.xcresult`
- Red-path result 2: failed with `Label not human-readable` because the decorative permission issue symbol was exposed as an accessibility element.
- Red-path result 2 bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_10-59-43-+0800.xcresult`
- Red-path result 3: failed with `Dynamic Type font sizes are partially unsupported` on the interrupted-scan center caption.
- Red-path result 3 bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_11-00-36-+0800.xcresult`
- Focused green command: `XcodeBuildMCP test_sim -only-testing:TrueKeepUITests/TrueKeepUITests/testPermissionAndScanStateScreensPassAccessibilityAudit`
- Focused green result: 1 UI test passed, 0 failures.
- Focused green result bundle: `/Users/edge/Library/Developer/XcodeBuildMCP/workspaces/photo-cleaner-c87594709434/result-bundles/test_sim_2026-06-11T03-04-06-009Z_pid62457_28d5cb9a.xcresult`
- Related regression command: `XcodeBuildMCP test_sim` with `testCriticalScreensPassAccessibilityAudit`, `testPermissionAndScanStateScreensPassAccessibilityAudit`, `testPermissionDeniedIssueStateIsReachableForAutomation`, `testInterruptedScanStateIsReachableForAutomation`, and `testLimitedCompletedScanShowsAccessWarningBeforeResults`.
- Related regression result: 5 UI tests passed, 0 failures.
- Related regression result bundle: `/Users/edge/Library/Developer/XcodeBuildMCP/workspaces/photo-cleaner-c87594709434/result-bundles/test_sim_2026-06-11T03-04-56-935Z_pid62457_3a591c8e.xcresult`

Implemented coverage:

- Permission issue content now scrolls above fixed bottom actions, so denied-access recovery copy can wrap under accessibility-size Dynamic Type.
- Decorative permission issue symbols are hidden from accessibility.
- Scan progress content now scrolls above fixed bottom actions, and the progress ring scales with Dynamic Type so interrupted/completed center status copy remains readable.
- Critical accessibility audit now covers permission-denied, interrupted-scan, Limited Photos Access completed-scan, and Limited Photos Access results states.

Still not verified:

- Manual VoiceOver navigation order on a physical device.
- Real Limited Photos Access picker behavior on a physical device.
- Physical-device signed install and TestFlight smoke.

## 2026-06-11 10:50 Permission And Scan State UI Coverage

Automated verification:

- Red-path command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepUITests/TrueKeepUITests/testPermissionDeniedIssueStateIsReachableForAutomation`
- Red-path result: failed before implementation because the App did not recognize the permission-denied UI test launch scenario.
- Focused green command: `xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=0157BFC9-C9C9-48DC-845E-AABED7B2DCE9' -only-testing:TrueKeepUITests/TrueKeepUITests/testPermissionDeniedIssueStateIsReachableForAutomation -only-testing:TrueKeepUITests/TrueKeepUITests/testInterruptedScanStateIsReachableForAutomation -only-testing:TrueKeepUITests/TrueKeepUITests/testLimitedCompletedScanShowsAccessWarningBeforeResults`
- Focused green result: 3 UI tests passed, 0 failures.
- Focused green result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_10-49-38-+0800.xcresult`

Implemented coverage:

- Permission-denied screen shows the denied-access copy, settings action, retry action, and return-to-permission action.
- Interrupted-scan screen shows the stopped state, no-deletion reassurance, retry action, and return-to-permission action.
- Limited Photos Access completed-scan screen shows the access warning before results.
- Home results now keep the same `访问范围有限` warning visible after tapping `查看结果`.

Still not verified:

- Actual iOS system Photos permission alert on a physical device.
- Real Limited Photos Access picker behavior on a physical device.
- VoiceOver navigation order on the permission and scan state screens.

## 2026-06-11 10:57 Full Local Release Preflight After UI State Coverage

Automated verification:

- Full preflight command: `python3 iOS/TrueKeep/Scripts/release_preflight.py --run-xcode`
- Full preflight result: 15 pass/info checks, 0 failures.
- Xcode result bundle: `/Users/edge/Library/Developer/Xcode/DerivedData/TrueKeep-brajjfrwyraedqfdgrnxbocjayob/Logs/Test/Test-TrueKeep-2026.06.11_10-51-30-+0800.xcresult`
- Test summary: 58 tests passed, 0 failures, 0 skipped.
- Unsigned Release archive: `/tmp/TrueKeepReleasePreflightUnsigned.xcarchive`
- Fast preflight result: 14 pass/info checks, 0 failures.
- Script unit tests: `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight iOS.TrueKeep.Scripts.tests.test_device_smoke` passed 10 tests, 0 failures.
- Python compile check, trailing-whitespace check, and `git diff --check` passed.

Still not verified:

- Physical-device signed install.
- Real-device smoke execution.
- Distribution-signed archive and App Store export.
- TestFlight install or smoke.
- Hosted Support/Privacy URLs and App Store Connect approval.
