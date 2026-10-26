# 本地照片模型实验

## 范围

Qwen3.5-0.8B 与 Gemma 4 E2B 使用独立于 `PhotoQualityScoring` 的 `PhotoSemanticAnalyzing` 异步接口。
两个模型共用 MLX 后端，固定模型配置定义仓库、revision、文件尺寸和 SHA-256。
业务页面不引用 MLX 类型。后续替换权重需要更新目录配置、预处理/提示词适配并重跑评测；替换推理框架则实现相同协议。

- `PhotoSemanticAnalyzing`：图片字节输入、异步进度、统一观察报告输出。
- `ModelFileInstalling`：安装目录、下载、移除，与推理实现分离，可独立替换。
- `LocalPhotoModelController`：业务状态与取消/过期保护，不直接调用 MLX。
- `MLXPhotoSemanticAnalyzer`：Qwen 使用有长度上限的单句描述，适配为 `uncertain=true`；Gemma 使用严格 JSON。当前提示词版本为 `observations-v2`。

Qwen 的初始真实测试出现缺失字段和畸形 JSON，因此没有采用“自动修复 JSON”或填入默认确定性。短描述本身仍可能不准确，界面始终标记无法可靠判断。

本功能默认关闭，不改变 Vision 扫描，不恢复推荐保留，不改变选中项、确认保留或删除确认。
本次提供逐张观察，不声称实现组内排名、多图关系推理或质量提升。

## 入口

- 设置 -> 本地模型实验 -> 开启 -> 选择模型 -> 确认下载。
- 下载需要网络，可能使用移动数据。下载请求只包含公开模型文件路径，不携带照片或 Photos ID。
- 复核页点击“分析前 N 张照片”。每次最多四张，按当前显示顺序，仅处理本地可读照片，不请求 iCloud 原图下载。
- 可取消任务、重新分析；失败保留同一组上次有效结果。切换分组、离开复核页、删除或关闭功能会取消旧分析并清除旧结果。
- 设置可移除模型。权重保存在 Application Support/TrueKeep/LocalModels，排除备份；照片和观察不落盘。
- 下载取消或失败会清理暂存文件。强制退出后，下一次下载同一模型会清理其未完成暂存并重新下载，不支持断点续传。
- 本地报告包含模型版本与耗时，不使用模型自报置信度作为准确率。

## 固定依赖与制品

| 项目 | 版本 |
| --- | --- |
| mlx-swift-lm | 3.32.3，禁用 FoundationModelsIntegration trait |
| mlx-swift | 0.32.3 |
| swift-transformers | 1.3.0 |
| Qwen MLX 4-bit | `mlx-community/Qwen3.5-0.8B-4bit` @ `da28692b5f139cb0ec58a356b437486b7dac7462` |
| Gemma MLX 4-bit | `mlx-community/gemma-4-e2b-it-4bit` @ `238767527555cb75a05732a84dff5d6ba0dd6809` |

Qwen 全部文件约 652 MB，Gemma 约 3.58 GB。这是 MLX 制品，不是 LiteRT 制品大小。
实验定位为 6 GB / 8 GB 级别设备，按系统可见物理内存至少 5 GiB / 7 GiB 筛选，预留硬件保留内存差异；这只是初步准入检查，不保证不会触发内存压力，仍需真机测量。
单张最多输出 256 tokens，输入缩放至 512 级别，批量上限四张；不后台自动扫描整个相册。
生成阶段每次收到输出片段时检查 90 秒限时；这不是模型加载或 GPU prefill 的硬超时。取消期间保持 busy，等待实际计算结束，不假装已完成取消。

Swift Package 和 Xcode workspace 均保留 `Package.resolved`，本次验证了 12 个远程依赖 pin 与实际构建 revision 一致。
模型包独立隐私清单声明本地空间预检和文件元数据访问；其资源已验证进入 Release 安装包。使用理由参见 [Apple Required Reason API](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)。原 App 隐私清单的本轮既有修改未覆盖。

权重来自 MLX Community 的量化转换，不等同于模型作者直接发布的制品。
原始 [Qwen 模型卡](https://huggingface.co/Qwen/Qwen3.5-0.8B) 与 [Gemma 模型卡](https://huggingface.co/google/gemma-4-E2B-it) 标注 Apache-2.0。
所选 [Gemma 量化制品页面](https://huggingface.co/mlx-community/gemma-4-e2b-it-4bit) 标注 `gemma`，与上游标注不同，正式发布前必须确认该制品许可及分发义务；实验界面保留实际制品许可链接，不擅自把它改标为 Apache。

## 验证命令

本机需要 Xcode 26 系列、Swift 6.2+ 与 Metal Toolchain。命令可通过 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 指定 Xcode，无需修改全局 xcode-select。

```sh
swift test --package-path iOS/TrueKeep/Packages/LocalPhotoModels
swift run -c release --package-path iOS/TrueKeep/Packages/LocalPhotoModels local-model-smoke install qwen3.5-0.8b /tmp/truekeep-qwen-weights IMAGE_PATH
```

真实推理需要 Xcode 构建包含 Metal shader 的 `local-model-smoke` scheme；纯 `swift run` 不编译 shader，不能用来验收推理。在 package 目录内先解析并列出 scheme，再构建：

```sh
cd iOS/TrueKeep/Packages/LocalPhotoModels
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme local-model-smoke -destination 'platform=macOS' -configuration Release -derivedDataPath /tmp/truekeep-model-mac
```

回到仓库根目录后，调用生成的工具。可以用进程沙箱禁止联网，明确检查推理不触发下载：

```sh
LLVM_PROFILE_FILE=/tmp/truekeep-smoke.profraw /usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)' /tmp/truekeep-model-mac/Build/Products/Release/local-model-smoke analyze qwen3.5-0.8b /tmp/truekeep-qwen-weights iOS/TrueKeep/TrueKeep/Resources/Assets.xcassets/LogoMark.imageset/logo-mark.png
```

Gemma 使用 `gemma4-e2b` 与独立测试缓存目录。`install` 只下载并校验；`analyze` 只读本地制品，不自动补下载。
smoke 可用项目自带 Logo，不能把这种加载/输出验证当作个人照片准确率评测。
CLI 可显式设置 `TRUEKEEP_MODEL_SMOKE_OUTPUT=1` 查看原始输出，仅用于获准测试素材。App 不设置该诊断回调，不记录私人照片描述。

`LocalPhotoModelsUITests` 使用双开关 `-TrueKeepUITestLocalModels` 和 `-TrueKeepDisablePhotoDeletion` 注入明确标记的 fixture，保留进行中交互、成功、失败与下载状态截图。Release 不编译 fixture 实现。

## 本次验证

2026-10-25：模型契约 10 项、App 单元 113 项、模型 UI 4 项通过；模拟器 Debug 与 iPhone Release 编译通过。两个真实模型均完成禁止联网的 Mac smoke；没有读取私人照片或执行删除，没有安装到手机。

完整环境、命令、指标、截图与边界见 [验证记录](../iOS/TrueKeep/TestArtifacts/2026-10-25-local-photo-models/README.md)。

## 发布前仍需验证

- 目标 iPhone 上真实权重的成功率、峰值内存、P50/P95 时延、取消响应和持续发热。
- 经许可的照片样本集与独立标注；比较 Vision 与模型观察的误导率和无法判断比例。
- 两个制品的许可确认，以及固定版本依赖的发布隐私清单审计。
- 不因协议测试、fixture UI 或 Mac smoke 通过而开启推荐保留。
