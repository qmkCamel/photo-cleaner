# 推荐保留手动覆盖 E2E 证据

- 验证日期：2026-08-25
- 基线：`dev@0c91316` 加本次未提交迭代
- 环境：Xcode 26.5，iPhone 17 Pro 模拟器，iOS 26.5（23F77）
- 完整回归：129/129 通过（97 个单元测试、32 个 UI 测试），0 失败、0 跳过
- 聚焦状态测试：3/3 通过
- 聚焦 UI E2E：1/1 通过
- 聚焦结果包：`/tmp/TrueKeepRecommendedKeepE2E-20260825-1721.xcresult`
- 完整结果包：`/tmp/TrueKeepRecommendedKeepFull-20260825-1725.xcresult`
- 删除安全：测试显式使用 `-TrueKeepDisablePhotoDeletion` 或禁用环境变量，没有执行真实 Photos 删除

| 状态 | 截图 |
| --- | --- |
| 推荐保留项被用户逐张选中；书签徽标与删除选择勾选同时可见，操作计数从 3 更新为 4 | `01-recommended-keep-selected.png` |
| 再次点击后取消删除选择；推荐书签仍保留，操作计数恢复为 3 | `02-recommended-keep-cleared.png` |

视觉检查确认两种状态下均无文字裁切、控件重叠或失效触控区域；推荐语义与删除选择语义可以独立识别。批量全选仍跳过推荐项，取消全选会清空当前组全部选择，包括用户手动选中的推荐项。
