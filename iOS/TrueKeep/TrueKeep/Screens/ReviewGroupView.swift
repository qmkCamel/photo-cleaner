import SwiftUI

struct ReviewGroupView: View {
    @ObservedObject private var localModels: LocalPhotoModelController
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.windowLayout) private var layout
    @ObservedObject private var deletion: DeletionCoordinator
    @Binding var state: CleanupFlowState
    var groupID: String?
    var onNavigate: (String) -> Void
    var onReturnToTasks: () -> Void
    @State private var previewCandidate: CleanupCandidate?
    private var isDeleting: Bool { deletion.isDeleting }
    private var deletionSuccessMessage: String? {
        deletion.resultSource == .group(groupID ?? state.currentReviewGroup.id) ? deletion.resultMessage : nil
    }
    private var completedGroup: CleanupGroup? { groupID.flatMap { deletion.completedGroups[$0] } }
    @State private var confirmedKeepFeedbackIDs: Set<String> = []

    var onAddedToReviewBin: () -> Void
    var onSetConfirmedKeep: (String, Bool) -> Void
    var onConfirmKeepGroup: (Set<String>) -> Void

    init(
        state: Binding<CleanupFlowState>,
        groupID: String? = nil,
        onNavigate: @escaping (String) -> Void = { _ in },
        onReturnToTasks: @escaping () -> Void = {},
        localModels: LocalPhotoModelController = .init(),
        deletion: DeletionCoordinator = .init(),
        onAddedToReviewBin: @escaping () -> Void,
        onSetConfirmedKeep: @escaping (String, Bool) -> Void = { _, _ in },
        onConfirmKeepGroup: @escaping (Set<String>) -> Void = { _ in }
    ) {
        self._state = state
        self.groupID = groupID
        self.onNavigate = onNavigate
        self.onReturnToTasks = onReturnToTasks
        self.localModels = localModels
        self.deletion = deletion
        self.onAddedToReviewBin = onAddedToReviewBin
        self.onSetConfirmedKeep = onSetConfirmedKeep
        self.onConfirmKeepGroup = onConfirmKeepGroup
    }

    private var displayedGroup: CleanupGroup? {
        if let completedGroup { return completedGroup }
        if let groupID { return state.reviewGroups.first { $0.id == groupID } }
        return state.reviewGroups.first { $0.id == state.currentReviewGroup.id }
    }

    var body: some View {
        Group {
        if let group = displayedGroup {
            groupContent(group)
                .fullScreenCover(item: $previewCandidate) { candidate in
                    MediaReviewView(candidates: group.candidates, initialID: candidate.id, onKeep: { id in
                        onSetConfirmedKeep(id, true)
                        confirmedKeepFeedbackIDs = [id]
                    })
                }
        } else {
            ContentUnavailableView("这组已处理完成", systemImage: "checkmark.circle", description: Text("请返回首页查看剩余任务。"))
        }
        }
        .navigationBarBackButtonHidden(!layout.usesSplitNavigation)
        .toolbar {
            if !layout.usesSplitNavigation {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onReturnToTasks) {
                        Label("返回任务", systemImage: "chevron.left")
                    }
                    .accessibilityIdentifier("review.return-to-tasks")
                }
            }
        }
    }

    private func groupContent(_ group: CleanupGroup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                groupNavigation(group)
                DeletionCancellationNotice(coordinator: deletion)
                Text(group.explanation)
                    .font(TrueKeepTheme.Font.caption)
                    .foregroundStyle(TrueKeepTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if let deletionSuccessMessage {
                    SafetyNotice(title: state.reviewGroupDeletionErrorMessage == nil ? "删除已完成" : "已完成部分删除", message: deletionSuccessMessage)
                }

                if let deletionErrorMessage = state.reviewGroupDeletionErrorMessage {
                    SafetyNotice(title: "删除未完成", message: deletionErrorMessage)
                }

                if !confirmedKeepFeedbackIDs.isEmpty {
                    confirmedKeepFeedback
                }

                AdaptivePhotoGrid {
                    ForEach(group.candidates) { candidate in
                        candidateCell(candidate)
                    }
                }

                let summaryLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                    : AnyLayout(HStackLayout())
                summaryLayout {
                    Text(groupCountText(group))
                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                    Text("本组预计可清理 \(group.estimatedBytes.formattedStorage)")
                }
                .font(TrueKeepTheme.Font.caption)
                .foregroundStyle(TrueKeepTheme.muted)


                if localModels.isEnabled, group.category != .largeVideos, completedGroup == nil {
                    LocalPhotoAnalysisSection(controller: localModels, group: group, isDeleting: isDeleting)
                }

                if layout.usesInlineActions { reviewActionsFooter }

            }
            .padding(20)
            .padding(.bottom, 12)
        }
        .clipped()
        .contentShape(Rectangle())
        .safeAreaInset(edge: .bottom) {
            if !layout.usesInlineActions { reviewActionsFooter }
        }
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu { directDeleteButton } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
                .accessibilityLabel("更多复核操作")
                .accessibilityIdentifier("review.more")
            }
        }
        .trueKeepScreenBackground()
    }

    private var reviewActionsFooter: some View {
        VStack(spacing: 4) {
            if completedGroup != nil {
                Text("这组已处理完成").font(TrueKeepTheme.Font.cardTitle)
                Text("请返回结果查看剩余任务。").font(TrueKeepTheme.Font.caption)
            } else {
                let selectionLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(spacing: 8))
                selectionLayout {
                    Text(state.currentReviewSelectionSummary)
                        .font(TrueKeepTheme.Font.bodySmall)
                        .foregroundStyle(TrueKeepTheme.muted)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                    if state.canToggleAllCandidatesInCurrentGroup {
                        Button {
                            state.toggleAllCandidatesInCurrentGroup()
                        } label: {
                            Text(state.areAllCandidatesInCurrentGroupSelected ? "取消全选" : "全选可清理项")
                                .font(TrueKeepTheme.Font.bodySmall.weight(.semibold))
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(TrueKeepTheme.greenStrong)
                        .disabled(isDeleting)
                        .accessibilityIdentifier(TrueKeepAccessibility.Control.reviewAllInGroup.id)
                    }
                }
                addToReviewBinButton
                if !remainingKeepIDs.isEmpty {
                    Button {
                        let ids = remainingKeepIDs
                        onConfirmKeepGroup(ids)
                        confirmedKeepFeedbackIDs = ids
                    } label: {
                        Text(state.currentReviewSelectionCount == 0 ? "全部保留" : "保留其余 \(remainingKeepIDs.count) 项")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TrueKeepTheme.greenStrong)
                    .disabled(isDeleting)
                    .accessibilityIdentifier("review.keep-group")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(TrueKeepTheme.page.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(TrueKeepTheme.line).frame(height: 1) }
    }

    private var remainingKeepIDs: Set<String> {
        Set((displayedGroup?.candidates ?? []).filter {
            !$0.confirmedKeep && !state.selectedCandidateIDs.contains($0.id)
        }.map(\.id))
    }

    private func groupNavigation(_ group: CleanupGroup) -> some View {
        HStack {
            Button {
                confirmedKeepFeedbackIDs = []
                state.moveToPreviousReviewGroup()
                onNavigate(state.currentReviewGroup.id)
            } label: {
                Label("上一组", systemImage: "chevron.left").labelStyle(.iconOnly).frame(width: 44, height: 44)
            }
            .disabled(isDeleting || completedGroup != nil || !state.canMoveToPreviousReviewGroup)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.previousReviewGroup.id)
            Spacer()
            Text(completedGroup != nil ? "本组已处理完成" : "第 \(state.currentReviewGroupIndex + 1) 组 / \(state.reviewGroups.count) 组")
                .font(TrueKeepTheme.Font.caption).foregroundStyle(TrueKeepTheme.muted)
                .accessibilityIdentifier("review.group-position")
            Spacer()
            Button {
                confirmedKeepFeedbackIDs = []
                state.moveToNextReviewGroup()
                onNavigate(state.currentReviewGroup.id)
            } label: {
                Label("下一组", systemImage: "chevron.right").labelStyle(.iconOnly).frame(width: 44, height: 44)
            }
            .disabled(isDeleting || completedGroup != nil || !state.canMoveToNextReviewGroup)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.nextReviewGroup.id)
        }
    }

    private func candidateCell(_ candidate: CleanupCandidate) -> some View {
        ZStack(alignment: .topTrailing) {
            Button { previewCandidate = candidate } label: {
                ThumbnailView(
                    style: candidate.thumbnail,
                    assetID: candidate.thumbnailAssetID,
                    isSelected: state.selectedCandidateIDs.contains(candidate.id),
                    isConfirmedKeep: candidate.confirmedKeep,
                    showsSelectionIndicator: false,
                    videoLabel: candidateVideoLabel(candidate)
                )
                .aspectRatio(1, contentMode: .fit)
                .contentShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .accessibilityIdentifier("review.preview.\(candidate.id)")
            .accessibilityLabel("预览，\(candidateAccessibilityLabel(candidate))，\(candidate.estimatedBytes > 0 ? candidate.estimatedBytes.formattedStorage : "大小未知")")
            .accessibilityHint("查看完整内容，不改变删除选择")
            .accessibilityAction(named: candidate.confirmedKeep ? "取消确认保留" : "确认保留") {
                onSetConfirmedKeep(candidate.id, !candidate.confirmedKeep)
                confirmedKeepFeedbackIDs = candidate.confirmedKeep ? [] : [candidate.id]
            }
            .contextMenu {
                Button(candidate.confirmedKeep ? "取消确认保留" : "确认保留，不再提醒") {
                    onSetConfirmedKeep(candidate.id, !candidate.confirmedKeep)
                    confirmedKeepFeedbackIDs = candidate.confirmedKeep ? [] : [candidate.id]
                }
            }
            if !candidate.confirmedKeep {
                Button {
                    state.toggleReviewCandidate(candidate)
                } label: {
                    Image(systemName: state.selectedCandidateIDs.contains(candidate.id) ? "checkmark.circle.fill" : "circle")
                        .font(TrueKeepTheme.Font.iconMedium)
                        .foregroundStyle(TrueKeepTheme.greenStrong)
                        .background(TrueKeepTheme.paper, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
                .accessibilityIdentifier(TrueKeepAccessibility.reviewCandidate(id: candidate.id))
                .accessibilityLabel(candidateAccessibilityLabel(candidate))
                .accessibilityHint("切换删除选择")
                .accessibilityAddTraits(state.selectedCandidateIDs.contains(candidate.id) ? .isSelected : [])
            }
        }
    }

    private var confirmedKeepFeedback: some View {
        HStack {
            Label("已确认保留 \(confirmedKeepFeedbackIDs.count) 项", systemImage: "checkmark.shield.fill")
                .font(TrueKeepTheme.Font.caption)
            Spacer(minLength: 8)
            Button("撤销") {
                let ids = confirmedKeepFeedbackIDs
                confirmedKeepFeedbackIDs = []
                for id in ids { onSetConfirmedKeep(id, false) }
            }.frame(minWidth: 44, minHeight: 44)
        }
        .foregroundStyle(TrueKeepTheme.greenStrong)
        .padding(.horizontal, 12)
        .background(TrueKeepTheme.greenSoft, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier(TrueKeepAccessibility.Control.confirmedKeepFeedback.id)
    }

    private var addToReviewBinButton: some View {
        PrimaryActionButton(title: selectionActionTitle(empty: "加入复核箱", selected: "加入复核箱")) {
            state.addCurrentSelectionToReviewBin()
            onAddedToReviewBin()
        }
        .disabled(completedGroup != nil || state.currentReviewSelectionCount == 0 || isDeleting)
        .accessibilityIdentifier(TrueKeepAccessibility.Control.addToReviewBin.id)
    }

    private var directDeleteButton: some View {
        Button(selectionActionTitle(empty: "删除所选项目…", selected: "删除所选"), role: .destructive) {
            deletion.prepare(source: .group(groupID ?? state.currentReviewGroup.id), assetIDs: state.selectedCurrentReviewAssetIDs)
        }
        .disabled(completedGroup != nil || state.currentReviewSelectionCount == 0 || isDeleting)
        .accessibilityIdentifier(TrueKeepAccessibility.Control.directDeleteSelection.id)
    }

    private func selectionActionTitle(empty: String, selected: String) -> String {
        state.currentReviewSelectionCount == 0
            ? empty
            : "\(selected)（\(state.currentReviewSelectionCount)）"
    }

    private func groupCountText(_ group: CleanupGroup) -> String {
        let confirmedKeepCount = group.candidates.filter(\.confirmedKeep).count
        let reviewCount = group.candidates.count - confirmedKeepCount
        if confirmedKeepCount > 0 {
            return "\(reviewCount) 项待复核 · \(confirmedKeepCount) 项已确认保留"
        }
        switch group.category {
        case .largeVideos:
            return "\(group.candidates.count) 个视频"
        case .similar, .screenshots, .accidental, .blurry:
            return "\(group.candidates.count) 张照片"
        }
    }

    private func candidateVideoLabel(_ candidate: CleanupCandidate) -> String? {
        candidate.category == .largeVideos ? candidate.estimatedBytes.formattedStorage : nil
    }

    private func candidateAccessibilityLabel(_ candidate: CleanupCandidate) -> String {
        if candidate.confirmedKeep {
            let recommendation = candidate.isRecommendedKeepActive ? "，系统推荐保留" : ""
            return "已确认保留\(recommendation)，\(candidate.category.title)，\(candidate.reason)"
        }
        let selectionState = state.selectedCandidateIDs.contains(candidate.id)
            ? "已选择删除"
            : "未选择删除"
        if candidate.isRecommendedKeepActive {
            return "推荐保留，\(selectionState)，\(candidate.category.title)，\(candidate.reason)"
        }
        return "\(selectionState)，\(candidate.category.title)，\(candidate.reason)"
    }

    private func candidateAccessibilityHint(_ candidate: CleanupCandidate) -> String {
        if candidate.confirmedKeep {
            return "不会加入删除选择；使用更多照片操作可以取消确认保留"
        }
        if candidate.isRecommendedKeepActive {
            return "系统建议保留；仍可切换删除选择，或使用更多照片操作确认保留"
        }
        return "切换删除选择；或使用更多照片操作确认保留"
    }
}

#Preview {
    NavigationStack {
        ReviewGroupView(
            state: .constant(.sample()),
            onAddedToReviewBin: {}
        )
    }
}
