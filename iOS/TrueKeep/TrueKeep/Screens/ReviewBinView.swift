import SwiftUI
import UIKit

struct ReviewBinView: View {
    @Binding var state: CleanupFlowState
    @State private var showsDeleteConfirmation = false
    @State private var isDeleting = false

    private let photoDeletion: any PhotoLibraryDeleting

    init(
        state: Binding<CleanupFlowState>,
        photoDeletion: any PhotoLibraryDeleting = SystemPhotoLibraryDeletionService()
    ) {
        self._state = state
        self.photoDeletion = photoDeletion
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if state.reviewBinItems.isEmpty {
                    emptyState
                } else {
                    reviewBinContent
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !state.reviewBinItems.isEmpty {
                    reviewBinActionsFooter
                }
            }
            .navigationTitle("复核箱")
            .navigationBarTitleDisplayMode(.inline)
            .trueKeepScreenBackground()
            .sheet(isPresented: $showsDeleteConfirmation) {
                DeleteConfirmationSheet(
                    count: state.reviewBinItems.filter(\.selectedForDelete).count,
                    isDeleting: isDeleting,
                    onCancel: { showsDeleteConfirmation = false },
                    onConfirm: { deleteSelectedAssets() }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(isDeleting)
            }
        }
    }

    private var selectedCount: Int {
        state.reviewBinItems.filter(\.selectedForDelete).count
    }

    private var reviewBinContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(selectedCount) 项 · \(state.reviewBinItems.map { $0.candidate.estimatedBytes }.reduce(0, +).formattedStorage)")
                .font(TrueKeepTheme.Font.caption)
                .foregroundStyle(TrueKeepTheme.muted)
                .frame(maxWidth: .infinity, alignment: .center)

            if let deletionSummary = state.deletionSummary {
                PhotoDeletionSummaryNotice(summary: deletionSummary)
            }

            SafetyNotice(
                title: state.deletionSummary == nil ? "尚未删除任何内容" : "剩余项目尚未删除",
                message: state.deletionSummary == nil
                    ? "复核箱中的项目只会在你确认后移除。"
                    : "以下项目仍在复核箱中，可重试删除或返回继续复核。"
            )

            if let deletionErrorMessage = state.deletionErrorMessage {
                SafetyNotice(title: "删除未完成", message: deletionErrorMessage)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(state.reviewBinItems) { item in
                    Button {
                        state.toggleReviewBinItem(item)
                    } label: {
                        ThumbnailView(
                            style: item.candidate.thumbnail,
                            assetID: item.candidate.thumbnailAssetID,
                            isSelected: item.selectedForDelete,
                            videoLabel: item.candidate.category == .largeVideos ? item.candidate.estimatedBytes.formattedStorage : nil
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 108)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(TrueKeepAccessibility.reviewBinItem(id: item.id))
                    .accessibilityLabel(reviewBinItemAccessibilityLabel(item))
                    .accessibilityHint(item.selectedForDelete ? "轻点可从删除选择中取消" : "轻点可重新选择删除")
                    .accessibilityAddTraits(item.selectedForDelete ? .isSelected : [])
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("删除安全清单")
                    .font(TrueKeepTheme.Font.cardTitle)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                SafetyCheckRow("项目仍在复核箱，还没有删除")
                SafetyCheckRow("你可以逐张复核每一项")
                SafetyCheckRow("删除后仍可从 Recently Deleted 恢复")
                SafetyCheckRow("未经确认不会影响 iCloud")
            }
            .padding(13)
            .background(TrueKeepTheme.yellowSoft)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.yellowLine))

            Text("复核箱项目仅本地保存 30 天。")
                .font(TrueKeepTheme.Font.caption)
                .foregroundStyle(TrueKeepTheme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .padding(.bottom, 12)
    }

    private var reviewBinActionsFooter: some View {
        HStack(spacing: 10) {
            SecondaryActionButton(title: "恢复选中") {
                state.restoreSelectedReviewBinItems()
            }
            .disabled(selectedCount == 0 || isDeleting)
            .opacity(selectedCount == 0 || isDeleting ? 0.55 : 1)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.restoreReviewBinSelection.id)

            DangerActionButton(title: "删除选中（\(selectedCount)）") {
                showsDeleteConfirmation = true
            }
            .disabled(selectedCount == 0 || isDeleting)
            .opacity(selectedCount == 0 || isDeleting ? 0.55 : 1)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.deleteReviewBinSelection.id)
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

