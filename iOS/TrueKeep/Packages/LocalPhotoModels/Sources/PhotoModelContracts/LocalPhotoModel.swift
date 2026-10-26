import Foundation

public struct ModelFile: Codable, Equatable, Sendable {
    public let name: String
    public let bytes: Int64
    public let sha256: String?
    public init(_ name: String, _ bytes: Int64, _ sha256: String? = nil) {
        self.name = name
        self.bytes = bytes
        self.sha256 = sha256
    }
}

public enum LocalPhotoModel: String, Codable, CaseIterable, Identifiable, Sendable {
    case qwen = "qwen3.5-0.8b"
    case gemma = "gemma4-e2b"

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .qwen: "Qwen3.5-0.8B"
        case .gemma: "Gemma 4 E2B"
        }
    }
    public var repository: String {
        switch self {
        case .qwen: "mlx-community/Qwen3.5-0.8B-4bit"
        case .gemma: "mlx-community/gemma-4-e2b-it-4bit"
        }
    }
    public var revision: String {
        switch self {
        case .qwen: "da28692b5f139cb0ec58a356b437486b7dac7462"
        case .gemma: "238767527555cb75a05732a84dff5d6ba0dd6809"
        }
    }
    public var minimumMemoryBytes: UInt64 {
        // Physical memory excludes hardware reservations; approximate the 6 GB / 8 GB device classes.
        switch self {
        case .qwen: 5 * 1_024 * 1_024 * 1_024
        case .gemma: 7 * 1_024 * 1_024 * 1_024
        }
    }
    public var downloadBytes: Int64 { files.reduce(0) { $0 + $1.bytes } }
    public var sourceURL: URL { URL(string: "https://huggingface.co/\(repository)/tree/\(revision)")! }
    public var licenseURL: URL {
        switch self {
        case .qwen: URL(string: "https://huggingface.co/Qwen/Qwen3.5-0.8B")!
        case .gemma: URL(string: "https://huggingface.co/mlx-community/gemma-4-e2b-it-4bit")!
        }
    }
    public var files: [ModelFile] {
        switch self {
        case .qwen:
            [
                .init("README.md", 678), .init("chat_template.jinja", 7755),
                .init("config.json", 3112),
                .init("model.safetensors", 625229487, "f5a0d9dd3efa73510542a8023d610ff26be2b4b020d181cfc4bedaa1fcc5dd9e"),
                .init("model.safetensors.index.json", 71473),
                .init("preprocessor_config.json", 390), .init("processor_config.json", 1300),
                .init("tokenizer.json", 19989343, "87a7830d63fcf43bf241c3c5242e96e62dd3fdc29224ca26fed8ea333db72de4"),
                .init("tokenizer_config.json", 1139), .init("video_preprocessor_config.json", 385),
                .init("vocab.json", 6722759)
            ]
        case .gemma:
            [
                .init("README.md", 593), .init("chat_template.jinja", 17336),
                .init("config.json", 6395), .init("generation_config.json", 208),
                .init("model.safetensors", 3550670554, "038e39a37a7667373d2c3991375446b10c96ae1d717a68674870343db376b76e"),
                .init("model.safetensors.index.json", 218323), .init("processor_config.json", 1316),
                .init("tokenizer.json", 32169626, "cc8d3a0ce36466ccc1278bf987df5f71db1719b9ca6b4118264f45cb627bfe0f"),
                .init("tokenizer_config.json", 2740)
            ]
        }
    }
}
