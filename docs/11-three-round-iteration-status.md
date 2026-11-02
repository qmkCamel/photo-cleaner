# 三轮迭代状态（2026-10-09）

> 本文下面的 2026-10-09 数字是历史证据。2026-11-02 与 `origin/dev@da0618c` 合并时，媒体保留操作已统一为远端“确认保留”，不再提供更换推荐保留项或独立忽略记录。推荐功能继续关闭；本次验证记录见 [合并验收](../iOS/TrueKeep/TestArtifacts/2026-11-02-dev-integration/README.md)。

本轮从 `dev@af9597a` 开始。以下为代码与规格交付状态，不表示已经发布、完成真机验收或通过完整原生回归。

| 轮次 | OpenSpec | 已实现 | 待验收 |
| --- | --- | --- | --- |
| 一 | `harden-review-session` | 本地会话、30 天复核箱记录、事务式重扫、损坏文件备份重建、稳定详情、权限／相册协调、隐私声明、CI | 首次扫描授权用例修复，取消重扫／权限变化／删除后失效详情专项验收 |
| 二 | `add-media-review-decisions` | 完整构图预览、缩放切换、本地视频播放、保留项更换、整组保留与清除、选中容量 | 实际照片／视频手势与大字号，真实媒体预览成功截图 |
| 三 | `expand-scan-coverage` | 全范围分批、覆盖统计、有界视觉缓存、跨时间重复候选＋资源摘要、报告导出、标注评测工具 | 大图库真实准确率，普通／低电量冷／热缓存基准 |

## 验证证据

### kwai-mobile-mirror 补充回归（2026-10-09）

通过本机 kwai-mobile-mirror Workbench／MirrorService 执行现有 9 条 P0 YAML 流程，最终 8/9 通过。扫描取消用例仍断言旧标题，在点击取消前失败；候选复核取消、删除安全锁等其他 8 条通过。已保留 111 张步骤截图与 111 份 XML 并核验哈希，提取 9 张命名关键截图。该结果只覆盖声明的 UI 条件，不代表真实图库识别或真删除验收。见 [Mobile Mirror 报告](../iOS/TrueKeep/TestArtifacts/2026-10-09-mobile-mirror/README.md)。

### 权限开放后的实际运行（2026-10-09 21:03）

- 原 CoreSimulator／Preview 宏权限阻断已解除，完整应用与测试包构建成功。
- iPhone 17 Pro / iOS 26.5 模拟器：101/101 单元测试通过，32/33 UI 测试通过；总计 133/134 通过，整体 `xcodebuild test` 仍为失败（退出码 65）。
- 唯一失败：`testAuthorizedColdLaunchCanStartAndRepeatScanFromHome`，系统照片授权弹窗打断点击，返回首页断言失败。该用例模拟 `.authorized`，但仍调用真实扫描器，不能据此认定真实已授权用户的重扫失败；需补齐授权场景隔离并复测。
- 本轮新增的覆盖统计、预览不可读取／更换保留项、整组保留／清除记录、会话重启恢复四个 UI 用例全部通过。
- 保留 25 张原生测试命名截图，另从失败用例自动录屏提取 1 张授权弹窗现场；截图使用测试数据，不代表真实图库识别质量。
- [运行证据与截图索引](../iOS/TrueKeep/TestArtifacts/2026-10-09-regression/README.md)。完整 xcresult 已保存在同目录（按仓库规则忽略，不进入 Git），包含失败录屏和诊断附件。
- Python 22/22、发布静态预检 14 项通过／信息（0 失败）、OpenSpec 11/11 与生命周期检查再次通过。
- 真实删除保持禁用。实际媒体成功预览／视频手势、权限变化／失效详情专项验收、真实图库标注和真机性能仍待完成；三个变更不归档。

### 先前受限环境记录（已由上面的运行结果补充）

- Python 脚本回归：22/22 通过。
- 发布静态预检：14 项通过／信息，0 失败；外部 URL 和上架资料仍未完成，未运行 `--run-xcode`。
- OpenSpec：本机缓存 1.9.0 CLI 严格校验 11/11、生命周期检查通过。仓库 CI 当前固定 1.2.0；此次没有联网安装或修改固定版本。
- iOS 应用、单元测试及 UI 测试源码可通过类型检查；受限环境不允许启动 Preview 宏子进程，诊断时仅在临时副本移除了文件末尾 Preview 声明。
- 完整 `xcodebuild build` 已尝试，因 CoreSimulator 服务／asset catalog runtime 不可用及 Preview 宏进程权限失败，不能称为完整构建通过。
- `xcrun simctl list devices booted` 返回 CoreSimulatorService connection invalid；本轮未执行 XCTest 或 AppClaw，也没有新运行截图。
- 未执行真实 Photos 删除。没有采集或上传真实家庭照片。

## 可复现入口

```bash
python3 -m unittest discover -s iOS/TrueKeep/Scripts/tests -p 'test_*.py'
python3 iOS/TrueKeep/Scripts/release_preflight.py
zsh iOS/TrueKeep/Scripts/typecheck_without_previews.sh
python3 openspec/check.py
```

正常 Xcode 环境使用工程原有 `xcodebuild test`；新 CI 会保留完整 xcresult 和 `keepAlways` 截图。诊断类型检查不能替代它。性能和准确率流程见 `iOS/TrueKeep/RECOGNITION_BENCHMARK.md`。

三个变更暂留 active，待运行验收完成后再接受并归档。`expand-scan-coverage` 的归档应在既有 `refine-photo-analysis-pipeline` 之后，避免旧增量覆盖新扫描边界。
