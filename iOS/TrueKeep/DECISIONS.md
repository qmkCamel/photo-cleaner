# TrueKeep iOS Decisions

This file records technical choices and product decisions made while turning the MVP trust-validation prototype into the native iOS app.

## 2026-06-10

### Technical choices

- Use SwiftUI for the first iOS implementation.
  - Reason: the prototype is screen- and state-driven, and SwiftUI maps directly to the onboarding, tab, sheet, and review flows.
- Use XcodeGen to generate `TrueKeep.xcodeproj` from `project.yml`.
  - Reason: the repo did not have an iOS project yet, and a generated project keeps target settings reviewable in text.
- Set minimum iOS to 17.0 for the first pass. Superseded by the 2026-07-13 iOS 18 Vision aesthetics decision below.
  - Reason: keeps the SwiftUI implementation modern while avoiding a premature iOS 26-only dependency before Photos/Vision capability work is validated.
- Keep the first product state model as value types.
  - Reason: the first milestone is local UI state and deterministic fixture data; value types are easy to test and do not require a shared observable store yet.
- Add unit tests for deletion safety flow before wiring the UI.
  - Covered behavior: selected candidates enter Review Bin before deletion, deletion confirmation clears selected items, and recommended keep items are not selected for deletion by default.
- Keep fixture thumbnails as SwiftUI-rendered fallback tiles.
  - Reason: real photo thumbnails are only available after Photos authorization and asset fetching, so fixture and empty states still need deterministic visuals.
- Introduce a `PhotoLibraryAuthorizing` service boundary before building the scanner.
  - Reason: system authorization, denied/restricted routing, and Limited Photos Access behavior need to be testable separately from the heavier asset-scanning pipeline.
- Keep Photos authorization requests behind the trust rationale screen.
  - Reason: users should see the local-processing and deletion-safety promises before iOS shows the system permission prompt.
- Introduce a `PhotoLibraryScanning` service boundary backed by `PHAsset.fetchAssets`.
  - Reason: the app now has a real Photos data source for supported categories, while the rules that turn asset snapshots into cleanup tasks remain unit-testable without a photo library.
- Do not use private `PHAssetResource` file-size KVC for the first scanner.
  - Reason: App Store safety is more important than exact byte estimates; unsupported exact-size logic should not rely on undocumented APIs.
- Introduce a `PhotoLibraryDeleting` service boundary backed by `PHPhotoLibrary.performChanges`.
  - Reason: deletion must be a real Photos mutation, not a local Review Bin state change. Keeping it behind a protocol makes failure handling and future UI tests injectable.
- Resolve deletion outcomes into success, partial failure, and failure states.
  - Reason: if Photos cannot delete every selected asset, the app must keep failed items in Review Bin and show a retryable error instead of pretending the library changed.
- Preserve `PHAsset.localIdentifier` on real scan candidates and load thumbnails through `PHCachingImageManager`.
  - Reason: review surfaces should show the user's actual library items after permission is granted, while retaining fixture fallbacks for prototype data and missing assets.
- Cache rendered thumbnail requests with a pixel-size cache key and local `NSCache`.
  - Reason: the same assets appear across result previews, review groups, and Review Bin. A stable in-memory cache avoids repeated Photos requests without persisting user photos outside the system library.
- Add a debug-only deletion safety lock controlled by launch argument or environment.
  - Reason: manual device testing sometimes needs real Photos permission and scan flows, but should be able to run with deletion disabled. Launching with `-TrueKeepDisablePhotoDeletion` or `TRUEKEEP_DISABLE_PHOTO_DELETION=1` makes the deletion service return a failure without calling Photos deletion APIs.
- Keep device signing/provisioning as an explicit release blocker. Resolved on 2026-07-31 after signed device install, safe launch, and App Store export succeeded.
  - Reason: the original local installation failed because no matching development provisioning profile existed for `app.truekeep.ios` and the configured Apple account could not refresh profiles.
- Keep `DEVELOPMENT_TEAM` empty in `project.yml` until the release Team is confirmed. Superseded on 2026-07-31 by confirmed Team `D8BE8WBTV5`.
  - Reason: the repo should not accidentally commit a provisional Team ID. Once Apple Developer Services confirmed the Team and Bundle ID, the source-of-truth Team was committed to the XcodeGen configuration.
