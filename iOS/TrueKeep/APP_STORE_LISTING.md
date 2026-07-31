# TrueKeep App Store Listing Draft

Updated: 2026-06-11

This is the working App Store Connect listing draft for the current MVP build. It is not a final submission package until App Store Connect name availability, legal/trademark clearance, support URLs, and accepted-size screenshot exports are confirmed.

## Source Rules

- Apple product-page metadata: the subtitle is a short summary and can be up to 30 characters.
  Source: https://developer.apple.com/app-store/product-page/
- Apple search metadata: keywords are limited to 100 characters, should be comma-separated, and should not repeat words already in the app name, subtitle, or category.
  Source: https://developer.apple.com/app-store/search/
- Apple screenshot slots and sizes: App Store Connect supports 1 to 10 screenshots per localization and requires accepted device-family screenshot dimensions.
  Source: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- Apple app information: app name, subtitle, keywords, and company name are used for search.
  Source: https://developer.apple.com/help/app-store-connect/create-an-app-record/view-and-edit-app-information/

## en-US Metadata Draft

Copy-paste files:

`AppStoreConnect/metadata/en-US/`

- App name: `TrueKeep: AI Photo Cleaner`
- Name length: 26 characters.
- Subtitle: `Private Camera Roll Cleanup`
- Subtitle length: 27 characters.
- Keywords: `duplicate,similar,blurry,screenshots,storage,album,local,family,kids,videos`
- Keywords length: 75 characters.
- Promotional text:
  `Find review-worthy cleanup candidates from your photo library without uploading photos. TrueKeep keeps every decision local, visible, and reversible until you confirm deletion.`
- Description:
  `TrueKeep helps you review screenshots, large videos, similar photos, blurry shots, and accidental photos from your local photo library. The app is built around trust: it explains Photos access before asking, runs analysis on the iPhone, keeps candidates in review groups, and requires a Review Bin plus a second confirmation before deletion. No account, upload, ads, analytics, or cross-app tracking is included in the current build.`
- Support URL: pending.
- Marketing URL: pending.
- Privacy Policy URL: pending; host `docs/app-store/privacy-policy.md`.

## zh-Hans Metadata Draft

Copy-paste files:

`AppStoreConnect/metadata/zh-Hans/`

- App name: `留真：AI 相册清理`
- Name length: 10 characters.
- Subtitle: `本机复核重复照片`
- Subtitle length: 8 characters.
- Keywords: `截图,大视频,模糊,重复,相似,隐私,本地,家庭,孩子,照片整理`
- Keywords length: 32 characters.
- Promotional text:
  `在 iPhone 本机找出值得复核的清理候选，不上传照片或视频，不自动删除。`
- Description:
  `留真用于本机复核相册中的截图、大视频、相似照片、模糊照片和误拍照片。应用会先说明为什么需要照片权限，再在 iPhone 上完成分析。所有候选都需要你逐组确认，加入复核箱后还要二次确认才会请求系统删除。当前版本没有账号、上传、广告、分析 SDK 或跨 App 跟踪。`
- Support URL: pending.
- Marketing URL: pending.
- Privacy Policy URL: pending; host `docs/app-store/privacy-policy.md`.

## Support And Privacy Pages

- Privacy policy content is drafted in `../../docs/app-store/privacy-policy.md`.
- Support page content is drafted in `../../docs/app-store/support.md`.
- Ready-to-host static template files are drafted in `../../docs/app-store/site-template/`.
- Age-rating, export-compliance, content-rights, and category-answer drafts are in `../../docs/app-store/compliance-answers.md`.
- Copy-paste App Store Connect metadata is saved in `AppStoreConnect/`.
- Apple requires a privacy policy URL for iOS apps and requires support/privacy links to be functional for review. Final URLs still need to be hosted and checked before submission.
- The static template is not final until the support-contact placeholder is replaced with a monitored email address or support form URL.
- Official references:
  - https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
  - https://developer.apple.com/distribute/app-review/
  - https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/
  - https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/

## Screenshot Set

Current candidate folder:

`MarketingScreenshots/2026-06-13-1811-photo-video-copy/`

Current simulator PNG size:

- Individual screenshots: 1206 x 2622 px.
- Contact sheet: 1050 x 1350 px.

