# Duo 适配实现与验证

日期：2026-11-05。状态：主体适配及当前可执行自动化已完成；仍有实现/形态验收缺口，**不是完整 Duo 支持或发布验收通过声明**。

**重要证据更正：**逐张检查方向请求前后的截图后，发现当前 Duo runtime 始终保持 `382×644pt`，并未真的旋转窗口。早期 5 条用例虽然断言通过，只能证明在方向指令下操作继续，不能证明任何跨尺寸/跨形态适配。用例现已增加实际窗口变化检查，未改变会 `XCTSkip` 并保存证据，绝不计为通过。以下旧附件中的 landscape/rotation 命名是测试意图，不是实测姿态。

## 代码范围

- `AdaptiveLayoutPolicy`：按实时安全可用区域判定单/双栏、1–4 列网格和矮窗口动作；辅助功能字号单列、动作可滚动。
- 永久 `NavigationSplitView` 拓扑，同一任务 ID 和共享清理状态；窄窗口显式“返回任务”，不按旧分组索引跳组。
- 27.1 availability 层读取真实 division/margins 与竖向工具栏；不硬编码折痕、物理尺寸或 Tab 高度。
- 根级 `DeletionCoordinator`：冻结集合、失效后二次核对、跨页单一提交/结果回写；已提交任务不提供虚假取消。新扫描清理旧完成快照。
- 删除说明改为原生 Form 独立段落；媒体保留资源 ID 与归一化缩放中心；真实换组明确清理旧模型结果。
- 截图继续使用命名 `XCTAttachment.keepAlways`，并保存一份 runner Documents/TestScreenshots 下的 PNG，避免结果包归档故障导致无法取出。

## 环境与安全

- Xcode 27.1 / 27A9275；Duo：`62A87288-C41F-42F7-981B-DD066ECC5CA8`，iOS 27.1 / 24A94232。
- 普通回归设备：iPhone 17 Pro / iOS 26.5，`642F2F40-1DF5-4C73-A382-494BBE4C53AB`。
- 实际产物 `DTSDKName=iphonesimulator27.1`、`MinimumOSVersion=18.0`、`UIDeviceFamily=[1]`；Info.plist 显式四方向。
- 所有 UI 自动化显式 `-TrueKeepDisablePhotoDeletion`；删除结果和模型推理均为 fixture，未删除系统照片、未访问用户真机图库。
- 已观察原生 Duo 当前显示的窗口：竖向诊断为 `382×644pt`，leading/trailing 安全边距 `0/84pt`。这不是硬编码设备规格，也不是内屏验收。

## 证据目录

### 关键截图快查

| 场景 | 证据 | 边界 |
| --- | --- | --- |
| Duo 删除确认完整安全说明 | [确认页](native-final-attachments/64FFFD5C-DE83-4041-9D06-D465DCEFE43B.png) | 原生当前窗口，可访问性检查通过；非内屏/折叠验证 |
| Duo 删除完成 | [完成态](native-back-attachments/F704092C-B98E-4343-917E-77872F3C4909.png) | 禁删 fixture，无真实 Photos 删除 |
| Duo 直接删除部分失败 | [失败项仍在](native-final-attachments/2714CC0A-6968-4463-AEE2-28F69FA7BE70.png) | 禁删 fixture |
| Duo 复核箱部分失败 | [复核箱失败项](native-final-attachments/17C47C5A-2F97-4BC0-A714-FA0973ED15FF.png) | 禁删 fixture |
| Duo 模型切组后旧结果清理 | [新组状态](native-final-attachments/6686C2C0-5471-4FAA-B841-6F787D69AA8A.png) | 模型 fixture，非真实推理 |
| 普通 iPhone 横屏报告失败/重试 | [横屏失败](fix-check-attachments/DF9F7CE2-D2AC-4158-96E3-C95E42C75AB9.png)、[重试成功](fix-check-attachments/7830E93D-D6F3-4D4D-88E5-50A80D793E10.png) | 确认实际窗口发生变化，但不是 Duo |
| Duo 方向请求未改变窗口 | [跳过证据](native-final-attachments/F5FAFB27-E169-4CC8-811D-E71A0994023A.png) | 明确 XCTSkip，不能计为通过 |

### 原始运行记录

- `baseline-home-native-duo.png`：改动前已安装的旧构建基线，不是新版本验收。
- `duo-delete-rotation.mp4`：直接删除和复核箱两条路径，方向请求及唯一提交结果；窗口未实际旋转，不是跨尺寸或折叠证据。`-clip.mp4` 是原片 32–67 秒连续片段，未拼接。
- `delete-attachments/manifest.json`：上述运行的 8 张命名截图映射。
- `duo-selection-rotation.mp4`：第二相似组选择和方向请求，窗口未实际旋转；`-clip.mp4` 是原片 28–39 秒连续片段，未拼接。
- `native-final-summary.json` / `native-final.log` / `native-final-attachments/manifest.json`：最终候选在原生 Duo 的 8 项专项测试，3 通过、5 跳过、0 失败。通过项为模型切组取消、删除确认可访问性、两条路径部分删除恢复。
- `native-back-summary.json` / `native-back-check.log` / `native-back-attachments/manifest.json`：同候选 Duo 删除菜单取消、再次确认、处理中、成功及返回任务，1/1 通过。
- `fix-check-summary.json` / `fix-check.log` / `fix-check-attachments/manifest.json`：同候选普通 iPhone 模型切组及真实横竖屏报告失败重试，2/2 通过；这不是 Duo 姿态测试。
- `iphone17-intermediate-recheck.log` / `native-intermediate-recheck.log`：中间复测保留。此前测试对顶部 NavigationBar、TabBar 和滚动区域的假设已修正；不可将这些旧失败计入最新专项结论，也不可隐藏它们。
- `build.log`、`openspec-check.log`、`script-tests.log`：最终候选编译、21/21 OpenSpec 和 25/25 Python 脚本测试记录。

