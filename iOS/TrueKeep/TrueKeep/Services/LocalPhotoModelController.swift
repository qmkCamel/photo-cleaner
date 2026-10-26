import Foundation
import LocalPhotoModels
import SwiftUI
@preconcurrency import Photos
@preconcurrency import UIKit

@MainActor
final class LocalPhotoModelController: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var selectedModel: LocalPhotoModel
    @Published private(set) var installed: Set<LocalPhotoModel> = []
    @Published private(set) var progress: PhotoModelProgress?
    @Published private(set) var operation: Operation?
    @Published private(set) var isCancelling = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var report: PhotoSemanticReport?
    @Published private(set) var reportGroupID: String?
    let isFixture: Bool

    enum Operation { case download, remove, analyze }
    private let files: any ModelFileInstalling
    private let analyzer: any PhotoSemanticAnalyzing
    private let defaults: UserDefaults
    private var task: Task<Void, Never>?
    private var operationID = UUID()
    private var analysisGeneration = UUID()

    init(
        files: (any ModelFileInstalling)? = nil,
        analyzer: (any PhotoSemanticAnalyzing)? = nil,
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.defaults = defaults
        #if DEBUG
        let fixture = arguments.contains("-TrueKeepUITestLocalModels") && arguments.contains("-TrueKeepDisablePhotoDeletion")
        #else
        let fixture = false
        #endif
        self.isFixture = fixture
        self.isEnabled = fixture || defaults.bool(forKey: "truekeep.localModels.enabled")
        self.selectedModel = fixture ? .qwen : LocalPhotoModel(rawValue: defaults.string(forKey: "truekeep.localModels.selected") ?? "") ?? .qwen
        let root = URL.applicationSupportDirectory.appendingPathComponent("TrueKeep/LocalModels", isDirectory: true)
        #if DEBUG
        self.files = files ?? (fixture ? FixtureModelFiles() : ModelFileStore(root: root))
        self.analyzer = analyzer ?? (fixture ? FixturePhotoAnalyzer() : MLXPhotoSemanticAnalyzer())
        #else
        self.files = files ?? ModelFileStore(root: root)
        self.analyzer = analyzer ?? MLXPhotoSemanticAnalyzer()
        #endif
    }

    var isBusy: Bool { operation != nil }
    var deviceSupported: Bool {
        isFixture || ProcessInfo.processInfo.physicalMemory >= selectedModel.minimumMemoryBytes
    }
    var statusText: String {
        if isCancelling { return "正在停止…" }
        switch progress {
        case .downloading(let fraction): return "下载中 \(Int(fraction * 100))%"
        case .verifying: return "校验模型文件…"
        case .loading: return "加载本地模型…"
        case .analyzing(let completed, let total): return "分析中 \(completed)/\(total)"
        case nil: return operation == .remove ? "移除模型…" : "读取本地照片…"
        }
    }

    func refresh() async { installed = await files.installedModels() }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !isFixture { defaults.set(enabled, forKey: "truekeep.localModels.enabled") }
        if !enabled {
            cancel()
            invalidateAnalysis()
        }
    }

    func select(_ model: LocalPhotoModel) {
        guard !isBusy else { return }
        selectedModel = model
        if !isFixture { defaults.set(model.rawValue, forKey: "truekeep.localModels.selected") }
        invalidateAnalysis()
        errorMessage = nil
    }

    func download() {
        guard isEnabled, !isBusy, !installed.contains(selectedModel), deviceSupported else { return }
        let model = selectedModel
        run(.download) { [files] update in try await files.install(model, progress: update) }
    }

    func remove() {
        guard !isBusy else { return }
        let model = selectedModel
        invalidateAnalysis()
        run(.remove) { [files] _ in try await files.remove(model) }
    }

    func analyze(groupID: String, assetIDs: [String]) {
        guard isEnabled, !isBusy else { return }
        guard deviceSupported else { errorMessage = PhotoModelError.unavailable.localizedDescription; return }
        guard installed.contains(selectedModel) else { errorMessage = PhotoModelError.notInstalled.localizedDescription; return }
        guard !assetIDs.isEmpty else { errorMessage = PhotoModelError.invalidInput.localizedDescription; return }
        let model = selectedModel
        let generation = analysisGeneration
        let ids = Array(assetIDs.prefix(4))
        run(.analyze) { [weak self, files, analyzer, isFixture] update in
            let photos: [SemanticPhoto]
            if isFixture { photos = ids.map { .init(id: $0, data: Data()) } }
            else { photos = try await LocalSemanticImageLoader().load(ids) }
            let directory = try await files.directory(for: model)
            let result = try await analyzer.analyze(photos: photos, model: model, directory: directory, progress: update)
            try Task.checkCancellation()
            guard let self, self.analysisGeneration == generation, self.isEnabled else { return }
            self.report = result
            self.reportGroupID = groupID
        }
    }

    func cancel() {
        guard task != nil else { return }
        isCancelling = true
        task?.cancel()
    }

    func invalidateAnalysis() {
        analysisGeneration = UUID()
        if operation == .analyze { cancel() }
        report = nil
        reportGroupID = nil
        if operation == nil || operation == .analyze { errorMessage = nil }
    }

    private func run(
        _ kind: Operation,
        work: @escaping @MainActor (@escaping PhotoModelProgressHandler) async throws -> Void
    ) {
        guard !isBusy else { return }
        let id = UUID()
        operationID = id
        operation = kind
        progress = kind == .download ? .downloading(0) : nil
        errorMessage = nil
        isCancelling = false
        task = Task { [weak self] in
            do {
                try await work { [weak self] stage in
                    await self?.updateProgress(stage, id: id)
                }
            } catch {
                if !Task.isCancelled { self?.errorMessage = error.localizedDescription }
            }
            guard let self, self.operationID == id else { return }
            await self.refresh()
            self.operation = nil
            self.progress = nil
            self.isCancelling = false
            self.task = nil
        }
    }

    private func updateProgress(_ value: PhotoModelProgress, id: UUID) {
        guard operationID == id, isBusy, !isCancelling else { return }
        if case .downloading(let next) = value {
            if case .verifying = progress { return }
            if case .downloading(let previous) = progress, next < previous { return }
        }
        progress = value
    }
}

