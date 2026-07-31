# 照片识别规格增量

## MODIFIED Requirements

### Requirement: 相似照片识别使用有边界的本地视觉信号

扫描器 MUST 在有边界的近期照片分类上限和较短创建时间窗口内，本地识别相似照片。当两张照片都具备可比较的 Vision feature print 时，扫描器必须优先使用 feature-print distance，而不是 pHash distance。当 feature print 不可用或不可比较时，扫描器可以回退到 pHash distance。

#### Scenario: Vision feature print 可用

- **当** 两张非截图照片落在相似时间窗口内
- **并且** 两张照片都有可比较的 Vision feature print
- **并且** 它们的 feature-print distance 在配置阈值内
- **则** 扫描器将它们分组为相似照片复核组

#### Scenario: Vision feature print 距离较远

- **当** 两张照片有可比较的 Vision feature print
- **并且** 它们的 feature-print distance 超出配置阈值
- **则** 扫描器不得再通过 pHash 兜底把它们分组

#### Scenario: Vision feature print 不可用

- **当** 一张或两张照片缺少可比较的 Vision feature print
- **并且** pHash distance 在配置阈值内
- **并且** 两张照片落在相似时间窗口内
- **则** 扫描器可以将它们分组为相似照片复核候选

### Requirement: 质量检测必须保守

扫描器 MUST 把模糊照片和疑似误拍检测作为低置信度复核辅助。扫描器必须通过本地质量评估做质量判断。如果 bundled Core ML 模型可用，扫描器应该使用该模型做质量评估。如果模型不可用或预测失败，扫描器必须使用确定性的本地启发式质量评分。

#### Scenario: Core ML 质量模型可用

- **当** bundled `TrueKeepPhotoQuality.mlmodelc` 模型可用
- **并且** 模型预测返回质量、模糊或误拍评分
- **则** 扫描器使用这些本地评分进行模糊和误拍复核分类

#### Scenario: Core ML 质量模型不可用

- **当** 没有 bundled 质量模型可用
- **则** 扫描器使用确定性的本地启发式质量评分
- **并且** 扫描继续执行，不向用户暴露模型加载错误

#### Scenario: 质量候选为低置信度

- **当** 质量评估将照片分类为模糊或疑似误拍
- **则** 该候选进入对应复核组
- **并且** 默认不得被选中删除

### Requirement: 识别保持本地且有边界

视觉识别 MUST 本地运行，不得请求网络回源的 iCloud 缩略图下载。Vision feature print 生成和质量评估必须只在视觉分类上限内、基于本地可用图像数据运行。

#### Scenario: 本地图像数据不可用

- **当** Photos 无法在不允许网络访问的情况下提供本地图像数据
- **则** 跳过该资源的 feature print 生成和质量评估
- **并且** 扫描继续处理其他可用资源
