# 本地模型接入验证

原始验证日期：2026-10-25。基线：`dev` / `a554bab`，加当时未提交的模型接入改动。未安装手机、未读取私人照片、未执行真实删除。2026-10-26 的提交前复验见文末。

## 环境与边界

- Mac：Apple M2 Pro，32 GiB 物理内存，macOS 26.3.1。
- 工具：Xcode 26.5（17F42）、Swift 6.3.2，已安装 Metal Toolchain。
- UI：iPhone 17 Pro 模拟器，iOS 26.5（23F77）。
- 真实推理输入：仓库 `TrueKeep/Resources/Assets.xcassets/LogoMark.imageset/logo-mark.png`。
- 输入 SHA-256：`7622dd6e35691410605e3983a0959d31b78dba7f5e57711e4b93182fa563f72a`。
- UI 使用明确标记的 fixture；它不验证模型输出质量。Mac smoke 使用真实下载并校验的权重，不能代表手机性能或照片准确率。

## 结果

| 项目 | 结果 |
| --- | --- |
| 模型契约测试 | 10/10：固定目录、JSON/短描述边界、SHA/尺寸、断网重试、取消清理、移除范围、隐私声明 |
| App 单元测试 | 113/113，包含 5 个模型控制器测试与已有清理/删除/权限测试 |
| 模型 UI 测试 | 4/4：进行中选择、成功、失败保留、切换模型、移除、下载取消、导航、取消分析、分组失效、最大字体 |
| iOS Debug 模拟器 | 构建与测试通过 |
| iPhone Release | `generic/platform=iOS`，`CODE_SIGNING_ALLOWED=NO`，构建通过；不是安装或真机验收 |
| 打包检查 | 安装包约 45 MB；包含 Metal shader 与模型包隐私清单，不包含权重 |
| 本变更 OpenSpec | `add-local-photo-models --strict` 通过 |
| 全库 OpenSpec | 12 通过、1 既有变更失败，见下文 |

结构化测试摘要见 `xctest-summary.json`，模型契约原始输出见 `model-contract-tests.log`。最终运行使用 `/tmp/truekeep-local-models-delivery.xcresult`；xcresult 本体不提交。

## 真实模型 Smoke

两次记录都通过 `/usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)'` 禁止进程网络访问。
记录的接口计时包含模型加载与单图生成；进程墙钟还包含启动开销。此前已运行过推理，不能当作冷启动基准或 P50/P95。

| 模型 | 固定 revision | 接口计时 | 进程墙钟 | 峰值 footprint | 最大 RSS |
| --- | --- | --- | --- | --- | --- |
| Qwen3.5-0.8B MLX 4-bit | `da28692b5f139cb0ec58a356b437486b7dac7462` | 1.70 秒 | 3.16 秒 | 1,440,089,600 B | 838,729,728 B |
| Gemma 4 E2B MLX 4-bit | `238767527555cb75a05732a84dff5d6ba0dd6809` | 3.32 秒 | 3.50 秒 | 4,258,860,296 B | 3,804,725,248 B |

指标来自 macOS `/usr/bin/time -l`，不是 iPhone 峰值或 MLX 专属显存指标。原始结果保存在 `qwen-offline-smoke.log`、`gemma-offline-smoke.log`。

Qwen 最初两版 JSON 提示出现缺 `uncertain` 和语法不完整，严格解析正确拒绝。最终 `observations-v2` 使用单句描述适配、强制不确定；没有猜测或修补畸形 JSON。Gemma 继续使用严格 JSON。两个输出只证明模型文件、视觉预处理、tokenizer、推理与结果适配链路可用，不证明观察准确。

## 截图

所有截图来自 `XCTAttachment`，设置 `keepAlways`；这些是合成测试输出。

| 文件 | 覆盖点 |
| --- | --- |
| `local-model-01-running-selection-responsive.png` | 分析进行中仍可改变照片选中状态 |
| `local-model-02-success-fixture.png` | 成功报告，不自动选中照片 |
| `local-model-03-failure-retains-result.png` | 第二次分析失败，保留上一份报告 |
| `local-model-04-gemma-settings.png` | 切换到 Gemma，显示体积与固定版本 |
| `local-model-05-download-complete-fixture.png` | 下载完成，跨 tab 导航可用 |
| `local-model-06-analysis-cancelled.png` | 用户取消分析，恢复可操作状态 |
| `local-model-07-group-change-discards-pending.png` | 切换分组使旧分析失效 |
| `local-model-08-accessibility-settings.png` | 最大辅助字体，模型名完整可读 |
| `local-model-09-accessibility-actions.png` | 最大辅助字体，移除动作与说明可滚动访问 |

