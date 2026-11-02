## Why

重扫和冷启动会丢失复核箱，权限变更后状态陈旧，删除后详情可能指向失效分组；发布检查与实际 API 使用不一致。

## What Changes

- 持久化本地复核会话，重扫采用成功后替换，失败和取消保留旧结果。
- 以分组 ID 解析详情，协调删除、前台权限和相册变化。
- 修正 UserDefaults 隐私声明和 SHA-256 检查，增加原生回归 CI。
- 非目标：不自动删除照片，不执行真实破坏性测试，不发布商店版本。

## Capabilities

### New Capabilities
- `review-session`: 本地会话恢复、权限协调和发布保障。

### Modified Capabilities
- 无；现有导航约束保持有效。

## Impact

影响 AppRootView、CleanupFlowState、复核箱、Photos 服务、隐私清单和自动化。磁盘只保存本地资源标识和复核元数据，不保存照片原始内容。
