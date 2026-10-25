# TrueKeep Support

TrueKeep / 留真 helps you review photo-library cleanup candidates locally on your iPhone.

## Contact

Support contact: [qmkhaust@gmail.com](mailto:qmkhaust@gmail.com).

Published support page: https://qmkcamel.github.io/photo-cleaner/support.html

Include the iPhone model, iOS version, app version, and a description of the issue. Original photos are not required; redact private information from optional screenshots.

## Common Questions

### Does TrueKeep upload my photos?

No. The current build does not upload photos or videos. Scanning runs on your iPhone.

### Does TrueKeep delete photos automatically?

No. You review and select candidates, then initiate deletion from Review Bin or directly from a review group. Both paths require a second explicit confirmation.

### What happens if I use iCloud Photos?

If iCloud Photos is enabled, deleting an item from Photos may also remove it from iCloud and your other devices. The app shows this warning before deletion.

### Can I use Limited Photos Access?

Yes. If you grant Limited Photos Access, TrueKeep can only scan the photos and videos you selected. Results may be incomplete until you allow more items.

### Why does the app show review candidates instead of exact duplicates only?

The current MVP is conservative. Similar, blurry, and accidental-shot items are local review candidates, not automatic decisions. You stay in control of what is kept or deleted.

## Confirmed Keeps

Mark a photo as a confirmed keep through its more-actions menu. The app remembers only its local Photos resource identifier. Manage or reset records in Settings. The current version does not select a recommended keep item for you.

## Website Source

`site-template/support.html` contains the complete Chinese and English support page, including interrupted scans, failed deletion, and Recently Deleted recovery guidance. Internal review configuration belongs in `iOS/TrueKeep/APP_STORE_REVIEW_NOTES.md`.