大字体测试使用正确的 `UICTContentSizeCategoryAccessibilityXXXL`；另用 `simctl ui ... content_size accessibility-extra-extra-extra-large` 确认实际效果，结束后已恢复模拟器原值 `large`。测试从既有授权首页入口进入设置。

## 运行方式

从仓库根目录执行，所有 xcodebuild 命令设置 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`：

```sh
swift test --package-path iOS/TrueKeep/Packages/LocalPhotoModels --scratch-path /tmp/truekeep-model-build
xcodebuild test -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'platform=iOS Simulator,id=A4D51039-1C35-4C22-A93B-3668154302C6' -derivedDataPath /tmp/truekeep-model-ios -only-testing:TrueKeepTests -only-testing:TrueKeepUITests/LocalPhotoModelsUITests -parallel-testing-enabled NO -resultBundlePath /tmp/truekeep-local-models-delivery.xcresult
xcodebuild build -project iOS/TrueKeep/TrueKeep.xcodeproj -scheme TrueKeep -destination 'generic/platform=iOS' -configuration Release -derivedDataPath /tmp/truekeep-model-device CODE_SIGNING_ALLOWED=NO
openspec validate add-local-photo-models --strict
python3 openspec/check.py
git diff --check
```

模型构建与断网 smoke 命令见 `docs/12-local-photo-models.md`。模型下载单独执行，两款模型均完成 SHA-256 校验；下载权重位于 `/tmp/truekeep-qwen-weights` 和 `/tmp/truekeep-model-weights`，未加入仓库。

## 尚未完成

1. iPhone 16 Plus 真机测试：尚未收到本轮安装授权，未安装；仍需签名测试构建、至少约 4.3 GB 权重空间，以及连续分析/取消/内存/发热测量。不得推断 Mac 数值就是手机数值。
2. 经用户许可的照片集和独立标注：未执行 100–200 组质量评估，不恢复推荐保留。
3. 许可与发布审计：所选 Gemma 量化制品的许可标注与上游不同，正式分发前须确认；本次只验证模型包隐私资源被正确打包，不代表所有依赖的发布审计完成。
4. 原始验证报告的 OpenSpec 既有问题：`refine-photo-analysis-pipeline` 的 MODIFIED 块遗漏正式规格同名场景，包含三个 `Vision feature print` 场景及 `本地图像数据不可用`。2026-10-26 使用 CI 固定的 OpenSpec 1.2.0 全库检查通过；本次未改写该既有变更，CLI 通过不代替归档前的场景完整性审查。
5. 附带发现：既有欢迎页在系统最大辅助字体下，“了解更多”可能超出可见区域。本次模型设置页已独立验证，未扩大范围修改欢迎页。
6. 完成目标 iPhone 验收与发布审计后，再合入本变更正式规格并归档。2026-10-25 验证阶段未提交代码；2026-10-26 按用户要求整理提交，隐私清单修复与模型接入分开提交，未完成项继续保留。

## 2026-10-26 提交前复验

- Python 脚本测试：`python3 -m unittest discover -s iOS/TrueKeep/Scripts/tests -v`，21/21 通过，使用带 Pillow 的 Python 3.12 环境。
- 模型包测试：`swift test --package-path iOS/TrueKeep/Packages/LocalPhotoModels --scratch-path /tmp/truekeep-model-build --skip-update`，10/10 通过。
- App 与界面回归：沿用上文 `xcodebuild test` 的测试范围与模拟器，增加 `-disableAutomaticPackageResolution`，结果写入 `/tmp/truekeep-commit-validation-20261026.xcresult`；113 个单元测试及 4 个模型 UI 测试全部通过，9 张命名截图通过 `keepAlways` 保留。结构化摘要见 `commit-validation-xctest-summary.json`。
- OpenSpec：使用与 CI 相同的 `@fission-ai/openspec@1.2.0`，`openspec validate add-local-photo-models --type change --strict --no-interactive` 与 `python3 openspec/check.py` 均通过；全库 13/13。
- 工程文件及两份隐私清单通过 `plutil -lint`。
- 发布预检：`python3 iOS/TrueKeep/Scripts/release_preflight.py`，13 项通过或提示、1 项失败。隐私清单修复通过；唯一失败仍为既有 `PhotoLibraryScanner.swift` 的 `import CryptoKit` 命中旧源码扫描规则，当前用于 SHA-256 文件指纹。本次未改变该规则，也未将其视为发布检查通过。
- 本轮不重新下载权重或运行真实模型推理，不安装真机；上文的离线 Mac smoke、无签名 Release 构建与原始截图仍为 2026-10-25 的证据。
