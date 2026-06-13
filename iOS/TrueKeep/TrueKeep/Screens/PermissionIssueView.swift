import SwiftUI

struct PermissionIssueView: View {
    var access: PhotoLibraryAccess
    var onBack: () -> Void
    var onOpenSettings: () -> Void
    var onRetry: () -> Void

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
                .accessibilityIdentifier(TrueKeepAccessibility.Control.permissionIssueBack.id)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: access == .restricted ? "lock.trianglebadge.exclamationmark" : "photo.badge.exclamationmark")
                        .font(TrueKeepTheme.Font.iconHero)
                        .foregroundStyle(TrueKeepTheme.green)
                        .frame(width: 88, height: 88)
                        .background(TrueKeepTheme.greenSoft)
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(access.displayTitle)
                            .font(TrueKeepTheme.Font.pageTitle)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(access.displayMessage)
                            .font(TrueKeepTheme.Font.body)
                            .foregroundStyle(TrueKeepTheme.muted)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    SafetyNotice(
                        title: "照片或视频不会被上传",
                        message: "开启权限只用于在本机扫描候选项目。未经你复核，留真不会修改或删除任何照片或视频。"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 26)
                .padding(.bottom, 16)
            }

            VStack(spacing: 12) {
                if access.requiresSettings {
                    PrimaryActionButton(title: "打开系统设置", action: onOpenSettings)
                        .accessibilityIdentifier(TrueKeepAccessibility.Control.openSettings.id)
                    SecondaryActionButton(title: "我已开启，重新检查", action: onRetry)
                        .accessibilityIdentifier(TrueKeepAccessibility.Control.retryPhotoAccess.id)
                } else {
                    PrimaryActionButton(title: "重新请求访问", action: onRetry)
                        .accessibilityIdentifier(TrueKeepAccessibility.Control.retryPhotoAccess.id)
                }
                InlineTextActionButton(title: "返回权限说明", action: onBack)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.returnToPermission.id)
            }
            .padding(20)
            .background(TrueKeepTheme.page)
        }
        .trueKeepScreenBackground()
    }
}

#Preview("Denied") {
    PermissionIssueView(access: .denied, onBack: {}, onOpenSettings: {}, onRetry: {})
}

#Preview("Limited") {
    PermissionIssueView(access: .limited, onBack: {}, onOpenSettings: {}, onRetry: {})
}