- Scan Photos assets in batches and yield between batches.
  - Reason: large libraries should not be processed as one long synchronous enumeration. The scanner now has a batch policy and cancellation checks before each batch.
- Use a smaller scan batch size in Low Power Mode.
  - Reason: battery state should affect local processing pressure. The first policy uses 200-item batches normally and 50-item batches when Low Power Mode is enabled.
- Use task cards as the Home review entry point.
  - Reason: a fixed Home footer duplicated the task-card entry and could cover the lower list content in screenshots. Review and Review Bin keep fixed bottom action areas where selection state matters; Home uses direct task-card navigation.
- Every tappable Home cleanup task must have a matching review group.
  - Reason: a task card that looks tappable but has no route breaks trust. Fixture/sample data now includes review groups for all five MVP categories, and a unit test guards that invariant.
- Disable the add-to-Review-Bin action when no candidates are selected.
  - Reason: `加入 Review Bin（0）` looked actionable but could only produce a no-op. Zero-selection states now prompt the user to select photos first and are not exposed as tappable targets.
- Add a `TrueKeepUITests` target to the main scheme.
  - Reason: the highest-risk MVP failures are interactive regressions, not pure model bugs. XCUITest now covers settings navigation, Home task routing, review actions, Review Bin deletion safety lock, zero-selection disabled behavior, and marketing screenshot capture with the debug deletion lock enabled.
- Disable all Review Bin footer actions when no items are selected.
  - Reason: `删除选中（0）` and `恢复选中` should not look actionable when they would only produce a no-op. UI tests now deselect every Review Bin item and verify both footer actions are disabled.
- Add `PrivacyInfo.xcprivacy` to the app target.
  - Reason: the current build has no analytics, ads, crash SDK, tracking domains, network upload, or required-reason API usage. The manifest declares no tracking, no collected data types, and no accessed API types; future SDK or telemetry additions must update this file and App Store privacy answers together.
- Gate sample cleanup data behind an explicit launch argument.
  - Reason: fixture categories are useful for UI automation and design review, but they must not appear as real scan results in a build that can be submitted. The default launch path starts with an empty real-scan state; UI tests opt into sample data with `-TrueKeepUseSampleCleanupData`.
- Centralize public supported-scan copy in `SupportedScanCopy`.
  - Reason: Photos permission and onboarding copy must stay aligned with the scanner's real capability. Unit tests now block public copy from claiming upload behavior, automatic deletion, or visual certainty beyond local review candidates.

### Product decisions

- Review Bin receives only the candidates selected for deletion.
  - Context: the web prototype visually showed more items in Review Bin than the `加入 Review Bin（3）` action implied.
  - Decision: the native app follows the safer and clearer interpretation: only selected deletion candidates move into Review Bin.
- Recommended keep items are not selectable for deletion by default.
  - Reason: preserving the best memory in a similar group is the core trust promise.
- The app does not ask for system photo permission on the welcome screen.
  - Reason: the product first explains local scanning and deletion safety, then asks for permission.
- Delete confirmation must explicitly mention iCloud Photos and Recently Deleted.
  - Reason: iCloud sync deletion and premature cleanup of Recently Deleted are the highest-risk user misunderstandings.
- Fixture data remains available only for tests and design review.
  - Reason: sample groups are still useful for deterministic UI automation and screenshot review, but the default runtime path now uses real metadata plus local visual heuristics instead of placeholder task cards. Sample data stays behind `-TrueKeepUseSampleCleanupData`.
- Full Photos Access and Limited Photos Access both enter the scan flow.
  - Reason: Limited Access users can still evaluate the product, but the app must explain that scan results may be incomplete.
- Limited Photos Access shows an incomplete-results warning on both scan progress and results.
  - Reason: silent partial scans would undermine trust and make cleanup recommendations look more definitive than they are.
- Denied and restricted Photos states route to a dedicated permission issue screen.
  - Reason: the app should not imply it scanned anything when it cannot read the library, and users need a clear path to Settings when recovery is possible.
