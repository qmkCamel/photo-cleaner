# 项目概览

TrueKeep / 留真是一个 iOS 照片清理 app，重点是信任、本地处理和可复核的清理流程。

## 产品原则

- 在触发系统照片权限弹窗前，先解释为什么需要访问照片。
- 当前产品范围内扫描必须本地完成，不上传照片或视频。
- 视觉识别只作为复核辅助，不作为自动删除决策。
- 默认选择必须保守：推荐保留项和低置信度候选默认不选中删除。
- 破坏性删除必须经过复核箱和二次确认。
- 有限照片访问是有效状态，必须说明扫描结果可能不完整。

## 技术背景

- 平台：`iOS/TrueKeep` 下的 iOS SwiftUI app。
- 最低部署版本：iOS 17.0。
- Xcode 项目：`iOS/TrueKeep/TrueKeep.xcodeproj`。
- 项目生成源：`iOS/TrueKeep/project.yml`，但当前环境没有安装 `xcodegen`。
- 本地扫描入口：`TrueKeep/Services/PhotoLibraryScanner.swift`。
- 单元测试：`TrueKeepTests`。
- UI 测试：`TrueKeepUITests`。

## 工程约定

- 行为变更尽量覆盖聚焦单元测试。
- 视觉清理分类必须面向用户理解，不能暴露为原始模型桶。
- 扫描工作必须有边界并可取消。
- 扫描、重新扫描、缩略图加载、导入、导出和删除动作必须有局部进度状态。
- 默认测试和 smoke 路径不得执行真实照片删除。
