# Photo Cleaner Docs

本文档整理自 2026-06-10 围绕“本地 AI 隐私相册清理工具”的讨论。核心场景是：手机里经常出现孩子乱拍的照片、重复/相似照片、截图、模糊照片和大视频，用户希望快速、安全、隐私地清理。

## 文档结构

- [01 用户问题与机会](./01-user-problem.md)：目标用户、痛点、为什么这个场景值得做。
- [02 工具与竞品调研](./02-tool-and-competitor-research.md)：iPhone、Android、Samsung 和第三方工具对比。
- [03 市场判断](./03-market-opportunity.md)：基于 Apple 2026 WWDC 本地 AI 能力的市场机会判断。
- [04 产品定位与 MVP](./04-product-positioning-and-mvp.md)：建议定位、功能边界、MVP 和验证指标。
- [05 隐私、安全与风险](./05-privacy-safety-risk.md)：隐私承诺、误删风险、App Store 风险和用户信任。
- [06 命名与 ASO](./06-naming-and-aso.md)：品牌名、App Store 名称、副标题、关键词和宣传语。
- [07 三阶段产品路线](./07-three-phase-roadmap.md)：按 MVP 信任验证、TestFlight 商业化、留存扩展拆解阶段目标。
- [08 MVP 与信任验证设计稿和交互稿](./08-mvp-trust-design-and-interaction.md)：阶段一的高保真原型、屏幕规格、交互规则和开发接口建议。
- [09 当前产品动线与截图](./09-current-product-flow-with-screenshots.md)：当前 iOS MVP 的实际使用动线，并配套最新模拟器截图。
- [10 当前识别策略](./10-current-recognition-strategy.md)：当前真实扫描候选规则、默认选中策略、限制和端侧 AI 引入建议。
- [App Store 隐私政策草稿](./app-store/privacy-policy.md)：可托管为 App Store 隐私政策 URL 的页面内容。
- [App Store 支持页草稿](./app-store/support.md)：可托管为 App Store Support URL 的页面内容。
- [App Store 合规问答草稿](./app-store/compliance-answers.md)：年龄分级、出口合规、内容权利和类别选择的提交前答案草稿。

## Native App

- [iOS README](../iOS/README.md)：原生 iOS 工程入口、构建命令和当前范围。
- [iOS Decisions](../iOS/TrueKeep/DECISIONS.md)：实现过程中记录的技术选型和产品决策。
- [iOS Release Checklist](../iOS/TrueKeep/RELEASE_CHECKLIST.md)：上架前需要完成和验证的事项。
- [iOS Device Signing](../iOS/TrueKeep/DEVICE_SIGNING.md)：真机签名、账号准备和安全 smoke test 操作说明。

## 当前结论

市场可以做，但不建议做普通“手机清理大师”或泛泛的“照片清理 App”。更好的切口是：

> 本地 AI 家庭相册整理工具，帮助家长快速清理孩子乱拍、相似连拍、截图、模糊照片和大视频，照片和视频不上传，删除前可解释、可复核、可恢复。

推荐品牌组合：

- App Store 名称：`TrueKeep: AI Photo Cleaner`
- 中文传播名：`留真`
- 副标题：`Private Camera Roll Cleanup`
- 一句话定位：`本地 AI 相册清理，留下真正值得留的照片。`

## 时间边界

本文档中的市场、竞品、App Store 评分和 Apple 平台能力基于 2026-06-10 讨论时的调研快照。正式立项、投放或提交 App Store 前，需要重新校验：

- App Store 竞品评分、订阅价格和隐私标签。
- Apple Foundation Models / App Intents / Core AI 的正式 API 可用性和设备要求。
- `TrueKeep`、`留真` 及相关名称的商标、域名和 App Store 占用情况。
