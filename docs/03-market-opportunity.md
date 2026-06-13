# 03 市场判断

## 一句话结论

市场可以做，但不能做成普通“照片清理 App”。更值得做的是：

> 隐私优先的本地 AI 家庭相册减负工具。

隐私是入场券，真正的差异化是家庭/孩子场景、保守删除建议、低误删风险和可解释清理。

## Apple 2026 WWDC 带来的利好

截至 2026-06-10 的讨论快照，Apple 在 2026 WWDC 继续强化本地 AI 和开发者能力：

- Foundation Models framework 开放给开发者使用。
- 支持更强的本地模型能力。
- 支持图像输入相关能力。
- App Intents / Siri AI 集成增强。
- Core AI 可用于运行自定义本地模型。
- Apple 继续强调 on-device processing 和 Private Cloud Compute 的隐私承诺。

这些能力利好本项目，因为照片清理天然适合本地推理：

- 低价值照片判断可以在设备端进行。
- 孩子照片、家庭照片不需要上传。
- 可以和 Siri / App Intents 做周期性轻量工作流。

来源：

- Apple Intelligence for developers: https://developer.apple.com/apple-intelligence/
- WWDC26 Foundation Models: https://developer.apple.com/videos/play/wwdc2026/241/
- Apple Newsroom: https://www.apple.com/newsroom/2026/06/apple-aids-app-development-with-new-intelligence-frameworks-and-advanced-tools/
- Apple Privacy: https://www.apple.com/privacy/

## 为什么不能只卖“隐私”

隐私本身不是足够护城河：

- Apple Photos 自带重复照片合并。
- Apple Photos 已经支持按媒体类型查看截图等内容。
- Apple 一直强调很多照片识别能力在设备端完成。
- 在 Apple 生态里，“本地处理”会逐渐变成用户预期，而不是独家卖点。

所以产品不能只说“照片和视频不上传”。更强的表达应该是：

> 专为家庭相册设计的本地 AI 清理建议，帮你保留值得留的，安全删掉明显没价值的。

## 需求验证

竞品评分和下载信号说明需求很强。讨论中记录到：

- Cleanup：约 664K ratings / 4.7。
- Swipewipe：约 79K ratings / 4.7。
- CleanMyPhone：约 23K ratings / 4.6。
- Slidebox：约 16K ratings / 4.8。

解读：

- 用户确实愿意寻找照片清理工具。
- 搜索词如 `photo cleaner`、`AI photo cleaner`、`duplicate photo cleaner` 有明确购买意图。
- 但大词竞争非常激烈，新产品需要更窄定位。

## 适合的商业形态

更适合 bootstrapped 小而美产品，不适合一开始包装成 VC 大市场故事。

原因：

- 泛手机清理赛道竞争极重。
- Apple 自带 Photos 能力会持续增强。
- App Store 获客依赖 ASO、口碑、短视频种草和具体场景切入。
- 如果产品定位精准，家长用户愿意为省时间和安心付费。

## 推荐商业模式

建议避免周费订阅，优先强调可信和克制：

- 免费扫描 + 少量删除。
- 一次性买断：`$9.99-$19.99`。
- 年费：`$14.99-$24.99`，支持 Family Sharing。
- 可选 Pro：大图库扫描、视频压缩、周清理计划、Siri 快捷清理。

不建议：

- `$9.99/week` 这类容易引发反感的订阅。
- 用“免费清理”诱导，再快速弹高价订阅。
- 做泛设备优化、VPN、安全中心等偏离定位的功能。

## 主要威胁

- Apple Photos 继续增强相似照片、低质量照片和截图清理。
- CleanMyPhone 等成熟工具扩大本地 AI 和家庭场景宣传。
- 用户对相册权限敏感，冷启动信任门槛高。
- “误删孩子照片”会造成强负面口碑。
- Cleaner 品类整体信誉弱，需要更清爽的品牌和商业模式。

## 成立条件

这个项目值得继续的条件：

- 用户愿意给全相册权限，或至少愿意给足够大范围的相册权限。
- 首轮扫描能明显节省空间，例如 2GB 以上或 500 张以上候选项。
- 用户认可“保守建议 + 复核”的体验，不要求一键全删。
- 误删恐惧低，删除后仍感觉可控。
- 用户愿意为隐私、本地处理和少订阅套路付费。
