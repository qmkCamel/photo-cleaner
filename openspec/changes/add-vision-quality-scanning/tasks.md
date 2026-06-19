# 任务

- [x] 创建 OpenSpec 基线和当前变更提案。
- [x] 为有边界的本地视觉扫描输入生成 Vision feature print。
- [x] 相似照片分组优先使用 feature-print distance，并保留 pHash 兜底。
- [x] 新增 Core ML-ready 的照片质量评分器和启发式兜底。
- [x] 将模糊和误拍分类改为基于质量评估。
- [x] 更新识别策略文档。
- [x] 增加 feature print 和质量评分行为的聚焦单元测试。
- [x] 在本地 Xcode 环境允许的范围内运行聚焦单元测试和更广泛构建/测试。
- [x] 记录测试环境限制。

## 验证记录

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/truekeep-module-cache xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/TrueKeepDerivedData-VisionQuality-Privileged`
  - 结果：通过。执行 54 个单元测试和 20 个 UI 测试，0 failure。
- 说明：不带 Xcode developer path / 模拟器权限的沙箱命令无法稳定访问 CoreSimulator；完整验证使用同一命令在已授权的 Xcode 环境下执行。