- The first real scanner creates metadata candidates and low-confidence visual candidates.
  - Reason: screenshots and long/large videos are explainable from Photos metadata. Similar photos, accidental shots, and blurry photos are now presented only as local review candidates derived from bounded thumbnail heuristics, not as certain cleanup decisions.
- Public Photos permission and onboarding copy can claim local visual candidates only with safety limits.
  - Reason: visual classifier overclaiming is an App Review and trust risk. Permission rationale and usage strings must describe local processing, no upload, no automatic deletion, and user confirmation before Photos changes.
- Empty scan results are shown as a real state instead of falling back to demo data.
  - Reason: once the user grants Photos access, showing fixture cleanup candidates would be misleading.
- Review Bin is only cleared after Photos confirms deletion.
  - Reason: user trust depends on app state matching the actual Photos library. Failed or missing assets stay visible with an error message.
- Real thumbnails never trigger network-backed iCloud downloads in the first MVP.
  - Reason: the product promise is local review and low-surprise behavior. iCloud-only assets can fall back visually until the app has explicit copy for network access.
- Scan results cannot be opened until the scan task completes.
  - Reason: showing stale fixture results while a real scan is still running would be misleading. The scan screen now has scanning, completed, and interrupted states.
- Cancelling a scan is non-destructive and returns to an interrupted scan state.
  - Reason: users need a safe escape hatch during first-run testing and large-library scans. Cancelling stops the active task, avoids publishing partial results, and offers retry.
- Settings rows should open explanatory detail pages, not act as static labels.
  - Reason: if the UI visually suggests a row can be tapped, it must either navigate or be clearly non-interactive.
- App Store privacy answers should currently be "No data collected" and "No tracking".
  - Reason: the current MVP uses Photos locally, keeps thumbnails in memory cache only, and does not include accounts, analytics, advertising, crash reporting, or upload behavior. This decision must be revisited before adding telemetry, subscription SDKs, support chat, or any server-backed feature.

## 2026-06-11

### Technical choices

- Add a critical XCTest accessibility audit as a regression gate.
  - Covered audit types: contrast, Dynamic Type, element detection, hit region, sufficient element description, text clipped, and trait.
  - Reason: the most visible MVP trust screens must fail fast when rows drift out of alignment, controls are too small, labels are missing, or text becomes clipped.
- Centralize text typography behind semantic `TrueKeepTheme.Font` tokens and block fixed text fonts in app sources.
  - Reason: fixed `.font(.system(size: ...))` calls produced Dynamic Type audit failures and made later screen-level fixes fragile. A source guard now fails if app text reintroduces fixed-size SwiftUI fonts.
- Adapt promise rows for accessibility-size Dynamic Type.
  - Reason: horizontal icon/text rows worked at normal sizes but clipped Privacy & Safety subtitles under accessibility sizes. Promise rows now stack vertically for accessibility Dynamic Type while keeping the original horizontal layout at standard sizes.
- Promote Home confidence labels from caption-sized styling to a scalable status-label token.
  - Reason: XCTest flagged the small capsule label as partially unsupported for Dynamic Type. The status-label token keeps the pill readable without changing the card hierarchy.
- Standardize inline text actions as real 44 pt controls.
  - Reason: text-only actions such as `了解更多`, `暂不`, `上一组`, and `下一组` were visually subtle and failed hit-region expectations. The shared inline action component keeps them tappable without making them look like primary actions.
- Treat decorative trust-row icons as hidden from accessibility.
  - Reason: VoiceOver should read the promise text, not duplicate standalone SF Symbol descriptions.
- Add stateful accessibility labels for review candidates and Review Bin rows.
  - Reason: a Review Bin row that only reads as a generic photo item hides the exact cleanup decision from VoiceOver users. Labels now include keep/delete state, cleanup category, cleanup reason, and estimated storage where relevant, and UI tests verify the selected/unselected announcement changes.
- Remove cramped visual task-card descriptions from Home cards while preserving them in accessibility labels.
  - Reason: the card descriptions were the source of contrast and clipping failures near the tab bar. The Home list now prioritizes scannable task titles and counts visually, while assistive technologies still receive the category description.
