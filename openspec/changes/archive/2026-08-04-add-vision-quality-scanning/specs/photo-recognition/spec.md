# 照片识别规格增量

## MODIFIED Requirements

### Requirement: 相似照片识别使用有边界的本地视觉信号

扫描器 MUST 在有边界的近期照片分类上限和较短创建时间窗口内，本地识别相似照片，并使用系统图片质量与可用的人脸拍摄质量辅助推荐保留。当两张照片都具备可比较的 Vision feature print 时，扫描器 MUST 优先使用 feature-print distance，而不是 pHash distance。当 feature print 不可用或不可比较时，扫描器 MAY 回退到 pHash distance。

#### Scenario: Vision feature print 可用

- **当** 两张非截图照片落在相似时间窗口内
- **并且** 两张照片都有可比较的 Vision feature print
- **并且** 它们的 feature-print distance 在配置阈值内
- **则** 扫描器将它们分组为相似照片复核组
- **并且** 推荐一张保留项，但不得自动删除其他照片

#### Scenario: Vision feature print 距离较远

- **当** 两张照片有可比较的 Vision feature print
- **并且** 它们的 feature-print distance 超出配置阈值
- **则** 扫描器不得再通过 pHash 兜底把它们分组

#### Scenario: Vision feature print 不可用

- **当** 一张或两张照片缺少可比较的 Vision feature print
- **并且** pHash distance 在配置阈值内
- **并且** 两张照片落在相似时间窗口内
- **则** 扫描器可以将它们分组为相似照片复核候选

#### Scenario: 照片超出时间窗口

- **当** 照片视觉信号相似但超出相似时间窗口
- **则** 扫描器不得将它们分组为相似照片

#### Scenario: 相似组包含可比较的人脸照片

- **当** 相似组成员具有 Vision 人脸拍摄质量结果
- **则** 推荐保留排序应该以总体图片质量为主、人脸拍摄质量为辅
- **并且** 推荐保留项不得自动加入删除选择

#### Scenario: 人脸质量不可用

- **当** 相似组成员没有可用的人脸拍摄质量
- **则** 推荐保留排序必须继续使用总体图片质量

### Requirement: 识别保持本地且有边界

视觉识别 MUST 本地运行，不得请求网络回源的 iCloud 缩略图下载。Vision feature print 生成和质量评估 MUST 只在视觉分类上限内、基于本地可用图像数据运行。

#### Scenario: 本地图像数据不可用

- **当** Photos 无法在不允许网络访问的情况下提供本地图像数据
- **则** 跳过该资源的 feature print 生成和质量评估
- **并且** 扫描继续处理其他可用资源
