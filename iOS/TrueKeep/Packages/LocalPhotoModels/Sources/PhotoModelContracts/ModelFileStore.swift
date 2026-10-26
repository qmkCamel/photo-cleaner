import CryptoKit
import Foundation

public protocol ModelFileInstalling: Sendable {
    func installedModels() async -> Set<LocalPhotoModel>
    func directory(for model: LocalPhotoModel) async throws -> URL
    func install(_ model: LocalPhotoModel, progress: @escaping PhotoModelProgressHandler) async throws
    func remove(_ model: LocalPhotoModel) async throws
}

public actor ModelFileStore: ModelFileInstalling {
    private let root: URL
    private let session: URLSession
    private var busy = false

    public init(root: URL, session: URLSession? = nil) {
        self.root = root
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        self.session = session ?? URLSession(configuration: configuration)
    }

    private func path(_ model: LocalPhotoModel) -> URL {
        root.appendingPathComponent(model.id).appendingPathComponent(model.revision)
    }

    public func installedModels() -> Set<LocalPhotoModel> {
        Set(LocalPhotoModel.allCases.filter { (try? directory(for: $0)) != nil })
    }

    public func directory(for model: LocalPhotoModel) throws -> URL {
        let directory = path(model)
        guard let marker = try? Data(contentsOf: directory.appendingPathComponent("installed.json")),
              let files = try? JSONDecoder().decode([ModelFile].self, from: marker), files == model.files,
              model.files.allSatisfy({ Self.hasExpectedSize(directory.appendingPathComponent($0.name), file: $0) })
        else { throw PhotoModelError.notInstalled }
        return directory
    }

    public func install(_ model: LocalPhotoModel, progress: @escaping PhotoModelProgressHandler) async throws {
        guard !busy else { throw PhotoModelError.busy }
        busy = true
        defer { busy = false }
        if (try? directory(for: model)) != nil { return }
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let stagingPrefix = "staging-\(model.id)-"
        for abandoned in try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        where abandoned.lastPathComponent.hasPrefix(stagingPrefix) {
            try fm.removeItem(at: abandoned)
        }
        var rootURL = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try rootURL.setResourceValues(values)
        if let available = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage,
           available < model.downloadBytes + 512 * 1_024 * 1_024 {
            throw PhotoModelError.insufficientSpace
        }
        let staging = root.appendingPathComponent("\(stagingPrefix)\(UUID().uuidString)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        var finished: Int64 = 0
        for file in model.files {
            try Task.checkCancellation()
            let url = URL(string: "https://huggingface.co/\(model.repository)/resolve/\(model.revision)/\(file.name)")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 120
            let base = finished
            let total = model.downloadBytes
            let delegate = DownloadProgress { bytes in
                Task { await progress(.downloading(min(1, Double(base + bytes) / Double(total)))) }
            }
            let (temporary, response) = try await session.download(for: request, delegate: delegate)
            defer { try? fm.removeItem(at: temporary) }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw PhotoModelError.corruptDownload }
            try Self.verify(temporary, file: file)
            try fm.moveItem(at: temporary, to: staging.appendingPathComponent(file.name))
            finished += file.bytes
            await progress(.downloading(Double(finished) / Double(total)))
        }
        await progress(.verifying)
        try Task.checkCancellation()
        try JSONEncoder().encode(model.files).write(to: staging.appendingPathComponent("installed.json"), options: .atomic)
        let destination = path(model)
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Only an incomplete installation can be replaced; the valid one returned above stays untouched.
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: staging, to: destination)
    }

    public func remove(_ model: LocalPhotoModel) throws {
        guard !busy else { throw PhotoModelError.busy }
        let directory = root.appendingPathComponent(model.id)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    public static func hasExpectedSize(_ url: URL, file: ModelFile) -> Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value == file.bytes
    }

    public static func verify(_ url: URL, file: ModelFile) throws {
        guard hasExpectedSize(url, file: file) else { throw PhotoModelError.corruptDownload }
        guard let expected = file.sha256 else { return }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == expected else { throw PhotoModelError.corruptDownload }
    }
}

private final class DownloadProgress: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let update: @Sendable (Int64) -> Void
    private let lock = NSLock()
    private var lastUpdate = Date.distantPast
    init(update: @escaping @Sendable (Int64) -> Void) { self.update = update }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        let shouldUpdate = lock.withLock {
            let now = Date()
            guard now.timeIntervalSince(lastUpdate) >= 0.25 || totalBytesWritten == totalBytesExpectedToWrite else { return false }
            lastUpdate = now
            return true
        }
        if shouldUpdate { update(totalBytesWritten) }
    }
}
