# 识别质量与性能评测

自动化默认禁用真实删除。不要为了采集指标删除照片、改变 iCloud 配置或下载原图。

## 数据与流程

1. 在授权的本地测试相册准备包含横竖图、全景、暗光纪念照、儿童连拍、跨日期字节副本、重新编码副本、Live Photo 和本地不可用资源的数据。至少覆盖 701 张非截图照片及混入截图的情况。
2. 人工标注 `truth.json`，字段为 `name`、`assetIDs`、`similarGroups`、`exactGroups`、`blurry`、`accidental`。分组用本地资源 ID 数组，单类分组不能重叠；不确定样本先讨论定标，不把模型建议当真值。
3. 完成扫描后、执行保留／删除决定前，点击“导出本次复核报告”，保存为 `prediction.json`。报告不含像素，但含本地资源标识，请仅保存在受控测试目录。
4. 执行 `python3 iOS/TrueKeep/Scripts/evaluate_recognition.py --truth truth.json --prediction prediction.json`。记录 pair precision/recall 和误拍／模糊 precision/recall；无分母输出 null，不能解读为 100%。

## 性能矩阵

同一图库分别记录普通模式和低电量模式、冷缓存和热缓存。每组至少三次，记录设备型号、iOS 版本、相册规模、Photos 授权、算法版本、耗时、缓存命中、不可读取和候选复核数量。报告的内存是批次边界采样的 resident memory 最大值，不是 Instruments 精确峰值；正式性能验收仍需 Instruments。

验收至少确认：低电量不再丢弃旧上限后的照片；取消保留旧会话；编辑资源后缓存失效；离开预览暂停视频；相同内容跨日期可以通过资源摘要确认，重新编码但视觉近似的内容不能称为精确重复。

## 本轮执行状态

尚未采集真实家庭图库标注和真机普通／低电量基准。当前环境无法访问 CoreSimulator；不得把脚本自测、类型检查或历史截图作为本轮真机／UI 验收证据。
