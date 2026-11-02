import Foundation
import Photos
import Darwin

struct PhotoAnalysisCache: Codable {
    struct Entry: Codable {
        var assetID: String
        var metrics: PhotoVisualMetrics
        var usedAt: Date
    }
    static let algorithmVersion = "aspect-fit-v2-20261009"
    static let capacity = 2_000
    var entries: [String: Entry] = [:]

    static var fileURL: URL {
        URL.cachesDirectory.appendingPathComponent("TrueKeep", isDirectory: true)
            .appendingPathComponent("visual-analysis.json")
    }

    static func key(assetID: String, modified: Date?, width: Int, height: Int, stage: String) -> String {
        "\(algorithmVersion)|\(assetID)|\(modified?.timeIntervalSince1970 ?? -1)|\(width)x\(height)|\(stage)"
    }

    static func key(for asset: PHAsset, stage: String) -> String {
        key(assetID: asset.localIdentifier, modified: asset.modificationDate, width: asset.pixelWidth, height: asset.pixelHeight, stage: stage)
    }

    static func load() -> PhotoAnalysisCache {
        guard let data = try? Data(contentsOf: fileURL), data.count < 64 * 1_024 * 1_024,
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else { return .init() }
        var cache = decoded
        cache.trim()
        return cache
    }

    static func clear() { try? FileManager.default.removeItem(at: fileURL) }

    func metrics(for key: String) -> PhotoVisualMetrics? { entries[key]?.metrics }

    mutating func insert(_ metrics: PhotoVisualMetrics, key: String, assetID: String) {
        entries[key] = Entry(assetID: assetID, metrics: metrics, usedAt: Date())
        if entries.count > Self.capacity + 100 { trim() }
    }

    mutating func retainAssets(_ ids: Set<String>) {
        entries = entries.filter { ids.contains($0.value.assetID) }
    }

    mutating func trim() {
        guard entries.count > Self.capacity else { return }
        entries = Dictionary(uniqueKeysWithValues: entries.sorted { $0.value.usedAt > $1.value.usedAt }.prefix(Self.capacity).map { ($0.key, $0.value) })
    }

    mutating func save() {
        trim()
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: Self.fileURL, options: [.atomic, .completeFileProtection])
    }
}

enum PhotoMemorySample {
    static func megabytes() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : 0
    }
}