Accepted-size export:

- Folder: `MarketingScreenshots/2026-06-13-1811-photo-video-copy/app-store-6.9/`
- Individual screenshots: 1320 x 2868 px.
- Device family: 6.9-inch iPhone portrait screenshot family.
- Visual check sheet: `MarketingScreenshots/2026-06-13-1811-photo-video-copy/app-store-6.9-contact-sheet.png`

Marketing candidate export:

- Folder: `MarketingScreenshots/2026-06-13-1811-photo-video-copy/app-store-6.9-marketing/`
- Individual screenshots: 1320 x 2868 px.
- Contact sheet: `MarketingScreenshots/2026-06-13-1811-photo-video-copy/app-store-6.9-marketing/contact-sheet.png`
- Generator: `Scripts/build_marketing_screenshots.py`
- Purpose: App Store / launch-marketing review candidates with Chinese value-proposition headers and a framed app screenshot.

Current visual QA notes:

- The current set was regenerated from `/tmp/TrueKeepMarketingScreenshots-1811.xcresult` after localizing the in-app Review Bin tab and updating trust copy to cover photos and videos.
- The Home review-queue screenshot now shows all five sample task cards without the prior bottom blank-area cut-off.
- The previous `MarketingScreenshots/2026-06-11-0955-localized-review-bin/` set is preserved as historical evidence and superseded for current review.

These images are usable as internal review and App Store Connect upload candidates. They still need human approval before submission because metadata, localization, final screenshot copy, and legal checks can change after App Store Connect name availability is confirmed.

Recommended order for App Store review:

1. `app-store-6.9-marketing/01-local-first.png` - local-first trust promise.
2. `app-store-6.9-marketing/02-permission-before-access.png` - Photos permission rationale before the system prompt.
3. `app-store-6.9-marketing/03-review-queue.png` - supported cleanup categories and review queue.
4. `app-store-6.9-marketing/04-review-before-bin.png` - group-level review before deletion.
5. `app-store-6.9-marketing/05-review-bin.png` - deletion staging area.
6. `app-store-6.9-marketing/06-delete-safety.png` - iCloud and Recently Deleted warning.

Raw fallback order if App Store Connect rejects the composed marketing screenshots or the final localization copy changes:

1. `app-store-6.9/01-welcome.png`
2. `app-store-6.9/02-permission-rationale.png`
3. `app-store-6.9/04-home-review-queue.png`
4. `app-store-6.9/05-screenshot-review.png`
5. `app-store-6.9/06-review-bin.png`
6. `app-store-6.9/07-delete-safety-confirmation.png`
7. `app-store-6.9/03-settings-trust.png`
8. `app-store-6.9/08-default-empty-no-fixtures.png`

Disclosure for App Review notes:

- Screenshot candidates are captured from UI automation.
- Sample cleanup groups appear only when launched with `-TrueKeepUseSampleCleanupData`.
- The default launch path uses real Photos metadata, on-device Vision analysis, and local explainable thumbnail signals instead of sample cleanup groups.
- Any final public screenshots that show sample items should be treated as representative demo content, not as a scan result from a real user library.

## Naming And Availability Notes

- A public web search did not find an obvious exact App Store result for `TrueKeep` or `TrueKeep: AI Photo Cleaner`; this is not authoritative. Final availability must be checked in App Store Connect.
- A similar competitor name exists: `PicKeep: AI Photo Cleaner`. This increases the risk of relying too heavily on the generic `AI Photo Cleaner` phrase as the brand signal.
- `truekeep.com` appears registered through Cloudflare and should be treated as unavailable unless the user owns it.
- `truekeep.app` was inconclusive from the local WHOIS command and still needs a registrar check.
- USPTO search was not completed as a legal clearance. The official USPTO search system should be used, and legal review may be needed before submission.

## Required Approvals Before Submission

- Confirm final app name and localized names.
- Confirm App Store Connect name availability.
- Confirm Apple Developer Team and Bundle ID.
- Confirm Support URL, Marketing URL, and Privacy Policy URL.
- Confirm trademark/legal clearance for `TrueKeep` and `留真`.
- Approve final App Store screenshots for the selected device family.
