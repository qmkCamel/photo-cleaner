# 接入 Vision Feature Print 和质量评分

## 摘要

把当前相似照片的 pHash-only 路径升级为优先使用 Vision feature print 相似度；同时引入 Core ML-ready 的照片质量评分路径，用于模糊和疑似误拍复核候选。

## 动机

当前视觉分类器是保守实现，依赖缩略图 pHash、亮度、饱和度和边缘清晰度启发式。Vision feature print 能更稳地处理轻微曝光、构图和连拍差异。Core ML 质量评分接口为后续模糊、低质量识别模型提供清晰接入点，同时保留确定性的本地规则兜底。

## 范围

- 为有边界的本地视觉扫描输入生成 Vision image feature print。
- 相似照片分组优先使用 feature-print distance；feature print 不可用时回退 pHash。
- 新增可加载 `TrueKeepPhotoQuality.mlmodelc` 的 Core ML-ready 质量评分器。
- 没有 bundled 模型或预测失败时，保留启发式质量评分。
- 所有视觉结果仍只作为复核候选。
- 增加 feature print 分组、兜底行为、质量评分和保守默认值的聚焦单元测试。

## 非目标

- 不引入云端 AI 或 Apple Intelligence 依赖。
- 不做自动删除决策。
- 不新增网络访问。
- 不新增破坏性真机测试路径。
- 除非后续单独提供训练好的模型资产，否则本变更不包含 `.mlmodel` 文件。

## 风险

- Vision feature print 阈值需要后续用真实照片库校准。
- 在提供训练模型资产前，Core ML 评分仍是可插拔接入路径。
- feature print 生成会增加本地 CPU/Neural Engine 工作量，必须保留现有扫描上限和取消机制。
