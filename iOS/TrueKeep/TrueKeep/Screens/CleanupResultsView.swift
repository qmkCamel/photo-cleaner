import SwiftUI

struct CleanupResultsView: View {
    var state: CleanupFlowState
    var scanLimitationWarning: String? = nil
    var shouldShowPhotoAccessPrompt: Bool = false
    var isRequestingAccess: Bool = false
    var onRequestPhotoAccess: () -> Void = {}
    var onReviewTask: (CleanupTask) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("扫描结果")
                            .font(TrueKeepTheme.Font.pageTitle)
                        Text("我们找到了值得你复核的项目。")
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
                    EmptyResultsState()
                } else {
                    HStack {
                        Text("预计可释放空间")
                            .font(TrueKeepTheme.Font.bodySmall.weight(.medium))
                            .foregroundStyle(TrueKeepTheme.green)
                        Spacer()
                        Text(state.totalEstimatedBytes.formattedStorage)
                            .font(TrueKeepTheme.Font.metric)
                            .foregroundStyle(TrueKeepTheme.ink)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(TrueKeepTheme.greenSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(spacing: 9) {
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(TrueKeepAccessibility.Control.cleanupResultsScreen.id)
        .trueKeepScreenBackground()
    }
}

private struct PhotoAccessPrompt: View {
    var isRequestingAccess: Bool
    var onRequestAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("需要照片访问才能扫描", systemImage: "photo.on.rectangle")
                .font(TrueKeepTheme.Font.cardTitle)
                .foregroundStyle(TrueKeepTheme.ink)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text("你已跳过首次说明。开启访问后，留真只会在本机查找候选项目，删除前仍需要你确认。")
                .font(TrueKeepTheme.Font.bodySmall)
                .foregroundStyle(TrueKeepTheme.muted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryActionButton(
                title: isRequestingAccess ? "正在请求访问..." : "开启照片访问",
                isBusy: isRequestingAccess,
                action: onRequestAccess
            )
            .disabled(isRequestingAccess)
            .opacity(isRequestingAccess ? 0.72 : 1)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.allowPhotos.id)
        }
        .padding(14)
        .background(TrueKeepTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
    }
}

private struct EmptyResultsState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(TrueKeepTheme.Font.iconLarge)
                .foregroundStyle(TrueKeepTheme.green)
            Text("暂未发现可清理项目")
                .font(TrueKeepTheme.Font.sectionTitle)
                .foregroundStyle(TrueKeepTheme.ink)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text("当前本机规则没有发现可复核候选。截图、大视频、相似、误拍和模糊结果都会只作为候选项呈现，由你逐项确认。")
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
}

private struct CleanupTaskCard: View {
    var task: CleanupTask
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: task.category.systemImage)
                    .font(TrueKeepTheme.Font.iconMedium)
                    .foregroundStyle(TrueKeepTheme.green)
                    .frame(width: 34, height: 34)
                    .background(Color(red: 0.953, green: 0.965, blue: 0.957))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.category.title)
                        .font(TrueKeepTheme.Font.cardTitle)
                        .foregroundStyle(TrueKeepTheme.ink)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
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
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(task.candidateCount.formatted(.number))
                        .font(TrueKeepTheme.Font.metric)
                        .foregroundStyle(TrueKeepTheme.ink)
                    Text(task.confidenceLabel)
                        .font(TrueKeepTheme.Font.statusLabel)
                        .foregroundStyle(TrueKeepTheme.green)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(TrueKeepTheme.greenSoft)
                        .clipShape(Capsule())
                }
            }
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
}

#Preview {
    NavigationStack {
        CleanupResultsView(state: .sample(), onReviewTask: { _ in })
    }
}
