## 1. 规格与状态模型

- [x] 1.1 定义算法推荐与用户确认保留的独立语义、持久化边界和跨扫描行为。
- [x] 1.2 增加本地保护 ID 存储、去重读写和重置能力。
- [x] 1.3 扩展候选、分组和任务派生状态，确保保护项不进入删除选择、复核箱、数量和预计体积。

## 2. 扫描协调与界面

- [x] 2.1 构建扫描结果时过滤非相似保护项，并在相似组中保留只读比较参考。
- [x] 2.2 在复核页增加“确认保留，不再提醒”、保护标记、成功反馈和即时撤销。
- [x] 2.3 在设置页增加保护数量、缩略图列表、逐项取消和全部重置。
- [x] 2.4 保持扫描进度、取消、中断和完成刷新符合 `user-action-contract`，不增加全局阻塞状态。

## 3. 自动化与证据

- [x] 3.1 增加存储、共享状态和扫描结果单元测试，覆盖保护、撤销、复核箱移除、相似参考和无任务结果。
- [x] 3.2 增加禁用真实删除的 UI E2E，覆盖确认保留、跨启动仍生效、撤销和设置管理。
- [x] 3.3 使用 `keepAlways` 保留确认成功、跨启动保护和设置管理关键截图，并检查 Dynamic Type、VoiceOver 和触控区域。

## 4. 验证与交付

- [x] 4.1 运行聚焦 Swift 单元测试和 UI 测试并记录实际结果。
- [x] 4.2 运行完整 Xcode 回归、OpenSpec 严格校验、`python3 openspec/check.py` 和 `git diff --check`。
- [x] 4.3 检查最终差异只包含本变更和进入工作区前已有改动，不覆盖真实删除 Scheme 配置与推荐项覆盖迭代。
- [ ] 4.4 变更被接受或发布后归档 OpenSpec，并把 `confirmed-keeps` 规格增量合入正式规格。

## 验证记录

- 2026-08-25：聚焦单元测试 90/90 通过；已确认保留 UI E2E 1/1 通过，覆盖确认、即时撤销、冷启动持久化、设置管理和逐项取消。结果包：`/tmp/TrueKeepConfirmedKeepsE2E-20260825-2.xcresult`。
- 2026-08-25：完整 Xcode 回归执行 139 项，初次 138 项通过，唯一失败为新增设置行下推版本号后触发的系统对比度审计；将版本号移出 TabBar 阴影区后，失败用例 `testCriticalScreensPassAccessibilityAudit` 单独重跑通过。完整结果包：`/tmp/TrueKeepConfirmedKeepsFull-20260825.xcresult`；修复后结果包：`/tmp/TrueKeepCriticalAccessibility-20260825-2.xcresult`。
- 2026-08-25：OpenSpec 1.8.0 对 `add-confirmed-keeps` 的严格校验通过；全仓 `python3 openspec/check.py` 为 9/10 通过，唯一失败来自进入本次工作前已有的 `refine-photo-analysis-pipeline` 规格场景缺失，未跨范围修改；`git diff --check` 通过。
- 2026-08-25：UI 自动化显式使用 `-TrueKeepDisablePhotoDeletion`，未调用真实 Photos 删除。4 张 `keepAlways` 截图保存在 `iOS/TrueKeep/TestArtifacts/2026-08-25-confirmed-keeps-e2e/`。
