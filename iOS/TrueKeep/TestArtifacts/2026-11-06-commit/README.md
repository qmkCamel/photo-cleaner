# 提交前校验（2026-11-06）

范围：此前尚未提交的 Debug 删除授权持久化、三轮交互优化、Duo 主体适配，以及对应 OpenSpec 和自动化证据。此记录不代表发布或完整 Duo 验收。

本轮重新执行：

- `xcodebuild build-for-testing`（iPhone 17 Pro 模拟器目标、Xcode 27.1、禁用签名）：通过，见 `build.log`。
- `python3 -m unittest discover -s iOS/TrueKeep/Scripts/tests -v`：25/25 通过，见 `script-tests.log`。
- `python3 openspec/check.py`（使用已安装 CLI）：21/21 严格校验及生命周期检查通过，见 `openspec-check.log`。
- `git diff --check` 和暂存差异检查通过。

本轮没有重跑 UI、操作真机或执行真实删除。重新构建的 `TrueKeep.debug.dylib` SHA-256 为 `e4488419551be4dfaa8ffea20095c097837f6fdcfee3199016e5345a9038083c`，与 2026-11-05 完整回归候选一致。此前 144 单元 + 55 UI 全部通过的报告、原生 Duo 3 通过/5 跳过/0 失败的专项报告及截图均保留于 [Duo 验证记录](../2026-11-05-duo/README.md)。

归档格式说明：提交前仅清理文本日志的行尾空白和多余文件尾空行，未删改诊断内容、失败记录或统计；截图与录屏保持原文件。三个新增规格文件同时去除多余尾空行。

仍未完成：完整 Duo 外/内屏及折叠形态、未知删除结果专项恢复、真实媒体/性能、最低 iOS 18 和人工读屏等验收。相关变更保持活跃，未因提交而归档。
