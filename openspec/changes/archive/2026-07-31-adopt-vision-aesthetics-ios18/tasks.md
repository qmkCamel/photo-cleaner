# 任务

- [x] 将工程与文档最低部署版本提升到 iOS 18。
- [x] 新增 Vision 图片美学评分和人脸拍摄质量分析。
- [x] 将模型总体质量、保守误拍风险和启发式解释信号融合进现有扫描器。
- [x] 保持 utility 图片不因模型标记而进入误拍候选。
- [x] 保持 Vision 失败时的启发式兜底、扫描上限和取消行为。
- [x] 更新当前识别策略和工程说明。
- [x] 增加模型分数归一化、utility 安全边界、失败兜底和推荐保留排序测试。
- [x] 运行 OpenSpec、Swift 解析、聚焦测试、完整 Xcode 测试和发布预检。

## 验证记录

- `openspec validate adopt-vision-aesthetics-ios18 --strict`
  - 结果：通过。
- `swiftc -parse $(find iOS/TrueKeep/TrueKeep iOS/TrueKeep/TrueKeepTests iOS/TrueKeep/TrueKeepUITests -name '*.swift' -print)`
  - 结果：通过。
- `xcodebuild test ... -only-testing:TrueKeepTests/PhotoScanResultBuilderTests`
  - 结果：通过，执行 20 个聚焦单元测试，0 failure。
- `python3 iOS/TrueKeep/Scripts/release_preflight.py --run-xcode`
  - 结果：通过；完整 Xcode 测试成功，无签名 Release Archive 成功，发布预检 0 failure。
