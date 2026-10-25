## MODIFIED Requirements

### Requirement: 相似照片识别使用有边界的本地视觉信号

扫描器 MUST 在有边界的近期照片分类上限和较短创建时间窗口内，本地识别相似照片。当推荐保留能力关闭时，扫描器 MAY 继续使用系统图片质量与可用的人脸拍摄质量进行内部质量比较，但 App MUST NOT 将比较结果作为推荐保留项暴露给用户，也 MUST NOT 让该结果影响默认选择、批量选择、预计空间、任务文案或无障碍语义。当两张照片都具备可比较的 Vision feature print 时，扫描器 MUST 优先使用 feature-print distance，而不是 pHash distance。当 feature print 不可用或不可比较时，扫描器 MAY 回退到 pHash distance。

#### Scenario: Vision feature print 可用

- **WHEN** 两张非截图照片落在相似时间窗口内
- **AND** 两张照片都有可比较的 Vision feature print
- **AND** 它们的 feature-print distance 在配置阈值内
- **THEN** 扫描器必须将它们分组为相似照片复核组
- **AND** App 不得展示推荐保留项或自动删除任何照片

#### Scenario: Vision feature print 距离较远

- **WHEN** 两张照片有可比较的 Vision feature print
- **AND** 它们的 feature-print distance 超出配置阈值
- **THEN** 扫描器不得再通过 pHash 兜底把它们分组

#### Scenario: Vision feature print 不可用

- **WHEN** 一张或两张照片缺少可比较的 Vision feature print
- **AND** pHash distance 在配置阈值内
- **AND** 两张照片落在相似时间窗口内
- **THEN** 扫描器可以将它们分组为相似照片复核候选
- **AND** App 不得因为内部质量比较而展示推荐保留项

#### Scenario: 照片超出时间窗口

- **WHEN** 照片视觉信号相似但超出相似时间窗口
- **THEN** 扫描器不得将它们分组为相似照片

#### Scenario: 相似组包含可比较的人脸照片

- **WHEN** 相似组成员具有 Vision 人脸拍摄质量结果
- **THEN** 扫描器可以在本地把总体图片质量作为主要内部比较信号，把人脸拍摄质量作为辅助信号
- **AND** App 不得向用户展示由该比较产生的推荐保留结果

#### Scenario: 人脸质量不可用

- **WHEN** 相似组成员没有可用的人脸拍摄质量
- **THEN** 扫描器可以继续使用总体图片质量完成内部比较
- **AND** App 不得向用户展示由该比较产生的推荐保留结果
