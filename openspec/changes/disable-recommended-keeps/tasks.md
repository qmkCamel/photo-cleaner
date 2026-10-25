## 1. 推荐能力边界

- [x] 1.1 增加默认关闭的产品级推荐保留开关，并为候选提供不泄漏原始算法标记的有效推荐语义。
- [x] 1.2 让任务构建、预计空间、批量选择和测试场景只读取有效推荐语义，确认保留继续优先保护。
- [x] 1.3 推荐关闭时让真实扫描和确定性样例的相似组默认零选择，并使用中性任务与分组文案。

## 2. 复核界面

- [x] 2.1 移除推荐书签、推荐专属布局和 VoiceOver 推荐语义，保留候选真实选择和确认保留状态。
- [x] 2.2 推荐关闭时让逐张选择与批量选择覆盖全部未确认保留候选，并保持两个删除入口零选择禁用。
- [x] 2.3 更新当前产品流程、交互设计和识别策略文档，明确推荐暂时关闭与内部评分保留边界。

## 3. 自动化与证据

- [x] 3.1 添加状态单元测试，覆盖有效推荐屏蔽、相似组零选择、中性任务文案、预计空间和批量选择。
- [x] 3.2 更新确认保留与删除相关回归，证明推荐关闭不会削弱用户保护和二次确认。
- [x] 3.3 添加禁用真实 Photos 删除的 UI E2E，保留推荐已屏蔽与用户手动选择的 `keepAlways` 命名截图并检查布局。

## 4. 验证与交付

- [x] 4.1 运行聚焦状态测试和推荐关闭 UI E2E，记录结果包与截图路径。
- [x] 4.2 使用可用 iPhone 模拟器运行完整 Xcode 回归，确认真实 Photos 删除保持禁用。
- [x] 4.3 运行 OpenSpec 严格校验、仓库生命周期检查、原始推荐读取审计和 `git diff --check`，记录实际结果与既有阻断。
- [ ] 4.4 变更被接受或发布后，按依赖顺序协调并归档相关 OpenSpec 增量。

## 验证记录

- 红灯基线：5 个聚焦状态测试按新要求运行，5 个失败、9 条断言失败；结果包 `/tmp/TrueKeepDisableRecommendedRed-20260830.xcresult`。
- 聚焦状态绿灯：5/5 通过；结果包 `/tmp/TrueKeepDisableRecommendedFocused2-20260830.xcresult`。
- 单元测试目标：107/107 通过，真实 Photos 删除由环境变量保持禁用；结果包 `/tmp/TrueKeepDisableRecommendedUnit-20260830.xcresult`。
- UI E2E：`testConfirmedKeepPersistsAcrossRelaunchAndCanBeManaged` 1/1 通过；推荐关闭用例首次运行因 XCUITest 默认点击命中独立更多操作热区失败，改用缩略图稳定点击坐标后 1/1 通过。成功结果包 `/tmp/TrueKeepDisableRecommendedUIRetry-20260830.xcresult`。
- 截图：`iOS/TrueKeep/TestArtifacts/2026-08-30-recommended-keep-disabled/01-recommended-keep-disabled-similar-review.png` 与 `02-recommended-keep-disabled-manual-selection.png`；目检无推荐语义、文字裁切、控件重叠或布局跳动。
- 完整回归：iPhone 17 Pro 模拟器、iOS 26.5（23F77）上 140/140 通过（107 个单元测试、33 个 UI 测试），0 失败、0 跳过；结果包 `/tmp/TrueKeepDisableRecommendedFull-20260830.xcresult`。环境变量与 UI launch argument 双重禁用真实 Photos 删除。
- OpenSpec：`disable-recommended-keeps` 严格校验通过。仓库生命周期检查仍被既有 `refine-photo-analysis-pipeline` 阻断：其两个 MODIFIED requirements 缺少当前正式规格已有的 4 个 scenarios，本次未修改该变更。
- 原始推荐读取审计：除扫描内部、共享模型边界和确定性样例外，产品源码没有直接读取原始 `recommendedKeep`；任务、预计空间、批量选择、删除同步和复核 UI 均读取有效推荐语义。
- 差异卫生：`git diff --check` 通过。
