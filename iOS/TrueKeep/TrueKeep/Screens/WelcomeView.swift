import SwiftUI

struct WelcomeView: View {
    var isRequestingAccess: Bool = false
    var onAllowPhotos: () -> Void
    var onNotNow: () -> Void
    var onLearnMore: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("TrueKeep / 留真")
                    .font(TrueKeepTheme.Font.brand).foregroundStyle(TrueKeepTheme.green)
                TrueKeepLogoMark().frame(maxWidth: .infinity).padding(.vertical, 16)
                Text("留下值得留的照片")
                    .font(TrueKeepTheme.Font.heroTitle)
                    .fixedSize(horizontal: false, vertical: true)
                Text("授权前先说清楚")
                    .font(TrueKeepTheme.Font.cardTitle)
                Text("读取你允许访问的照片和视频，找出值得复核的候选。你也可以只授权部分照片。")
                    .font(TrueKeepTheme.Font.bodySmall).foregroundStyle(TrueKeepTheme.muted)
                PromiseRow(systemImage: "iphone", title: "本地处理", subtitle: "扫描与分析在这台 iPhone 上进行。")
                PromiseRow(systemImage: "icloud.slash", title: "不上传", subtitle: "不会上传你的照片或视频。")
                PromiseRow(systemImage: "checkmark.shield", title: "不会自动删除", subtitle: "先复核，再由你确认是否删除。")
                PrimaryActionButton(title: isRequestingAccess ? "正在请求访问…" : "开启照片访问",
                                    isBusy: isRequestingAccess, action: onAllowPhotos)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.allowPhotos.id)
                HStack {
                    Button("暂不", action: onNotNow)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier(TrueKeepAccessibility.Control.permissionNotNow.id)
                    Spacer()
                    Button("了解更多", action: onLearnMore)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier(TrueKeepAccessibility.Control.welcomeLearnMore.id)
                }.disabled(isRequestingAccess)
            }.padding(24).readableContent()
        }
        .trueKeepScreenBackground()
    }
}

#Preview {
    WelcomeView(onAllowPhotos: {}, onNotNow: {}, onLearnMore: {})
}
