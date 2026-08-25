import SwiftUI

enum PrivacySafetyTopic: String, CaseIterable, Identifiable, Hashable {
    case confirmedKeeps = "confirmed-keeps"
    case howItWorks = "how-it-works"
    case privacyDetails = "privacy-details"
    case helpSupport = "help-support"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .confirmedKeeps:
            "已确认保留"
        case .howItWorks:
            "留真如何工作"
        case .privacyDetails:
            "数据与隐私细节"
        case .helpSupport:
            "帮助与支持"
        }
    }

    var detailTitle: String {
        switch self {
        case .confirmedKeeps:
            "已确认保留"
        case .howItWorks:
            "留真如何工作"
        case .privacyDetails:
            "数据与隐私细节"
        case .helpSupport:
            "帮助与支持"
        }
    }

    var detailBody: String {
        switch self {
        case .confirmedKeeps:
            "这里保存你明确确认要保留的照片记录。记录只包含本机 Photos 资源 ID，不保存照片或缩略图；取消后，照片可能在下次扫描中再次出现。"
        case .howItWorks:
            "留真会在本机读取可访问的照片和视频元数据及缩略图，先找出可解释的候选项目，再让你逐项复核。当前真实扫描覆盖截图、大视频，以及低置信度的相似、误拍和模糊视觉候选。"
        case .privacyDetails:
            "照片和视频不会上传到服务器。应用不需要账号，不加入广告 SDK，不做跨 App 追踪。缩略图只通过系统 Photos 框架读取并使用内存缓存，不会把你的照片或视频另存到应用目录。"
        case .helpSupport:
            "如果扫描结果不完整，请检查是否只授予了 Limited Photos Access。删除前请确认 iCloud Photos 状态；删除后不要立即清空 Recently Deleted，这样仍有恢复窗口。"
        }
    }

    var accessibilityIdentifier: String {
        "truekeep.settings.topic.\(rawValue)"
    }
}

struct PrivacySafetyView: View {
    var confirmedKeepAssetIDs: Set<String> = []
    var onRemoveConfirmedKeep: (String) -> Void = { _ in }
    var onResetConfirmedKeeps: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("我们的承诺")
                        .font(TrueKeepTheme.Font.sheetTitle)
                    Text("用清楚的话说明留真会做什么，也说明不会做什么。")
                        .font(TrueKeepTheme.Font.bodySmall)
                        .foregroundStyle(TrueKeepTheme.muted)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("TrueKeep / 留真 · v0.1.0")
                        .font(TrueKeepTheme.Font.captionStrong)
                        .foregroundStyle(TrueKeepTheme.ink)
                }

                VStack(alignment: .leading, spacing: 16) {
                    PromiseRow(systemImage: "lock.shield", title: "100% 本地处理", subtitle: "所有分析都在你的 iPhone 上完成，不经过服务器。")
                    PromiseRow(systemImage: "icloud.slash", title: "不收集照片或视频", subtitle: "我们不会收集、上传、分享你的照片或视频。")
                    PromiseRow(systemImage: "eye.slash", title: "不做跟踪", subtitle: "没有广告 SDK，没有用于画像的追踪。")
                    PromiseRow(systemImage: "person.crop.circle", title: "由你控制", subtitle: "你决定保留什么、删除什么。未经你确认不会删除。")
                }

                SafetyNotice(
                    title: "iCloud Photos",
                    message: "删除照片或视频可能会同步到 iCloud 和其他设备。真正删除前，请在 Photos App 的 Recently Deleted 中保留恢复窗口。"
                )

                VStack(spacing: 8) {
                    ForEach(PrivacySafetyTopic.allCases) { topic in
                        NavigationLink(value: topic) {
                            SettingsRow(
                                title: topic.title,
                                detail: topic == .confirmedKeeps
                                    ? confirmedKeepsCountText
                                    : nil
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(topic.accessibilityIdentifier)
                        .accessibilityLabel(topic.title)
                        .accessibilityValue(topic == .confirmedKeeps ? confirmedKeepsCountText : "")
                        .accessibilityHint("打开详情")
                    }
                }
            }
            .padding(20)
            .padding(.bottom, TrueKeepTheme.tabScrollBottomPadding)
        }
        .navigationTitle("隐私与安全")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PrivacySafetyTopic.self) { topic in
            if topic == .confirmedKeeps {
                ConfirmedKeepsView(
                    assetIDs: confirmedKeepAssetIDs,
                    onRemove: onRemoveConfirmedKeep,
                    onReset: onResetConfirmedKeeps
                )
            } else {
                PrivacySafetyTopicDetailView(topic: topic)
            }
        }
        .trueKeepScreenBackground()
    }

    private var confirmedKeepsCountText: String {
        confirmedKeepAssetIDs.isEmpty ? "暂无" : "\(confirmedKeepAssetIDs.count) 项"
    }
}

