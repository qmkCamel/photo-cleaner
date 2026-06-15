import SwiftUI

struct PermissionIntroView: View {
    var isRequestingAccess: Bool = false
    var onBack: () -> Void
    var onAllow: () -> Void
    var onNotNow: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(TrueKeepTheme.Font.iconSmall)
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("返回")
                .accessibilityIdentifier(TrueKeepAccessibility.Control.permissionBack.id)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView {
                VStack(spacing: 0) {
                    Image(systemName: "lock")
                        .font(TrueKeepTheme.Font.iconLarge)
                        .foregroundStyle(TrueKeepTheme.green)
                        .frame(width: 68, height: 68)
                        .background(TrueKeepTheme.greenSoft)
                        .clipShape(Circle())
                        .padding(.top, 26)

                    Text("我们只需要访问\n你的照片和视频")
                        .font(TrueKeepTheme.Font.pageTitle)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 18)

                    Text("留真会在这台 iPhone 上扫描相册，找出你可能想复核的项目。")
                        .font(TrueKeepTheme.Font.bodySmall)
                        .foregroundStyle(TrueKeepTheme.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 42)
                        .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 18) {
                        PromiseRow(systemImage: "icloud.slash", title: "我们不会上传你的照片或视频", subtitle: "所有分析都留在本机。")
                        PromiseRow(systemImage: "lock", title: "扫描结果保存在此 iPhone", subtitle: "不需要账号，也不会同步到云端。")
                        PromiseRow(systemImage: "gearshape", title: "权限可以随时更改", subtitle: "你可以在系统设置中撤销或限制访问。")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 34)

                    SafetyNotice(
                        title: "删除前一定会复核",
                        message: SupportedScanCopy.permissionSafetyMessage
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 12) {
                PrimaryActionButton(
                    title: isRequestingAccess ? "正在请求访问..." : "允许访问照片",
                    isBusy: isRequestingAccess,
                    action: onAllow
                )
                    .disabled(isRequestingAccess)
                    .opacity(isRequestingAccess ? 0.72 : 1)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.allowPhotos.id)
                InlineTextActionButton(title: "暂不", action: onNotNow)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.permissionNotNow.id)
            }
            .padding(20)
        }
        .trueKeepScreenBackground()
    }
}

#Preview {
    PermissionIntroView(onBack: {}, onAllow: {}, onNotNow: {})
}
