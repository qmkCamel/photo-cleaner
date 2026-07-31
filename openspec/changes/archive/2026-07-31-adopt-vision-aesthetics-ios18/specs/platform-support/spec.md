## ADDED Requirements

### Requirement: TrueKeep 最低支持 iOS 18

原生 App、单元测试和 UI 测试 MUST 以 iOS 18 或更高版本为最低部署目标，以统一使用系统图片美学评分能力。

#### Scenario: 生成 Xcode 工程

- **当** 使用仓库中的 XcodeGen 配置生成工程
- **则** 所有 iOS target 的 deployment target 必须为 iOS 18.0

#### Scenario: 运行照片质量扫描

- **当** App 在受支持系统上扫描本地照片
- **则** 扫描器可以直接调用 iOS 18 Vision 图片美学评分 API
- **并且** 不需要保留 iOS 17 的系统版本分支