候选标识：基于 `dev` / `2d05317` 加工作区修改，**不是已提交版本**。构建产物 SHA-256：

- `TrueKeep.app/TrueKeep.debug.dylib`：`e4488419551be4dfaa8ffea20095c097837f6fdcfee3199016e5345a9038083c`
- `TrueKeepUITests.xctest/TrueKeepUITests`：`aed2fb569a7f577f7a67f0122b8be916092486a3b520b0a22fd0c3ed9a808479`

### 最终结果

| 检查 | 结果 | 可核对记录 |
| --- | --- | --- |
| iPhone 17 Pro / iOS 26.5 完整回归 | 199/199 通过，0 失败、0 跳过；144 单元 + 55 UI | `iphone17-final-summary.json`、`iphone17-final.log` |
| 同构建 UI 截图 | 导出 115 张 PNG，保留用例与名称映射 | `iphone17-final-attachments/manifest.json` |
| 原生 Duo 专项 | 3 通过、5 跳过、0 失败 | `native-final-summary.json` |
| 原生 Duo 删除取消/再提交/返回 | 1/1 通过 | `native-back-summary.json` |
| 截图辅助函数修正后的 Duo 冒烟 | 1/1 通过 | `final-screenshot-smoke-summary.json` |
| Python 脚本测试 | 25/25 通过 | `script-tests.log` |
| OpenSpec 全仓严格/生命周期检查 | 21/21 通过 | `openspec-check.log` |
| 编译与差异检查 | build-for-testing、git diff --check 通过 | `final-harness-build.log` |

完整回归结果包：`/tmp/TrueKeepDuo-20261105-candidate7-full.xcresult`。五项窗口变化用例在普通 iPhone 上均通过实际尺寸变化断言；它们仍不能代替 Duo 折叠验收。

全量运行后仅给测试截图辅助函数补充 `@MainActor` 标注，未修改应用代码，应用二进制 SHA-256 保持上面的值。测试包新 SHA-256 为 `1a7393eb8a96702403dec1128fb7864923253eea3932c2a3de10109c11512da1`，补充编译和原生 Duo 截图冒烟通过，截图存于 `final-screenshot-smoke-attachments/`。不把这一次冒烟描述为第二次全量运行。

首轮日志已有 144/144 单元、5/5 新场景断言通过（不构成旋转覆盖，见上方更正），但设置 Dynamic Type 审查失败；该轮 Xcode 结果包收尾卡住且 SIGINT 未能正常完成，已结束该进程。原始日志保存在 `initial-focused.log`，不能把未完成的 xcresult 当成有效报告。后续独立删除录屏运行已正常完成，8 张附件成功导出。

首次全量 Duo 尝试在模型用例 setUp 使用旧 `app.tabBars.buttons` 查询时失败：Duo 的竖向栏不暴露为该类型；停止该轮并保留 `aborted-legacy-tab-locator.log`，现统一按按钮语义标签定位，不假设 Tab 的方向/AX 容器类型。

## 复现

```sh
xcodegen generate --spec iOS/TrueKeep/project.yml
xcodebuild build-for-testing -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep \
  -destination 'platform=iOS Simulator,id=62A87288-C41F-42F7-981B-DD066ECC5CA8' \
  -derivedDataPath /tmp/truekeep-duo-20261105 CODE_SIGNING_ALLOWED=NO
xcodebuild test-without-building -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep \
  -destination 'platform=iOS Simulator,id=62A87288-C41F-42F7-981B-DD066ECC5CA8' \
  -derivedDataPath /tmp/truekeep-duo-20261105 -parallel-testing-enabled NO \
  -collect-test-diagnostics never -resultBundlePath /tmp/TrueKeepDuo-new-run.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

## 未覆盖/发布阻断

Device Hub 桌面控制权限未开放，不能操作外/内屏切换、分屏、书本/桌面/帐篷姿态。当前公开 simctl/XCUIDevice 接口未发现姿态切换；不使用私有方法或把矩形缩放冒充折叠。后续在 Device Hub 人工执行 design.md 的 D01–D04 并保存实际窗口参数及录屏。

还需：D05 真正跨形态的扫描/模型/报告计数与删除连续性；真实本地照片/视频成功预览及播放/缩放；手动 VoiceOver、RTL、深浅色/减弱动态、小屏和 iOS 18 运行；内存/掉帧/首图性能对比。常规删除始终禁用，真实删除测试另需明确计划和授权。

实现边界：删除协调器目前保护同一进程内的请求、布局重排和结果回写，不提供进程被终止后的持久化删除事务日志。此类“上次提交结果未知”的专项恢复仍未实现/验收，不能用同进程防重复测试代替；对应 2.6/4.4 保持未完成。
