## ADDED Requirements

### Requirement: Duo 发布构建必须使用已验证的 SDK 与运行矩阵

声称支持 iPhone Duo 的发布构建 MUST 使用 iOS 27.1 或更高 SDK，并验证真实构建配置和 Duo 原生运行时行为。现有最低 iOS 18 支持 MUST 保持不变；新 API MUST 按其声明的系统可用性隔离，不得把构建 SDK 版本当作最低运行版本，也不得为 Duo 擅自开放 iPad/Mac 产品支持。

#### Scenario: 生成发布工程
- **WHEN** 使用 XcodeGen 生成 Duo 适配版本
- **THEN** App 和测试目标的最低系统保持 iOS 18，App 保持 iPhone 产品范围
- **AND** 实际构建产物的方向、SDK 与窗口支持经核验，不以模拟器机型存在代替验收

#### Scenario: 在旧系统启动
- **WHEN** App 在 iOS 18 等既有支持系统运行
- **THEN** 不执行不可用的 27.1 API，现有权限、扫描、复核和二次删除确认流程保持可用

#### Scenario: 只完成普通矩形窗口预览
- **WHEN** 尚未完成 Duo 原生模拟器的外屏、内屏和姿态切换验证
- **THEN** 只能声明完成布局预览或代码准备，不得声明已完整支持 Duo
