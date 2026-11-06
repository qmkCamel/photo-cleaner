# 全页面交互改版验收（2026-11-05）

对应 OpenSpec：`simplify-review-interactions`、`prioritize-home-review-results`、`reorganize-settings-and-onboarding`。当前 checkout 为 `dev`，包含未提交实现与先前删除授权持久化工作；未发布或归档。

## 后续验证更新（2026-11-06 核对）

本目录保留当时的分轮执行记录，不覆盖原始失败证据。后续 Duo 改造将删除确认改为原生 Form，2026-11-05 的同一应用候选完整回归已达到 144/144 单元、55/55 UI 通过，原 textClipped 失败已关闭；原生 Duo 的删除确认专项审查也通过。最新结果见 [Duo 实施报告](../2026-11-05-duo/README.md)。真实媒体、人工读屏、完整 Duo 形态及最低系统验收仍未完成，未发布/归档。

## 本阶段历史结论

三轮主体已实现。按每个测试的最新运行结果汇总：**134/134 单元测试通过，48/49 UI 用例分轮通过，8 条新增改版 UI 用例全部通过**。这不是一次全量测试全绿；唯一剩余失败是 `testCriticalScreensPassAccessibilityAudit` 的删除确认页 `.textClipped` 审查。

该用例已通过引导、无权限首页、设置、结果首页、截图复核和复核箱，最后在 iCloud 同步说明上报告“较大 Dynamic Type 可能截断”。普通字号截图完整可读，独立最大字号测试能滚动到完整说明和确认/取消按钮并通过；仍不能据此认定系统审查误报，也不移除该审查。此项及下文真实媒体/跨设备人工验收未关闭，三个变更不归档。

完整运行日志位于 `logs/`；各截图目录中的 manifest 可追溯用例、设备和时间。真实删除全程关闭。

## 实现范围

- 复核页：图片预览与角标选择分离；双列/无障碍字号单列；加入复核箱为主操作，直接删除收进更多；全选双态、保留其余及就地撤销；保留缩略图不再整体蒙灰；稳定完成状态。
- 媒体预览：黑色画布、固定切换/保留工具栏、详情按需展示；确认保留后停留；不可用资源可重试/关闭，继续禁止 iCloud 下载。
- 复核箱/删除确认：移出语义、记录 30 天说明、安全清单折叠；内容可滚动的确认表单；二次确认、局部忙碌和失败恢复保留。
- 首页/扫描：任务优先，范围设置草稿与提交分离；扫描详情与异步报告生成；单阶段进度、继续浏览、取消与同范围重试；只在成功提交新结果时重置旧删除摘要。
- 设置/引导：任务型分组与版本；保留管理浏览/编辑、全量确认和撤销；授权前三项承诺；按无权限、未扫描、无候选、处理完成区分空态。

## 安全与证据类型

所有 UI 用例显式启用 `-TrueKeepDisablePhotoDeletion`。成功/部分成功删除均为 Debug 测试替身，没有删除系统照片。样例缩略图不是用户图库，也不能证明真实照片/视频成功加载、识别质量或真机性能。报告失败使用禁删模式下的 Debug 一次性故障注入，重试走真实 JSON 编码路径。

操作契约采用全局 `user-action-contract`：根视图拥有扫描任务，按请求 ID 拒绝过时进度，取消后不发布半成品；报告编码在 detached worker 中执行并传播取消；删除只根据服务返回的成功 ID 更新共享状态。

## 环境和可复现命令

- iPhone 17 Pro / iOS 26.5 模拟器，UDID `642F2F40-1DF5-4C73-A382-494BBE4C53AB`。
- Xcode 默认安装，SDK 27.1；部署目标为 iOS 18。未因此宣称已在 iOS 18 运行。

```sh
xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep \
  -destination 'platform=iOS Simulator,id=642F2F40-1DF5-4C73-A382-494BBE4C53AB' \
  -derivedDataPath /tmp/truekeep-merge-cached-20261102 \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -collect-test-diagnostics never -resultBundlePath /tmp/TrueKeepUX-20261105-regression.xcresult
python3 -m unittest discover -s iOS/TrueKeep/Scripts/tests -v
python3 openspec/check.py # PATH 需包含已安装的 openspec
git diff --check
```

关闭的是失败后大型 simctl diagnose 收集，不是断言、测试日志或 `XCTAttachment.keepAlways` 截图。

## 执行记录

