import SwiftUI

struct CleanupResultsView: View {
    var state: CleanupFlowState
    var scanLimitationWarning: String? = nil
    var shouldShowPhotoAccessPrompt: Bool = false
    var hasCompletedScan: Bool = true
    var canScan: Bool = false
    var isRequestingAccess: Bool = false
    var onRequestPhotoAccess: () -> Void = {}
    var onScan: () -> Void = {}
    var onReviewTask: (CleanupTask) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("扫描结果")
                            .font(TrueKeepTheme.Font.pageTitle)
                        Text(headerMessage)
                            .font(TrueKeepTheme.Font.bodySmall)
                            .foregroundStyle(TrueKeepTheme.muted)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    TrustChip(title: "本地", systemImage: "checkmark.circle")
                }

                if let scanLimitationWarning {
                    SafetyNotice(
                        title: "访问范围有限",
                        message: scanLimitationWarning
                    )
                }

                if shouldShowPhotoAccessPrompt {
                    PhotoAccessPrompt(
                        isRequestingAccess: isRequestingAccess,
                        onRequestAccess: onRequestPhotoAccess
                    )
                }

                if state.tasks.isEmpty {
                    if canScan {
                        scanAction
                    }
                    EmptyResultsState(hasCompletedScan: hasCompletedScan)
                } else {
                    HStack {
                        Text("预计可释放空间")
                            .font(TrueKeepTheme.Font.bodySmall.weight(.medium))
                            .foregroundStyle(TrueKeepTheme.greenStrong)
                        Spacer()
                        Text(state.totalEstimatedBytes.formattedStorage)
                            .font(TrueKeepTheme.Font.metric)
                            .foregroundStyle(TrueKeepTheme.ink)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(TrueKeepTheme.greenSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    LazyVStack(spacing: 9) {
                        ForEach(state.tasks) { task in
                            CleanupTaskCard(task: task) {
                                onReviewTask(task)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, TrueKeepTheme.tabScrollBottomPadding)
        }
        .accessibilityIdentifier(TrueKeepAccessibility.Control.cleanupResultsScreen.id)
        .safeAreaInset(edge: .bottom) {
            if canScan, !state.tasks.isEmpty {
                resultsRescanFooter
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .trueKeepScreenBackground()
    }

    private var headerMessage: String {
        if !hasCompletedScan {
            return "扫描后，本地复核候选会显示在这里。"
        }
        if state.tasks.isEmpty {
            return "本次扫描没有发现需要复核的项目。"
        }
        return "我们找到了值得你复核的项目。"
    }

    @ViewBuilder
    private var scanAction: some View {
        PrimaryActionButton(title: hasCompletedScan ? "重新扫描" : "扫描相册", action: onScan)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.homeScan.id)
    }

    private var resultsRescanFooter: some View {
        PrimaryActionButton(title: "重新扫描", action: onScan)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.homeScan.id)
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
}

private struct PhotoAccessPrompt: View {
    var isRequestingAccess: Bool
    var onRequestAccess: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(TrueKeepTheme.Font.iconMedium)
                .foregroundStyle(TrueKeepTheme.greenStrong)
                .frame(width: 34, height: 34)
                .background(Color(red: 0.953, green: 0.965, blue: 0.957))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("需要照片访问才能扫描")
                    .font(TrueKeepTheme.Font.cardTitle)
                    .foregroundStyle(TrueKeepTheme.ink)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text("仅在本机查找候选，删除前仍需确认。")
                    .font(TrueKeepTheme.Font.caption)
                    .foregroundStyle(TrueKeepTheme.muted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryActionButton(
                title: isRequestingAccess ? "请求中..." : "开启访问",
                isBusy: isRequestingAccess,
                action: onRequestAccess
            )
            .frame(width: 116)
            .disabled(isRequestingAccess)
            .opacity(isRequestingAccess ? 0.72 : 1)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.allowPhotos.id)
            .accessibilityLabel(isRequestingAccess ? "正在请求照片访问" : "开启照片访问")
        }
        .padding(12)
        .background(TrueKeepTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
    }
}

private struct EmptyResultsState: View {
    var hasCompletedScan: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(TrueKeepTheme.Font.iconLarge)
                .foregroundStyle(TrueKeepTheme.green)
            Text(hasCompletedScan ? "暂未发现可清理项目" : "尚未扫描相册")
                .font(TrueKeepTheme.Font.sectionTitle)
                .foregroundStyle(TrueKeepTheme.ink)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(TrueKeepTheme.Font.bodySmall)
                .foregroundStyle(TrueKeepTheme.muted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrueKeepTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
    }

    private var message: String {
        if hasCompletedScan {
            return "当前本机规则没有发现可复核候选。截图、大视频、相似、误拍和模糊结果都会只作为候选项呈现，由你逐项确认。"
        }
        return "扫描只在本机进行。截图、大视频、相似、误拍和模糊结果都会先作为候选项呈现，由你逐项确认。"
    }
}

private struct CleanupTaskCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var task: CleanupTask
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            cardContent
            .padding(11)
            .background(TrueKeepTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(TrueKeepAccessibility.cleanupTask(category: task.category))
        .accessibilityLabel("\(task.category.title)，\(task.description)，\(task.candidateCount) 项，\(task.confidenceLabel)")
        .accessibilityHint("打开复核列表")
    }

    @ViewBuilder
    private var cardContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    categoryIcon
                    taskTitle
                    Spacer(minLength: 8)
                }

                previewStrip

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    candidateCount
                    Spacer(minLength: 8)
                    confidenceBadge
                }
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                categoryIcon

                VStack(alignment: .leading, spacing: 6) {
                    taskTitle
                    previewStrip
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    candidateCount
                    confidenceBadge
                }
            }
        }
    }

    private var categoryIcon: some View {
        Image(systemName: task.category.systemImage)
            .font(TrueKeepTheme.Font.iconMedium)
            .foregroundStyle(TrueKeepTheme.greenStrong)
            .frame(width: 34, height: 34)
            .background(Color(red: 0.953, green: 0.965, blue: 0.957))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var taskTitle: some View {
        Text(task.category.title)
            .font(TrueKeepTheme.Font.cardTitle)
            .foregroundStyle(TrueKeepTheme.ink)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var previewStrip: some View {
        HStack(spacing: 4) {
            ForEach(task.previewCandidates.prefix(4)) { candidate in
                ThumbnailView(
                    style: candidate.thumbnail,
                    assetID: candidate.thumbnailAssetID
                )
                .frame(width: 37, height: 37)
            }
        }
    }

    private var candidateCount: some View {
        Text(task.candidateCount.formatted(.number))
            .font(TrueKeepTheme.Font.metric)
            .foregroundStyle(TrueKeepTheme.ink)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var confidenceBadge: some View {
        Text(task.confidenceLabel)
            .font(TrueKeepTheme.Font.statusLabel)
            .foregroundStyle(TrueKeepTheme.greenStrong)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(TrueKeepTheme.greenSoft)
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        CleanupResultsView(state: .sample(), onReviewTask: { _ in })
    }
}
