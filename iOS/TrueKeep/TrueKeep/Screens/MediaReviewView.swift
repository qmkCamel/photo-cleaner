import SwiftUI
import AVKit
@preconcurrency import Photos
import Combine

@MainActor
final class LocalMediaLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var player: AVPlayer?
    @Published var isLoading = false
    @Published var failure: String?
    private let manager = PHImageManager()
    private var requestID: PHImageRequestID?
    private var generation = UUID()

    func cancel() {
        generation = UUID()
        if let requestID { manager.cancelImageRequest(requestID) }
        requestID = nil
        player?.pause()
        player = nil
        isLoading = false
    }

    func load(_ candidate: CleanupCandidate) {
        cancel()
        image = nil
        failure = nil
        guard let id = candidate.thumbnailAssetID,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            failure = "本机暂时无法读取此项目。可在系统照片中确认资源和访问权限后重试。"
            return
        }
        isLoading = true
        let token = generation
        if asset.mediaType == .video {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .highQualityFormat
            requestID = manager.requestPlayerItem(forVideo: asset, options: options) { item, _ in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.isLoading = false
                    if let item { self.player = AVPlayer(playerItem: item) }
                    else { self.failure = "视频未存储在本机，或访问权限已变化。留真不会下载 iCloud 视频。" }
                }
            }
        } else {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            requestID = manager.requestImage(for: asset, targetSize: CGSize(width: 2048, height: 2048), contentMode: .aspectFit, options: options) { image, _ in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.isLoading = false
                    self.image = image
                    if image == nil { self.failure = "照片未存储在本机，或访问权限已变化。留真不会下载 iCloud 原图。" }
                }
            }
        }
    }
}

struct MediaReviewView: View {
    var candidates: [CleanupCandidate]
    var initialID: String
    var onKeep: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loader = LocalMediaLoader()
    @State private var index = 0
    @State private var zoom: CGFloat = 1
    @GestureState private var magnification: CGFloat = 1

    private var candidate: CleanupCandidate? {
        candidates.indices.contains(index) ? candidates[index] : nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if let candidate {
                    GeometryReader { geometry in
                        ZStack {
                            Color.black
                            if let image = loader.image {
                                ScrollView([.horizontal, .vertical]) {
                                    Image(uiImage: image).resizable().scaledToFit()
                                        .frame(width: geometry.size.width * min(4, max(1, zoom * magnification)), height: geometry.size.height * min(4, max(1, zoom * magnification)))
                                        .accessibilityLabel("完整照片，可双指缩放")
                                }
                                .simultaneousGesture(MagnifyGesture().updating($magnification) { value, state, _ in state = value.magnification }.onEnded { value in zoom = min(4, max(1, zoom * value.magnification)) })
                                .onTapGesture(count: 2) { zoom = zoom == 1 ? 2 : 1 }
                            } else if let player = loader.player {
                                VideoPlayer(player: player)
                            } else if loader.isLoading {
                                ProgressView("正在读取本地内容…").tint(.white).foregroundStyle(.white)
                            } else {
                                VStack(spacing: 16) {
                                    Text(loader.failure ?? "本地内容不可用").multilineTextAlignment(.center)
                                        .accessibilityIdentifier("media.unavailable")
                                    Button("重试") { loader.load(candidate) }.frame(minHeight: 44)
                                        .accessibilityIdentifier("media.retry")
                                }.foregroundStyle(.white).padding()
                            }
                        }
                    }
                    .frame(minHeight: 200)
                    .simultaneousGesture(DragGesture().onEnded { value in
                        guard zoom == 1, abs(value.translation.width) > 80, abs(value.translation.width) > abs(value.translation.height) else { return }
                        move(value.translation.width < 0 ? 1 : -1)
                    })

                    ScrollView {
                        VStack(spacing: 10) {
                            Text(candidate.reason).font(.body)
                            HStack {
                                Button("上一张") { move(-1) }.disabled(index == 0)
                                Spacer()
                                Text("\(index + 1) / \(candidates.count)")
                                Spacer()
                                Button("下一张") { move(1) }.disabled(index + 1 >= candidates.count)
                            }.frame(minHeight: 44)
                            if let onKeep {
                                Button(candidate.confirmedKeep ? "已确认保留" : "确认保留，不再提醒") { onKeep(candidate.id) }
                                    .disabled(candidate.confirmedKeep)
                                    .frame(minHeight: 44)
                                    .accessibilityIdentifier("media.keep")
                            }
                            Text("预览不会改变删除选择。仅显示本地可读取内容。")
                                .font(.caption)
                        }.padding(.horizontal)
                    }.frame(maxHeight: 220)
                }
            }
            .navigationTitle("逐项复核")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .onAppear {
            index = candidates.firstIndex { $0.id == initialID } ?? 0
            if let candidate { loader.load(candidate) }
        }
        .onDisappear { loader.cancel() }
    }

    private func move(_ offset: Int) {
        guard candidates.indices.contains(index + offset) else { return }
        index += offset
        zoom = 1
        if let candidate { loader.load(candidate) }
    }
}
