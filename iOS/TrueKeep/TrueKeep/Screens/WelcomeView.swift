import SwiftUI

struct WelcomeView: View {
    var isRequestingAccess: Bool = false
    var onAllowPhotos: () -> Void
    var onNotNow: () -> Void
    var onLearnMore: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading) {
                Text("TrueKeep / 留真")
                    .font(TrueKeepTheme.Font.brand)
                    .foregroundStyle(TrueKeepTheme.green)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 30)
                VStack(spacing: 22) {
                    TrueKeepLogoMark()
                    Text("你的回忆，\n只在你的设备上。")
                        .font(TrueKeepTheme.Font.heroTitle)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TrueKeepTheme.ink)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 18) {
                    PromiseRow(systemImage: "photo.on.rectangle", title: "需要照片访问才能扫描", subtitle: "留真会读取可访问照片和视频，找出你可能想复核的项目。")
                    PromiseRow(systemImage: "shield", title: "100% 本地处理", subtitle: "分析只在这台 iPhone 上进行，照片和视频不会离开设备。")
                    PromiseRow(systemImage: "eye", title: "删除前先复核", subtitle: "所有候选都需要你确认，不会自动删除。")
                }
                .padding(.top, 40)

                SafetyNotice(
                    title: "授权前先说清楚",
                    message: SupportedScanCopy.permissionSafetyMessage
                )
                .padding(.top, 24)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)

            VStack(spacing: 12) {
                HStack {
                    TrustChip(title: "本地扫描", systemImage: "checkmark.circle")
                    Spacer()
                    TrustChip(title: "不需要联网", systemImage: "wifi.slash")
                }
                PrimaryActionButton(
                    title: isRequestingAccess ? "正在请求访问..." : "允许访问照片",
                    isBusy: isRequestingAccess,
                    action: onAllowPhotos
                )
                    .disabled(isRequestingAccess)
                    .opacity(isRequestingAccess ? 0.72 : 1)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.allowPhotos.id)

                HStack(spacing: 12) {
                    InlineTextActionButton(title: "暂不", action: onNotNow)
                        .accessibilityIdentifier(TrueKeepAccessibility.Control.permissionNotNow.id)
                    InlineTextActionButton(title: "了解更多", action: onLearnMore)
                        .accessibilityIdentifier(TrueKeepAccessibility.Control.welcomeLearnMore.id)
                }
            }
            .padding(20)
        }
        .trueKeepScreenBackground()
    }
}

#Preview {
    WelcomeView(onAllowPhotos: {}, onNotNow: {}, onLearnMore: {})
}
