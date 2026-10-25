# TrueKeep Privacy Policy

Effective date: 2026-10-25

Published policy: https://qmkcamel.github.io/photo-cleaner/privacy.html

The bilingual website source is `site-template/privacy.html`. This document summarizes the app policy; the published page also covers website hosting and support correspondence.

TrueKeep / 留真 is designed to help you review photo-library cleanup candidates on your iPhone. The current app is local-first and does not collect personal data.

## Summary

- No account is required.
- Photos and videos are not uploaded.
- Photo analysis runs on your device.
- No analytics, advertising, crash-reporting, or tracking SDK is included in the current build.
- No personal data is sold or shared for advertising.
- Deletion only happens after you review and select items, then explicitly confirm deletion from Review Bin or a review group.

## Photos Access

TrueKeep asks for Photos access so it can scan your local photo library for review candidates such as screenshots, large videos, similar photos, blurry photos, and accidental shots.

The app reads photo and video metadata and requests thumbnails through Apple's Photos framework. These thumbnails are used only for local review inside the app. The current build does not copy your original photos or videos into the app container.

If you choose Limited Photos Access, TrueKeep can only scan the items you allow. You can change Photos permissions at any time in iOS Settings.

## Local Processing

TrueKeep identifies screenshots and large videos from Photos metadata. Similar-photo, overall-quality, blurry-photo, and accidental-shot candidates use bounded on-device Vision analysis together with local explainable thumbnail signals. These results are review candidates, not automatic deletion decisions. Images marked as utility content are not treated as cleanup candidates from that label alone.

The current visual scan does not allow network-backed iCloud thumbnail downloads.

## Local Settings and Confirmed Keeps

The app stores onboarding completion and confirmed-keep Photos resource identifiers in local settings. These records preserve user choices across launches and scans without copying photos or videos. Confirmed-keep records can be removed or reset in Settings. Deleting the app and its data removes local settings; iOS offloading, backup, and restoration may preserve or restore them.

## Data Collection

The current build does not collect data from the app.

TrueKeep does not currently include:

- User accounts.
- Server upload.
- Analytics SDKs.
- Advertising SDKs.
- Crash-reporting SDKs.
- Cross-app tracking.
- Third-party data brokers.

If future versions add subscriptions, support forms, crash reporting, analytics, or cloud features, this policy and the App Store privacy answers must be updated before release.

## Deletion Safety

TrueKeep does not automatically delete photos or videos.

To delete items, you must:

1. Review a group of candidates.
2. Select items for deletion.
3. Use Review Bin or the direct-delete action in a review group.
4. Confirm deletion in a second confirmation sheet.

If iCloud Photos is enabled, deleting an item from Photos may also remove it from iCloud and your other devices. Deleted items may be recoverable from the Photos app's Recently Deleted album for a limited time unless you remove them there.

## Contact

Support contact: [qmkhaust@gmail.com](mailto:qmkhaust@gmail.com).

The support website uses GitHub Pages without added analytics or tracking scripts. GitHub may process service access data under its privacy statement. If a user emails support, their email address and voluntarily supplied content are used to handle the request. The published policy explains retention and privacy-request contact details.
