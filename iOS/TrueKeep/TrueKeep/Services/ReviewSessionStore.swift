import Foundation
import Photos

struct SavedReviewSession: Codable {
    var version = 2
    var state: CleanupFlowState
    var completedRange: PhotoScanDateRange?

    mutating func expireReviewBin(now: Date) {
        let cutoff = now.addingTimeInterval(-30 * 24 * 60 * 60)
        state.reviewBinItems.removeAll { $0.addedAt < cutoff }
    }
}

struct ReviewSessionStore {
    var fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory
            .appendingPathComponent("TrueKeep", isDirectory: true)
            .appendingPathComponent("review-session.json")
    }

    func load(now: Date = Date()) throws -> SavedReviewSession? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        var session = try JSONDecoder().decode(SavedReviewSession.self, from: Data(contentsOf: fileURL))
        guard session.version == 2 else { throw CocoaError(.coderReadCorrupt) }
        session.expireReviewBin(now: now)
        return session
    }

    func save(_ session: SavedReviewSession) throws {
        let data = try JSONEncoder().encode(session)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func rebuildPreservingBackup(_ session: SavedReviewSession) throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("review-session-backup-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: fileURL, to: backup)
        }
        try save(session)
    }
}

extension Notification.Name {
    static let trueKeepPhotoLibraryChanged = Notification.Name("truekeep.photoLibraryChanged")
    static let trueKeepThumbnailsInvalidated = Notification.Name("truekeep.thumbnailsInvalidated")
}

final class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        NotificationCenter.default.post(name: .trueKeepPhotoLibraryChanged, object: nil)
    }
}

struct PhotoScanReport: Codable, Hashable, Sendable {
    var eligiblePhotos = 0
    var analyzedPhotos = 0
    var unavailablePhotos = 0
    var cacheHits = 0
    var refinedPhotos = 0
    var elapsedSeconds: Double = 0
    var sampledPeakMemoryMB: Double = 0
    var lowPowerMode = false

    var summary: String {
        "照片分析 \(analyzedPhotos)/\(eligiblePhotos) · 本地不可读取 \(unavailablePhotos) · 复用缓存 \(cacheHits)"
    }
}

struct ScanEvaluationExport: Codable {
    var similarGroups: [[String]]
    var exactGroups: [[String]]
    var blurry: [String]
    var accidental: [String]
    var report: PhotoScanReport?
}
