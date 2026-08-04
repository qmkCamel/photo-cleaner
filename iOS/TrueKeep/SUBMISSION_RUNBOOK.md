# TrueKeep App Store Submission Runbook

Updated: 2026-07-31

This runbook is the ordered path from the current local release candidate to an App Store submission. It separates local evidence that can be produced in this repo from external work that requires the Apple Developer account, a physical iPhone, hosted URLs, and App Store Connect.

## Current Readiness

Local evidence already prepared:

- Full simulator regression and local release preflight have passed.
- Unsigned Release iPhoneOS archive has passed.
- App Store metadata drafts are saved in `AppStoreConnect/`.
- Privacy, support, and compliance drafts are saved in `../../docs/app-store/`.
- Native and composed 6.9-inch screenshot candidates are saved in `MarketingScreenshots/2026-06-13-1811-photo-video-copy/`.
- Physical-device smoke runner is prepared at `Scripts/device_smoke.py`, with dry-run as the default and deletion disabled during execution. Debug builds also keep the deletion safety lock active by default.
- Release Team `D8BE8WBTV5` and Bundle ID `app.truekeep.ios` are confirmed.
- Automatic Development signing, physical-device installation, and deletion-safe launch have succeeded.
- Release archive and local App Store Connect export have succeeded with cloud-managed Apple Distribution signing.

Submission blockers still open:

- Full physical-device smoke coverage must pass; only signed install and deletion-safe launch are currently confirmed.
- TestFlight upload and real-device TestFlight smoke must pass.
- Privacy Policy URL and Support URL must be hosted and verified.
- App Store Connect compliance answers, metadata, screenshots, and Review Notes must be entered and approved by the account owner.
- Final legal, trademark, name, and domain clearance must be confirmed.

## Non-Negotiable Safety Rules

- Do not share Apple ID passwords, 2FA codes, app-specific passwords, Keychain secrets, certificates, or provisioning profiles in this repo or chat.
- Do not run real Photos deletion during smoke testing. Debug builds are deletion-safe by default; keep `-TrueKeepDisablePhotoDeletion` and `TRUEKEEP_DISABLE_PHOTO_DELETION=1` enabled as extra guards until a separate destructive-test plan is approved.
- Do not pass `-TrueKeepEnableDestructivePhotoDeletion` or `TRUEKEEP_ENABLE_DESTRUCTIVE_PHOTO_DELETION=1` during normal smoke testing.
- Keep committed `DEVELOPMENT_TEAM` aligned with confirmed release Team `D8BE8WBTV5`.
- Do not mark the app ready for submission until every stop condition below is cleared with fresh evidence.

## Phase 1: Freeze The Local Candidate

Goal: prove the local app, metadata packet, screenshots, and static pages are internally consistent before touching signing or App Store Connect.

Commands:

```bash
cd /Users/edge/side/photo-cleaner
python3 iOS/TrueKeep/Scripts/release_preflight.py
```

Run the full local gate before any TestFlight or final archive attempt:

```bash
cd /Users/edge/side/photo-cleaner
python3 iOS/TrueKeep/Scripts/release_preflight.py --run-xcode
```

Pass criteria:

- Fast preflight reports 0 failed checks.
- Full preflight reports 0 failed checks.
- `xcodebuild test` passes all unit and UI tests.
- Unsigned Release archive succeeds.
- `DEVELOPMENT_TEAM` is `D8BE8WBTV5` in `project.yml`.
- App Store metadata length checks pass.
- Raw and composed screenshot exports are `1320 x 2868`.
- Static support/privacy template links resolve locally.

Stop if:

- Any test fails.
- Any screenshot dimension check fails.
- Privacy manifest no longer matches the no-collection/no-tracking claim.
- Source guardrails detect networking, WebKit, StoreKit, ads, tracking, custom crypto, or key-management patterns that have not been reflected in App Store privacy/compliance drafts.
- The support/privacy pages still contain final-submission placeholders after a hosted URL has been claimed as ready.