    private func deleteSelectedAssets() {
        guard !isDeleting else { return }
        let assetIDs = state.selectedReviewBinAssetIDs
        guard !assetIDs.isEmpty else {
            showsDeleteConfirmation = false
            return
        }

        isDeleting = true
        let selectedCandidatesByID = Dictionary(
            uniqueKeysWithValues: state.reviewBinItems
                .filter(\.selectedForDelete)
                .map { ($0.id, $0.candidate) }
        )
        let photoDeletion = photoDeletion
        Task {
            let result = await photoDeletion.deleteAssets(withLocalIdentifiers: assetIDs)
            await MainActor.run {
                state.applyDeletionResult(result)
                isDeleting = false
                showsDeleteConfirmation = false
                UIAccessibility.post(
                    notification: .announcement,
                    argument: deletionAnnouncement(
                        for: result,
                        selectedCandidatesByID: selectedCandidatesByID
                    )
                )
            }
        }
    }

    private func deletionAnnouncement(
        for result: PhotoDeletionResult,
        selectedCandidatesByID: [String: CleanupCandidate]
    ) -> String {
        switch result {
        case .success(let deletedAssetIDs):
            let bytes = estimatedBytes(for: deletedAssetIDs, candidatesByID: selectedCandidatesByID)
            return "删除完成，\(Set(deletedAssetIDs).count) 项已移至最近删除，约 \(bytes.formattedStorage)。这些项目仍可恢复，空间可能尚未立即释放。"
        case .partial(let deletedAssetIDs, let failedAssetIDs, let message):
            let bytes = estimatedBytes(for: deletedAssetIDs, candidatesByID: selectedCandidatesByID)
            return "部分删除完成，成功 \(Set(deletedAssetIDs).count) 项，约 \(bytes.formattedStorage)，失败 \(Set(failedAssetIDs).count) 项。\(message)"
        case .failure(_, let message):
            return "删除未完成。\(message)"
        }
    }

    private func estimatedBytes(
        for assetIDs: [String],
        candidatesByID: [String: CleanupCandidate]
    ) -> Int64 {
        Set(assetIDs)
            .compactMap { candidatesByID[$0]?.estimatedBytes }
            .reduce(0, +)
    }

    private func reviewBinItemAccessibilityLabel(_ item: ReviewBinItem) -> String {
        let status = item.selectedForDelete ? "已选择删除" : "未选择删除"
        let candidate = item.candidate
        return "\(status)，\(candidate.category.title)，\(candidate.reason)，预计释放 \(candidate.estimatedBytes.formattedStorage)"
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: state.hasDeletedItems ? "checkmark.shield" : "tray")
                .font(TrueKeepTheme.Font.iconHero)
                .foregroundStyle(TrueKeepTheme.green)
                .padding(.top, 92)
            Text(state.hasDeletedItems ? "复核箱已清空" : "复核箱为空")
                .font(TrueKeepTheme.Font.sheetTitle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text(state.postDeletionRecoveryMessage ?? "复核时加入的候选会先出现在这里。删除前，你仍可以逐张确认。")
                .font(TrueKeepTheme.Font.bodySmall)
                .foregroundStyle(TrueKeepTheme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .padding(.bottom, TrueKeepTheme.tabScrollBottomPadding)
    }
}

private struct SafetyCheckRow: View {
    var title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(TrueKeepTheme.Font.iconCaption)
                .foregroundStyle(TrueKeepTheme.green)
            Text(title)
                .font(TrueKeepTheme.Font.caption)
                .foregroundStyle(Color(red: 0.220, green: 0.318, blue: 0.290))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DeleteConfirmationSheet: View {
    var count: Int
    var isDeleting: Bool
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Capsule()
                    .fill(TrueKeepTheme.line)
                    .frame(width: 42, height: 5)
                    .frame(maxWidth: .infinity)

                Text("删除前再确认一次")
                    .font(TrueKeepTheme.Font.sheetTitle)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("这 \(count) 项照片或视频会从系统照片图库移除。删除后通常可以在 Recently Deleted 中恢复。")
                    .font(TrueKeepTheme.Font.bodySmall)
                    .foregroundStyle(TrueKeepTheme.ink)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                SafetyNotice(
                    title: "iCloud Photos 风险",
                    message: "如果你开启了 iCloud Photos，删除可能会同步到 iCloud 和其他设备。请不要立即清空 Recently Deleted。"
                )

                VStack(spacing: 10) {
                    DangerActionButton(
                        title: isDeleting ? "正在请求系统删除..." : "确认删除 \(count) 项",
                        isBusy: isDeleting,
                        action: onConfirm
                    )
                    .disabled(isDeleting)
                    .opacity(isDeleting ? 0.72 : 1)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.confirmPhotoDeletion.id)
                    SecondaryActionButton(title: "返回复核", action: onCancel)
                        .disabled(isDeleting)
                        .opacity(isDeleting ? 0.55 : 1)
                        .accessibilityIdentifier(TrueKeepAccessibility.Control.cancelPhotoDeletion.id)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview {
    ReviewBinView(state: .constant({
        var state = CleanupFlowState.sample()
        state.addCurrentSelectionToReviewBin()
        return state
    }()))
}
