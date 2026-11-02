# kwai-mobile-mirror 安全回归（2026-10-09）

## 结论

**9 条 P0 流程：8 通过、1 失败，不能称为全绿。**

- 使用本机 `kwai-mobile-mirror` 的 `master@f9fedbc`，版本 `0.1.0-alpha.2`，运行前工作区干净。
- 入口为该工程 `scripts/mobile-mirror-cli.mjs test job`，由 Workbench／MirrorService 持有 Appium 会话，报告 engine 为 `AppClaw 2.7.0 · MirrorService`。没有用其他 MCP 安装包或 XCUITest 结果冒充本次结果。
- 目标为 iPhone 17 Pro / iOS 26.5 模拟器，安装前一轮完整构建的当前未提交 TrueKeep Debug 包；不是已发布版本，也不是真机测试。
- 每条 case 使用独立 session 和 `cases.json` 中原启动参数；必须包含 `-TrueKeepDisablePhotoDeletion`，并注入 `TRUEKEEP_DISABLE_PHOTO_DELETION=1`。没有执行真实 Photos 删除。
- 不启用 AI recovery，不改产品代码或原始 AppClaw YAML，不更新视觉基线。

## 结果表

| 场景 | 结果 | 关键截图 |
| --- | --- | --- |
| 授权说明与暂不授权 | PASS | [结果](screenshots/trust-intro-skip-result.png) |
| 隐私与安全详情 | PASS | [结果](screenshots/settings-trust-details-result.png) |
| 复核箱二次确认与删除安全锁 | PASS | [安全锁拦截](screenshots/review-bin-deletion-safety-result.png) |
| 权限拒绝后重试／恢复 | PASS | [结果](screenshots/permission-denied-retry-result.png) |
| 扫描取消／恢复 | FAIL | [失败现场](screenshots/scan-cancel-recovery-failure.png) |
| 候选复核离页继续／返回／取消 | PASS | [取消恢复](screenshots/candidate-refinement-continuity-result.png) |
| 有限权限结果重扫 | PASS | [结果](screenshots/limited-results-rescan-result.png) |
| 时间范围选择 | PASS | [结果](screenshots/scan-date-range-selection-result.png) |
| 删除成功后首页同步（夹具） | PASS | [结果](screenshots/post-deletion-home-sync-result.png) |

## 唯一失败：旧用例标题未同步

`scan-cancel-recovery` 第 3 步断言“正在扫描你的相册”，当前 `ScanProgressView` 粗筛阶段标题为“正在快速分析照片”。实际截图可见扫描进度和取消按钮，但用例在点击取消前停止。

这证明原用例需要维护，不能据此断言取消功能失败，也不能将这条完整流程算通过。候选复核阶段的取消恢复通过，不替代粗筛取消的独立验收。建议后续以稳定阶段 identifier 配合状态断言更新旧用例，再复跑；本轮未改原用例。

## 适配过程与证据保留

原 9 条用例来自 `iOS/TrueKeep/AppClaw/cases.json` 及 `flows/`。Workbench 要求受限 header、扁平 step 数组及结构化 selector，因此执行前做了以下转换：

- 按原顺序拼接 setup、steps、assertions；删除仅用于描述的 header 字段。
- `waitUntil`／`waitUntilGone` 转为 `{target, timeout}`，保留等待预算。
- 字符串 selector 转为结构化 selector；原 AppClaw 字符串断言在 `run-yaml-flow.js` 使用不区分大小写的包含匹配，转换后显式保留 `contains`。
- “重扫按钮位于首页上方”的空间断言转为 `above` 关系，不删除此断言。

首次适配误用了精确匹配，导致整段隐私文案及带后缀任务 ID 的假失败。这些初始尝试保留在本目录各 case 子目录；暂停后让当前受管 job 正常取消／清理，再在 `semantic-rerun/` 完整重跑 9 条。最终结果仅引用完整语义复验，不把初始适配错误计为产品缺陷，也不覆盖原失败记录。

- `verified-results.json`：最终各 run ID、原 verdict、失败步骤及证据校验结果。
- `semantic-rerun/summary.json`：各 job 退出码及总耗时（包含启动／清理，不是 App 性能数据）。
- `flows/`：实际执行的 9 份结构化 YAML，可用于 Workbench 复现。
- `screenshots/`：9 张按场景命名的关键结果／失败截图。
- `semantic-rerun/<case>/runs/<runId>/`：原生 manifest、计划、每步 PNG／XML、执行日志；本地保留并被 `.gitignore` 忽略，避免将私有会话元数据与运行时密钥提交。
- 最终 9 个 run 共 111 个已记录步骤，其中 110 通过、1 失败；保留 111 张 PNG 与 111 份 XML，全部 222 份步骤附件均重新校验字节数及 SHA-256。
- Headless managed job 的录像为 `not-performed`，没有声称生成视频。

## 复现方式

在工作台创建相应受信项目，登记本目录 `flows/` 下用例；每条 flow 建立同名单用例 suite。私有 runtime config 仅授权对应 suite／flow、`ios` 和 `app.truekeep.ios`。每条私有 connection 使用 `cases.json` 中同名用例的启动参数，并保留双重禁用真实删除配置。

```sh
node /absolute/path/to/kwai-mobile-mirror/scripts/mobile-mirror-cli.mjs test job <case-id> \
  --config /private/path/runtime.json \
  --connection /private/path/connection.json \
  --report-dir /private/path/new-report
```

连接文件含本机设备标识，不放入源码。每次使用新报告目录保留原始结果。运行后应同时检查 jobExitCode、suiteExitCode、manifest verdict 和证据完整性，不能只看命令是否受理。

## 验收边界

所有 run 的 verificationScope 为 `declared-ui-assertions`，businessVerification 和 visualVerification 均为 `not-performed`。截图经过人工抽查不等同于确定性视觉基线断言；夹具删除成功页面不代表真实资源已删除。

这次没有重跑 101 项单测、33 项 XCUITest、22 项 Python 测试。它们的上一轮状态另见 [完整测试清单](../../../../docs/12-test-inventory.md)。真实媒体、标注图库准确率、真机性能及真删除仍需独立验收。
