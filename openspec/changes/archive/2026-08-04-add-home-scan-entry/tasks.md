# 任务

## 1. 规格与状态所有权

- [x] 1.1 记录已授权冷启动缺少扫描入口的状态断点。
- [x] 1.2 明确当前运行周期扫描完成状态由 `AppRootView` 持有。
- [x] 1.3 补齐 proposal、design、规格增量和归档前协调规则。

## 2. 首页扫描入口

- [x] 2.1 增加“尚未扫描”空态及“扫描相册”入口。
- [x] 2.2 将首页入口连接到现有本地扫描、进度、取消和恢复流程。
- [x] 2.3 在空结果状态展示“重新扫描”。
- [x] 2.4 在已有复核任务的结果页增加不遮挡内容和 Tab Bar 的“重新扫描”操作区。

## 3. 无障碍与自动化

- [x] 3.1 增加稳定的扫描入口无障碍标识。
- [x] 3.2 增加已授权冷启动、空结果和有结果状态回归。
- [x] 3.3 校验有结果重扫入口可见、可点击且位于 Tab Bar 上方。

## 4. 验证与交付

- [x] 4.1 运行 Swift 解析、聚焦测试和完整发布预检。
- [x] 4.2 保留历史真机构建、安装和启动证据，并把本次入口可见性定向 UI 验证与真机进程证据分开记录。
- [x] 4.3 重新运行 OpenSpec 严格校验和发布预检。
- [x] 4.4 对照当前代码与正式规格完成归档前协调。

## 验证记录

- `python3 openspec/check.py`
  - 结果：通过；正式规格 3/3 严格校验通过，无活跃 change、不可解析 proposal 或归档 `TBD`。
- `swiftc -parse $(rg --files iOS/TrueKeep/TrueKeep iOS/TrueKeep/TrueKeepTests iOS/TrueKeep/TrueKeepUITests -g '*.swift')`
  - 结果：通过。
- `python3 -m unittest iOS.TrueKeep.Scripts.tests.test_release_preflight iOS.TrueKeep.Scripts.tests.test_device_smoke`
  - 结果：通过；执行 12 个脚本单元测试，0 failure。
- `python3 iOS/TrueKeep/Scripts/release_preflight.py --run-xcode`
  - 结果：通过；15 个通过/信息项、0 failure，完整 `xcodebuild test` 和无签名 Release Archive 均成功。
- 真机边界：本轮 OpenSpec 收口未重新执行物理设备安装；历史记录只证明当时构建、安装和启动成功，本次新增的有结果重扫入口由完整模拟器 UI 回归验证，不把进程证据表述为当前视觉证明。
- 归档结果：`add-home-scan-entry` 已归档为 `2026-08-04-add-home-scan-entry`，正式 `scan-entry` Purpose 已补齐。