private struct ConfirmedKeepsView: View {
    var assetIDs: Set<String>
    var onRemove: (String) -> Void
    var onReset: () -> Void

    @State private var showsResetConfirmation = false

    private var sortedAssetIDs: [String] {
        assetIDs.sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SafetyNotice(
                    title: "只在本机记住",
                    message: "这些照片不会再作为普通清理候选。相似照片复核中仍可能作为受保护的比较参考；取消后可能在下次扫描再次出现。"
                )

                if sortedAssetIDs.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.shield")
                            .font(TrueKeepTheme.Font.iconLarge)
                            .foregroundStyle(TrueKeepTheme.green)
                            .accessibilityHidden(true)
                        Text("还没有已确认保留的照片")
                            .font(TrueKeepTheme.Font.cardTitle)
                            .foregroundStyle(TrueKeepTheme.ink)
                        Text("在复核照片时使用更多操作即可确认保留。")
                            .font(TrueKeepTheme.Font.bodySmall)
                            .foregroundStyle(TrueKeepTheme.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        ForEach(Array(sortedAssetIDs.enumerated()), id: \.element) { index, assetID in
                            VStack(alignment: .leading, spacing: 8) {
                                ThumbnailView(
                                    style: .kidPortrait,
                                    assetID: assetID,
                                    isConfirmedKeep: true,
                                    showsSelectionIndicator: false
                                )
                                .frame(height: 132)

                                Text("保留照片 \(index + 1)")
                                    .font(TrueKeepTheme.Font.captionStrong)
                                    .foregroundStyle(TrueKeepTheme.ink)

                                Button {
                                    onRemove(assetID)
                                } label: {
                                    Label("取消保留", systemImage: "arrow.uturn.backward")
                                        .font(TrueKeepTheme.Font.inlineAction)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(TrueKeepTheme.greenStrong)
                                .background(TrueKeepTheme.paper)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(TrueKeepTheme.line)
                                }
                                .accessibilityIdentifier(TrueKeepAccessibility.confirmedKeepItem(id: assetID))
                                .accessibilityLabel("取消保留照片 \(index + 1)")
                                .accessibilityHint("取消后可能在下次扫描中再次出现")
                            }
                            .padding(10)
                            .background(TrueKeepTheme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(TrueKeepTheme.line)
                            }
                        }
                    }

                    Button(role: .destructive) {
                        showsResetConfirmation = true
                    } label: {
                        Label("全部取消保留", systemImage: "arrow.counterclockwise")
                            .font(TrueKeepTheme.Font.button)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TrueKeepTheme.danger)
                    .background(TrueKeepTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(TrueKeepTheme.danger.opacity(0.45))
                    }
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.resetConfirmedKeeps.id)
                }
            }
            .padding(20)
            .padding(.bottom, TrueKeepTheme.tabScrollBottomPadding)
        }
        .navigationTitle("已确认保留")
        .navigationBarTitleDisplayMode(.inline)
        .trueKeepScreenBackground()
        .alert("全部取消保留？", isPresented: $showsResetConfirmation) {
            Button("取消", role: .cancel) {}
            Button("全部取消保留", role: .destructive) {
                onReset()
            }
        } message: {
            Text("不会删除任何照片，但这些照片可能在下次扫描中再次成为复核候选。")
        }
    }
}

private struct PrivacySafetyTopicDetailView: View {
    var topic: PrivacySafetyTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(topic.detailTitle)
                    .font(TrueKeepTheme.Font.pageTitle)
                    .foregroundStyle(TrueKeepTheme.ink)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(topic.detailBody)
                    .font(TrueKeepTheme.Font.body)
                    .foregroundStyle(TrueKeepTheme.muted)
                    .lineSpacing(4)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                SafetyNotice(
                    title: "安全原则",
                    message: "本页说明仅反映当前实现。任何新增 SDK、网络上传或自动删除能力，都必须先更新产品说明和 App Store 隐私信息。"
                )
            }
            .padding(20)
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .trueKeepScreenBackground()
        .accessibilityIdentifier("\(topic.accessibilityIdentifier).detail")
    }
}

private struct SettingsRow: View {
    var title: String
    var detail: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(TrueKeepTheme.Font.bodySmall.weight(.medium))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if let detail {
                Text(detail)
                    .font(TrueKeepTheme.Font.caption)
                    .foregroundStyle(TrueKeepTheme.muted)
            }
            Image(systemName: "chevron.right")
                .font(TrueKeepTheme.Font.iconCaption2)
                .foregroundStyle(TrueKeepTheme.muted)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(minHeight: 46)
        .background(TrueKeepTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
    }
}

#Preview {
    NavigationStack {
        PrivacySafetyView()
    }
}