- Use a large scrollable delete-confirmation sheet.
  - Reason: fixed and medium detents clipped confirmation content under the XCTest text audit. The large detent introduces extra empty space on some devices, but it keeps the destructive confirmation copy and actions readable and reachable.
- Add a visible tab bar toolbar background.
  - Reason: scroll content should not visually collide with the tab bar in screenshots or during review flows.
- Add bounded local visual classification before the first TestFlight pass.
  - Reason: the MVP needs real similar, accidental, and blurry candidate flows without uploading photos or introducing a model dependency. The first implementation uses local thumbnail perceptual hashes, brightness, saturation, and edge-sharpness heuristics.
- Keep visual classification network-free and bounded.
  - Reason: the trust promise is local and low-surprise. Visual scanning uses `PHImageRequestOptions.isNetworkAccessAllowed = false`, processes only a capped number of recent assets, and uses a smaller cap in Low Power Mode.
- Select the sharpest similar item as the recommended keep candidate.
  - Reason: similar groups should preserve the best memory by default. The recommended keep item is not selected for deletion unless the user changes the selection.
- Add UI-test launch scenarios for permission-denied, interrupted-scan, and limited-completed-scan states.
  - Reason: these states depend on system Photos authorization or asynchronous scan timing and are otherwise hard to reach deterministically in XCUITest. Launch arguments keep the default user path unchanged while allowing repeatable coverage of high-risk trust screens.
- Extend the critical accessibility audit to permission-denied, interrupted-scan, limited-completed-scan, and limited-results states.
  - Reason: these are not edge-case cosmetics; they are the exact recovery states users see when trust is fragile. The permission issue screen now uses scrollable content with fixed bottom actions, decorative symbols are hidden from accessibility, and the scan progress screen uses scrollable content plus a Dynamic-Type-scaled progress ring so status copy stays readable.

### Product decisions

- Accessibility regressions are treated as product trust issues, not cosmetic polish.
  - Reason: the product promise depends on clarity and control. Misaligned trust rows, small tappable text, and clipped deletion warnings directly weaken the deletion-safety story.
- Permission and scan-recovery states are part of the MVP trust surface.
  - Reason: denied access, canceled scans, and Limited Photos Access are common first-run outcomes. They need the same visual and accessibility quality bar as the happy path before TestFlight.
- Review Bin VoiceOver copy must be decision-complete.
  - Reason: users should be able to understand what will be deleted without relying on visual layout. The accessibility announcement must include whether the item is selected for deletion, why it was suggested, and what category it belongs to.
- Marketing screenshots should use the latest accessibility-passing simulator capture.
  - Reason: earlier screenshot sets are useful for comparison, but public-facing review should start from `MarketingScreenshots/2026-06-13-1811-photo-video-copy/`, which includes the current photo/video trust copy, permission-page clipping fix, localized `复核箱` copy, and corrected Home review-queue card visibility.
- The delete confirmation can favor accessibility over compact sheet height for MVP validation.
  - Reason: whitespace is less risky than hiding or clipping destructive-action copy. A denser sheet can be revisited after the VoiceOver pass.
- Similar, accidental, and blurry findings are review candidates, not automatic cleanup decisions.
  - Reason: the current classifier is heuristic-based and intentionally conservative. The product copy and default selection behavior must keep the user in control until real-device quality data supports stronger recommendations.
- App Store screenshot exports are treated as upload candidates, not final approved assets.
  - Reason: the latest simulator screenshots are useful for internal review and marketing planning, and a 6.9-inch `1320 x 2868` export set now exists. Final App Store Connect screenshots still need human approval. Any sample-data screenshot must remain clearly representative and consistent with App Review notes.
- Keep marketing screenshot composition reproducible.
  - Reason: raw simulator screenshots are useful as evidence, but App Store review usually needs clearer value framing. The composed 6.9-inch marketing candidates are generated from the current screenshot export by `Scripts/build_marketing_screenshots.py`, so copy and layout can be revised without overwriting the test evidence.
