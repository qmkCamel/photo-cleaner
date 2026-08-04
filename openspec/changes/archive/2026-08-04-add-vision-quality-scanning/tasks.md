# 任务

## 1. 规格与设计

- [x] 1.1 创建 OpenSpec 基线、proposal、design 和规格增量。
- [x] 1.2 明确 feature print 优先级、pHash 兜底和本地有界处理边界。
- [x] 1.3 对照后续 iOS 18 Vision 归档协调完整最终 Requirement，避免旧增量覆盖新规格。

## 2. 视觉扫描实现

- [x] 2.1 为有边界的本地视觉扫描输入生成 Vision feature print。
- [x] 2.2 相似照片分组优先使用 feature-print distance，并保留不可比较时的 pHash 兜底。
- [x] 2.3 新增 Core ML-ready 的照片质量评分器和启发式兜底 seam。
- [x] 2.4 将模糊和误拍分类接入统一质量评估，同时保持复核候选和保守默认值。

## 3. 文档与测试

- [x] 3.1 更新识别策略文档。
- [x] 3.2 增加 feature print 优先、远距离不回退、缺失兜底和质量评分行为测试。
- [x] 3.3 记录测试环境限制和可复现命令。

## 4. 验证与交付

- [x] 4.1 在可访问 CoreSimulator 的 Xcode 环境运行聚焦与完整测试。
- [x] 4.2 运行 OpenSpec 严格校验并确认归档差异保留后续正式规格。

## 验证记录

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/truekeep-module-cache xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/TrueKeepDerivedData-VisionQuality-Privileged`
  - 结果：通过。执行 54 个单元测试和 20 个 UI 测试，0 failure。
- 说明：不带 Xcode developer path / 模拟器权限的沙箱命令无法稳定访问 CoreSimulator；完整验证使用同一命令在已授权的 Xcode 环境下执行。
- `python3 iOS/TrueKeep/Scripts/release_preflight.py --run-xcode`（2026-08-04 归档收口）
  - 结果：通过；15 个通过/信息项、0 failure，完整 `xcodebuild test` 和无签名 Release Archive 均成功。
- 归档结果：只同步 feature-print 与本地有界处理的 2 条完整 Requirement；后续 iOS 18 美学评分、人脸质量和保守安全场景均保留。