Evidence to keep:

- Latest preflight command and summary in `MANUAL_QA.md`.
- Latest result bundle path in `APP_STORE_REVIEW_NOTES.md`.
- Final screenshot decision in `APP_STORE_LISTING.md`.
- Any product or technical scope change in `DECISIONS.md`.

## Phase 2: Fix Signing And Prove The App On A Real iPhone

Goal: install and smoke-test the app on a physical iPhone without deleting any photo or video items.

Confirmed account state:

1. The release Team is `D8BE8WBTV5`.
2. Bundle ID `app.truekeep.ios` is registered to that Team.
3. Automatic signing is enabled through the committed XcodeGen source.
4. Re-authenticate this account in Xcode only if a future provisioning request reports an expired session.

Device discovery:

```bash
cd /Users/edge/side/photo-cleaner
xcrun devicectl list devices
xcodebuild -showdestinations \
  -project iOS/TrueKeep/TrueKeep.xcodeproj \
  -scheme TrueKeep
```

Generic signing preflight:

```bash
cd /Users/edge/side/photo-cleaner
xcodebuild build \
  -project iOS/TrueKeep/TrueKeep.xcodeproj \
  -scheme TrueKeep \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/TrueKeepSignedGenericBuild \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=D8BE8WBTV5 \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY='Apple Development'
```

Safe physical-device dry-run:

```bash
cd /Users/edge/side/photo-cleaner
python3 iOS/TrueKeep/Scripts/device_smoke.py \
  --team-id D8BE8WBTV5 \
  --device-id <DEVICE_ID>
```

Safe physical-device execution:

```bash
cd /Users/edge/side/photo-cleaner
python3 iOS/TrueKeep/Scripts/device_smoke.py \
  --team-id D8BE8WBTV5 \
  --device-id <DEVICE_ID> \
  --execute
```

Physical-device smoke flow:

1. Launch app and confirm the welcome screen renders.
2. Tap `继续` and confirm the Photos permission rationale appears before the iOS Photos prompt.
3. Test Limited Photos Access and confirm incomplete-results copy appears.
4. Test Full Photos Access and run scan.
5. Cancel a scan and confirm the interrupted state appears without stale results.
6. Re-run scan and confirm supported results or the real empty state.
7. Open Home task cards that are available from real scan results.
8. Add candidates to Review Bin.
9. Open delete confirmation with deletion safety lock enabled.
10. Confirm deletion attempt shows the safety-lock failure message and removes no photo or video items.
11. Open Privacy & Safety rows and confirm every row navigates and returns.
12. Run a quick VoiceOver pass over onboarding, Home, Review Bin, and delete confirmation.

Pass criteria:

- Physical iPhone is available as a destination.
- Signed development build succeeds.
- App installs and launches on the physical iPhone.
- Deletion safety lock is active during the smoke test.
- No photo or video items are removed.
- No crash occurs during permission, scan, review, Review Bin, settings, or delete-confirmation flows.
- Manual VoiceOver navigation finds no blocking issue in the main MVP flow.

Stop if:

- Xcode still reports `No Accounts` or missing profile errors.
- No physical iPhone appears as an available destination.
- The dry-run command does not show both deletion-safety controls.
- The app asks for Photos permission before the rationale screen.
- The app shows fixture/sample task cards on the default launch path.
- A delete attempt reaches real Photos deletion during debug smoke.
- A Debug build reaches real Photos deletion without the explicit destructive-test opt-in.
- Any obvious UI alignment, clipping, hit-region, or navigation issue appears.

Evidence to keep:

- Device model, iOS version, Team ID, Bundle ID, and device destination ID in `MANUAL_QA.md`.
- Signed build command result in `DEVICE_SIGNING.md`.
- Smoke-test result and screenshots in `MANUAL_QA.md`.
- Any screenshots useful for promotion copied or referenced from the current `MarketingScreenshots/` set.

