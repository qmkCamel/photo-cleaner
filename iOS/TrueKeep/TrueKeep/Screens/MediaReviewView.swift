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
    @State private var currentID: String?
    @State private var keptDuringPreview: Set<String> = []
    @State private var showsDetails = false
    @State private var zoom: CGFloat = 1
    @State private var photoPosition = ScrollPosition(point: .zero)
    @State private var normalizedCenter = CGPoint(x: 0.5, y: 0.5)
    @GestureState private var magnification: CGFloat = 1

    private var candidate: CleanupCandidate? {
        candidates.first { $0.id == (currentID ?? initialID) }
    }

    private var index: Int { candidates.firstIndex { $0.id == (currentID ?? initialID) } ?? 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                                .scrollPosition($photoPosition)
                                .onScrollGeometryChange(for: CGPoint.self) { scroll in
                                    CGPoint(x: (scroll.contentOffset.x + scroll.containerSize.width / 2) / max(1, scroll.contentSize.width),
                                            y: (scroll.contentOffset.y + scroll.containerSize.height / 2) / max(1, scroll.contentSize.height))
                                } action: { _, center in
                                    normalizedCenter = center
                                }
                                .onChange(of: geometry.size) { _, size in
                                    let contentWidth = size.width * zoom
                                    let contentHeight = size.height * zoom
                                    photoPosition.scrollTo(point: CGPoint(
                                        x: min(max(0, contentWidth - size.width), max(0, normalizedCenter.x * contentWidth - size.width / 2)),
                                        y: min(max(0, contentHeight - size.height), max(0, normalizedCenter.y * contentHeight - size.height / 2))))
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
                                    Button { loader.load(candidate) } label: {
                                        Text("重试").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                        .accessibilityIdentifier("media.retry")
                                }.foregroundStyle(.white).padding()
                            }
                        }
                    }
                    .frame(minHeight: 80)
                    .simultaneousGesture(DragGesture().onEnded { value in
                        guard zoom == 1, abs(value.translation.width) > 80, abs(value.translation.width) > abs(value.translation.height) else { return }
                        move(value.translation.width < 0 ? 1 : -1)
                    })

                    VStack(spacing: 6) {
                            HStack {
                                Button { move(-1) } label: {
                                    Text("上一张").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(index == 0)
                                Spacer()
                                Text("\(index + 1) / \(candidates.count)")
                                Spacer()
                                Button { move(1) } label: {
                                    Text("下一张").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(index + 1 >= candidates.count)
                            }
                            if let onKeep {
                                let isKept = candidate.confirmedKeep || keptDuringPreview.contains(candidate.id)
                                Button {
                                    keptDuringPreview.insert(candidate.id)
                                    onKeep(candidate.id)
                                } label: {
                                    Text(isKept ? "已确认保留" : "确认保留，不再提醒")
                                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                                }
                                    .buttonStyle(.plain)
                                    .disabled(isKept)
                                    .accessibilityIdentifier("media.keep")
                            }
                    }.padding(.horizontal).padding(.bottom, 8)
                } else {
                    ContentUnavailableView("此项目已不可用", systemImage: "photo", description: Text("内容或访问权限可能已变化，请关闭预览返回复核。"))
                }
            }
            .navigationTitle("逐项复核")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { showsDetails = true } label: { Image(systemName: "info.circle").frame(width: 44, height: 44) }
                        .accessibilityLabel("照片详情")
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .background(.black)
            .foregroundStyle(.white)
            .tint(.white)
            .sheet(isPresented: $showsDetails) {
                NavigationStack {
                    Form {
                        if let candidate {
                            Text(candidate.reason)
                            Text(candidate.estimatedBytes > 0 ? candidate.estimatedBytes.formattedStorage : "大小未知")
                        }
                        Text("预览不会改变删除选择。仅显示本地可读取内容，不下载 iCloud 原图。")
                    }
                    .navigationTitle("照片详情")
                    .toolbar { Button("完成") { showsDetails = false } }
                }.presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            guard currentID == nil else { return }
            currentID = initialID
            if let candidate { loader.load(candidate) }
        }
        .onDisappear { loader.cancel() }
        .onChange(of: candidates.map(\.id)) {
            if candidate == nil { loader.cancel() }
        }
    }

    private func move(_ offset: Int) {
        guard candidates.indices.contains(index + offset) else { return }
        currentID = candidates[index + offset].id
        zoom = 1
        normalizedCenter = CGPoint(x: 0.5, y: 0.5)
        photoPosition.scrollTo(point: .zero)
        if let candidate { loader.load(candidate) }
    }
}
