# 自动化测试清单（2026-10-09）

## 分层概览

不同层包含重叠场景，不应把数量相加当成独立业务覆盖率。

| 层级 | 用例数 | 主要职责 | 入口 |
| --- | ---: | --- | --- |
| Swift XCTest | 101 | 识别规则、状态、安全边界、持久化、缓存、隐私及标识 | `iOS/TrueKeep/TrueKeepTests/` |
| XCUITest | 33 | 页面交互、恢复路径、无障碍及命名截图 | `iOS/TrueKeep/TrueKeepUITests/TrueKeepUITests.swift` |
| Python | 22 | 发布预检、设备 smoke／AppClaw 运行器、识别评测器 | `iOS/TrueKeep/Scripts/tests/` |
| AppClaw P0 | 9 | 可复用的端到端确定性流程 | `iOS/TrueKeep/AppClaw/cases.json` |

上一轮实际 Xcode 回归：101 单测通过，32/33 UI 通过。首次授权扫描用例被系统权限弹窗打断，不能称为全绿。详见 [Xcode 回归报告](../iOS/TrueKeep/TestArtifacts/2026-10-09-regression/README.md)。

## Swift 单测分布

| 测试类 | 数量 | 范围 |
| --- | ---: | --- |
| `CleanupFlowStateTests` | 17 | 选择、复核箱、部分／全部删除结果、分组身份、统计同步 |
| `PhotoDeletionResultTests` | 8 | 安全开关、显式开启／禁用优先级、删除结果 |
| `PhotoLibraryAuthorizationTests` | 13 | 权限状态、启动入口与路由 |
| `PhotoLibraryScanPolicyTests` | 4 | 普通／低电量策略、分批处理 |
| `PhotoScanResultBuilderTests` | 39 | 分类、相似组、模糊／误拍候选、保留推荐、精确重复证据 |
| `PhotoThumbnailRequestKeyTests` | 2 | 缩略图请求与缓存键 |
| `PrivacyManifestTests` | 1 | 隐私声明 |
| `PrivacySafetyTopicTests` | 2 | 安全说明 |
| `PublicScanCapabilityCopyTests` | 1 | 本地识别与候选能力文案 |
| `ReviewIterationTests` | 10 | 会话恢复／过期、损坏备份、重扫合并、保留决定、权限缩减、缓存与跨日期重复 |
| `TrueKeepAccessibilityTests` | 4 | 自动化标识及可访问性静态约束 |

## XCUITest 场景

- 授权前说明、跳过与重启；默认启动不泄漏测试数据。
- 授权后首扫／重扫、结果页重扫入口、扫描范围及大字号范围选择。
- 扫描局部忙碌／取消、候选复核离页继续／返回／取消、扫描中断恢复。
- 权限拒绝、重试局部状态、有限权限提醒。
- 所有任务打开正确详情、第二相似组定位、首页缩略图无选择圈。
- 本地预览不可读取、预览确认保留、整组确认保留／清除、视频元数据（2026-11-02 合并后沿用远端确认保留逻辑，旧推荐覆盖用例已替换）。
- 会话重启恢复复核箱、扫描覆盖与不可读取统计。
- 复核箱二次确认／安全锁／恢复选择、删除中忙碌／失败保留、空选择禁用。
- 分组批量选择反馈、零选择禁止加入、VoiceOver 选择状态与原因。
- 删除成功后首页统计更新、重扫保留、删除后大字号无障碍。
- 主要页面及权限／扫描页无障碍审计、大控件边缘点击、中文 Tab、设置详情。
- 营销截图与关键状态截图留存。

上述媒体预览错误态使用夹具，不等于已验证真实照片加载、视频播放或真实识别效果。

## 9 条可复用 P0 流程

| case ID | 场景 |
| --- | --- |
| `trust-intro-skip` | 本地处理说明、不会自动删除、暂不授权后恢复入口 |
| `settings-trust-details` | 隐私／安全说明导航、不上传与不追踪 |
| `review-bin-deletion-safety` | 任务复核 → 复核箱 → 二次确认 → 安全锁阻止删除 |
| `permission-denied-retry` | 权限关闭、局部重试状态、回到首页 |
| `scan-cancel-recovery` | 扫描取消、未改动照片、恢复入口 |
| `candidate-refinement-continuity` | 候选复核进度、离页继续、返回、取消 |
| `limited-results-rescan` | 有限权限提醒、重扫按钮位置与进入扫描 |
| `scan-date-range-selection` | 近一个月切近三个月，进度／结果保留实际范围 |
| `post-deletion-home-sync` | 删除后移除候选／空间旧值、摘要与重扫 |

本次将这些现有用例转换为 kwai-mobile-mirror Workbench 接受的扁平、结构化 YAML 执行。转换不增加新的产品断言；[Mobile Mirror 运行报告](../iOS/TrueKeep/TestArtifacts/2026-10-09-mobile-mirror/README.md) 单列原始尝试、复验及证据。

## 尚缺的验收

- 首次扫描用例的真实权限前置条件隔离及全绿复验。
- 真媒体成功预览、照片缩放、视频播放、图库权限动态缩减及失效详情专项验证。
- 真实标注图库 precision／recall、真机普通／低电量及冷／热缓存性能。
- 真实 Photos 删除：不在默认回归范围，必须另行批准计划与显式 opt-in。
- XCUITest 新增的预览／会话／保留／覆盖四项，尚未迁入现有 9 条 P0 YAML 套件。
