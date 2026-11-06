## Why

用户已明确开启真机真实删除，但 Debug 授权仅由启动参数控制，桌面重开后恢复安全锁，打断手动验收。

## What Changes

- 将明确的 Debug 真实删除授权保存到本机应用偏好，普通重启继续生效。
- 显式禁删参数或环境变量优先，并撤销已保存授权；首次安装仍默认禁删。
- 不更改二次确认、系统 Photos 权限、删除 API 或 Release 行为；不执行真实照片删除测试。

## Capabilities

### New Capabilities
- `debug-deletion-authorization`: Debug 真机删除授权的持久化与撤销。

### Modified Capabilities
- 无。

## Impact

影响 PhotoDeletionSafetyPolicy、聚焦单元测试和真机操作文档。使用现有 UserDefaults 隐私声明；无网络、账户或照片内容持久化变更。