- 首轮聚焦测试：5 个新增改版 UI 用例通过；另发现扫描标题断言和两条单元回归需随最终契约调整，未把首轮报告标记全绿。`initial/manifest.json` 保留截图与测试名称对应关系。
- 全量首轮 `regression`：单元 131/131；UI 35/46，11 条失败。失败涉及旧文案/入口、滚动定位与系统无障碍审查，未将该轮标记通过。
- `recheck`：单元 132/133、UI 15/21；8 条新增改版 UI 用例全部通过。修正重复 ID 测试数据和模型页滚动定位后继续复测。
- `final`：单元 134/134、UI 6/11。目录名仅为当时运行名称，不代表全绿；剩余 5 条均为无障碍相关复测。
- `accessibility`：UI 3/5。导航工具栏和表单取消的大字号审查通过；继续处理设置分组文字与扫描时间。
- `contrast`：单元 134/134、UI 0/2；`audit-closeout`：UI 0/2。失败过程保留，用于区分代码编译与运行验收。
- `audit-final`：UI 1/2，扫描范围/扫描时间的对比度已通过；`critical`：UI 0/1，定位到设置页的系统 Section 标题字号约束，继续复测。
- `critical-recheck`、`critical-content`、`hit-targets`：各 UI 0/1。依次暴露设置标题字号、全选按钮实际热区和全选文字对比度问题，均保留日志。
- `verification`：单元 134/134、UI 3/4；保留管理、预览/选择和最大字号复测通过；关键路径已通过设置、首页和复核页，继续修正复核箱“删除前须知”对比度。
- `acceptance`：单元 134/134、UI 2/3。失败附件进一步确认复核箱说明被底部操作栏部分覆盖；改为独立滚动区与操作栏后继续执行 `bin-layout`。此目录名同样不表示验收已通过。
- `bin-layout`：UI 2/3；`safety-layout`：UI 2/3。将折叠须知移到缩略图前后，复核箱无障碍审查通过，最后暴露删除确认页文字裁切审查。
- `confirmation`：UI 1/2，最大字号确认与取消通过；`text-layout`：UI 0/1，显式换行/垂直自适应后，iCloud 同步说明仍被系统报告可能截断，保持待验收。
- 脚本测试：25/25 通过。OpenSpec 全仓严格/生命周期检查：20/20 通过。
- `AppClaw/flows/` 已更新新入口及文案；本轮尚未执行 AppClaw/Mirror，历史运行文件保持原样。

## 截图入口

以下为测试附件的原样副本，没有修改画面。其他截图及原始测试对应关系见各运行目录的 `manifest.json`；`isAssociatedWithFailure` 是 Xcode 附件属性，不是该测试最终结果，运行是否通过以执行记录为准。

| 状态 | 截图 | 原始附件 |
| --- | --- | --- |
| 未选择 | [review-none](screenshots/review-none.png) | recheck/4D07F56E-9FF0-4993-AD93-752698EA5E8A.png |
| 已选择 | [review-selected](screenshots/review-selected.png) | recheck/7288AE8B-113C-43BB-BD82-A5914661D1CF.png |
| 已保留 | [review-kept](screenshots/review-kept.png) | recheck/5B456304-B1A6-43F0-B70B-4A33626C1636.png |
| 部分删除失败（替身） | [delete-partial-failure](screenshots/delete-partial-failure.png) | final/318F5F85-D779-4A2D-A8B9-1C18B2E541F0.png |
| 报告失败 | [export-failure](screenshots/export-failure.png) | final/4898012F-445F-4773-8303-0DFE3E3C49FC.png |
| 报告重试成功 | [export-success](screenshots/export-success.png) | final/8A280F2E-B061-4FCF-81E8-7889DE1F9B63.png |
| 最大字号确认 | [delete-confirm-maximum-text](screenshots/delete-confirm-maximum-text.png) | confirmation/DB9F9FBE-38BD-4C04-8E1F-022859A3837A.png |
| 设置分组 | [settings-groups](screenshots/settings-groups.png) | confirmation/7FA188F0-090E-4860-BC47-2549E5B443FD.png |
| 结果首页 | [home-results](screenshots/home-results.png) | confirmation/26894EC1-CE53-4890-B592-7247CE1049CC.png |
| 待删除复核箱 | [bin-pending](screenshots/bin-pending.png) | confirmation/ECEE8E1B-8405-4F38-9372-7D78B70CE2A6.png |
| 确认页审查失败现场 | [delete-confirm-audit-failure](screenshots/delete-confirm-audit-failure.png) | confirmation/1F532664-29DB-4F3C-9CB2-465107CFAFE7.png |

自动审查沿用已有测试范围：大字号用例不包含系统 `.textClipped` 审查，Limited 长列表用例不包含 `.contrast`；其他指定关键画面的对比度审查仍启用。截图人工核查与系统审查互相补充，不能据此宣称所有界面、所有辅助功能均已覆盖。

## 尚未声称完成的验收

专用本地真实照片/视频成功预览、缩放和播放，实际 VoiceOver 手工读屏，小屏/横屏/iOS 18 运行，以及真机大图库性能与识别准确率仍需专项验收。最大字号截图和系统无障碍自动审查不等于人工 VoiceOver 验收。不得将本报告用作这些项目的完成证据。