- Localize the in-app deletion staging area as `复核箱` for Chinese UI and screenshots.
  - Reason: the previous `Review Bin` label was understandable internally but looked unfinished in Chinese App Store screenshots. Internal identifiers and English App Store copy can keep the Review Bin concept, while the user-facing Chinese UI should read as one localized product.
- Prefer content padding over a bottom safe-area cover on the Home results list.
  - Reason: the previous Home screenshot showed a partial bottom task card above the tab bar. Keeping spacing in the scroll content preserves tab clearance without visually clipping the last visible card in launch-marketing screenshots.
- Prepare static support and privacy pages before choosing hosting.
  - Reason: App Store Connect requires reachable Support and Privacy Policy URLs, but the domain and monitored support contact are not confirmed yet. Keeping deployable static templates in `docs/app-store/site-template/` lets hosting be a small operational step later without pretending the URLs are already live.
- Centralize local release checks in a preflight script.
  - Reason: release readiness was previously evidenced by separate commands scattered across QA notes. `Scripts/release_preflight.py` now checks static release files, metadata limits, App Store Connect metadata packet consistency, screenshot dimensions, privacy guardrails, Chinese localized-copy guardrails, support/privacy page links, and signing blocker state in one repeatable command, with full Xcode tests and unsigned archive available behind `--run-xcode`.
- Keep the App Store Connect copy-paste packet synchronized with `APP_STORE_LISTING.md`.
  - Reason: App Store submission will likely involve manual paste by the account owner. A drift between listing docs and `AppStoreConnect/metadata/*` would be easy to miss during submission, so preflight now compares app name, subtitle, keywords, promotional text, and description for both `en-US` and `zh-Hans`.
- Keep Chinese-localized publish surfaces free of `Review Bin` while preserving English copy where appropriate.
  - Reason: App source, zh-Hans metadata, the zh-Hans listing section, and Chinese marketing screenshot text should use `复核箱`; English metadata/support/review notes can still explain the Review Bin concept. The preflight guard now enforces that boundary and skips binary assets.
- Keep Chinese design docs and the high-fidelity prototype aligned with the localized `复核箱` UI.
  - Reason: implementation, design review, and launch screenshots should not drift into different user-facing terms. The preflight guard now covers the Chinese MVP docs and interactive prototype in addition to app and metadata surfaces.
- Report final-submission URL/contact placeholders in preflight as explicit external blockers.
  - Reason: local HTML link checks can pass while App Store Connect still lacks hosted Privacy/Support URLs and a monitored support contact. The preflight now emits an `external-submission-placeholders` info line so the remaining operational work is visible without failing local code validation.
- Keep Limited Photos Access warnings visible after the scan result transition.
  - Reason: the scan screen already explained the limited access boundary, but users can act on results from Home. The Home notice now uses the same `访问范围有限` title so incomplete results remain clear while reviewing cleanup candidates.
- Use `TrueKeep: AI Photo Cleaner` with `Private Camera Roll Cleanup` as the current App Store metadata draft.
  - Reason: the name keeps the brand visible while carrying the primary search intent. The subtitle avoids repeating `Photo Cleaner` and better describes the broader screenshots, videos, similar-photo, and review-bin workflow than a duplicate-only subtitle.
- Treat `AI Photo Cleaner` as a useful but risky generic phrase.
  - Reason: similar competitor phrasing exists, including `PicKeep: AI Photo Cleaner`. The final listing should make `TrueKeep` and the local trust promise prominent instead of relying only on category keywords.
- Keep unsigned Release archive preflight separate from distribution signing readiness.
  - Reason: `xcodebuild archive` with `CODE_SIGNING_ALLOWED=NO` proves the Release iPhoneOS archive path compiles and packages the app bundle, but it does not prove provisioning, distribution certificates, App Store export, or TestFlight upload readiness.
- Keep Apple Team IDs out of committed project settings until the release account is confirmed.
  - Reason: the current machine has an Apple Development certificate for `KTTVMPA76Y`, but the Xcode account session is invalid and no matching provisioning profile exists for `app.truekeep.ios`. Signing preflights can pass `DEVELOPMENT_TEAM` on the command line without committing a personal or provisional Team ID.
