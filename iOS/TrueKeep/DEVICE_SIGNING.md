# TrueKeep Device Signing and Smoke Test

This note records what is needed before TrueKeep can be installed on a physical iPhone for manual verification.

## Current State

- Release Team: `D8BE8WBTV5`
- Bundle ID: `app.truekeep.ios`
- Project: `TrueKeep.xcodeproj`
- Scheme: `TrueKeep`
- `project.yml` commits the confirmed release Team, and XcodeGen propagates it to the generated project.
- 2026-07-31: Xcode automatic signing confirmed that `app.truekeep.ios` is registered to Team `D8BE8WBTV5`.
- 2026-07-31: a Debug device build used `iOS Team Provisioning Profile: *`, installed on an iPhone 16 Plus (iOS 26.2.1; device identifier intentionally omitted), and launched with both deletion safety controls enabled.
- 2026-07-31: Release archive succeeded at `/tmp/TrueKeepDistribution-20260731-1504.xcarchive`.
- 2026-07-31: local App Store Connect export succeeded at `/tmp/TrueKeepAppStoreExport-20260731-1505/TrueKeep.ipa`.
- Distribution export used `Cloud Managed Apple Distribution`, Team `D8BE8WBTV5`, application identifier `D8BE8WBTV5.app.truekeep.ios`, and `iOS Team Store Provisioning Profile: app.truekeep.ios`.
- Full real-library physical-device smoke and TestFlight validation remain open. No destructive Photos test was run.
- 2026-06-11 09:01 CST check: `xcrun devicectl list devices` sees three physical iPhone entries, but all are currently `unavailable`.
- 2026-06-11 09:01 CST check: `xcodebuild -showdestinations` lists only the generic iOS device placeholder and simulators; no physical iPhone is currently available as a build destination.
- 2026-06-11 09:01 CST check: Keychain contains `Apple Development: Meikai Qu (KTTVMPA76Y)`.
- 2026-06-11 09:01 CST check: no local `.mobileprovision` or `.provisionprofile` files were found under `~/Library/MobileDevice/Provisioning Profiles`.
- 2026-06-11 09:20 CST automatic signing preflight was attempted with `DEVELOPMENT_TEAM=KTTVMPA76Y` passed only on the command line.
- 2026-06-11 09:20 CST result: the app compiled for iPhoneOS, then signing failed with `No Accounts: Add a new account in Accounts settings` and `No profiles for 'app.truekeep.ios' were found`.
- 2026-06-11 09:20 CST result: Xcode also reported invalid local account credentials, including missing `Xcode-Username` / `Xcode-Token` entries.
- 2026-06-11 09:45 CST recheck: `xcrun devicectl list devices` still sees the three physical iPhone entries, but all remain `unavailable`.
- 2026-06-11 09:45 CST recheck: `xcodebuild -showdestinations` still lists no real physical iPhone destination for the `TrueKeep` scheme.
- 2026-06-11 09:45 CST recheck: local provisioning profile count is still `0`.
- Unsigned iPhoneOS compilation succeeds with `CODE_SIGNING_ALLOWED=NO`.
- The 2026-06-11 signed-install blocker below is retained as historical evidence and was cleared on 2026-07-31.
- Debug builds now keep the deletion safety lock active by default, even when launched directly from Xcode without extra arguments.

## Confirmed Signing Source Of Truth

Do not share Apple ID passwords, 2FA codes, app-specific passwords, or Keychain secrets in this repo or chat.

1. Keep Team `D8BE8WBTV5` as the release source of truth.
2. Keep Bundle ID `app.truekeep.ios`; Apple Developer Services confirmed it is registered to this Team.
3. Keep automatic signing enabled for the TrueKeep target.
4. If the account session expires, re-authenticate the same Team in `Xcode > Settings > Accounts` and rerun the checks below.

## Safe Device Verification Command

Use the scripted dry-run first:

```bash
cd /Users/edge/side/photo-cleaner
python3 iOS/TrueKeep/Scripts/device_smoke.py \
  --team-id D8BE8WBTV5 \
  --device-id <DEVICE_ID>
```

The dry-run prints the exact `devicectl` and `xcodebuild` commands without building, installing, or launching. When the commands look correct and the iPhone is available, run:

```bash
cd /Users/edge/side/photo-cleaner
python3 iOS/TrueKeep/Scripts/device_smoke.py \
  --team-id D8BE8WBTV5 \
  --device-id <DEVICE_ID> \
  --execute
```

The script builds with automatic signing, installs the signed app, and launches it with deletion disabled. Debug builds are deletion-safe by default, and the script also passes both `TRUEKEEP_DISABLE_PHOTO_DELETION=1` and `-TrueKeepDisablePhotoDeletion`.

If you need to run the underlying signed device build manually, use:

```bash
cd /Users/edge/side/photo-cleaner
xcodebuild build \
  -project iOS/TrueKeep/TrueKeep.xcodeproj \
  -scheme TrueKeep \
  -configuration Debug \
  -destination 'platform=iOS,id=<DEVICE_ID>' \
  -derivedDataPath /tmp/TrueKeepDeviceSmokeBuild \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=D8BE8WBTV5 \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY='Apple Development'
```

Install and launch only after the build produces a signed `.app`.

For a generic iPhoneOS signing preflight before a device is available, use:

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

For manual smoke tests, Debug builds are deletion-safe by default. Keep the explicit deletion-disable launch argument as an extra guard:

```text
-TrueKeepDisablePhotoDeletion
```

The same protection can be enabled with:

```bash
TRUEKEEP_DISABLE_PHOTO_DELETION=1
```

With the safety lock active, deletion attempts return an in-app failure message and do not call Photos deletion APIs.

Only run a destructive test after a separate test plan is approved. The Debug-only opt-in controls are intentionally verbose:

```text
-TrueKeepEnableDestructivePhotoDeletion
```

or:

```bash
TRUEKEEP_ENABLE_DESTRUCTIVE_PHOTO_DELETION=1
```

Do not use either opt-in during normal physical-device smoke testing.

## Smoke Test Pass Criteria

- App installs on the physical iPhone.
- App launches without crashing.
- Permission rationale screen appears before the iOS Photos permission prompt.
- Full Photos Access and Limited Photos Access both reach the scan screen.
- Cancelling scan shows the interrupted state and does not show stale results.
- Completed scan can show metadata-backed screenshots and large videos when present.
- Review Bin and delete confirmation can be opened with the deletion safety lock active.
- No photos or videos are removed during debug verification.

## Release Blockers

- Complete the full physical-device smoke criteria above without changing deletion safety behavior.
- Upload a release candidate to TestFlight and complete a real-device TestFlight smoke pass.
- Keep the Xcode account session valid for future provisioning/profile renewal.
