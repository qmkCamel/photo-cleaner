## 1. 范围模型与 Photos 查询

- [x] 1.1 新增 `PhotoScanDateRange`，定义近一个月、近三个月和全部的标题、说明、默认值与可测试日期区间。
- [x] 1.2 扩展 `PhotoLibraryScanning` 接口，使每轮扫描接收不可变范围快照，并在照片和视频 fetch 中复用同一参考时刻。
- [x] 1.3 为近期范围增加 `creationDate` 起止谓词，保持隐藏资源排除与降序排序；全部范围不设置日期谓词。
- [x] 1.4 明确缺少拍摄时间的资源只进入全部范围，并验证 Limited Access 继续由系统授权集合约束。

## 2. 范围状态与用户界面

- [x] 2.1 在 `AppRootView` 分离当前选择、进行中范围和最近完成范围；首次授权自动扫描默认近一个月，取消重试复用原范围。
- [x] 2.2 在首页增加可换行、可点击的范围选项；未扫描时显示纵向“扫描范围”，已有结果时显示紧凑“下次扫描范围”，无障碍字号自动恢复纵向布局。
- [x] 2.3 在范围卡明确说明选择只影响本地扫描、不改变照片权限，并在 Limited Access 下保留原有限访问提醒。
- [x] 2.4 在扫描进度页和结果页展示本轮实际范围；用户更改下次范围时不得改写旧结果标签。
- [x] 2.5 为范围选项补充稳定 accessibility identifier、VoiceOver 选中状态、触控区域和 Dynamic Type 布局。

## 3. 自动化与截图证据

- [x] 3.1 增加范围日期单元测试，覆盖默认值、一个月/三个月边界、全部范围、闭区间和未知拍摄时间。
- [x] 3.2 增加 XCUITest，覆盖默认近一个月、切换近三个月、扫描进度、完成结果和下次范围与本次范围分离。
- [x] 3.3 为范围成功结果与无障碍大字号状态保存语义命名 `XCTAttachment`，并设置 `keepAlways`。实际附件名为 `home-scan-range-last-three-months-result` 与 `home-scan-range-picker-accessibility-text`。
- [x] 3.4 新增 AppClaw P0 范围选择 Flow，更新清单、README 和脚本测试，保留运行报告及逐步截图。

## 4. 验证与交付

- [x] 4.1 运行 `openspec validate add-scan-date-range --type change --strict --no-interactive`。实际结果：proposal、design、specs 和 tasks 制品完整，严格校验通过。
- [x] 4.2 运行聚焦 Swift 单元测试、UI 测试和 AppClaw 脚本测试，记录范围切换与截图制品结果。实际结果：范围相关单测 3/3、XCUITest 2/2、AppClaw 脚本测试 6/6 通过；两张命名 XCUITest 截图保存在 xcresult。
- [x] 4.3 在可用模拟器或真机运行新增 AppClaw Flow，并保留 `.appclaw/runs/` 报告和逐步截图。实际结果：最新 iPhone 17 模拟器构建严格模式 15/15 步通过；run `20260811T053302-ff7814` 保留 15 张逐步截图与 7.9 MB manifest。
- [x] 4.4 运行完整 Xcode 回归、`python3 iOS/TrueKeep/Scripts/release_preflight.py --run-xcode` 和 `python3 openspec/check.py`。实际结果：完整 Xcode 95/95 通过；发布预检 15 项通过/信息、0 失败，Release 无签名归档成功；OpenSpec 5/5 严格校验和生命周期检查通过。
- [x] 4.5 运行 `git diff --check`，确认未覆盖既有删除结果协调改动和其他用户工作区变更。实际结果：通过；既有删除结果协调改动保持在工作区，未执行清理、暂存、提交或推送。
