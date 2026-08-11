## Why

当前 TrueKeep 获得照片访问权限后会扫描全部可访问照片和视频。用户只想整理近期内容时，无法控制扫描规模，也容易把系统照片权限的“可访问范围”和 App 的“本次扫描范围”混为一谈。增加明确的时间范围选择，可以缩短近期整理路径，同时继续保持本地处理、有限权限和人工复核边界。

## What Changes

- 在首页增加扫描范围选择，提供“近一个月”“近三个月”“全部”三个选项，默认“近一个月”。
- 明确范围选择只限制 App 本次本地扫描，不改变系统 Photos 权限，也不额外触发权限弹窗。
- “近一个月”和“近三个月”按当前时刻向前推一个或三个自然月，包含起点和当前时刻；缺少拍摄时间的资源只在“全部”中扫描。
- 照片和视频使用同一范围；Limited Photos Access 下只扫描“已授权资源”与“所选时间范围”的交集。
- 扫描开始时锁定本次范围；用户随后修改选择只影响下一次扫描，结果页继续展示实际生成当前结果的范围。
- 扫描进度、完成、取消和重试继续复用现有动作局部状态与恢复路径，并显示本次范围。
- 为默认范围、切换范围、重新扫描、Limited Access、Dynamic Type 和 VoiceOver 补充自动化覆盖与命名截图。
- 非目标：不提供任意日期选择器、不按修改日期筛选、不改变照片权限申请、不自动删除、不调整候选识别算法。

## Capabilities

### New Capabilities

- `scan-scope`: 定义应用内扫描时间范围的选项、日期语义、Photos 查询过滤、结果归属和可访问性要求。

### Modified Capabilities

无。

## Impact

- 扫描服务：`PhotoLibraryScanning`、`SystemPhotoLibraryScanner` 和 Photos fetch options。
- 状态所有权：`AppRootView` 保存当前选择、进行中的范围和最近完成结果范围。
- 用户界面：`CleanupResultsView` 范围选择、`ScanProgressView` 本次范围反馈和结果范围说明。
- 自动化：范围纯函数单元测试、XCUITest 命名截图、AppClaw P0 Flow 与回归清单。
- 不新增网络、持久化或第三方依赖，不改变 `NSPhotoLibraryUsageDescription`、签名配置和删除安全开关。
