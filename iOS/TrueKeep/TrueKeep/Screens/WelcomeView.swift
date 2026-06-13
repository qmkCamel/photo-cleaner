import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void
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
                    PromiseRow(systemImage: "shield", title: "100% 本地处理", subtitle: "照片和视频不会离开你的 iPhone。")
                    PromiseRow(systemImage: "icloud.slash", title: "隐私优先", subtitle: "不收集、不上传、不出售任何照片或视频数据。")
                    PromiseRow(systemImage: "eye", title: "删除前先复核", subtitle: "所有候选都需要你确认，不会自动删除。")
                }
                .padding(.top, 40)
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
                PrimaryActionButton(title: "继续", action: onContinue)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.welcomeContinue.id)
                InlineTextActionButton(title: "了解更多", action: onLearnMore)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.welcomeLearnMore.id)
            }
            .padding(20)
        }
        .trueKeepScreenBackground()
    }
}

#Preview {
    WelcomeView(onContinue: {}, onLearnMore: {})
}
