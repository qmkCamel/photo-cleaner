import Foundation

public struct SemanticPhoto: Sendable {
    public let id: String
    public let data: Data

    public init(id: String, data: Data) {
        self.id = id
        self.data = data
    }
}

public struct PhotoObservation: Codable, Equatable, Sendable {
    public let subject: String
    public let observations: [String]
    public let uncertain: Bool

    public init(subject: String, observations: [String], uncertain: Bool) {
        self.subject = subject
        self.observations = observations
        self.uncertain = uncertain
    }

    public static func decode(_ text: String) throws -> Self {
        // Accept a single fenced JSON object, never extract arbitrary embedded instructions.
        var json = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasPrefix("```json\n"), json.hasSuffix("```") {
            json = String(json.dropFirst(8).dropLast(3))
        }
        let data = Data(json.utf8)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["subject", "observations", "uncertain"] else { throw PhotoModelError.invalidOutput }
        let result = try JSONDecoder().decode(Self.self, from: data)
        guard !result.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              result.subject.count <= 160, result.observations.count <= 4,
              result.observations.allSatisfy({ !$0.isEmpty && $0.count <= 240 }),
              result.uncertain || !result.observations.isEmpty else {
            throw PhotoModelError.invalidOutput
        }
        return result
    }

    public static func unverifiedCaption(_ text: String) throws -> Self {
        let caption = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !caption.isEmpty, caption.count <= 160,
              !caption.contains("\n"), !caption.contains("\r"), !caption.contains("```"),
              !caption.contains("<think>"), !caption.contains("</think>"),
              !caption.hasPrefix("{"), !caption.hasPrefix("[") else { throw PhotoModelError.invalidOutput }
        return .init(subject: caption, observations: [], uncertain: true)
    }
}

public struct SemanticPhotoResult: Sendable, Identifiable {
    public let id: String
    public let observation: PhotoObservation
    public init(id: String, observation: PhotoObservation) {
        self.id = id
        self.observation = observation
    }
}

public struct PhotoSemanticReport: Sendable {
    public let model: LocalPhotoModel
    public let photos: [SemanticPhotoResult]
    public let completedAt: Date
    public let elapsedSeconds: Double
    public static let promptVersion = "observations-v2"

    public init(model: LocalPhotoModel, photos: [SemanticPhotoResult], completedAt: Date, elapsedSeconds: Double) {
        self.model = model
        self.photos = photos
        self.completedAt = completedAt
        self.elapsedSeconds = elapsedSeconds
    }
}

public enum PhotoModelProgress: Equatable, Sendable {
    case downloading(Double)
    case verifying
    case loading
    case analyzing(completed: Int, total: Int)
}

public typealias PhotoModelProgressHandler = @Sendable (PhotoModelProgress) async -> Void

public protocol PhotoSemanticAnalyzing: Sendable {
    func analyze(
        photos: [SemanticPhoto], model: LocalPhotoModel, directory: URL,
        progress: @escaping PhotoModelProgressHandler
    ) async throws -> PhotoSemanticReport
}

public enum PhotoModelError: Error, LocalizedError, Sendable {
    case invalidOutput, invalidInput, notInstalled, insufficientSpace, corruptDownload
    case unavailable, busy, timedOut, thermalLimit

    public var errorDescription: String? {
        switch self {
        case .invalidOutput: "模型未返回有效的观察结果，请重试。"
        case .invalidInput: "需要 1 至 4 张本地可读取的照片。"
        case .notInstalled: "请先在设置中下载所选模型。"
        case .insufficientSpace: "剩余空间不足，请释放空间后重试。"
        case .corruptDownload: "模型文件校验失败，请重新下载。"
        case .unavailable: "当前设备不支持本地模型推理。"
        case .busy: "已有模型任务正在进行。"
        case .timedOut: "分析超时，请减少照片数量后重试。"
        case .thermalLimit: "设备温度较高，请稍后重试。"
        }
    }
}
