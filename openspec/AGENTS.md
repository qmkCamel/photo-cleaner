# OpenSpec 使用说明

本仓库的产品、行为、架构和用户可见流程变更都使用 OpenSpec 管理。

后续所有项目的 OpenSpec 内容都使用中文撰写；除非某个工具强制要求固定英文关键字，否则 proposal、tasks、spec、design 和归档说明都保持中文。

## 工作流

1. 先阅读 `openspec/project.md` 和 `openspec/specs/` 下的相关规格。
2. 选择唯一、动词开头的变更编号，例如 `add-vision-quality-scanning`。
3. 创建 `openspec/changes/<change-id>/proposal.md`、`tasks.md`，并在 `openspec/changes/<change-id>/specs/<capability>/spec.md` 写规格增量。
4. 只实现变更描述中的范围；如果范围变化，先更新 proposal 和 tasks。
5. 使用聚焦测试和该变更要求的更广泛检查完成验证。
6. 变更被接受或发布后，把增量合入 `openspec/specs/`，再归档该变更。

## 规格格式

- 变更增量使用 `## 新增需求`、`## 修改需求` 或 `## 移除需求`。
- 每条需求至少包含一个 `#### 场景：` 小节。
- 需求使用明确的约束词，例如“必须”“不得”“应该”“可以”。
- 规格聚焦行为；复杂实现细节只在必要时写入 `design.md`。

## 项目规则

- TrueKeep / 留真是信任优先的本地照片清理 app。AI 和启发式识别只产出复核候选。
- 不得弱化核心流程：信任页、权限说明、本地扫描、任务复核、复核箱、二次删除确认。
- 破坏性真机测试必须有明确 opt-in 和经过确认的计划。
- 长耗时用户操作还必须满足全局 `user-action-contract` 技能要求。
