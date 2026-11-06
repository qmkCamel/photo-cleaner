import SwiftUI
import UIKit

struct ReviewBinView: View {
    @Binding var state: CleanupFlowState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.windowLayout) private var layout
    @ObservedObject private var deletion: DeletionCoordinator
    private var isDeleting: Bool { deletion.isDeleting }
    @State private var previewCandidate: CleanupCandidate?

    init(
        state: Binding<CleanupFlowState>,
        deletion: DeletionCoordinator = .init()
    ) {
        self._state = state
        self.deletion = deletion
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    if state.reviewBinItems.isEmpty {
                        emptyState
                    } else {
                        reviewBinContent
                        if layout.usesInlineActions { reviewBinActionsFooter }
                    }
                }
                .clipped()
                if !state.reviewBinItems.isEmpty && !layout.usesInlineActions {
                    reviewBinActionsFooter
                }
            }
            .navigationTitle("复核箱")
            .navigationBarTitleDisplayMode(.inline)
            .trueKeepScreenBackground()
            .fullScreenCover(item: $previewCandidate) { candidate in
                MediaReviewView(candidates: state.reviewBinItems.map(\.candidate), initialID: candidate.id)
            }
        }
    }

    private var selectedCount: Int {
        state.reviewBinItems.filter(\.selectedForDelete).count
    }

    private var reviewBinContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeletionCancellationNotice(coordinator: deletion)
            Text("已选 \(selectedCount) 项 · 约 \(state.reviewBinItems.filter(\.selectedForDelete).map { $0.candidate.estimatedBytes }.reduce(0, +).formattedStorage)")
                .font(TrueKeepTheme.Font.bodySmall)
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

            deletionGuidance

            AdaptivePhotoGrid {
                ForEach(state.reviewBinItems) { item in
                    ZStack(alignment: .topTrailing) {
                        Button { previewCandidate = item.candidate } label: {
                            ThumbnailView(
                                style: item.candidate.thumbnail,
                                assetID: item.candidate.thumbnailAssetID,
                                isSelected: item.selectedForDelete,
                                showsSelectionIndicator: false,
                                videoLabel: item.candidate.category == .largeVideos ? item.candidate.estimatedBytes.formattedStorage : nil
                            ).aspectRatio(1, contentMode: .fit)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDeleting)
                        .accessibilityIdentifier("bin.preview.\(item.id)")
                        .accessibilityLabel("预览，\(item.candidate.reason)")
                        Button { state.toggleReviewBinItem(item) } label: {
                            Image(systemName: item.selectedForDelete ? "checkmark.circle.fill" : "circle")
                                .font(TrueKeepTheme.Font.iconMedium)
                                .foregroundStyle(TrueKeepTheme.greenStrong)
                                .background(TrueKeepTheme.paper, in: Circle())
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isDeleting)
                        .accessibilityIdentifier(TrueKeepAccessibility.reviewBinItem(id: item.id))
                        .accessibilityLabel(reviewBinItemAccessibilityLabel(item))
                        .accessibilityHint("切换删除选择")
                        .accessibilityAddTraits(item.selectedForDelete ? .isSelected : [])
                    }
                }
            }

            Text("待删除记录保留 30 天；过期只移除记录，不会删除照片。")
                .font(TrueKeepTheme.Font.bodySmall)
                .foregroundStyle(TrueKeepTheme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .padding(.bottom, 12)
    }

    private var deletionGuidance: some View {
        DisclosureGroup {
            SafetyCheckRow("项目仍在复核箱，还没有删除")
            SafetyCheckRow("你可以逐张复核每一项")
            SafetyCheckRow("删除后仍可从 “最近删除” 恢复")
            SafetyCheckRow("未经确认不会影响 iCloud")
        } label: {
            Text("删除前须知")
                .font(TrueKeepTheme.Font.bodySmall.weight(.semibold))
                .foregroundStyle(TrueKeepTheme.ink)
                .frame(minHeight: 44)
        }
        .tint(TrueKeepTheme.greenStrong)
        .padding(13)
        .background(TrueKeepTheme.yellowSoft)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.yellowLine))
    }

    private var reviewBinActionsFooter: some View {
        VStack(spacing: 8) {
            Button {
                state.restoreSelectedReviewBinItems()
            } label: {
                Text("移出复核箱")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(TrueKeepTheme.greenStrong)
            .disabled(selectedCount == 0 || isDeleting)
            .opacity(selectedCount == 0 || isDeleting ? 0.55 : 1)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.restoreReviewBinSelection.id)

            DangerActionButton(title: "删除所选 \(selectedCount) 项…") {
                deletion.prepare(source: .reviewBin, assetIDs: state.selectedReviewBinAssetIDs)
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
        .readableContent()
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

struct DeleteConfirmationSheet: View {
    var count: Int
    var isDeleting: Bool
    var message: String? = nil
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        Form {
            Section {
                Text("删除 \(count) 项？")
                    .font(TrueKeepTheme.Font.sheetTitle)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("这 \(count) 项照片或视频会从系统照片图库移除。删除后通常可以在照片 App 的“最近删除”中恢复。")
                    .font(TrueKeepTheme.Font.bodySmall)
                    .foregroundStyle(TrueKeepTheme.ink)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

            }
            Section {
                Text("如果你开启了 iCloud 照片，删除可能会同步到 iCloud 和其他设备。")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
                Text("请不要立即清空“最近删除”。")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("iCloud 照片同步").font(.headline).foregroundStyle(TrueKeepTheme.ink)
            }
            Section {
                if let message { SafetyNotice(title: "请重新核对", message: message) }
                VStack(spacing: 10) {
                    DangerActionButton(
                        title: isDeleting ? "正在请求系统删除..." : "确认删除 \(count) 项",
                        isBusy: isDeleting,
                        action: onConfirm
                    )
                    .disabled(isDeleting || count == 0)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.confirmPhotoDeletion.id)
                    SecondaryActionButton(title: "取消", action: onCancel)
                        .disabled(isDeleting)
                        .accessibilityIdentifier(TrueKeepAccessibility.Control.cancelPhotoDeletion.id)
                }
            }
        }
        .readableContent()
        .scrollContentBackground(.hidden)
        .trueKeepScreenBackground()
    }
}

#Preview {
    ReviewBinView(state: .constant({
        var state = CleanupFlowState.sample()
        state.addCurrentSelectionToReviewBin()
        return state
    }()))
}
