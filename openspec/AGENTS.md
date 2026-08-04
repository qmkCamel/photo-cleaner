# OpenSpec 使用说明

本仓库的产品、行为、架构和用户可见流程变更都使用 OpenSpec 管理。`openspec/config.yaml` 是 CLI 读取的 schema、项目上下文和制品规则来源；`openspec/project.md` 保留为便于人工阅读的项目概览。

OpenSpec 正文默认使用中文，但 CLI 解析依赖的固定标题和关键字必须保留英文。不要把 `Why`、`What Changes`、`Capabilities`、`Impact`、`ADDED Requirements`、`MODIFIED Requirements`、`REMOVED Requirements`、`Requirement`、`Scenario`、`MUST` 或 `SHALL` 翻译成中文。

## 工作流

1. 先阅读 `openspec/config.yaml`、`openspec/project.md` 和 `openspec/specs/` 下的相关正式规格。
2. 选择唯一、动词开头的变更编号，例如 `add-vision-quality-scanning`。
3. 按 `spec-driven` schema 创建 `proposal.md`、规格增量、需要时的 `design.md` 和分组编号的 `tasks.md`。使用 `openspec instructions <artifact> --change <change-id>` 获取当前模板。
4. 开始实现前运行 `openspec status --change <change-id> --json`，确认 apply 所需制品齐全；只实现提案和规格描述的范围。
5. 范围或实现决策变化时，先同步 proposal、design、规格增量和 tasks，再继续实现。
6. 完成聚焦测试和更广泛检查后更新任务状态，并运行 `openspec validate <change-id> --type change --strict --no-interactive`。
7. 归档前重新比较 `MODIFIED Requirements` 与当前 `openspec/specs/`。增量必须包含完整的最终 Requirement，禁止用陈旧增量覆盖后续已接受的规格。
8. 变更被接受或发布后运行 `openspec archive <change-id> --yes`，把增量合入正式规格并归档。新 capability 归档后必须把自动生成的 `TBD` Purpose 改成真实说明。
9. 最后运行 `python3 openspec/check.py`。已完成任务但仍停留在活跃目录的 change、不可解析的 proposal、严格校验失败或正式规格中的归档 `TBD` 都必须阻断交付。

## 制品格式

- Proposal 至少使用固定标题 `## Why`、`## What Changes`、`## Capabilities` 和 `## Impact`；标题下的内容使用中文。
- `Capabilities` 必须明确列出 New Capabilities 和 Modified Capabilities，名称与 `specs/<capability>/spec.md` 目录完全一致。
- 规格增量使用 `## ADDED Requirements`、`## MODIFIED Requirements`、`## REMOVED Requirements` 或 `## RENAMED Requirements`。
- 每条需求使用 `### Requirement:`，至少包含一个 `#### Scenario:`；正文使用明确的 `MUST` 或 `SHALL` 约束。
- `MODIFIED Requirements` 必须复制并更新完整 Requirement，包括所有仍然有效的场景；不能只写新增场景。
- Tasks 使用 `## 1. ...` 分组以及 `- [ ] 1.1 ...` 编号复选框，并保留可复现的验证记录。
- 跨模块、状态所有权、性能、安全、迁移或需要说明取舍的变更必须提供 `design.md`。

## 项目规则

- TrueKeep / 留真是信任优先的本地照片清理 app。AI 和启发式识别只产出复核候选。
- 不得弱化核心流程：信任页、权限说明、本地扫描、任务复核、复核箱、二次删除确认。
- 破坏性真机测试必须有明确 opt-in 和经过确认的计划。
- 长耗时用户操作还必须满足全局 `user-action-contract` 技能要求。
