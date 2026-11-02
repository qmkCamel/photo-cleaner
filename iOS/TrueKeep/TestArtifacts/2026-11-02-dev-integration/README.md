# 本地三轮迭代与远端 dev 合并验收

日期：2026-11-02（Asia/Shanghai）。本地 `dev` 从 `af9597a` 快进至 `da0618c`，再协调未提交的三轮改动。下文记录提交前的验收快照；本报告随代码提交，未安装到真机。

## 保留与协调范围

- 保留本地会话恢复、30 天复核箱记录过期、成功后替换的重扫、稳定分组导航、媒体预览、全范围分批扫描、缓存和覆盖报告。
- 采用远端 ConfirmedKeepStore，预览及整组保留统一进入已有确认保留管理；删除选择、复核箱、恢复快照与重扫结果均应用最新保护记录。
- `recommendedKeepEnabled` 保持 false，不恢复推荐覆盖、preferredKeepIDs 或 ignoredAssetIDs。保留远端直接删除二次确认和本地模型实验入口。
- 本轮不迁移未发布的旧会话 schema；新快照版本 2，无法读取旧快照时保留原文件及重建恢复路径。
- 原工作区（包括未跟踪文件）备份在 stash `5ffd317efd6c004e6627c40aa8b4bcbd3e8e0ff9`，未删除备份。

## 验证进度

- Python：25/25 通过，使用 Codex 已有 Python 依赖环境；系统 Python 缺少 Pillow，未修改全局环境。
- 发布静态检查：14 项通过／信息，0 失败；不代表发布或真机验收。
- OpenSpec：16/16 严格校验通过，生命周期检查通过。
- 完整应用及测试包构建通过，原生单测 126/126 通过，其中合并相关 ReviewIterationTests 13/13。见 [单测摘要](unit-summary.json)；完整包保存在本目录 `unit.xcresult`（Git 忽略）。
- iPhone 17 Pro / iOS 26.5 模拟器关键 UI 回归 7/7 通过，0 跳过；保留 15 张语义命名截图。见 [UI 摘要](ui-summary.json)、[运行日志](ui-xcodebuild.log) 与 [附件清单](screenshots/manifest.json)。完整包保存在本目录 `ui.xcresult`（Git 忽略）。
- 提交前检查：Git 无未解决冲突，`git diff --check` 通过，基线 HEAD 与 origin/dev 一致（0 ahead / 0 behind）。

## UI 回归与截图

| 场景 | 结果 | 关键证据 |
| --- | --- | --- |
| 覆盖统计与不可读取计数 | 通过 | [覆盖报告](screenshots/scan-coverage-with-local-unavailable.png) |
| 直接删除安全锁失败后保留选择 | 通过 | [失败保留](screenshots/direct-delete-06-failure-preserved.png) |
| 直接删除模拟成功与首页同步 | 通过 | [完成反馈](screenshots/direct-delete-04-success.png)、[首页同步](screenshots/direct-delete-05-home-synced.png) |
| 整组确认保留与设置清除 | 通过 | [整组保留](screenshots/review-entire-group-kept.png)、[清除完成](screenshots/review-confirmed-keeps-cleared.png) |
| 预览不可读取与确认保留 | 通过 | [不可读取](screenshots/media-preview-local-unavailable.png)、[确认保留](screenshots/review-preview-confirmed-keep.png) |
| 推荐关闭、相似组零默认选择与手动选择 | 通过 | [默认状态](screenshots/recommended-keep-disabled-similar-review.png)、[手动选择](screenshots/recommended-keep-disabled-manual-selection.png) |
| 复核箱跨启动恢复 | 通过 | [恢复前](screenshots/review-session-before-relaunch.png)、[恢复后](screenshots/review-session-restored-after-relaunch.png) |

本轮不是完整 UI 套件验收。历史首次扫描授权弹窗用例未重测，真实照片／视频成功预览、权限变化专项、真实图库准确率和真机性能仍待验收，三轮变更不归档。

## 原生验证命令

使用锁定依赖和缓存：`xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=642F2F40-1DF5-4C73-A382-494BBE4C53AB' -derivedDataPath /tmp/truekeep-merge-cached-20261102 -skipPackageUpdates -disableAutomaticPackageResolution -only-testing:TrueKeepTests CODE_SIGNING_ALLOWED=NO`。

UI 用例均使用 `-TrueKeepDisablePhotoDeletion` 和样例数据，截图使用 `XCTAttachment.keepAlways`。不测试真实 Photos 删除，不把 fixture 结果认作真实图库准确率或真机性能。

UI 使用同一 destination 与 derivedDataPath，运行 `test-without-building -parallel-testing-enabled NO`，选择本表对应的 7 个 `TrueKeepUITests/TrueKeepUITests/test...` 方法；完整调用记录见运行日志首行。