- Make physical-device smoke testing opt-in and deletion-safe by default.
  - Reason: once signing is fixed, the riskiest mistake is accidentally installing or launching a build without the deletion safety lock. `Scripts/device_smoke.py` defaults to dry-run and, when explicitly executed, launches with both the environment variable and launch argument that disable Photos deletion.
- Keep App Store compliance answers evidence-based and conservative.
  - Reason: current code has no custom cryptography, networking features, accounts, StoreKit, WebKit, ads, analytics, or tracking frameworks. The App Store Connect drafts should reflect that exact current scope and must be revisited before adding subscriptions, support chat, crash reporting, analytics, or server-backed features.
- Treat App Store submission as three explicit gates: local candidate freeze, signed real-device/TestFlight validation, and App Store Connect submission.
  - Reason: the local build is much more mature than the external account/signing state. `SUBMISSION_RUNBOOK.md` keeps the remaining steps executable without pretending that signing, URLs, TestFlight, or legal/name clearance are already complete.

## 2026-06-13

### Technical choices

- Make Debug builds deletion-safe by default.
  - Reason: a normal Xcode Run on a connected iPhone should never be able to delete Photos items by accident during smoke testing. Debug builds now keep `PhotoDeletionSafetyPolicy.current` disabled unless a separate destructive test explicitly opts in with `-TrueKeepEnableDestructivePhotoDeletion` or `TRUEKEEP_ENABLE_DESTRUCTIVE_PHOTO_DELETION=1`. Explicit disable controls still win over destructive opt-in.

### Product decisions

- Treat real Photos deletion as a separately approved destructive test, not part of ordinary verification.
  - Reason: the MVP trust promise depends on not surprising the tester or user. Smoke tests can still exercise the Review Bin and confirmation flow, but they should end at the safety-lock failure message until a separate destructive-test plan is approved.

## 2026-07-13

### Technical choices

- Raise the minimum deployment target to iOS 18.0.
  - Reason: TrueKeep now uses the system `VNCalculateImageAestheticsScoresRequest` as the default photo-quality model path, which is available from iOS 18. Keeping an iOS 17 branch would preserve a rules-only runtime that the product no longer intends to support.
- Use Vision aesthetics as the primary overall-quality signal while preserving deterministic heuristics.
  - Reason: the system model provides an on-device quality score without bundling a custom model. Brightness, saturation, and edge sharpness remain useful for explainable candidate reasons and provide a safe fallback if Vision returns no result.
- Use face capture quality only as a bounded recommended-keep assist.
  - Reason: face quality is useful when comparing similar family-photo frames, but it is not a general measure of memory value. Recommended-keep ranking weights overall quality at 80% and face capture quality at 20% when a face signal exists.

### Product decisions

- Never turn Vision's utility flag directly into a cleanup candidate.
  - Reason: receipts, documents, screenshots, and other utility images may be valuable even when they are not aesthetically memorable. Utility classification is context, not deletion intent.
- Keep model-driven accidental findings conservative and unselected by default.
  - Reason: only a very low non-utility aesthetics score can independently cross the existing accidental-risk threshold. The result remains a low-confidence review aid and still requires the 复核箱 plus second deletion confirmation.

## Open decisions

- Whether the first TestFlight should proactively prompt Limited Access users to expand access after their first incomplete scan.
- How to estimate or retrieve exact asset byte size without private APIs or misleading cleanup numbers.
- Whether the scan screen should expose exact item-level progress once Photos enumeration cost is profiled on large libraries.
- Whether to fine-tune a lightweight Core ML accidental-shot model after Vision aesthetics and heuristic false positives are collected from real-device testing.
- Whether the first paid SKU is one-time purchase only or one-time purchase plus optional annual Pro.
- Which Apple Developer Team, bundle identifier, and provisioning profile should be treated as the release source of truth.
- How much additional VoiceOver-specific polish is needed before the first TestFlight parent-user pass.
- Whether `truekeep.app`, `truekeep.ai`, or another owned domain becomes the support and privacy-policy home.
- Whether final legal/trademark review approves `TrueKeep` and `留真` for App Store submission.
