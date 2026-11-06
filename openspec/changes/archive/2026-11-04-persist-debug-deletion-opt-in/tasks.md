## 1. 实现
- [x] 1.1 实现 Debug 授权持久化及显式禁删撤销，并保持 Release 行为。
- [x] 1.2 补充隔离偏好的回归测试与更新真机操作文档。

## 2. 验证
- [x] 2.1 聚焦单元测试、现有禁删 UI 用例及命名截图：11 单元 + 1 UI 全通过。
- [x] 2.2 编译安装真机，验证显式开启后无参数重启和偏好保留，不执行删除：两次读取专用偏好均为 true，重启后进程存在。
- [x] 2.3 严格校验 OpenSpec、diff 检查并记录结果：变更严格校验通过，release_preflight 14 passed/info、0 failed；详见 TestArtifacts/2026-11-04-deletion-persistence。
