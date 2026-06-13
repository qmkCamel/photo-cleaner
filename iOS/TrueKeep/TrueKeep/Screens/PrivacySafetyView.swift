import SwiftUI

enum PrivacySafetyTopic: String, CaseIterable, Identifiable, Hashable {
    case howItWorks = "how-it-works"
    case privacyDetails = "privacy-details"
    case helpSupport = "help-support"

    var id: String { rawValue }

    var title: String {
        switch self {
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
                            SettingsRow(title: topic.title)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(topic.accessibilityIdentifier)
                        .accessibilityLabel(topic.title)
                        .accessibilityHint("打开详情")
                    }
                }

                Text("TrueKeep / 留真 · v0.1.0")
                    .font(TrueKeepTheme.Font.caption)
                    .foregroundStyle(TrueKeepTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }
            .padding(20)
            .padding(.bottom, TrueKeepTheme.tabScrollBottomPadding)
        }
        .navigationTitle("隐私与安全")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PrivacySafetyTopic.self) { topic in
            PrivacySafetyTopicDetailView(topic: topic)
        }
        .trueKeepScreenBackground()
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

    var body: some View {
        HStack {
            Text(title)
                .font(TrueKeepTheme.Font.bodySmall.weight(.medium))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Image(systemName: "chevron.right")
                .font(TrueKeepTheme.Font.iconCaption2)
                .foregroundStyle(TrueKeepTheme.muted)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(minHeight: 46)
        .background(TrueKeepTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
    }
}

#Preview {
    NavigationStack {
        PrivacySafetyView()
    }
}
