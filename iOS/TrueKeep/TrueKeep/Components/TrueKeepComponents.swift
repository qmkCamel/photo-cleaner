import SwiftUI
import UIKit

struct PrimaryActionButton: View {
    var title: String
    var isBusy: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionButtonContent(title: title, isBusy: isBusy, progressTint: .white)
        }
        .disabled(isBusy)
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(TrueKeepTheme.greenStrong)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: TrueKeepTheme.green.opacity(0.20), radius: 12, y: 6)
    }
}

struct SecondaryActionButton: View {
    var title: String
    var isBusy: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionButtonContent(title: title, isBusy: isBusy, progressTint: TrueKeepTheme.green)
        }
        .disabled(isBusy)
        .buttonStyle(.plain)
        .foregroundStyle(TrueKeepTheme.ink)
        .background(TrueKeepTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TrueKeepTheme.line)
        )
    }
}

struct DangerActionButton: View {
    var title: String
    var isBusy: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionButtonContent(title: title, isBusy: isBusy, progressTint: .white)
        }
        .disabled(isBusy)
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(TrueKeepTheme.danger)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ActionButtonContent: View {
    var title: String
    var isBusy: Bool
    var progressTint: Color

    var body: some View {
        HStack(spacing: isBusy ? 8 : 0) {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(progressTint)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(TrueKeepTheme.Font.button)
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .contentShape(Rectangle())
    }
}

struct InlineTextActionButton: View {
    var title: String
    var minWidth: CGFloat = 44
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TrueKeepTheme.Font.inlineAction)
                .foregroundStyle(TrueKeepTheme.ink)
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .frame(minWidth: minWidth, minHeight: 44)
                .background(TrueKeepTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(TrueKeepTheme.green, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .tint(TrueKeepTheme.ink)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct TrustChip: View {
    var title: String
    var systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(TrueKeepTheme.Font.captionStrong)
            .foregroundStyle(TrueKeepTheme.greenStrong)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(TrueKeepTheme.greenSoft)
            .clipShape(Capsule())
    }
}

struct PromiseRow: View {
    var systemImage: String
    var title: String
    var subtitle: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                icon
                textStack
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: 14) {
                icon
                textStack
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(TrueKeepTheme.Font.iconMedium)
            .foregroundStyle(TrueKeepTheme.green)
            .frame(width: 26, height: 26)
            .accessibilityHidden(true)
    }

    private var textStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(TrueKeepTheme.Font.cardTitle)
                .foregroundStyle(TrueKeepTheme.ink)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(TrueKeepTheme.Font.caption)
                .foregroundStyle(TrueKeepTheme.muted)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }
}

struct TrueKeepLogoMark: View {
    var body: some View {
        Image("LogoMark")
            .resizable()
            .scaledToFit()
            .frame(width: 132, height: 132)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct ThumbnailView: View {
    var style: ThumbnailStyle
    var assetID: String? = nil
    var isSelected: Bool = false
    var isRecommendedKeep: Bool = false
    var videoLabel: String?
    var thumbnailProvider: any PhotoThumbnailProviding = SystemPhotoThumbnailProvider.shared

    @Environment(\.displayScale) private var displayScale
    @State private var thumbnailImage: UIImage?
    @State private var loadedRequestKey: PhotoThumbnailRequestKey?
    @State private var inFlightRequestKey: PhotoThumbnailRequestKey?
    @State private var requestID: PhotoThumbnailRequestID?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                fallbackThumbnail

                if let thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }

                if isRecommendedKeep {
                    VStack {
                        HStack {
                Label("推荐保留", systemImage: "checkmark.seal.fill")
                    .font(TrueKeepTheme.Font.caption2Strong)
                    .foregroundStyle(TrueKeepTheme.greenStrong)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(TrueKeepTheme.greenSoft.opacity(0.95))
                                .clipShape(Capsule())
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }

                VStack {
                    HStack {
                        Spacer()
                        selectionIndicator
                    }
                    Spacer()
                    if let videoLabel {
                        HStack {
                            Spacer()
                            Text(videoLabel)
                                .font(TrueKeepTheme.Font.caption2Strong)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.black.opacity(0.65))
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }
                }
                .padding(7)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected || isRecommendedKeep ? TrueKeepTheme.green : .white.opacity(0.65), lineWidth: isSelected || isRecommendedKeep ? 2 : 1)
            }
            .onAppear {
                loadThumbnail(size: proxy.size)
            }
            .onChange(of: assetID) {
                loadThumbnail(size: proxy.size)
            }
            .onChange(of: proxy.size) { _, newSize in
                loadThumbnail(size: newSize)
            }
            .onDisappear {
                cancelThumbnailRequest()
            }
        }
    }

    private var fallbackThumbnail: some View {
        ZStack {
            LinearGradient(colors: [style.topColor, style.bottomColor], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: style.symbolName)
                .font(TrueKeepTheme.Font.iconLarge)
                .foregroundStyle(.white.opacity(0.82))
                .shadow(radius: 6)
        }
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected || isRecommendedKeep {
            Image(systemName: "checkmark")
                .font(TrueKeepTheme.Font.iconCaption)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(TrueKeepTheme.green)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
        } else {
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.18), in: Circle())
        }
    }

    private func loadThumbnail(size: CGSize) {
        guard let assetID else {
            cancelThumbnailRequest()
            thumbnailImage = nil
            loadedRequestKey = nil
            return
        }

        let requestKey = PhotoThumbnailRequestKey(
            assetID: assetID,
            targetSize: size,
            scale: displayScale
        )

        if loadedRequestKey == requestKey, thumbnailImage != nil {
            return
        }

        if inFlightRequestKey == requestKey {
            return
        }

        cancelThumbnailRequest()

        if let cachedImage = thumbnailProvider.cachedImage(for: requestKey) {
            thumbnailImage = cachedImage
            loadedRequestKey = requestKey
            return
        }

        inFlightRequestKey = requestKey
        requestID = thumbnailProvider.requestImage(for: requestKey) { image in
            guard inFlightRequestKey == requestKey else { return }
            thumbnailImage = image
            loadedRequestKey = image == nil ? nil : requestKey
            inFlightRequestKey = nil
            requestID = nil
        }
    }

    private func cancelThumbnailRequest() {
        if let requestID {
            thumbnailProvider.cancelRequest(requestID)
            self.requestID = nil
        }
        inFlightRequestKey = nil
    }
}

struct SafetyNotice: View {
    var title: String
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(TrueKeepTheme.Font.cardTitle)
                .foregroundStyle(TrueKeepTheme.ink)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(TrueKeepTheme.Font.caption)
                .foregroundStyle(Color(red: 0.427, green: 0.353, blue: 0.169))
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrueKeepTheme.yellowSoft)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TrueKeepTheme.yellowLine)
        )
    }
}
