## Why

缩略图勾选不足以判断画面和视频内容，用户无法纠正推荐保留或记住已经决定保留的照片。

## What Changes

- 提供本地全屏照片预览、缩放、前后切换和视频播放。
- 分离预览和勾选操作，单项及整组保留统一写入远端已有的“确认保留”记录。
- 复用设置中的确认保留管理入口，修正选中容量统计。
- 非目标：不下载 iCloud 原图、不自动删除、不增加账号。

## Capabilities

### New Capabilities
- `media-review`: 可操作预览和可撤销的保留决定。
### Modified Capabilities
- 无；沿用 add-confirmed-keeps 和 disable-recommended-keeps 的最新约束，不恢复系统推荐保留。

## Impact

影响复核页、复核箱、预览服务、持久化快照和 UI 回归。