## Phase 3: Submit Through TestFlight And App Store Connect

Goal: validate the signed distribution build, complete App Store Connect data entry, and submit only after external approval gates are cleared.

Prepare hosted URLs:

1. Replace the support-contact placeholder in `../../docs/app-store/site-template/`.
2. Host `privacy.html` and `support.html` on the confirmed public domain.
3. Verify both URLs load without login, geoblocking, or review-only redirects.
4. Update `APP_STORE_LISTING.md` and App Store Connect metadata with the final URLs.

Prepare App Store Connect:

1. Confirm final app name and localized names.
2. Confirm name availability in App Store Connect.
3. Confirm category, age rating, content rights, export compliance, and encryption answers from `../../docs/app-store/compliance-answers.md`.
4. Paste metadata from `AppStoreConnect/metadata/en-US/` and `AppStoreConnect/metadata/zh-Hans/`.
5. Paste Review Notes from `AppStoreConnect/review-notes.txt`.
6. Upload approved screenshots from the selected `MarketingScreenshots/` folder.
7. Re-check that screenshots, metadata, Review Notes, and privacy answers describe the same build behavior.

Distribution archive and upload:

```bash
cd /Users/edge/side/photo-cleaner
xcodebuild archive \
  -project iOS/TrueKeep/TrueKeep.xcodeproj \
  -scheme TrueKeep \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/TrueKeepDistribution.xcarchive \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=D8BE8WBTV5 \
  CODE_SIGN_STYLE=Automatic
```

Use Xcode Organizer or App Store Connect upload tooling only after the archive is signed with the confirmed distribution assets.

TestFlight smoke:

1. Install the TestFlight build on a physical iPhone.
2. Run the same non-destructive smoke flow from Phase 2.
3. Ask parent users to try the onboarding, scan, Review Bin, and deletion-warning flow.
4. Record any confusion about local processing, iCloud deletion, or Review Bin control before submitting for App Review.

Pass criteria:

- Distribution-signed archive succeeds.
- TestFlight upload succeeds.
- TestFlight build installs and launches on a physical iPhone.
- TestFlight smoke passes without Photos deletion.
- Hosted privacy/support URLs are accepted by App Store Connect.
- App privacy answers still match the shipped binary.
- Final screenshot set is human-approved.
- Legal/trademark/name/domain clearance is confirmed.

Stop if:

- Distribution archive fails signing or export validation.
- App Store Connect rejects screenshots, metadata, URLs, privacy answers, or compliance answers.
- TestFlight users misunderstand deletion behavior or believe the app uploads photos.
- The final binary adds analytics, networking, subscriptions, crash reporting, support chat, or third-party SDKs without updating privacy, compliance, Review Notes, and user-facing copy.
- Any real-device UI issue weakens the trust story.

Evidence to keep:

- Final archive path and export/upload result in `MANUAL_QA.md`.
- TestFlight build number and smoke result in `MANUAL_QA.md`.
- Final URLs in `APP_STORE_LISTING.md`.
- Any changed App Store answers in `APP_STORE_REVIEW_NOTES.md` and `AppStoreConnect/`.
- Final release blockers cleared in `RELEASE_CHECKLIST.md`.

## Final Submit Gate

Before pressing Submit for Review, confirm all of the following are true:

- `RELEASE_CHECKLIST.md` has no open submission blocker except intentional post-launch follow-ups.
- `APP_STORE_REVIEW_NOTES.md` matches the exact binary uploaded to App Store Connect.
- `APP_STORE_LISTING.md` has final URLs, names, screenshots, and metadata.
- `DEVICE_SIGNING.md` reflects the confirmed Team ID, Bundle ID, and provisioning state.
- `MANUAL_QA.md` includes fresh simulator, physical-device, and TestFlight evidence.
- The current build has not deleted any Photos item during testing unless a separate destructive-test plan was explicitly approved.
