# Global Codex Agents Guide

<!-- OPENSPEC:START -->
## OpenSpec 工作流

- 产品、行为、架构或用户可见流程变更前，先阅读 `openspec/AGENTS.md` 和相关规格。
- 大幅代码改动前，先在 `openspec/changes/<change-id>/` 下创建或更新 OpenSpec 变更。
- 实现范围必须跟对应变更的 `proposal.md`、`tasks.md` 和规格增量保持一致。
- 工作推进时同步更新任务清单；变更发布后再把规格增量合入正式规格并归档。
<!-- OPENSPEC:END -->

## Cross-Project Interaction Rules

- When implementing, reviewing, or testing user-triggered UI actions that may exceed 300ms, use the global `user-action-contract` skill. Keep project files limited to references and project-specific differences; the skill is the source of truth.

## Photo Cleaner Interaction Rules

- Treat TrueKeep / 留真 as a trust-first local photo cleanup app, not a one-click cleaner. Preserve the core flow: trust screen -> permission rationale -> local scan -> task review -> Review Bin / 复核箱 -> second deletion confirmation.
- Do not trigger the system Photos permission prompt before the app explains why access is needed, that processing is local, that uploads are not performed, and that cleanup candidates are never deleted automatically.
- Scans must produce review candidates only. Similar-photo, accidental-shot, and blurry-photo detections are low-confidence review aids unless product requirements explicitly raise their confidence.
- Long-running scan, rescan, thumbnail loading, import, deletion, and export actions must show action-local progress or status, avoid blocking unrelated navigation, and provide a recovery path for interrupted or failed work.
- Limited Photos Access is a valid state. Show that scan results may be incomplete and keep a path for the user to adjust access or continue with the available library subset.
- Organize cleanup results as user-understandable tasks, not raw technical buckets. Candidate review surfaces must show thumbnails where available, cleanup reasons, estimated storage impact when known, and recommended keep items.
- Default selections must be conservative: recommended keep items and low-confidence visual candidates should not be selected for deletion by default.
- The Review Bin is a pre-delete buffer, not a deleted-items list. Copy and state names must not imply that anything has already been removed before the final deletion confirmation succeeds.
- Destructive actions require an explicit second confirmation. The confirmation must summarize the affected item count, explain removal from the system Photos library, and call out iCloud Photos sync plus Recently Deleted recovery behavior.
- After deletion finishes, report succeeded, failed, and still-retained items. Failed items must remain recoverable in UI state with enough context for retry or manual review.
- UI tests and manual smoke paths must keep real Photos deletion disabled by default. Any destructive-device test needs an explicit approved plan and opt-in launch configuration.
- New or changed user-visible requirements must retain named screenshots in their automated-test artifacts. Capture at least the key success/result state and, when applicable, the failure or recovery state; use `XCTAttachment` with `keepAlways` for XCUITest and retain the AppClaw step report/screenshots for AppClaw runs.
- Accessibility is part of the interaction contract. Critical flows must support Dynamic Type without clipping, expose meaningful VoiceOver labels for candidate category, reason, and selection state, and keep touch targets usable.
