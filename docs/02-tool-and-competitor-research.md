# 02 工具与竞品调研

## iPhone 免费方案

### Apple Photos

适合先做第一轮安全清理：

- `Photos > Collections > Utilities > Duplicates > Merge`：合并重复照片和视频。
- `Photos > Collections > Media Types > Screenshots`：集中查看截图。
- 删除后进入 `Recently Deleted`，通常有 30 天恢复窗口。

注意事项：

- 开启 iCloud Photos 后，一个设备删除会同步到其他设备和 iCloud。
- 系统能力适合处理“完全重复”和“截图分类”，但对“孩子乱拍”“模糊”“相似连拍中的最佳选择”帮助有限。

来源：

- Apple Photos duplicate merge: https://support.apple.com/guide/iphone/merge-duplicate-photos-and-videos-iph1978d9c23/ios
- Apple Photos media types: https://support.apple.com/guide/iphone/locate-photos-and-videos-by-media-type-iph8530ff6a2/ios
- Apple delete/recover photos: https://support.apple.com/en-us/104967

## iPhone 第三方工具

### CleanMyPhone

定位：AI 手机照片/视频清理。

讨论中识别到的能力：

- 扫描重复、相似、模糊照片。
- 找旧截图、大视频等占空间内容。
- 官方强调本地处理、不自动删除。

适合：

- 照片超过 1 万张。
- 孩子乱拍、相似连拍很多。
- 用户愿意接受订阅或试用。

风险：

- Cleaner 品类普遍订阅争议较多。
- 需要验证最新价格、隐私标签和用户评论。

来源：

- https://apps.apple.com/us/app/cleanmy-phone-cleanup-storage/id1277110040
- https://macpaw.com/support/cleanmyphone/knowledgebase/safety

### PhotoSweeper Mobile

定位：更偏专业、可控的重复/相似照片清理。

讨论中识别到的能力：

- 精确重复照片。
- 相似照片。
- 截图、技术照片、大文件。
- 有一次性买断选项。

注意：

- 讨论时看到它要求 iOS 26，需要正式立项前重新确认。

来源：

- https://apps.apple.com/us/app/photosweeper-mobile/id6529521230

### Slidebox / Swipewipe

定位：手势式人工整理相册。

适合：

- 用户自己判断“这张有没有意义”。
- 按月、按批次快速保留或删除。
- 不完全依赖 AI 判断。

不足：

- 照片量很大时仍然会疲劳。
- 对“相似组自动挑最佳”和“孩子乱拍识别”帮助有限。

来源：

- Slidebox: https://apps.apple.com/us/app/slidebox-photo-cleaner-app/id984305203
- Swipewipe: https://apps.apple.com/us/app/photo-cleaner-swipewipe/id1583884012

## Android 免费方案

### Files by Google

能力：

- 清理重复文件。
- 清理旧截图。
- 查看占空间文件。

来源：

- Duplicate files: https://support.google.com/files/answer/9764075
- Old screenshots: https://support.google.com/files/answer/9808842

### Google Photos

能力：

- 管理存储。
- 查找模糊照片、截图、大视频。
- `Free up space on this device` 可以删除已备份的本地副本。

注意：

- 适合释放本地空间，但用户仍要理解“本地副本”和“云端照片”的关系。

来源：

- Manage storage: https://support.google.com/photos/answer/10100180
- Free up space: https://support.google.com/photos/answer/6128843

## Samsung 自带方案

### Samsung My Files

能力：

- `My Files > Analyze Storage > Duplicate files` 找重复文件。

风险：

- 删除重复文件时要确认不要删掉原件或仍被其他 App 引用的重要副本。

来源：

- https://www.samsung.com/latin_en/support/mobile-devices/how-to-find-and-remove-duplicate-files-on-your-galaxy-device/

## 竞品信号

讨论中记录的 App Store 竞品信号，截至 2026-06-10：

- Cleanup: 约 664K ratings / 4.7。
- Swipewipe: 约 79K ratings / 4.7。
- CleanMyPhone: 约 23K ratings / 4.6。
- Slidebox: 约 16K ratings / 4.8。

这些信号说明需求真实存在，但也说明泛照片清理赛道已经很卷。

来源：

- Cleanup: https://apps.apple.com/us/app/cleanup-phone-storage-cleaner/id1510944943
- Swipewipe: https://apps.apple.com/us/app/photo-cleaner-swipewipe/id1583884012
- CleanMyPhone: https://apps.apple.com/us/app/cleanmy-phone-cleanup-storage/id1277110040
- Slidebox: https://apps.apple.com/us/app/slidebox-photo-cleaner-app/id984305203

## 建议清理流程

### iPhone 用户

1. 先确认 iCloud Photos、电脑备份或其他备份方式。
2. 使用 Apple Photos 合并重复项目。
3. 使用 Apple Photos 的 Screenshots 相册批量清截图。
4. 使用第三方工具扫描相似、模糊、大视频和低质量照片。
5. 删除前逐组复核。
6. 不急着清空 Recently Deleted，保留 30 天缓冲。

### Android 用户

1. 确认 Google Photos 备份状态。
2. 使用 Files by Google 清理重复文件和旧截图。
3. 使用 Google Photos 管理模糊照片、截图和大视频。
4. Samsung 用户额外检查 My Files 的重复文件。

## 不建议宣传的方向

不要把产品包装成“万能手机清理大师”：

- iOS 第三方 App 不能像电脑清理器一样随意清系统目录。
- “一键加速”“清系统缓存”“杀毒变快”容易造成用户不信任，也可能带来审核风险。
- 本项目应该聚焦照片和视频整理，而不是泛设备优化。

