import SwiftUI

struct ReviewGroupView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var state: CleanupFlowState
    @State private var showsDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deletionSuccessMessage: String?
    @State private var completedGroup: CleanupGroup?
    @State private var confirmedKeepFeedbackAssetID: String?

    private let photoDeletion: any PhotoLibraryDeleting
    var onAddedToReviewBin: () -> Void
    var onSetConfirmedKeep: (String, Bool) -> Void

    init(
        state: Binding<CleanupFlowState>,
        photoDeletion: any PhotoLibraryDeleting = SystemPhotoLibraryDeletionService(),
        onAddedToReviewBin: @escaping () -> Void,
        onSetConfirmedKeep: @escaping (String, Bool) -> Void = { _, _ in }
    ) {
        self._state = state
        self.photoDeletion = photoDeletion
        self.onAddedToReviewBin = onAddedToReviewBin
        self.onSetConfirmedKeep = onSetConfirmedKeep
    }

    var body: some View {
        let group = completedGroup ?? state.currentReviewGroup
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                VStack(spacing: 3) {
                    Text(group.title)
                        .font(TrueKeepTheme.Font.sectionTitle)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(group.subtitle)
                        .font(TrueKeepTheme.Font.caption)
                        .foregroundStyle(TrueKeepTheme.muted)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                if let deletionSuccessMessage {
                    SafetyNotice(title: "删除已完成", message: deletionSuccessMessage)
                }

                if let deletionErrorMessage = state.reviewGroupDeletionErrorMessage {
                    SafetyNotice(title: "删除未完成", message: deletionErrorMessage)
                }

                if let confirmedKeepFeedbackAssetID {
                    confirmedKeepFeedback(assetID: confirmedKeepFeedbackAssetID)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(group.candidates) { candidate in
                        candidateCell(candidate)
                        .gridCellColumns(candidate.recommendedKeep ? 3 : 1)
                    }
                }

                HStack {
                    Text(groupCountText(group))
                    Spacer()
                    Text("预计释放 \(group.estimatedBytes.formattedStorage)")
                }
                .font(TrueKeepTheme.Font.caption)
                .foregroundStyle(TrueKeepTheme.muted)

                SafetyNotice(title: "为什么标记这组？", message: group.explanation)

            }
            .padding(20)
            .padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom) {
            reviewActionsFooter
        }
        .navigationTitle(group.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .trueKeepScreenBackground()
        .sheet(isPresented: $showsDeleteConfirmation) {
            DeleteConfirmationSheet(
                count: state.currentReviewSelectionCount,
                isDeleting: isDeleting,
                onCancel: { showsDeleteConfirmation = false },
                onConfirm: { deleteSelectedAssets() }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(isDeleting)
        }
    }

    private var reviewActionsFooter: some View {
        let canToggleAll = completedGroup == nil
            && state.canToggleAllCandidatesInCurrentGroup
            && !isDeleting

        return VStack(spacing: 10) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    addToReviewBinButton
                    directDeleteButton
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        addToReviewBinButton
                        directDeleteButton
                    }

                    VStack(spacing: 10) {
                        addToReviewBinButton
                        directDeleteButton
                    }
                }
            }

            SecondaryActionButton(
                title: completedGroup == nil && state.areAllCandidatesInCurrentGroupSelected
                    ? "取消全选"
                    : "全选本组可清理项"
            ) {
                deletionSuccessMessage = nil
                state.toggleAllCandidatesInCurrentGroup()
            }
            .disabled(!canToggleAll)
            .opacity(canToggleAll ? 1 : 0.55)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.reviewAllInGroup.id)
            .accessibilityHint(
                state.areAllCandidatesInCurrentGroupSelected
                    ? "取消当前分组所有可清理项的选择"
                    : "选择当前分组所有可清理项，推荐保留项不会被选择"
            )

            if completedGroup == nil && (state.canMoveToPreviousReviewGroup || state.canMoveToNextReviewGroup) {
                HStack {
                    InlineTextActionButton(title: "上一组", minWidth: 64) {
                        deletionSuccessMessage = nil
                        state.moveToPreviousReviewGroup()
                    }
                    .disabled(!state.canMoveToPreviousReviewGroup)
                    .opacity(state.canMoveToPreviousReviewGroup ? 1 : 0.45)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.previousReviewGroup.id)

                    Spacer()

                    InlineTextActionButton(title: "下一组", minWidth: 64) {
                        deletionSuccessMessage = nil
                        state.moveToNextReviewGroup()
                    }
                    .disabled(!state.canMoveToNextReviewGroup)
                    .opacity(state.canMoveToNextReviewGroup ? 1 : 0.45)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.nextReviewGroup.id)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(TrueKeepTheme.page.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(TrueKeepTheme.line)
                .frame(height: 1)
        }
    }

    private func candidateCell(_ candidate: CleanupCandidate) -> some View {
        ZStack(alignment: .bottomLeading) {
            Button {
                deletionSuccessMessage = nil
                confirmedKeepFeedbackAssetID = nil
                state.toggleReviewCandidate(candidate)
            } label: {
                ThumbnailView(
                    style: candidate.thumbnail,
                    assetID: candidate.thumbnailAssetID,
                    isSelected: state.selectedCandidateIDs.contains(candidate.id),
                    isRecommendedKeep: candidate.recommendedKeep,
                    isConfirmedKeep: candidate.confirmedKeep,
                    showsSelectionIndicator: !candidate.confirmedKeep,
                    videoLabel: candidateVideoLabel(candidate)
                )
                .frame(maxWidth: .infinity)
                .frame(height: candidate.recommendedKeep ? 178 : 104)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(candidate.confirmedKeep || isDeleting)
            .accessibilityIdentifier(TrueKeepAccessibility.reviewCandidate(id: candidate.id))
            .accessibilityLabel(candidateAccessibilityLabel(candidate))
            .accessibilityHint(candidateAccessibilityHint(candidate))
            .accessibilityAddTraits(state.selectedCandidateIDs.contains(candidate.id) ? .isSelected : [])

            Menu {
                if candidate.confirmedKeep {
                    Button {
                        onSetConfirmedKeep(candidate.id, false)
                        confirmedKeepFeedbackAssetID = nil
                    } label: {
                        Label("取消确认保留", systemImage: "arrow.uturn.backward")
                    }
                } else {
                    Button {
                        confirmKeep(candidate)
                    } label: {
                        Label("确认保留，不再提醒", systemImage: "checkmark.shield")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(TrueKeepTheme.Font.iconCaption)
                    .foregroundStyle(TrueKeepTheme.ink)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .accessibilityIdentifier(TrueKeepAccessibility.reviewCandidateActions(id: candidate.id))
            .accessibilityLabel(candidate.confirmedKeep ? "管理已确认保留" : "更多照片操作")
            .accessibilityHint(candidate.confirmedKeep ? "可以取消确认保留" : "可以确认保留并在后续扫描中不再提醒")
            .help(candidate.confirmedKeep ? "管理已确认保留" : "更多照片操作")
        }
    }

    private func confirmedKeepFeedback(assetID: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(TrueKeepTheme.Font.iconMedium)
                .foregroundStyle(TrueKeepTheme.greenStrong)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("已确认保留")
                    .font(TrueKeepTheme.Font.cardTitle)
                    .foregroundStyle(TrueKeepTheme.ink)
                Text("这张照片不会再作为普通清理候选，仍可用于相似照片比较。")
                    .font(TrueKeepTheme.Font.caption)
                    .foregroundStyle(TrueKeepTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button("撤销") {
                onSetConfirmedKeep(assetID, false)
                confirmedKeepFeedbackAssetID = nil
            }
            .font(TrueKeepTheme.Font.inlineAction)
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(12)
        .background(TrueKeepTheme.greenSoft)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TrueKeepAccessibility.Control.confirmedKeepFeedback.id)
    }

    private func confirmKeep(_ candidate: CleanupCandidate) {
        deletionSuccessMessage = nil
        onSetConfirmedKeep(candidate.id, true)
        confirmedKeepFeedbackAssetID = candidate.id
    }

    private var addToReviewBinButton: some View {
        PrimaryActionButton(title: selectionActionTitle(empty: "选择项目后加入复核箱", selected: "加入复核箱")) {
            state.addCurrentSelectionToReviewBin()
            onAddedToReviewBin()
        }
        .disabled(completedGroup != nil || state.currentReviewSelectionCount == 0 || isDeleting)
        .opacity(completedGroup != nil || state.currentReviewSelectionCount == 0 || isDeleting ? 0.55 : 1)
        .accessibilityIdentifier(TrueKeepAccessibility.Control.addToReviewBin.id)
    }

    private var directDeleteButton: some View {
        DangerActionButton(title: selectionActionTitle(empty: "选择后直接删除", selected: "直接删除")) {
            showsDeleteConfirmation = true
        }
        .disabled(completedGroup != nil || state.currentReviewSelectionCount == 0 || isDeleting)
        .opacity(completedGroup != nil || state.currentReviewSelectionCount == 0 || isDeleting ? 0.55 : 1)
        .accessibilityIdentifier(TrueKeepAccessibility.Control.directDeleteSelection.id)
    }

    private func selectionActionTitle(empty: String, selected: String) -> String {
        state.currentReviewSelectionCount == 0
            ? empty
            : "\(selected)（\(state.currentReviewSelectionCount)）"
    }

    private func deleteSelectedAssets() {
        guard !isDeleting else { return }
        let assetIDs = state.selectedCurrentReviewAssetIDs
        guard !assetIDs.isEmpty else {
            showsDeleteConfirmation = false
            return
        }

        deletionSuccessMessage = nil
        isDeleting = true
        let photoDeletion = photoDeletion
        Task {
            let result = await photoDeletion.deleteAssets(withLocalIdentifiers: assetIDs)
            await MainActor.run {
                completedGroup = completedGroupSnapshot(for: result, from: state.currentReviewGroup)
                state.applyDirectDeletionResult(result)
                deletionSuccessMessage = directDeletionSuccessMessage(for: result)
                isDeleting = false
                showsDeleteConfirmation = false
            }
        }
    }

    private func directDeletionSuccessMessage(for result: PhotoDeletionResult) -> String? {
        let deletedCount: Int
        switch result {
        case .success(let deletedAssetIDs), .partial(let deletedAssetIDs, _, _):
            deletedCount = deletedAssetIDs.count
        case .failure:
            return nil
        }

        guard deletedCount > 0 else { return nil }
        return "\(deletedCount) 项已移入 Photos 的 Recently Deleted。返回首页时，任务数量、预计空间和预览会保持同步。"
    }

    private func completedGroupSnapshot(
        for result: PhotoDeletionResult,
        from group: CleanupGroup
    ) -> CleanupGroup? {
        let deletedAssetIDs: [String]
        switch result {
        case .success(let assetIDs), .partial(let assetIDs, _, _):
            deletedAssetIDs = assetIDs
        case .failure:
            return nil
        }

        guard !deletedAssetIDs.isEmpty else { return nil }
        let deletedIDs = Set(deletedAssetIDs)
        var snapshot = group
        snapshot.candidates.removeAll { deletedIDs.contains($0.id) }
        guard CleanupTaskBuilder.task(from: snapshot) == nil else { return nil }
        snapshot.subtitle = "\(snapshot.candidates.count) 项"
        return snapshot
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
            let recommendation = candidate.recommendedKeep ? "，系统推荐保留" : ""
            return "已确认保留\(recommendation)，\(candidate.category.title)，\(candidate.reason)"
        }
        let selectionState = state.selectedCandidateIDs.contains(candidate.id)
            ? "已选择删除"
            : "未选择删除"
        if candidate.recommendedKeep {
            return "推荐保留，\(selectionState)，\(candidate.category.title)，\(candidate.reason)"
        }
        return "\(selectionState)，\(candidate.category.title)，\(candidate.reason)"
    }

    private func candidateAccessibilityHint(_ candidate: CleanupCandidate) -> String {
        if candidate.confirmedKeep {
            return "不会加入删除选择；使用更多照片操作可以取消确认保留"
        }
        if candidate.recommendedKeep {
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
