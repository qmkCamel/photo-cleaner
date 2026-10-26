import Darwin
import Foundation
import LocalPhotoModels

@main
struct LocalModelSmoke {
    static func main() async {
        do { try await run() }
        catch {
            FileHandle.standardError.write(Data("Model smoke failed: \(error)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func run() async throws {
        let args = CommandLine.arguments
        guard args.count == 5, let model = LocalPhotoModel(rawValue: args[2]),
              ["install", "analyze"].contains(args[1]) else {
            print("Usage: local-model-smoke install|analyze qwen3.5-0.8b|gemma4-e2b MODEL_ROOT IMAGE_PATH")
            return
        }
        let store = ModelFileStore(root: URL(fileURLWithPath: args[3]))
        if args[1] == "install" {
            try await store.install(model) { stage in
                if case .verifying = stage { print("Verifying \(model.title)") }
            }
            print("Installed \(model.title) \(model.revision)")
            return
        }
        let directory = try await store.directory(for: model)
        let data = try Data(contentsOf: URL(fileURLWithPath: args[4]))
        let observer: (@Sendable (String) -> Void)?
        if ProcessInfo.processInfo.environment["TRUEKEEP_MODEL_SMOKE_OUTPUT"] == "1" {
            observer = { @Sendable (output: String) in print("Raw model output: \(output)") }
        } else {
            observer = nil
        }
        let result = try await MLXPhotoSemanticAnalyzer(outputObserver: observer).analyze(
            photos: [.init(id: "smoke-image", data: data)], model: model, directory: directory,
            progress: { print(String(describing: $0)) }
        )
        print("model=\(model.id) revision=\(model.revision) seconds=\(result.elapsedSeconds)")
        for photo in result.photos { print(String(decoding: try JSONEncoder().encode(photo.observation), as: UTF8.self)) }
    }
}
