# Debug 真实删除授权持久化验收

日期：2026-11-04（Asia/Shanghai）。代码基础：dev `2d05317` 加本次未提交变更。

## 结果

- PhotoDeletionResultTests：11/11 通过，覆盖参数/环境变量授权、重建 UserDefaults 后读取、显式禁删撤销及冲突优先级、Release 隔离。
- UI：testReviewFlowDeleteSafetyLockAndRestoreSelection 1/1 通过。使用模拟器 fixture、显式禁删，未删除真实照片。
- 命名截图保存在 screenshots，manifest.json 对应 XCTest 附件；禁删结果和复核箱恢复均使用 keepAlways。
- Debug 真机包 BUILD SUCCEEDED，已安装到连接的 iPhone 16 Plus。
- 首次带 `-TrueKeepEnableDestructivePhotoDeletion` 及对应环境变量启动，读取 `TrueKeepDebugDestructivePhotoDeletionEnabled` 为 true。
- 使用 `devicectl device process launch --terminate-existing app.truekeep.ios` 无额外参数重启，偏好仍为 true，TrueKeep 进程存在。
- 未执行任何真实照片删除；未收集照片内容。完整应用偏好仅临时用于核对，不纳入仓库。
- release_preflight：14 passed/info，0 failed。OpenSpec 变更严格校验、git diff --check 通过。

## 本机原始证据

- 测试结果：`/tmp/TrueKeepDeletionPersistence-20261104.xcresult`
- 测试日志：`/tmp/TrueKeepDeletionPersistence-20261104-tests.log`
- 截图复跑结果：`/tmp/TrueKeepDeletionPersistence-screenshots-20261104.xcresult`，1/1 UI 用例通过；首轮编译开始后补入截图语句，因此以复跑附件为准。
- 构建日志：`/tmp/TrueKeepDeletionPersistence-20261104-build.log`

## 复现

运行 PhotoDeletionResultTests 和 TrueKeepUITests/testReviewFlowDeleteSafetyLockAndRestoreSelection。手动设备授权仅用于用户明确请求的删除验收；恢复安全模式时使用 `-TrueKeepDisablePhotoDeletion` 启动一次，会撤销持久授权。正常自动化继续禁删。