private actor LocalSemanticImageLoader {
    func load(_ assetIDs: [String]) throws -> [SemanticPhoto] {
        let access = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard access == .authorized || access == .limited else { throw PhotoModelError.invalidInput }
        let manager = PHImageManager()
        return try assetIDs.map { id in
            try Task.checkCancellation()
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject,
                  asset.mediaType == .image else { throw PhotoModelError.invalidInput }
            let image = PhotoImageRequestStrategy.firstAvailable { deliveryMode -> UIImage? in
                var result: UIImage?
                manager.requestImage(
                    for: asset, targetSize: CGSize(width: 768, height: 768), contentMode: .aspectFit,
                    options: PhotoImageRequestStrategy.requestOptions(deliveryMode: deliveryMode)
                ) { image, info in
                    if info?[PHImageErrorKey] == nil, (info?[PHImageCancelledKey] as? Bool) != true { result = image }
                }
                return result
            }
            guard let image, let normalized = PhotoImageOrientationNormalizer.normalizedCGImage(from: image),
                  let data = UIImage(cgImage: normalized).jpegData(compressionQuality: 0.9) else {
                throw PhotoModelError.invalidInput
            }
            return SemanticPhoto(id: id, data: data)
        }
    }
}

#if DEBUG
private actor FixtureModelFiles: ModelFileInstalling {
    private var installed: Set<LocalPhotoModel> = [.qwen, .gemma]
    func installedModels() -> Set<LocalPhotoModel> { installed }
    func directory(for model: LocalPhotoModel) throws -> URL {
        guard installed.contains(model) else { throw PhotoModelError.notInstalled }
        return URL(fileURLWithPath: "/fixture-not-a-real-model")
    }
    func install(_ model: LocalPhotoModel, progress: @escaping PhotoModelProgressHandler) async throws {
        for index in 0...10 {
            try await Task.sleep(for: .milliseconds(700))
            await progress(.downloading(Double(index) / 10))
        }
        installed.insert(model)
    }
    func remove(_ model: LocalPhotoModel) { installed.remove(model) }
}

private actor FixturePhotoAnalyzer: PhotoSemanticAnalyzing {
    private var calls = 0
    func analyze(
        photos: [SemanticPhoto], model: LocalPhotoModel, directory: URL, progress: @escaping PhotoModelProgressHandler
    ) async throws -> PhotoSemanticReport {
        calls += 1
        await progress(.loading)
        try await Task.sleep(for: .seconds(1))
        await progress(.analyzing(completed: 0, total: photos.count))
        try await Task.sleep(for: .seconds(4))
        if calls == 2 { throw PhotoModelError.invalidOutput }
        return .init(model: model, photos: photos.map {
            .init(id: $0.id, observation: .init(subject: "测试画面", observations: ["合成测试观察，不是真实模型输出"], uncertain: true))
        }, completedAt: Date(), elapsedSeconds: 5)
    }
}
#endif
