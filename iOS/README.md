# TrueKeep iOS

This folder contains the native iOS implementation for TrueKeep / 留真.

## Current App

- Project: `TrueKeep/TrueKeep.xcodeproj`
- Scheme: `TrueKeep`
- Bundle ID: `app.truekeep.ios`
- Minimum iOS: 17.0
- UI framework: SwiftUI
- Project generation: XcodeGen via `TrueKeep/project.yml`

## Build

```bash
cd iOS/TrueKeep
xcodegen generate
xcodebuild test -project TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,name=iPhone 17'
```

The scheme includes unit tests and UI automation tests. UI tests launch with the deletion safety lock enabled and do not delete Photos items. Fixture cleanup groups are only exposed when tests pass `-TrueKeepUseSampleCleanupData`; the default app launch path does not show unsupported placeholder categories.

When multiple simulator runtimes are installed, prefer a device UDID from:

```bash
xcrun simctl list devices available
```

## Scope

The first native milestone implements the MVP trust-validation prototype:

- Welcome / trust screen
- Photo permission rationale
- Local scan progress with scanning, completed, and interrupted states
- Cleanup task results for supported scan categories
- Review group flow
- 复核箱
- iCloud deletion confirmation
- Privacy & Safety page

Real Photos authorization, screenshot scanning, large-video scanning, local thumbnail loading, 复核箱安全机制, and Photos deletion error handling are wired through service boundaries. Similar-photo, accidental-shot, and blurry-photo results are exposed as low-confidence local review candidates from bounded thumbnail heuristics, not as automatic deletion decisions.

## Device Signing

Physical-device installation is blocked until the Apple Developer account session and provisioning profile are fixed in Xcode. See [TrueKeep device signing](./TrueKeep/DEVICE_SIGNING.md) for the required account-owner steps and the safe smoke-test command.

After signing is fixed, preview the physical-device smoke command without installing:

```bash
python3 iOS/TrueKeep/Scripts/device_smoke.py --team-id <TEAM_ID> --device-id <DEVICE_ID>
```

Add `--execute` only after the iPhone is available and the printed command is correct. The script launches with the deletion safety lock enabled.

## QA

Manual simulator smoke-test coverage is tracked in [TrueKeep manual QA](./TrueKeep/MANUAL_QA.md).

Fast local release preflight:

```bash
python3 iOS/TrueKeep/Scripts/release_preflight.py
```

Full local release preflight, including `xcodebuild test` and unsigned Release archive:

```bash
python3 iOS/TrueKeep/Scripts/release_preflight.py --run-xcode
```

The preflight script does not prove physical-device signing, TestFlight, hosted URLs, or App Store Connect approval. It reports those as external blockers when the local evidence is missing.

## App Store Readiness

Release blockers are tracked in [TrueKeep release checklist](./TrueKeep/RELEASE_CHECKLIST.md). Current App Store privacy answers and Review Notes drafts are in [TrueKeep App Store review notes](./TrueKeep/APP_STORE_REVIEW_NOTES.md). Listing metadata and screenshot-selection notes are in [TrueKeep App Store listing draft](./TrueKeep/APP_STORE_LISTING.md).

Use [TrueKeep App Store submission runbook](./TrueKeep/SUBMISSION_RUNBOOK.md) as the ordered path for the remaining account, signing, physical-device, TestFlight, hosted-URL, and App Store Connect work.
