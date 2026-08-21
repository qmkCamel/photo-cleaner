## 1. 状态与界面

- [x] 1.1 为 `CleanupFlowState` 增加当前分组可选择候选集合、是否全部选中及双态切换逻辑。
- [x] 1.2 将复核页批量按钮改为“全选本组可清理项 / 取消全选”，并补充对应无障碍提示与空集合禁用状态。

## 2. 自动化回归

- [x] 2.1 增加状态单元测试，覆盖部分选择时补齐、全部选择时取消及推荐保留项排除。
- [x] 2.2 增加禁用真实删除的 XCUITest，断言双态文案、加入复核箱数量，并保留取消全选与重新全选命名截图。

## 3. 验证与交付

- [x] 3.1 运行聚焦单元测试、聚焦 UI 测试和相关回归，记录实际结果。
  - `CleanupFlowStateTests`：17/17 通过；`TrueKeepTests`：91/91 通过。
  - 双态 UI 聚焦用例：1/1 通过；受影响 UI 回归：6/6 通过，真实 Photos 删除保持禁用。
  - `review-group-bulk-selection-cleared` 与 `review-group-bulk-selection-restored` 两张 `keepAlways` 截图已导出到 `.appclaw/artifacts/fix-review-all-selection-feedback/2026-08-20-xcuitest/`。
- [x] 3.2 运行 OpenSpec 严格校验、生命周期检查和 `git diff --check`，记录实际结果。
  - 变更状态完整，严格校验通过；归档后生命周期检查和 `git diff --check` 通过。
- [x] 3.3 构建并覆盖安装到已连接真机，以关闭真实删除的安全启动验证按钮可见反馈。
  - iPhone 16 Plus 真机构建、签名、覆盖安装和启动成功；bundle ID 为 `app.truekeep.ios`，启动同时注入双重删除安全锁。
