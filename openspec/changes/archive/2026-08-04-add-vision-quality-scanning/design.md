# 设计：Feature Print 相似分组与质量评分 seam

## Context

最初的相似照片分组只使用缩略图感知 hash，容易受轻微曝光、裁切和连拍构图变化影响。本变更在现有有界本地扫描器中引入 Vision feature print，同时建立可插拔质量评分协议和启发式兜底。

随后归档的 `adopt-vision-aesthetics-ios18` 已将最低系统版本提升到 iOS 18，并把默认质量评分迁移到系统 Vision 美学评分及人脸拍摄质量。当前归档必须保留这个后续决策，不能用旧 Core ML-ready 增量覆盖正式规格。

## Goals / Non-Goals

**Goals:**

- 在 feature print 可比较时用其距离决定相似分组。
- 只有 feature print 缺失或不可比较时才回退 pHash。
- 保持视觉分析本地、有扫描上限、可取消且单张失败不影响其他资源。
- 保留可插拔质量评分 seam 和确定性启发式兜底。
- 归档时协调后续 iOS 18 Vision 规格，不回退正式行为。

**Non-Goals:**

- 不分发自定义 Core ML 模型，也不把它恢复为当前默认路径。
- 不新增网络访问、云端推理、自动删除或破坏性测试。
- 不在本次归档中重新调整 feature print 阈值或质量阈值。

## Decisions

### 1. Feature print 可比较时拥有相似判定优先级

两张照片都能产生可比较 feature print 时，只使用 feature-print distance。距离超阈值后不得再用 pHash 把它们分组，否则会抵消更强视觉信号的否定结果。只有 feature print 缺失或不可比较时才使用 pHash。

### 2. 视觉信号只在有界本地输入上生成

沿用近期照片数量上限、创建时间窗口、取消检查和 `isNetworkAccessAllowed = false`。本地图像不可用或单张 Vision 请求失败时跳过该资源，继续处理其他资源。

### 3. 质量评分使用协议 seam，当前默认由后续规格决定

`PhotoQualityScoring` 隔离启发式、custom Core ML 和系统 Vision 实现。原变更提供 Core ML-ready scorer，但没有模型资产；后续 iOS 18 变更选择 `VisionPhotoQualityScorer` 作为系统扫描器默认实现。归档增量因此不再声明 bundled Core ML 必须成为默认行为。

### 4. 低置信度结果保持保守

无论质量信号来自启发式、custom Core ML 或系统 Vision，模糊与疑似误拍都只进入复核候选，默认不得选中删除。相似组推荐保留也不等价于自动删除其他成员。

### 5. 归档使用完整最终 Requirement

`MODIFIED Requirements` 从当前正式规格复制全部仍有效场景，再加入 feature print 行为。这样归档不会删除后续美学评分、人脸质量和推荐保留契约。

## Risks / Trade-offs

- [风险] Feature print 计算增加 CPU/Neural Engine 成本 → 保持扫描数量上限、时间窗口和取消检查。
- [风险] 阈值对真实家庭图库存在误报或漏报 → 保持复核候选和默认不选中，并把阈值校准留给独立变更。
- [风险] 旧 change 与后续正式规格发生顺序冲突 → 归档前复制并协调完整 Requirement，使用差异检查确认没有场景丢失。
- [取舍] 保留未启用的 Core ML scorer seam 会增加少量维护面 → 它为后续经过训练和独立提案的模型提供注入点，但不影响当前默认路径。

## Migration Plan

- 无用户数据迁移；代码已在现有扫描器中生效。
- 归档只同步当前最终规格。若归档差异删除 iOS 18 美学评分、人脸质量或保守安全场景，必须停止并修正规格增量。
- 回滚 feature print 时可以恢复 pHash-only 判定，但必须通过独立变更更新正式规格和聚焦测试。

## Open Questions

- Feature-print distance `0.16` 是否需要按真实图库标注结果调整，留给后续校准变更。
