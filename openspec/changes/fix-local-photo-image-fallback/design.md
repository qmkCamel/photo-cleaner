## Context

当前调用链为 `SystemPhotoLibraryScanner.scan` → `fetchAssetSnapshots` → `fetchVisualClassifications` → `visualMetrics` → `PHImageManager.requestImage`。`SystemPhotoLibraryScanner` 是本轮扫描和视觉输入构建的所有者；`PhotoVisualClassifier` 只消费成功构建的输入，不知道 Photos 图片请求是否失败。

现有 `visualMetrics` 固定配置同步 `fastFormat`、快速 resize、禁止网络访问。iOS 26.3 模拟器真实相册中，Photos 可以 fetch 到照片元数据和完整本地资源，但没有匹配的快速派生资源；`fastFormat` 因此对每张照片返回 `PHPhotosErrorMissingResource (3303)`，当前代码将其等同于“本地图像不可用”并静默跳过。临时切换为同步 `highQualityFormat` 后，同一批资源能够生成视觉输入和相似候选。

扫描仍是超过 300ms 的用户动作，交互继续以全局 `user-action-contract` 为规范来源，复用现有进度、取消、中断和重新扫描路径；本变更不复制或修改通用交互规则。

## Goals / Non-Goals

**Goals:**

- 快速派生资源缺失时，可靠读取仍在本机的完整图片用于视觉分析。
- 快速路径成功时不增加第二次 Photos 请求。
- 所有请求继续禁止网络访问，保持 iCloud 回源边界。
- 单张图片两次请求都失败时继续扫描其他资源。
- 用纯策略测试锁定请求顺序、成功短路和回退行为，并用真实模拟器 Photos 资产验证端到端结果。

**Non-Goals:**

- 不修改相似度、质量、时间窗口或推荐保留算法。
- 不增加网络下载、iCloud 回源或后台预下载。
- 不改变视觉分类上限、扫描范围、权限说明、进度页面或删除流程。
- 不将低置信度候选自动加入删除选择。

## Decisions

### 1. 使用“快速本地请求 → 高质量本地请求”的有序回退

每张非截图照片先使用 `.fastFormat` 请求 224×224 图片；只有返回能够提供 `CGImage` 的可分析图片时才立即停止。如果结果为空、被取消、包含错误，或 `UIImage` 没有可供视觉分析的 `CGImage`，则使用 `.highQualityFormat` 对同一照片重试一次。两次请求都保持 `.isNetworkAccessAllowed = false`、`.isSynchronous = true` 和快速 resize。

选择高质量请求作为回退，是因为它能够从本地完整资源生成目标尺寸图片，而不依赖预先存在的快速派生资源。替代方案是直接永久改为 `.highQualityFormat`，实现更简单但会放弃已有快速资源的性能收益，因此不采用。另一个方案是允许网络访问下载 iCloud 资源，会破坏现有本地处理边界，因此不采用。

### 2. 把回退顺序提取为可测试的内部策略

增加内部策略，公开固定的 delivery mode 顺序，并通过接收请求闭包返回首个可用的分析输入。PhotoKit 适配层仍负责为每个 mode 构造请求选项、调用 `PHImageManager` 并提取 `CGImage`；策略层不持有 `PHAsset`，单元测试可以用假闭包验证调用次数和顺序，无需伪造系统 Photos 对象。

替代方案是在测试中直接构造 `PHAsset` 和模拟 `PHImageManager`。`PHAsset` 由 Photos 管理，难以稳定构造，且会让单元测试依赖模拟器照片库状态，因此不采用。

### 3. 保持单资源失败隔离和现有取消边界

两种本地请求都失败时，`visualMetrics` 返回 `nil`，上层继续处理下一张照片；不将单资源失败提升为整轮扫描失败。每张照片开始前继续执行现有 `Task.checkCancellation()`，且分类上限不变。

同步高质量回退在单次请求期间不可取消，这是现有同步请求模型的延续。因为只在快速路径失败时启用、禁止网络且受视觉分类上限约束，本次不扩大为异步扫描架构改造。

## Risks / Trade-offs

- [大量照片没有快速派生资源时扫描耗时增加] → 仅失败时回退，目标尺寸保持 224×224，禁止网络，并继续受 300/80 张视觉分类上限约束。
- [iCloud-only 图片两种请求都失败] → 保持当前本地边界，跳过该资源并继续扫描；不把无法本地读取误报为扫描失败。
- [Photos 返回空图片或没有 `CGImage` 的 `UIImage`] → 只有可分析的 `CGImage` 才视为请求成功，其他结果执行高质量回退。
- [未来修改 delivery mode 顺序造成回归] → 单元测试断言固定顺序、快速成功短路和两次失败结果。
- [回退恢复更多低置信度候选] → 仍使用现有阈值、推荐保留和默认选择规则，所有候选继续人工复核。

## Migration Plan

1. 增加回退策略和聚焦单元测试。
2. 将 `visualMetrics` 接入两阶段本地请求，不改变上层扫描接口和状态模型。
3. 运行单元测试、完整 Xcode 回归和 OpenSpec 校验。
4. 在禁用真实删除的模拟器上扫描真实 Photos 资产，使用 AppClaw 验证相似任务并保留命名截图。

回滚只需恢复单一 `.fastFormat` 请求并移除策略测试，不涉及数据、权限或照片库迁移。

## Open Questions

无。网络访问继续保持关闭，高质量请求只作为本地快速资源不可用时的第二路径。
