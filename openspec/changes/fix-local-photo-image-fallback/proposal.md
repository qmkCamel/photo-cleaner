## Why

当前扫描器只使用同步 `fastFormat` 向 Photos 请求视觉分析图片；当本地照片没有匹配的快速派生资源时，Photos 会返回 `PHPhotosErrorMissingResource (3303)`，即使完整本地图片仍然可用，扫描也会把全部视觉输入静默跳过，导致明显的相似照片被错误报告为“0 项待复核”。

## What Changes

- 保留快速本地图片请求作为首选路径；快速资源不可用时，使用仍然禁止网络访问的高质量本地请求重试同一照片。
- 只有快速和高质量本地请求都无法提供图片时才跳过该照片，且单张失败不影响其他照片和视频扫描。
- 为请求顺序、成功短路和失败回退补充可重复的单元测试，并使用模拟器真实 Photos 资产和 AppClaw 验证相似候选恢复。
- 自动化保留“扫描完成”和“相似照片结果”命名截图；真实照片删除继续保持禁用。
- 非目标：不改变相似度阈值、扫描范围、权限流程、网络/iCloud 回源策略、默认删除选择或二次删除确认。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `photo-recognition`：视觉识别在快速派生资源缺失但完整本地图片可用时，必须回退到高质量本地图片请求，避免错误跳过可识别照片。

## Impact

- 代码：`iOS/TrueKeep/TrueKeep/Services/PhotoLibraryScanner.swift`。
- 测试：`TrueKeepTests` 中的图片请求回退测试，以及模拟器真实相册 AppClaw smoke。
- 系统边界：继续使用 Photos/PhotoKit 和 Vision；不增加依赖、不请求网络、不改变照片库内容。
