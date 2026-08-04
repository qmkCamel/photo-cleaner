# 接入 Vision Feature Print 和质量评分

## Why

当前视觉分类器是保守实现，依赖缩略图 pHash、亮度、饱和度和边缘清晰度启发式。Vision feature print 能更稳地处理轻微曝光、构图和连拍差异。Core ML 质量评分接口为后续模糊、低质量识别模型提供清晰接入点，同时保留确定性的本地规则兜底。

## What Changes

- 为有边界的本地视觉扫描输入生成 Vision image feature print。
- 相似照片分组优先使用 feature-print distance；feature print 不可用时回退 pHash。
- 新增可加载 `TrueKeepPhotoQuality.mlmodelc` 的 Core ML-ready 质量评分器。
- 没有 bundled 模型或预测失败时，保留启发式质量评分。
- 所有视觉结果仍只作为复核候选。
- 增加 feature print 分组、兜底行为、质量评分和保守默认值的聚焦单元测试。
- 后续 `adopt-vision-aesthetics-ios18` 已把默认质量评分迁移到 iOS 18 Vision 美学评分；本次归档只把仍然生效的 feature-print 和本地有界处理契约合入正式规格，不覆盖后续规则。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `photo-recognition`: 明确 feature print 优先、pHash 兜底和本地图像不可用时继续扫描的行为。

## Impact

- 扫描器：`PhotoLibraryScanner.swift` 的 feature print 生成、相似分组与可插拔质量评分 seam。
- 测试：feature print 优先级、不可比较兜底、远距离不回退和质量评分保守行为。
- 正式规格：只协调当前仍有效的 feature-print 与本地有界处理需求；质量默认路径继续由后续 iOS 18 Vision 归档负责。

## Non-Goals

- 不引入云端 AI 或 Apple Intelligence 依赖。
- 不做自动删除决策。
- 不新增网络访问。
- 不新增破坏性真机测试路径。
- 除非后续单独提供训练好的模型资产，否则本变更不包含 `.mlmodel` 文件。

## Risks

- Vision feature print 阈值需要后续用真实照片库校准。
- Core ML 评分只保留为可插拔实现 seam；当前默认评分路径是后续已接受的 iOS 18 Vision 美学评分。
- feature print 生成会增加本地 CPU/Neural Engine 工作量，必须保留现有扫描上限和取消机制。
